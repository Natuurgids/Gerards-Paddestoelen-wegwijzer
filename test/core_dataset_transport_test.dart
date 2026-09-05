import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_transport.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_update.dart';
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

  test('verified package downloads and applies newer dataset', () async {
    final packageBytes = _packageBytes(datasetVersion: 2);
    final packageUri = Uri.parse('https://updates.example.org/core-v2.json');
    final source = _FixedManifestSource(
      _manifest(
        datasetVersion: 2,
        packageUri: packageUri,
        packageBytes: packageBytes,
      ),
    );
    final bytes = _FakeByteSource({packageUri: packageBytes});

    final result = await CoreDatasetUpdater(
      manifestSource: source,
      byteSource: bytes,
    ).checkAndApply(db);

    expect(result.outcome, CoreDatasetUpdateOutcome.updated);
    expect(result.installedBefore.datasetVersion, 1);
    expect(result.installedAfter.datasetVersion, 2);
    expect(await db.query('species'), hasLength(1));
    expect(bytes.requestedUris, [packageUri]);
  });

  test('SHA-256 mismatch is rejected before database activation', () async {
    final packageBytes = _packageBytes(datasetVersion: 2);
    final packageUri = Uri.parse('https://updates.example.org/core-v2.json');
    final source = _FixedManifestSource(
      CoreDatasetUpdateManifest.fromDecoded({
        'manifest_version': 1,
        'dataset_key': coreDatasetKey,
        'dataset_version': 2,
        'database_schema_version': DatabaseSchema.currentVersion,
        'published_at': '2026-09-05T07:00:00Z',
        'package_url': packageUri.toString(),
        'package_sha256': List.filled(64, '0').join(),
        'package_size_bytes': packageBytes.length,
        'components': const ['species_catalog'],
      }),
    );
    final bytes = _FakeByteSource({packageUri: packageBytes});

    await expectLater(
      CoreDatasetUpdater(
        manifestSource: source,
        byteSource: bytes,
      ).checkAndApply(db),
      throwsFormatException,
    );

    expect(await db.query('species'), isEmpty);
    final state = await db.query(
      'bundled_content_state',
      where: 'content_key=?',
      whereArgs: const [coreDatasetKey],
    );
    expect(state, isEmpty);
  });

  test('package size mismatch is rejected before hash or activation', () async {
    final packageBytes = _packageBytes(datasetVersion: 2);
    final packageUri = Uri.parse('https://updates.example.org/core-v2.json');
    final manifest = CoreDatasetUpdateManifest.fromDecoded({
      'manifest_version': 1,
      'dataset_key': coreDatasetKey,
      'dataset_version': 2,
      'database_schema_version': DatabaseSchema.currentVersion,
      'published_at': '2026-09-05T07:00:00Z',
      'package_url': packageUri.toString(),
      'package_sha256': sha256.convert(packageBytes).toString(),
      'package_size_bytes': packageBytes.length + 1,
      'components': const ['species_catalog'],
    });
    final bytes = _FakeByteSource({packageUri: packageBytes});

    await expectLater(
      CoreDatasetUpdater(
        manifestSource: _FixedManifestSource(manifest),
        byteSource: bytes,
      ).checkAndApply(db),
      throwsFormatException,
    );
    expect(await db.query('species'), isEmpty);
  });

  test('up-to-date dataset does not download package bytes', () async {
    final packageBytes = _packageBytes(datasetVersion: 1);
    final packageUri = Uri.parse('https://updates.example.org/core-v1.json');
    final bytes = _FakeByteSource({packageUri: packageBytes});

    final result = await CoreDatasetUpdater(
      manifestSource: _FixedManifestSource(
        _manifest(
          datasetVersion: 1,
          packageUri: packageUri,
          packageBytes: packageBytes,
        ),
      ),
      byteSource: bytes,
    ).checkAndApply(db);

    expect(result.outcome, CoreDatasetUpdateOutcome.upToDate);
    expect(bytes.requestedUris, isEmpty);
  });

  test('remote manifest source pins package to configured HTTPS origin', () async {
    final manifestUri = Uri.parse('https://updates.example.org/latest.json');
    final packageBytes = _packageBytes(datasetVersion: 2);
    final packageUri = Uri.parse('https://cdn.example.net/core-v2.json');
    final manifestBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode(
          _manifestDecoded(
            datasetVersion: 2,
            packageUri: packageUri,
            packageBytes: packageBytes,
          ),
        ),
      ),
    );
    final bytes = _FakeByteSource({manifestUri: manifestBytes});
    final source = RemoteCoreDatasetUpdateSource(
      manifestUri: manifestUri,
      byteSource: bytes,
    );

    await expectLater(source.loadLatestManifest(), throwsFormatException);
    expect(bytes.requestedUris, [manifestUri]);
  });

  test('remote manifest endpoint itself must be trusted HTTPS', () {
    expect(
      () => RemoteCoreDatasetUpdateSource(
        manifestUri: Uri.parse('http://updates.example.org/latest.json'),
        byteSource: _FakeByteSource(const {}),
      ),
      throwsFormatException,
    );
    expect(
      () => RemoteCoreDatasetUpdateSource(
        manifestUri: Uri.parse('https://user@updates.example.org/latest.json'),
        byteSource: _FakeByteSource(const {}),
      ),
      throwsFormatException,
    );
  });
}

class _FixedManifestSource implements CoreDatasetUpdateSource {
  const _FixedManifestSource(this.manifest);

  final CoreDatasetUpdateManifest manifest;

  @override
  Future<CoreDatasetUpdateManifest> loadLatestManifest() async => manifest;
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

CoreDatasetUpdateManifest _manifest({
  required int datasetVersion,
  required Uri packageUri,
  required Uint8List packageBytes,
}) =>
    CoreDatasetUpdateManifest.fromDecoded(
      _manifestDecoded(
        datasetVersion: datasetVersion,
        packageUri: packageUri,
        packageBytes: packageBytes,
      ),
    );

Map<String, dynamic> _manifestDecoded({
  required int datasetVersion,
  required Uri packageUri,
  required Uint8List packageBytes,
}) =>
    {
      'manifest_version': 1,
      'dataset_key': coreDatasetKey,
      'dataset_version': datasetVersion,
      'database_schema_version': DatabaseSchema.currentVersion,
      'published_at': '2026-09-05T07:00:00Z',
      'package_url': packageUri.toString(),
      'package_sha256': sha256.convert(packageBytes).toString(),
      'package_size_bytes': packageBytes.length,
      'components': const ['species_catalog'],
    };

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
