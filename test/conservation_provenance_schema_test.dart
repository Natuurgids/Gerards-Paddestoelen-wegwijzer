import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/species_catalog_importer.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  test('fresh schema supports multiple scoped conservation systems', () async {
    await DatabaseSchema.create(db);

    final columns = await db.rawQuery(
      'PRAGMA table_info(species_conservation_status)',
    );
    final names = columns.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll(<String>{
        'species_id',
        'system',
        'scope',
        'jurisdiction_code',
        'status',
        'source_id',
        'source_record_id',
      }),
    );

    final primaryKey = {
      for (final row in columns) row['name']: row['pk'],
    };
    expect(primaryKey['species_id'], 1);
    expect(primaryKey['system'], 2);
    expect(primaryKey['scope'], 3);
    expect(primaryKey['jurisdiction_code'], 4);

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='species_conservation_status'",
    );
    expect(
      indexes.map((row) => row['name']),
      contains('idx_species_conservation_lookup'),
    );
  });

  test('v8 migration preserves legacy IUCN status as scoped row', () async {
    await db.execute('''CREATE TABLE species (
      id INTEGER PRIMARY KEY,
      conservation_status TEXT
    )''');
    await db.insert('species', {'id': 7, 'conservation_status': 'VU'});

    await DatabaseSchema.upgrade(db, 8, 9);

    final rows = await db.query('species_conservation_status');
    expect(rows, hasLength(1));
    expect(rows.single['species_id'], 7);
    expect(rows.single['system'], 'iucn_red_list');
    expect(rows.single['scope'], 'global');
    expect(rows.single['jurisdiction_code'], '');
    expect(rows.single['status'], 'VU');
  });

  test('catalogue importer persists distinct conservation provenance rows', () async {
    await DatabaseSchema.create(db);

    await SpeciesCatalogImporter.syncDecoded(db, <String, dynamic>{
      'sources': <dynamic>[
        <String, dynamic>{
          'id': 'iucn-red-list',
          'title': 'IUCN Red List',
          'version': '2026-1',
          'url': 'https://example.test/iucn',
          'license': 'CC BY 4.0',
          'citation': 'IUCN test citation',
          'retrieved_at': '2026-09-04',
        },
        <String, dynamic>{
          'id': 'nl-red-list',
          'title': 'Dutch Red List',
          'version': 'test',
          'url': 'https://example.test/nl',
          'license': 'test',
          'citation': 'Dutch test citation',
          'retrieved_at': '2026-09-04',
        },
      ],
      'taxa': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'parent_id': null,
          'rank': 'species',
          'scientific_name': 'Testus fungalis',
          'author_citation': null,
        },
      ],
      'species': <dynamic>[
        <String, dynamic>{
          'id': 1,
          'taxon_id': 1,
          'edible_status': 'unknown',
          'toxicity_level': 'unknown',
          'conservation_status': 'VU',
          'conservation_statuses': <dynamic>[
            <String, dynamic>{
              'system': 'iucn_red_list',
              'scope': 'global',
              'jurisdiction_code': '',
              'status': 'VU',
              'source_id': 'iucn-red-list',
              'source_record_id': 'Testus fungalis',
            },
            <String, dynamic>{
              'system': 'nl_red_list',
              'scope': 'national',
              'jurisdiction_code': 'NL',
              'status': 'KW',
              'source_id': 'nl-red-list',
              'source_record_id': 'nl-1',
            },
          ],
          'texts': <String, dynamic>{
            'nl': <String, dynamic>{
              'common_name': 'Testpaddenstoel',
              'description': 'Testbeschrijving',
            },
          },
        },
      ],
    });

    final rows = await db.query(
      'species_conservation_status',
      orderBy: 'system',
    );
    expect(rows, hasLength(2));

    final iucn = rows.singleWhere((row) => row['system'] == 'iucn_red_list');
    expect(iucn['scope'], 'global');
    expect(iucn['status'], 'VU');
    expect(iucn['source_id'], 'iucn-red-list');

    final dutch = rows.singleWhere((row) => row['system'] == 'nl_red_list');
    expect(dutch['scope'], 'national');
    expect(dutch['jurisdiction_code'], 'NL');
    expect(dutch['status'], 'KW');
    expect(dutch['source_id'], 'nl-red-list');
  });
}
