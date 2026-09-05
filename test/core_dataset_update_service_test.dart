import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/bundled_content_sync.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_transport.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_update.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_update_service.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseSchema.create(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('unconfigured updater stays offline and reports bundled version', () async {
    final bytes = _FakeByteSource(const {});
    final attempt = await CoreDatasetUpdateService(
      manifestUrl: '   ',
      byteSource: bytes,
    ).checkAndApply(db);

    expect(attempt.outcome, CoreDatasetUpdateAttemptOutcome.notConfigured);
    expect(attempt.installedVersion, 1);
    expect(attempt.latestVersion, isNull);
    expect(bytes.requestedUris, isEmpty);
  });

  test('offline manifest fetch is non-destructive and reported unavailable', () async {
    final attempt = await CoreDatasetUpdateService(
      manifestUrl: 'https://updates.example.org/latest.json',
      byteSource: const _OfflineByteSource(),
    ).checkAndApply(db);

    expect(attempt.outcome, CoreDatasetUpdateAttemptOutcome.unavailable);
    expect(attempt.installedVersion, 1);
    expect(await db.query('species'), isEmpty);
    expect(
      await db.query(
        'bundled_content_state',
        where: 'content_key=?',
        whereArgs: const [coreDatasetKey],
      ),
      isEmpty,
    );
  });

  test('configured verified update reports new installed version', () async {
    final manifestUri = Uri.parse('https://updates.example.org/latest.json');
    final packageUri = Uri.parse('https://updates.example.org/core-v2.json');
    final packageBytes = _packageBytes(datasetVersion: 2);
    final manifestBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'manifest_version': 1,
          'dataset_key': coreDatasetKey,
          'dataset_version': 2,
          'database_schema_version': DatabaseSchema.currentVersion,
          'published_at': '2026-09-05T07:30:00Z',
          'package_url': packageUri.toString(),
          'package_sha256': sha256.convert(packageBytes).toString(),
          'package_size_bytes': packageBytes.length,
          'components': const ['species_catalog'],
        }),
      ),
    );
    final bytes = _FakeByteSource({
      manifestUri: manifestBytes,
      packageUri: packageBytes,
    });

    final attempt = await CoreDatasetUpdateService(
      manifestUrl: manifestUri.toString(),
      byteSource: bytes,
    ).checkAndApply(db);

    expect(attempt.outcome, CoreDatasetUpdateAttemptOutcome.updated);
    expect(attempt.installedVersion, 2);
    expect(attempt.latestVersion, 2);
    expect(await db.query('species'), hasLength(1));
    expect(bytes.requestedUris, [manifestUri, packageUri]);
  });

  test('invalid remote content is rejected without activation', () async {
    final manifestUri = Uri.parse('https://updates.example.org/latest.json');
    final invalidManifest = Uint8List.fromList(utf8.encode('{"not":"a manifest"}'));
    final bytes = _FakeByteSource({manifestUri: invalidManifest});

    final attempt = await CoreDatasetUpdateService(
      manifestUrl: manifestUri.toString(),
      byteSource: bytes,
    ).checkAndApply(db);

    expect(attempt.outcome, CoreDatasetUpdateAttemptOutcome.rejected);
    expect(attempt.installedVersion, 1);
    expect(await db.query('species'), isEmpty);
  });

  test('newer remote dataset prevents bundled reference overwrite', () async {
    await db.insert('bundled_content_state', {
      'content_key': coreDatasetKey,
      'revision': 2,
      'synced_at': '2026-09-05T07:30:00Z',
    });
    var ranBundledSync = false;

    final failures = await BundledContentSync.runIfNeeded(db, () async {
      ranBundledSync = true;
      return const [];
    });

    expect(failures, isEmpty);
    expect(ranBundledSync, isFalse);
    expect(
      await db.query(
        'bundled_content_state',
        where: 'content_key=?',
        whereArgs: const [BundledContentSync.contentKey],
      ),
      isEmpty,
    );
  });

  test('bundled reference sync may run when remote version is not newer', () async {
    await db.insert('bundled_content_state', {
      'content_key': coreDatasetKey,
      'revision': 1,
      'synced_at': '2026-09-05T07:30:00Z',
    });
    var ranBundledSync = false;

    final failures = await BundledContentSync.runIfNeeded(db, () async {
      ranBundledSync = true;
      return const [];
    });

    expect(failures, isEmpty);
    expect(ranBundledSync, isTrue);
    final rows = await db.query(
      'bundled_content_state',
      where: 'content_key=?',
      whereArgs: const [BundledContentSync.contentKey],
    );
    expect(rows.single['revision'], BundledContentSync.revision);
  });
}

class _FakeByteSource implements CoreDatasetByteSource {
  _FakeByteSource(this.responses);

  final Map<Uri, Uint8List> responses;
  final List<Uri> requestedUris = [];

  @override
  Future<Uint8List> fetch(Uri uri, {required int maxBytes}) async {
    requestedUris.add(uri);
    final response = responses[uri];
    if (response == null) throw StateError('No fake response for $uri');
    if (response.length > maxBytes) {
      throw FormatException('Fake response exceeds $maxBytes bytes');
    }
    return response;
  }
}

class _OfflineByteSource implements CoreDatasetByteSource {
  const _OfflineByteSource();

  @override
  Future<Uint8List> fetch(Uri uri, {required int maxBytes}) {
    throw const SocketException('offline');
  }
}

Uint8List _packageBytes({required int datasetVersion}) => Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'package_version': 1,
          'dataset_key': coreDatasetKey,
          'dataset_version': datasetVersion,
          'database_schema_version': DatabaseSchema.currentVersion,
          'components': {'species_catalog': _catalogue()},
        }),
      ),
    );

Map<String, dynamic> _catalogue() => {
      'sources': [
        {
          'id': 'test-source',
          'title': 'Test source',
          'version': '1',
          'url': 'https://example.org/source',
          'license': 'CC BY 4.0',
          'citation': 'Test source citation',
          'retrieved_at': '2026-09-05',
        },
      ],
      'taxa': [
        {
          'id': 1,
          'parent_id': null,
          'rank': 'species',
          'scientific_name': 'Testus exemplaris',
          'author_citation': null,
        },
      ],
      'species': [
        {
          'id': 1,
          'taxon_id': 1,
          'catalog_only': true,
          'edible_status': 'unknown',
          'toxicity_level': 'unknown',
          'source_id': 'test-source',
          'source_record_id': 'test-1',
          'texts': {
            'nl': {
              'common_name': 'Testpaddenstoel',
              'summary': null,
              'description': null,
              'habitat': null,
              'lookalikes': null,
            },
          },
        },
      ],
    };
