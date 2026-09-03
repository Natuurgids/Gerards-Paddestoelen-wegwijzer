import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('same species and month can coexist across different regions', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await db.execute('''
      CREATE TABLE species_season (
        species_id INTEGER NOT NULL,
        region_code TEXT NOT NULL,
        month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
        likelihood INTEGER NOT NULL DEFAULT 1 CHECK(likelihood BETWEEN 1 AND 3),
        PRIMARY KEY(species_id, region_code, month)
      )
    ''');

    await db.insert('species_season', {
      'species_id': 1,
      'region_code': 'GB-IE',
      'month': 10,
      'likelihood': 3,
    });
    await db.insert('species_season', {
      'species_id': 1,
      'region_code': 'NL',
      'month': 10,
      'likelihood': 2,
    });

    final rows = await db.query(
      'species_season',
      where: 'species_id=? AND month=?',
      whereArgs: [1, 10],
      orderBy: 'region_code',
    );

    expect(rows, hasLength(2));
    expect(rows.map((row) => row['region_code']), containsAll(['GB-IE', 'NL']));
  });

  test('same species region and month remains unique', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await db.execute('''
      CREATE TABLE species_season (
        species_id INTEGER NOT NULL,
        region_code TEXT NOT NULL,
        month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
        likelihood INTEGER NOT NULL DEFAULT 1 CHECK(likelihood BETWEEN 1 AND 3),
        PRIMARY KEY(species_id, region_code, month)
      )
    ''');

    await db.insert('species_season', {
      'species_id': 1,
      'region_code': 'GB-IE',
      'month': 10,
      'likelihood': 3,
    });

    expect(
      () => db.insert('species_season', {
        'species_id': 1,
        'region_code': 'GB-IE',
        'month': 10,
        'likelihood': 1,
      }),
      throwsA(anything),
    );
  });
}
