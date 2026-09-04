import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';

void main() {
  sqfliteFfiInit();

  test('fresh schema exposes reference provenance fields', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await DatabaseSchema.create(db);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    expect(tables.map((row) => row['name']), contains('reference_source'));

    final speciesColumns = await db.rawQuery('PRAGMA table_info(species)');
    expect(
      speciesColumns.map((row) => row['name']),
      containsAll(<String>{'source_id', 'source_record_id'}),
    );

    final traitColumns = await db.rawQuery('PRAGMA table_info(species_trait)');
    expect(
      traitColumns.map((row) => row['name']),
      containsAll(<String>{'source_id', 'source_record_id'}),
    );

    final imageColumns = await db.rawQuery('PRAGMA table_info(species_image)');
    expect(
      imageColumns.map((row) => row['name']),
      containsAll(<String>{
        'source_url',
        'source_record_id',
        'creator',
        'license_url',
      }),
    );
  });

  test('v7 migration adds provenance without deleting existing rows', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await db.execute('''CREATE TABLE species (
      id INTEGER PRIMARY KEY,
      taxon_id INTEGER NOT NULL,
      edible_status TEXT NOT NULL DEFAULT 'unknown',
      toxicity_level TEXT NOT NULL DEFAULT 'unknown'
    )''');
    await db.execute('''CREATE TABLE species_trait (
      species_id INTEGER NOT NULL,
      trait_id INTEGER NOT NULL,
      option_id INTEGER,
      weight REAL NOT NULL DEFAULT 1.0,
      PRIMARY KEY(species_id, trait_id, option_id)
    )''');
    await db.execute('''CREATE TABLE species_image (
      id INTEGER PRIMARY KEY,
      species_id INTEGER NOT NULL,
      asset_path TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_primary INTEGER NOT NULL DEFAULT 0,
      is_placeholder INTEGER NOT NULL DEFAULT 1
    )''');
    await db.insert('species', {
      'id': 1,
      'taxon_id': 11,
      'edible_status': 'unknown',
      'toxicity_level': 'unknown',
    });
    await db.insert('species_trait', {
      'species_id': 1,
      'trait_id': 1,
      'option_id': 1,
      'weight': 1.0,
    });
    await db.insert('species_image', {
      'id': 1,
      'species_id': 1,
      'asset_path': 'assets/images/species/species_1/1.jpg',
      'sort_order': 0,
      'is_primary': 1,
      'is_placeholder': 1,
    });

    await DatabaseSchema.upgrade(db, 7, DatabaseSchema.currentVersion);

    expect(await db.query('species'), hasLength(1));
    expect(await db.query('species_trait'), hasLength(1));
    expect(await db.query('species_image'), hasLength(1));
    expect(await db.query('reference_source'), isEmpty);
  });
}
