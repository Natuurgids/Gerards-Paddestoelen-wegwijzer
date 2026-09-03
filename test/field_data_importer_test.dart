import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/field_data_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
  });

  tearDown(() async {
    await db.close();
  });

  test('sync removes stale field rows before importing manifest', () async {
    await db.insert('species_measurement', {
      'species_id': 999,
      'measurement_code': 'stale_measurement',
      'min_value': 1.0,
      'max_value': 2.0,
      'unit': 'cm',
    });
    await db.insert('species_season', {
      'species_id': 999,
      'region_code': 'STALE',
      'month': 1,
      'likelihood': 3,
    });

    await FieldDataImporter.sync(db);

    expect(
      await db.query(
        'species_measurement',
        where: 'species_id = ?',
        whereArgs: [999],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'species_season',
        where: 'species_id = ?',
        whereArgs: [999],
      ),
      isEmpty,
    );

    final measurementCount = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM species_measurement',
    );
    final seasonCount = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM species_season',
    );
    expect(measurementCount.single['count'] as int, greaterThan(0));
    expect(seasonCount.single['count'] as int, greaterThan(0));
  });
}
