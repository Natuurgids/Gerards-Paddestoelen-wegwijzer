import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  test('fresh schema creates core tables and query indexes', () async {
    await DatabaseSchema.create(db);

    final objects = await db.rawQuery(
      "SELECT type, name FROM sqlite_master WHERE type IN ('table', 'index')",
    );
    final tables = objects
        .where((row) => row['type'] == 'table')
        .map((row) => row['name'])
        .toSet();
    final indexes = objects
        .where((row) => row['type'] == 'index')
        .map((row) => row['name'])
        .toSet();

    expect(
      tables,
      containsAll(<String>{
        'taxon',
        'species',
        'species_text',
        'trait',
        'trait_text',
        'species_trait',
        'species_measurement',
        'species_season',
        'species_image',
        'lesson',
        'question',
        'training_progress',
      }),
    );
    expect(
      indexes,
      containsAll(<String>{
        'idx_species_text_language_name',
        'idx_species_trait_filter',
        'idx_species_measurement_lookup',
        'idx_species_season_region_month',
        'idx_species_image_gallery',
      }),
    );

    final seasonColumns = await db.rawQuery('PRAGMA table_info(species_season)');
    final region = seasonColumns.singleWhere((row) => row['name'] == 'region_code');
    expect(region['notnull'], 1);
  });

  test('v4 to v5 migration preserves season rows and enables regions', () async {
    await db.execute('CREATE TABLE species (id INTEGER PRIMARY KEY)');
    await db.execute('''CREATE TABLE species_season (
      species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
      month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
      likelihood INTEGER NOT NULL DEFAULT 1 CHECK(likelihood BETWEEN 1 AND 3),
      region_code TEXT,
      PRIMARY KEY(species_id, month)
    )''');
    await db.insert('species', {'id': 1});
    await db.insert('species_season', {
      'species_id': 1,
      'month': 9,
      'likelihood': 2,
      'region_code': null,
    });
    await db.insert('species_season', {
      'species_id': 1,
      'month': 10,
      'likelihood': 3,
      'region_code': 'NL',
    });

    await DatabaseSchema.upgrade(db, 4, DatabaseSchema.currentVersion);

    final rows = await db.query(
      'species_season',
      orderBy: 'month',
    );
    expect(rows, hasLength(2));
    expect(rows[0]['region_code'], 'UNSPECIFIED');
    expect(rows[0]['month'], 9);
    expect(rows[0]['likelihood'], 2);
    expect(rows[1]['region_code'], 'NL');
    expect(rows[1]['month'], 10);
    expect(rows[1]['likelihood'], 3);

    await db.insert('species_season', {
      'species_id': 1,
      'region_code': 'GB-IE',
      'month': 10,
      'likelihood': 1,
    });
    final october = await db.query(
      'species_season',
      where: 'species_id=? AND month=?',
      whereArgs: [1, 10],
    );
    expect(october, hasLength(2));

    final columns = await db.rawQuery('PRAGMA table_info(species_season)');
    final region = columns.singleWhere((row) => row['name'] == 'region_code');
    expect(region['notnull'], 1);
    final primaryKey = {
      for (final row in columns) row['name']: row['pk'],
    };
    expect(primaryKey['species_id'], 1);
    expect(primaryKey['region_code'], 2);
    expect(primaryKey['month'], 3);

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='species_season'",
    );
    expect(
      indexes.map((row) => row['name']),
      contains('idx_species_season_region_month'),
    );
  });
}
