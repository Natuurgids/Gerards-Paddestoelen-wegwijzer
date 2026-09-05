import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/trait_manifest_importer.dart';

void main() {
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

  test('legacy base species traits may remain without provenance', () async {
    await _insertSpecies(db, 10);
    await TraitManifestImporter.syncDecoded(db, _baseTraits());

    expect(await db.query('species_trait'), hasLength(1));
  });

  test('sourced supplemental species traits are accepted', () async {
    await _insertSpecies(db, 20);

    await TraitManifestImporter.syncDecoded(
      db,
      _baseTraits(includeBaseRelation: false),
      supplemental: {
        'species_traits': [
          {
            'species_id': 20,
            'trait_id': 1,
            'option_id': 100,
            'source_id': 'reviewed-source',
            'source_record_id': 'record-20',
          },
        ],
      },
    );

    final rows = await db.query(
      'species_trait',
      where: 'species_id = ?',
      whereArgs: [20],
    );
    expect(rows, hasLength(1));
    expect(rows.single['source_id'], 'reviewed-source');
    expect(rows.single['source_record_id'], 'record-20');
  });

  test('supplemental species traits require source id before mutation', () async {
    await expectLater(
      TraitManifestImporter.syncDecoded(
        db,
        _baseTraits(includeBaseRelation: false),
        supplemental: {
          'species_traits': [
            {
              'species_id': 20,
              'trait_id': 1,
              'option_id': 100,
              'source_record_id': 'record-20',
            },
          ],
        },
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await db.query('trait'), isEmpty);
    expect(await db.query('species_trait'), isEmpty);
  });

  test('supplemental species traits require source record id before mutation',
      () async {
    await expectLater(
      TraitManifestImporter.syncDecoded(
        db,
        _baseTraits(includeBaseRelation: false),
        supplemental: {
          'species_traits': [
            {
              'species_id': 20,
              'trait_id': 1,
              'option_id': 100,
              'source_id': 'reviewed-source',
            },
          ],
        },
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await db.query('trait'), isEmpty);
    expect(await db.query('species_trait'), isEmpty);
  });
}

Map<String, dynamic> _baseTraits({bool includeBaseRelation = true}) => {
      'traits': [
        {
          'id': 1,
          'code': 'cap_color',
          'category': 'cap',
          'labels': {
            'nl': 'Hoedkleur',
            'en': 'Cap colour',
            'de': 'Hutfarbe',
          },
          'options': [
            {
              'id': 100,
              'code': 'red',
              'labels': {'nl': 'Rood', 'en': 'Red', 'de': 'Rot'},
            },
          ],
        },
      ],
      'species_traits': includeBaseRelation
          ? [
              {
                'species_id': 10,
                'trait_id': 1,
                'option_id': 100,
              },
            ]
          : <dynamic>[],
    };

Future<void> _insertSpecies(Database db, int speciesId) async {
  await db.insert('taxon', {
    'id': speciesId,
    'rank': 'species',
    'scientific_name': 'Example species $speciesId',
  });
  await db.insert('species', {
    'id': speciesId,
    'taxon_id': speciesId,
  });
}
