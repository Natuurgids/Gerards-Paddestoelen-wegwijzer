import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_transport.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package_installer.dart';

void main() {
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

  test('unconfigured installer performs no network request', () async {
    final bytes = _FakeByteSource(const {});
    final result = await LearningPackageInstaller(
      catalogUrl: ' ',
      entitlements: _Entitlements(const []),
      byteSource: bytes,
    ).install(db, 'boletes-pores');

    expect(result.outcome, LearningPackageInstallOutcome.notConfigured);
    expect(bytes.requestedUris, isEmpty);
  });

  test('missing entitlement never downloads package bytes', () async {
    final fixture = _fixture(contentVersion: 1);
    final bytes = _FakeByteSource({fixture.catalogUri: fixture.catalogBytes});

    final result = await LearningPackageInstaller(
      catalogUrl: fixture.catalogUri.toString(),
      entitlements: _Entitlements(const []),
      byteSource: bytes,
    ).install(db, fixture.packageKey);

    expect(result.outcome, LearningPackageInstallOutcome.notEntitled);
    expect(bytes.requestedUris, [fixture.catalogUri]);
    expect(await db.query('lesson'), isEmpty);
    expect(await _stateRows(db, fixture.packageKey), isEmpty);
  });

  test('verified entitled package installs atomically and records state', () async {
    final fixture = _fixture(contentVersion: 1);
    final bytes = _FakeByteSource({
      fixture.catalogUri: fixture.catalogBytes,
      fixture.packageUri: fixture.packageBytes,
    });

    final result = await LearningPackageInstaller(
      catalogUrl: fixture.catalogUri.toString(),
      entitlements: _Entitlements([fixture.entitlementKey]),
      byteSource: bytes,
    ).install(
      db,
      fixture.packageKey,
      installedAt: DateTime.utc(2026, 9, 5, 12),
    );

    expect(result.outcome, LearningPackageInstallOutcome.installed);
    expect(result.contentVersion, 1);
    expect(bytes.requestedUris, [fixture.catalogUri, fixture.packageUri]);
    expect((await db.query('lesson')).single['id'], 1000);
    expect((await _stateRows(db, fixture.packageKey)).single['revision'], 1);
    expect(await db.query('training_progress'), isEmpty);
  });

  test('current installed package skips package download', () async {
    final fixture = _fixture(contentVersion: 1);
    await db.insert('bundled_content_state', {
      'content_key': 'learning-package:${fixture.packageKey}',
      'revision': 1,
      'synced_at': '2026-09-05T12:00:00.000Z',
    });
    final bytes = _FakeByteSource({fixture.catalogUri: fixture.catalogBytes});

    final result = await LearningPackageInstaller(
      catalogUrl: fixture.catalogUri.toString(),
      entitlements: _Entitlements([fixture.entitlementKey]),
      byteSource: bytes,
    ).install(db, fixture.packageKey);

    expect(result.outcome, LearningPackageInstallOutcome.alreadyCurrent);
    expect(bytes.requestedUris, [fixture.catalogUri]);
  });

  test('hash mismatch rejects package without lessons or install state', () async {
    final fixture = _fixture(contentVersion: 1, catalogShaOverride: '0' * 64);
    final bytes = _FakeByteSource({
      fixture.catalogUri: fixture.catalogBytes,
      fixture.packageUri: fixture.packageBytes,
    });

    expect(
      () => LearningPackageInstaller(
        catalogUrl: fixture.catalogUri.toString(),
        entitlements: _Entitlements([fixture.entitlementKey]),
        byteSource: bytes,
      ).install(db, fixture.packageKey),
      throwsA(isA<FormatException>()),
    );
    expect(await db.query('lesson'), isEmpty);
    expect(await _stateRows(db, fixture.packageKey), isEmpty);
  });

  test('package update preserves existing training progress', () async {
    final first = _fixture(contentVersion: 1, bodySuffix: ' v1');
    final firstBytes = _FakeByteSource({
      first.catalogUri: first.catalogBytes,
      first.packageUri: first.packageBytes,
    });
    final installer = LearningPackageInstaller(
      catalogUrl: first.catalogUri.toString(),
      entitlements: _Entitlements([first.entitlementKey]),
      byteSource: firstBytes,
    );
    await installer.install(db, first.packageKey);
    await db.insert('training_progress', {
      'lesson_id': 1000,
      'completed_at': '2026-09-05T12:15:00.000Z',
      'best_score': 1.0,
      'attempts': 2,
    });

    final second = _fixture(contentVersion: 2, bodySuffix: ' v2');
    final secondBytes = _FakeByteSource({
      second.catalogUri: second.catalogBytes,
      second.packageUri: second.packageBytes,
    });
    final result = await LearningPackageInstaller(
      catalogUrl: second.catalogUri.toString(),
      entitlements: _Entitlements([second.entitlementKey]),
      byteSource: secondBytes,
    ).install(db, second.packageKey);

    expect(result.outcome, LearningPackageInstallOutcome.installed);
    final progress = (await db.query('training_progress')).single;
    expect(progress['best_score'], 1.0);
    expect(progress['attempts'], 2);
    expect((await _stateRows(db, second.packageKey)).single['revision'], 2);
    final text = (await db.query(
      'lesson_text',
      where: 'lesson_id=? AND language_code=?',
      whereArgs: const [1000, 'nl'],
    )).single;
    expect(text['body'], endsWith('v2'));
  });
}

Future<List<Map<String, Object?>>> _stateRows(Database db, String packageKey) =>
    db.query(
      'bundled_content_state',
      where: 'content_key=?',
      whereArgs: ['learning-package:$packageKey'],
    );

class _Fixture {
  const _Fixture({
    required this.packageKey,
    required this.entitlementKey,
    required this.catalogUri,
    required this.packageUri,
    required this.catalogBytes,
    required this.packageBytes,
  });

  final String packageKey;
  final String entitlementKey;
  final Uri catalogUri;
  final Uri packageUri;
  final Uint8List catalogBytes;
  final Uint8List packageBytes;
}

_Fixture _fixture({
  required int contentVersion,
  String bodySuffix = '',
  String? catalogShaOverride,
}) {
  const packageKey = 'boletes-pores';
  const entitlementKey = 'learning.specialist.boletes-pores';
  final catalogUri = Uri.parse('https://learning.example.org/learning_package_catalog.json');
  final packageUri = Uri.parse('https://learning.example.org/packages/boletes-pores.json');
  final packageBytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'package_version': 1,
        'package_key': packageKey,
        'content_version': contentVersion,
        'course': {
          'key': 'specialist-boletes-pores',
          'access': 'entitlement_required',
          'delivery': 'downloadable',
          'entitlement_key': entitlementKey,
          'product_key': 'learning_pack_boletes_pores',
          'group_key': 'specializations',
          'sort_order': 110,
          'prerequisite_course_keys': ['determination-foundations'],
        },
        'modules': [
          {
            'key': 'boletes-pores-basics',
            'course_key': 'specialist-boletes-pores',
            'lesson_ids': [1000],
            'sort_order': 10,
          },
        ],
        'training_content': {
          'version': 2,
          'lessons': [
            {
              'id': 1000,
              'slug': 'boletes-pores-basics',
              'difficulty': 2,
              'sort_order': 1,
              'texts': {
                'nl': {'title': 'Boleten', 'body': 'Nederlandse les$bodySuffix'},
                'en': {'title': 'Boletes', 'body': 'English lesson$bodySuffix'},
                'de': {'title': 'Röhrlinge', 'body': 'Deutsche Lektion$bodySuffix'},
              },
              'questions': [
                {
                  'id': 10000,
                  'sort_order': 1,
                  'texts': {
                    'nl': {'prompt': 'Welke structuur?', 'explanation': 'Bekijk meerdere kenmerken.'},
                    'en': {'prompt': 'Which structure?', 'explanation': 'Use multiple characters.'},
                    'de': {'prompt': 'Welche Struktur?', 'explanation': 'Nutze mehrere Merkmale.'},
                  },
                  'answers': [
                    {
                      'id': 100000,
                      'correct': true,
                      'sort_order': 1,
                      'labels': {'nl': 'Poriën', 'en': 'Pores', 'de': 'Poren'},
                    },
                    {
                      'id': 100001,
                      'correct': false,
                      'sort_order': 2,
                      'labels': {'nl': 'Alleen kleur', 'en': 'Colour only', 'de': 'Nur Farbe'},
                    },
                  ],
                },
              ],
            },
          ],
        },
      }),
    ),
  );
  final digest = sha256.convert(packageBytes).toString();
  final catalogBytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'catalog_version': 1,
        'packages': [
          {
            'package_key': packageKey,
            'course_key': 'specialist-boletes-pores',
            'entitlement_key': entitlementKey,
            'product_key': 'learning_pack_boletes_pores',
            'content_version': contentVersion,
            'package_path': 'packages/boletes-pores.json',
            'package_sha256': catalogShaOverride ?? digest,
            'package_size_bytes': packageBytes.length,
            'sort_order': 110,
            'texts': {
              'nl': {'title': 'Boleten & poriën', 'summary': 'Verdieping'},
              'en': {'title': 'Boletes & pores', 'summary': 'Specialization'},
              'de': {'title': 'Röhrlinge & Poren', 'summary': 'Vertiefung'},
            },
          },
        ],
      }),
    ),
  );
  return _Fixture(
    packageKey: packageKey,
    entitlementKey: entitlementKey,
    catalogUri: catalogUri,
    packageUri: packageUri,
    catalogBytes: catalogBytes,
    packageBytes: packageBytes,
  );
}

class _Entitlements implements EntitlementRepository {
  const _Entitlements(this.keys);

  final List<String> keys;

  @override
  Future<EntitlementSnapshot> loadEntitlements() async => EntitlementSnapshot(keys);
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
    if (response.length > maxBytes) throw const FormatException('Response too large');
    return response;
  }
}
