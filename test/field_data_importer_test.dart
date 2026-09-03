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

  Future<void> insertExistingRows() async {
    await db.insert('species_measurement', {
      'species_id': 999,
      'measurement_code': 'existing_measurement',
      'min_value': 1.0,
      'max_value': 2.0,
      'unit': 'cm',
    });
    await db.insert('species_season', {
      'species_id': 999,
      'region_code': 'NL',
      'month': 1,
      'likelihood': 3,
    });
  }

  Future<void> expectExistingRowsPreserved() async {
    expect(
      await db.query(
        'species_measurement',
        where: 'species_id = ?',
        whereArgs: [999],
      ),
      hasLength(1),
    );
    expect(
      await db.query(
        'species_season',
        where: 'species_id = ?',
        whereArgs: [999],
      ),
      hasLength(1),
    );
  }

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

  test('invalid region content fails before authoritative rows are deleted',
      () async {
    await insertExistingRows();

    final malformed = <String, dynamic>{
      'season_regions': [
        {
          'code': 'nl',
          'labels': {'nl': 'Nederland', 'en': 'Netherlands', 'de': 'Niederlande'},
          'notes': {'nl': 'Test', 'en': 'Test', 'de': 'Test'},
        },
      ],
      'species': [
        {
          'species_id': 1,
          'measurements': const [],
          'season_datasets': [
            {
              'region_code': 'nl',
              'months': [
                {'month': 1, 'likelihood': 3},
              ],
            },
          ],
        },
      ],
    };

    await expectLater(
      FieldDataImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
    await expectExistingRowsPreserved();
  });

  test('invalid measurement range fails before authoritative rows are deleted',
      () async {
    await insertExistingRows();

    final malformed = <String, dynamic>{
      'season_regions': const [],
      'species': [
        {
          'species_id': 1,
          'measurements': [
            {
              'code': 'cap_diameter',
              'min': 20.0,
              'max': 10.0,
              'unit': 'cm',
            },
          ],
          'season_datasets': const [],
        },
      ],
    };

    await expectLater(
      FieldDataImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
    await expectExistingRowsPreserved();
  });

  test('unsupported measurement code preserves existing rows', () async {
    await insertExistingRows();

    final malformed = <String, dynamic>{
      'season_regions': const [],
      'species': [
        {
          'species_id': 1,
          'measurements': [
            {
              'code': 'cap_diamter',
              'min': 1.0,
              'max': 2.0,
              'unit': 'cm',
            },
          ],
          'season_datasets': const [],
        },
      ],
    };

    await expectLater(
      FieldDataImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
    await expectExistingRowsPreserved();
  });

  test('wrong measurement unit preserves existing rows', () async {
    await insertExistingRows();

    final malformed = <String, dynamic>{
      'season_regions': const [],
      'species': [
        {
          'species_id': 1,
          'measurements': [
            {
              'code': 'cap_diameter',
              'min': 10.0,
              'max': 20.0,
              'unit': 'mm',
            },
          ],
          'season_datasets': const [],
        },
      ],
    };

    await expectLater(
      FieldDataImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
    await expectExistingRowsPreserved();
  });

  test('invalid season month fails before authoritative rows are deleted',
      () async {
    await insertExistingRows();

    final malformed = <String, dynamic>{
      'season_regions': [
        {
          'code': 'NL',
          'labels': {'nl': 'Nederland', 'en': 'Netherlands', 'de': 'Niederlande'},
          'notes': {'nl': 'Test', 'en': 'Test', 'de': 'Test'},
        },
      ],
      'species': [
        {
          'species_id': 1,
          'measurements': const [],
          'season_datasets': [
            {
              'region_code': 'NL',
              'months': [
                {'month': 13, 'likelihood': 3},
              ],
            },
          ],
        },
      ],
    };

    await expectLater(
      FieldDataImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
    await expectExistingRowsPreserved();
  });

  test('duplicate species entry fails before authoritative rows are deleted',
      () async {
    await insertExistingRows();

    final malformed = <String, dynamic>{
      'season_regions': const [],
      'species': [
        {
          'species_id': 1,
          'measurements': const [],
          'season_datasets': const [],
        },
        {
          'species_id': 1,
          'measurements': const [],
          'season_datasets': const [],
        },
      ],
    };

    await expectLater(
      FieldDataImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
    await expectExistingRowsPreserved();
  });
}
