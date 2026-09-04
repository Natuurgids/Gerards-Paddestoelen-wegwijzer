import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/field_data_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/image_manifest_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/species_catalog_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/training_manifest_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/trait_manifest_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('all bundled manifests populate every reference-content table', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseSchema.create(db);

    Future<void> syncAll() async {
      await SpeciesCatalogImporter.sync(db);
      await TraitManifestImporter.sync(db);
      await FieldDataImporter.sync(db);
      await ImageManifestImporter.sync(db);
      await TrainingManifestImporter.sync(db);
    }

    await syncAll();
    expect(await db.query('training_progress'), isEmpty);
    await db.insert('training_progress', {
      'lesson_id': 1,
      'completed_at': '2026-09-04T00:00:00Z',
      'best_score': 0.75,
      'attempts': 2,
    });
    await syncAll();

    const expectedCounts = <String, int>{
      'taxon': 6,
      'species': 3,
      'species_text': 9,
      'trait': 20,
      'trait_text': 60,
      'trait_option': 139,
      'trait_option_text': 417,
      'species_trait': 60,
      'species_measurement': 7,
      'season_region': 1,
      'season_region_text': 3,
      'species_season': 14,
      'species_image': 15,
      'lesson': 12,
      'lesson_text': 36,
      'question': 60,
      'question_text': 180,
      'answer_option': 180,
      'answer_option_text': 540,
    };

    for (final entry in expectedCounts.entries) {
      final result = await db.rawQuery('SELECT COUNT(*) AS count FROM ${entry.key}');
      expect(
        result.single['count'],
        entry.value,
        reason: '${entry.key} should contain all bundled manifest rows',
      );
    }

    final placeholders = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM species_image WHERE is_placeholder = 1',
    );
    expect(placeholders.single['count'], 15);

    final progress = await db.query('training_progress');
    expect(progress, hasLength(1));
    expect(progress.single['lesson_id'], 1);
    expect(progress.single['completed_at'], '2026-09-04T00:00:00Z');
    expect(progress.single['best_score'], 0.75);
    expect(progress.single['attempts'], 2);
  });
}
