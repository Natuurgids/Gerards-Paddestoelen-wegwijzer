import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/species_catalog_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/trait_manifest_importer.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE taxon (
      id INTEGER PRIMARY KEY,
      parent_id INTEGER,
      rank TEXT NOT NULL,
      scientific_name TEXT NOT NULL,
      author_citation TEXT
    )''');
    await db.execute('''CREATE TABLE species (
      id INTEGER PRIMARY KEY,
      taxon_id INTEGER NOT NULL,
      edible_status TEXT NOT NULL,
      toxicity_level TEXT NOT NULL,
      conservation_status TEXT
    )''');
    await db.execute('''CREATE TABLE species_text (
      species_id INTEGER NOT NULL,
      language_code TEXT NOT NULL,
      common_name TEXT NOT NULL,
      summary TEXT,
      description TEXT NOT NULL,
      habitat_text TEXT,
      lookalikes_text TEXT,
      PRIMARY KEY(species_id, language_code)
    )''');
    await db.execute('''CREATE TABLE trait (
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL,
      category TEXT NOT NULL,
      value_type TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE trait_text (
      trait_id INTEGER NOT NULL,
      language_code TEXT NOT NULL,
      label TEXT NOT NULL,
      PRIMARY KEY(trait_id, language_code)
    )''');
    await db.execute('''CREATE TABLE trait_option (
      id INTEGER PRIMARY KEY,
      trait_id INTEGER NOT NULL,
      code TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    )''');
    await db.execute('''CREATE TABLE trait_option_text (
      option_id INTEGER NOT NULL,
      language_code TEXT NOT NULL,
      label TEXT NOT NULL,
      PRIMARY KEY(option_id, language_code)
    )''');
    await db.execute('''CREATE TABLE species_trait (
      species_id INTEGER NOT NULL,
      trait_id INTEGER NOT NULL,
      option_id INTEGER,
      weight REAL NOT NULL,
      PRIMARY KEY(species_id, trait_id, option_id)
    )''');
  });

  tearDown(() async {
    await db.close();
  });

  test('valid catalogue and traits accept required languages plus extras', () async {
    final catalogue = <String, dynamic>{
      'taxa': [
        {
          'id': 1,
          'parent_id': null,
          'rank': 'species',
          'scientific_name': 'Example species',
        },
      ],
      'species': [
        {
          'id': 10,
          'taxon_id': 1,
          'texts': {
            'nl': {'common_name': 'Voorbeeld', 'description': 'Beschrijving'},
            'en': {'common_name': 'Example', 'description': 'Description'},
            'de': {'common_name': 'Beispiel', 'description': 'Beschreibung'},
            'fr': {'common_name': 'Exemple', 'description': 'Description'},
          },
        },
      ],
    };
    final traits = <String, dynamic>{
      'traits': [
        {
          'id': 1,
          'code': 'cap_color',
          'category': 'cap',
          'labels': {
            'nl': 'Hoedkleur',
            'en': 'Cap color',
            'de': 'Hutfarbe',
            'fr': 'Couleur du chapeau',
          },
          'options': [
            {
              'id': 100,
              'code': 'red',
              'labels': {'nl': 'Rood', 'en': 'Red', 'de': 'Rot', 'fr': 'Rouge'},
            },
          ],
        },
      ],
      'species_traits': [
        {
          'species_id': 10,
          'trait_id': 1,
          'option_id': 100,
          'weight': 1.0,
        },
      ],
    };

    await SpeciesCatalogImporter.syncDecoded(db, catalogue);
    await TraitManifestImporter.syncDecoded(db, traits);

    expect(await db.query('species', where: 'id = 10'), hasLength(1));
    expect(await db.query('species_text', where: 'species_id = 10'), hasLength(4));
    expect(await db.query('trait', where: 'id = 1'), hasLength(1));
    expect(await db.query('trait_text', where: 'trait_id = 1'), hasLength(4));
    expect(await db.query('species_trait', where: 'species_id = 10'), hasLength(1));
  });

  test('catalogue rejects unknown taxon before database mutation', () async {
    final malformed = <String, dynamic>{
      'taxa': [
        {
          'id': 1,
          'parent_id': null,
          'rank': 'species',
          'scientific_name': 'Example species',
        },
      ],
      'species': [
        {
          'id': 10,
          'taxon_id': 999,
          'texts': {
            'nl': {'common_name': 'Voorbeeld', 'description': 'Beschrijving'},
            'en': {'common_name': 'Example', 'description': 'Description'},
            'de': {'common_name': 'Beispiel', 'description': 'Beschreibung'},
          },
        },
      ],
    };

    await expectLater(
      SpeciesCatalogImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
  });

  test('traits reject option references outside their trait before SQL', () async {
    final malformed = <String, dynamic>{
      'traits': [
        {
          'id': 1,
          'code': 'cap_color',
          'category': 'cap',
          'labels': {'nl': 'Hoedkleur', 'en': 'Cap color', 'de': 'Hutfarbe'},
          'options': [
            {
              'id': 100,
              'code': 'red',
              'labels': {'nl': 'Rood', 'en': 'Red', 'de': 'Rot'},
            },
          ],
        },
        {
          'id': 2,
          'code': 'ring',
          'category': 'stem',
          'labels': {'nl': 'Ring', 'en': 'Ring', 'de': 'Ring'},
          'options': [
            {
              'id': 200,
              'code': 'present',
              'labels': {'nl': 'Aanwezig', 'en': 'Present', 'de': 'Vorhanden'},
            },
          ],
        },
      ],
      'species_traits': [
        {
          'species_id': 10,
          'trait_id': 1,
          'option_id': 200,
          'weight': 1.0,
        },
      ],
    };

    await expectLater(
      TraitManifestImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );
  });
}
