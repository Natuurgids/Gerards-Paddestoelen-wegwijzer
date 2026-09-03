import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('identification lookups use query-focused indexes', () async {
    final traitPlan = await _plan(
      db,
      'SELECT species_id FROM species_trait WHERE trait_id=? AND option_id=?',
      [1, 101],
    );
    expect(traitPlan, contains('idx_species_trait_filter'));

    final measurementPlan = await _plan(
      db,
      '''SELECT species_id FROM species_measurement
         WHERE measurement_code=? AND min_value<=? AND max_value>=?''',
      ['cap_diameter', 12.0, 12.0],
    );
    expect(measurementPlan, contains('idx_species_measurement_lookup'));

    final seasonPlan = await _plan(
      db,
      '''SELECT species_id FROM species_season
         WHERE region_code=? AND month=?''',
      ['NL', 10],
    );
    expect(seasonPlan, contains('idx_species_season_region_month'));
  });

  test('localized catalogue lookup uses language-name index', () async {
    final plan = await _plan(
      db,
      '''SELECT species_id FROM species_text
         WHERE language_code=? AND common_name=? COLLATE NOCASE''',
      ['nl', 'Vliegenzwam'],
    );

    expect(plan, contains('idx_species_text_language_name'));
  });
}

Future<String> _plan(Database db, String sql, List<Object?> args) async {
  final rows = await db.rawQuery('EXPLAIN QUERY PLAN $sql', args);
  return rows.map((row) => row['detail']).join('\n');
}

Future<void> _createSchema(Database db) async {
  await db.execute('''CREATE TABLE species_text (
    species_id INTEGER NOT NULL,
    language_code TEXT NOT NULL,
    common_name TEXT NOT NULL,
    PRIMARY KEY(species_id, language_code)
  )''');
  await db.execute('''CREATE TABLE species_trait (
    species_id INTEGER NOT NULL,
    trait_id INTEGER NOT NULL,
    option_id INTEGER,
    weight REAL NOT NULL DEFAULT 1.0
  )''');
  await db.execute('''CREATE TABLE species_measurement (
    species_id INTEGER NOT NULL,
    measurement_code TEXT NOT NULL,
    min_value REAL,
    max_value REAL,
    unit TEXT NOT NULL,
    PRIMARY KEY(species_id, measurement_code)
  )''');
  await db.execute('''CREATE TABLE species_season (
    species_id INTEGER NOT NULL,
    region_code TEXT NOT NULL,
    month INTEGER NOT NULL,
    likelihood INTEGER NOT NULL,
    PRIMARY KEY(species_id, region_code, month)
  )''');

  await db.execute(
    'CREATE INDEX idx_species_text_language_name ON species_text(language_code, common_name COLLATE NOCASE)',
  );
  await db.execute(
    'CREATE INDEX idx_species_trait_filter ON species_trait(trait_id, option_id, species_id)',
  );
  await db.execute(
    'CREATE INDEX idx_species_measurement_lookup ON species_measurement(measurement_code, min_value, max_value, species_id)',
  );
  await db.execute(
    'CREATE INDEX idx_species_season_region_month ON species_season(region_code, month, likelihood, species_id)',
  );
}
