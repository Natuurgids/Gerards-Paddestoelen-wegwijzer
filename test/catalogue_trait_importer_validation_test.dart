import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/species_catalog_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/trait_manifest_importer.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
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
