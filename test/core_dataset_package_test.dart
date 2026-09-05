import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_package.dart';
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

  test('successful package applies atomically and records installed version', () async {
    await db.insert('lesson', {
      'id': 9001,
      'slug': 'transaction-test',
      'difficulty': 1,
      'sort_order': 1,
    });
    await db.insert('training_progress', {
      'lesson_id': 9001,
      'completed_at': '2026-09-01T12:00:00Z',
      'best_score': 0.75,
      'attempts': 3,
    });

    final manifest = _manifest(
      datasetVersion: 2,
      components: const ['species_catalog', 'training_content'],
    );
    await CoreDatasetPackageApplier.apply(
      db,
      manifest,
      _package(
        datasetVersion: 2,
        components: {
          'species_catalog': _catalogue(),
          'training_content': _training(),
        },
      ),
      appliedAt: DateTime.utc(2026, 9, 5, 4),
    );

    expect(await db.query('species'), hasLength(1));
    final lessons = await db.query('lesson', where: 'id=?', whereArgs: [9001]);
    expect(lessons.single['difficulty'], 2);

    final progress = await db.query(
      'training_progress',
      where: 'lesson_id=?',
      whereArgs: [9001],
    );
    expect(progress, hasLength(1));
    expect(progress.single['attempts'], 3);
    expect(progress.single['best_score'], 0.75);

    final state = await db.query(
      'bundled_content_state',
      where: 'content_key=?',
      whereArgs: const [coreDatasetKey],
    );
    expect(state.single['revision'], 2);
    expect(state.single['synced_at'], '2026-09-05T04:00:00.000Z');

    final installed = await CoreDatasetInstalledState.load(db);
    expect(installed.datasetVersion, 2);
    expect(installed.databaseSchemaVersion, DatabaseSchema.currentVersion);
  });

  test('later component failure rolls back earlier component writes and state', () async {
    final manifest = _manifest(
      datasetVersion: 2,
      components: const ['species_catalog', 'training_content'],
    );

    await expectLater(
      CoreDatasetPackageApplier.apply(
        db,
        manifest,
        _package(
          datasetVersion: 2,
          components: {
            'species_catalog': _catalogue(),
            'training_content': _training(includeGermanText: false),
          },
        ),
      ),
      throwsFormatException,
    );

    expect(await db.query('species'), isEmpty);
    expect(await db.query('taxon'), isEmpty);
    expect(await db.query('reference_source'), isEmpty);
    expect(
      await db.query(
        'bundled_content_state',
        where: 'content_key=?',
        whereArgs: const [coreDatasetKey],
      ),
      isEmpty,
    );
  });

  test('package metadata and component set must exactly match manifest', () {
    final manifest = _manifest(
      datasetVersion: 2,
      components: const ['species_catalog'],
    );

    expect(
      () => CoreDatasetPackage.fromDecoded(
        _package(
          datasetVersion: 3,
          components: {'species_catalog': _catalogue()},
        ),
        manifest,
      ),
      throwsFormatException,
    );
    expect(
      () => CoreDatasetPackage.fromDecoded(
        _package(
          datasetVersion: 2,
          components: {
            'species_catalog': _catalogue(),
            'training_content': _training(),
          },
        ),
        manifest,
      ),
      throwsFormatException,
    );
  });

  test('trait base and supplemental data must move together', () {
    final manifest = _manifest(
      datasetVersion: 2,
      components: const ['identification_traits'],
    );

    expect(
      () => CoreDatasetPackage.fromDecoded(
        _package(
          datasetVersion: 2,
          components: {
            'identification_traits': const {
              'traits': <dynamic>[],
              'species_traits': <dynamic>[],
            },
          },
        ),
        manifest,
      ),
      throwsFormatException,
    );
  });

  test('learning catalog waits for staged file activation layer', () {
    final manifest = _manifest(
      datasetVersion: 2,
      components: const ['learning_catalog'],
    );

    expect(
      () => CoreDatasetPackage.fromDecoded(
        _package(
          datasetVersion: 2,
          components: {
            'learning_catalog': const {
              'version': 1,
              'courses': <dynamic>[],
              'modules': <dynamic>[],
            },
          },
        ),
        manifest,
      ),
      throwsFormatException,
    );
  });

  test('installed state falls back to bundled metadata before remote update', () async {
    final installed = await CoreDatasetInstalledState.load(db);
    final bundled = await CoreDatasetMetadata.loadBundled();

    expect(installed.datasetVersion, bundled.datasetVersion);
    expect(installed.databaseSchemaVersion, bundled.databaseSchemaVersion);
  });

  test('same or older dataset cannot be applied over installed remote data', () async {
    await db.insert('bundled_content_state', {
      'content_key': coreDatasetKey,
      'revision': 3,
      'synced_at': '2026-09-05T04:00:00Z',
    });
    final manifest = _manifest(
      datasetVersion: 3,
      components: const ['species_catalog'],
    );

    await expectLater(
      CoreDatasetPackageApplier.apply(
        db,
        manifest,
        _package(
          datasetVersion: 3,
          components: {'species_catalog': _catalogue()},
        ),
      ),
      throwsStateError,
    );
    expect(await db.query('species'), isEmpty);
  });
}

CoreDatasetUpdateManifest _manifest({
  required int datasetVersion,
  required List<String> components,
}) {
  return CoreDatasetUpdateManifest.fromDecoded({
    'manifest_version': 1,
    'dataset_key': coreDatasetKey,
    'dataset_version': datasetVersion,
    'database_schema_version': DatabaseSchema.currentVersion,
    'published_at': '2026-09-05T04:00:00Z',
    'package_url': 'https://updates.example.org/core-v$datasetVersion.zip',
    'package_sha256':
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    'package_size_bytes': 123456,
    'components': components,
  });
}

Map<String, dynamic> _package({
  required int datasetVersion,
  required Map<String, dynamic> components,
}) {
  return {
    'package_version': 1,
    'dataset_key': coreDatasetKey,
    'dataset_version': datasetVersion,
    'database_schema_version': DatabaseSchema.currentVersion,
    'components': components,
  };
}

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

Map<String, dynamic> _training({bool includeGermanText = true}) => {
      'lessons': [
        {
          'id': 9001,
          'slug': 'transaction-test',
          'difficulty': 2,
          'sort_order': 1,
          'texts': {
            'nl': {'title': 'Bijgewerkt', 'body': 'Nieuwe testinhoud'},
            'en': {'title': 'Updated', 'body': 'New test content'},
            if (includeGermanText)
              'de': {'title': 'Aktualisiert', 'body': 'Neuer Testinhalt'},
          },
          'questions': <dynamic>[],
        },
      ],
    };
