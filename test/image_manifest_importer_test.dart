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
      is_placeholder INTEGER NOT NULL DEFAULT 1,
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
      'is_placeholder': 1,
    });

    await ImageManifestImporter.sync(db);

    expect(
      await db.query('species_image', where: 'species_id = ?', whereArgs: [999]),
      isEmpty,
    );
    final rows = await db.query('species_image');
    expect(rows, isNotEmpty);
    expect(rows.every((row) => row['is_placeholder'] == 1), isTrue);
  });

  test('invalid gallery fails before authoritative rows are deleted', () async {
    await db.insert('species_image', {
      'species_id': 999,
      'asset_path': 'assets/images/species/existing.jpg',
      'angle_code': 'top',
      'sort_order': 0,
      'is_primary': 1,
      'is_placeholder': 1,
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
              'placeholder': true,
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

  test('real gallery images require photographer and licence metadata', () async {
    final malformed = _gallery(placeholder: false);
    final firstImage = ((malformed['species'] as List<dynamic>).first
        as Map<String, dynamic>)['images'] as List<dynamic>;
    (firstImage.first as Map<String, dynamic>).remove('license');

    await expectLater(
      ImageManifestImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
  });

  test('real gallery images persist attribution metadata', () async {
    await ImageManifestImporter.syncDecoded(
      db,
      _gallery(placeholder: false),
    );

    final rows = await db.query(
      'species_image',
      where: 'species_id = ?',
      whereArgs: [42],
      orderBy: 'sort_order',
    );
    expect(rows, hasLength(5));
    expect(rows.every((row) => row['photographer'] == 'Example photographer'),
        isTrue);
    expect(rows.every((row) => row['license'] == 'CC BY 4.0'), isTrue);
    expect(rows.every((row) => row['is_placeholder'] == 0), isTrue);
  });

  test('placeholder gallery images must not carry fake attribution', () async {
    final malformed = _gallery(placeholder: true);
    final firstImage = ((malformed['species'] as List<dynamic>).first
        as Map<String, dynamic>)['images'] as List<dynamic>;
    (firstImage.first as Map<String, dynamic>)['photographer'] = 'Unknown';

    await expectLater(
      ImageManifestImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _gallery({required bool placeholder}) {
  const angles = ['top', 'underside', 'side', 'base', 'habitat'];
  return {
    'species': [
      {
        'speciesId': 42,
        'images': [
          for (var index = 0; index < angles.length; index++)
            {
              'path': 'assets/images/species/species_42/${index + 1}.jpg',
              'angle': angles[index],
              'order': index,
              'primary': index == 0,
              'placeholder': placeholder,
              if (!placeholder) 'photographer': 'Example photographer',
              if (!placeholder) 'license': 'CC BY 4.0',
            },
        ],
      },
    ],
  };
}
