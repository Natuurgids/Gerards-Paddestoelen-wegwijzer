import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/field_data_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/image_manifest_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/species_catalog_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/training_manifest_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/trait_manifest_importer.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseSchema.create(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('all decoded importers can share one rollback-safe transaction', () async {
    await expectLater(
      db.transaction((txn) async {
        await SpeciesCatalogImporter.syncDecoded(txn, _catalogue());
        await TraitManifestImporter.syncDecoded(txn, const {
          'traits': <dynamic>[],
          'species_traits': <dynamic>[],
        });
        await FieldDataImporter.syncDecoded(txn, const {
          'season_regions': <dynamic>[],
          'species': <dynamic>[],
        });
        await ImageManifestImporter.syncDecoded(txn, const {
          'species': <dynamic>[],
        });
        await TrainingManifestImporter.syncDecoded(txn, _training());

        expect(await txn.query('species'), hasLength(1));
        expect(await txn.query('lesson'), hasLength(1));
        throw StateError('simulate later dataset component failure');
      }),
      throwsStateError,
    );

    expect(await db.query('species'), isEmpty);
    expect(await db.query('taxon'), isEmpty);
    expect(await db.query('reference_source'), isEmpty);
    expect(await db.query('lesson'), isEmpty);
  });
}

Map<String, dynamic> _catalogue() => {
      'sources': [
        {
          'id': 'test-source',
          'title': 'Test source',
          'version': '1',
          'url': 'https://example.org/source',
          'license': 'CC BY 4.0',
          'citation': 'Test source citation',
          'retrieved_at': '2026-09-05',
        },
      ],
      'taxa': [
        {
          'id': 1,
          'parent_id': null,
          'rank': 'species',
          'scientific_name': 'Testus exemplaris',
          'author_citation': null,
        },
      ],
      'species': [
        {
          'id': 1,
          'taxon_id': 1,
          'catalog_only': true,
          'edible_status': 'unknown',
          'toxicity_level': 'unknown',
          'source_id': 'test-source',
          'source_record_id': 'test-1',
          'texts': {
            'nl': {
              'common_name': 'Testpaddenstoel',
              'summary': null,
              'description': null,
              'habitat': null,
              'lookalikes': null,
            },
          },
        },
      ],
    };

Map<String, dynamic> _training() => {
      'lessons': [
        {
          'id': 9001,
          'slug': 'transaction-test',
          'difficulty': 1,
          'sort_order': 1,
          'texts': {
            'nl': {'title': 'Test', 'body': 'Testinhoud'},
            'en': {'title': 'Test', 'body': 'Test content'},
            'de': {'title': 'Test', 'body': 'Testinhalt'},
          },
          'questions': <dynamic>[],
        },
      ],
    };
