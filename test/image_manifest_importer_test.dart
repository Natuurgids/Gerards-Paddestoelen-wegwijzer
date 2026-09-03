import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/image_manifest_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE species_image (
      id INTEGER PRIMARY KEY,
      species_id INTEGER NOT NULL,
      asset_path TEXT NOT NULL,
      thumbnail_path TEXT,
      angle_code TEXT,
      photographer TEXT,
      license TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_primary INTEGER NOT NULL DEFAULT 0,
      UNIQUE(species_id, asset_path)
    )''');
  });

  tearDown(() async {
    await db.close();
  });

  test('sync removes stale gallery rows before importing manifest', () async {
    await db.insert('species_image', {
      'species_id': 999,
      'asset_path': 'assets/images/species/stale.jpg',
      'angle_code': 'top',
      'sort_order': 0,
      'is_primary': 1,
    });

    await ImageManifestImporter.sync(db);

    expect(
      await db.query('species_image', where: 'species_id = ?', whereArgs: [999]),
      isEmpty,
    );
    final rows = await db.query('species_image');
    expect(rows, isNotEmpty);
  });

  test('invalid gallery fails before authoritative rows are deleted', () async {
    await db.insert('species_image', {
      'species_id': 999,
      'asset_path': 'assets/images/species/existing.jpg',
      'angle_code': 'top',
      'sort_order': 0,
      'is_primary': 1,
    });

    final malformed = <String, dynamic>{
      'species': [
        {
          'speciesId': 1,
          'images': [
            {
              'path': 'assets/images/species/species_1/1.jpg',
              'angle': 'top',
              'order': 0,
              'primary': true,
            },
          ],
        },
      ],
    };

    await expectLater(
      ImageManifestImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );

    expect(
      await db.query('species_image', where: 'species_id = ?', whereArgs: [999]),
      hasLength(1),
    );
  });
}
