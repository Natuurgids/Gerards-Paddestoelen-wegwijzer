import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/conservation_status_repository.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseSchema.create(db);
    await db.insert('taxon', {
      'id': 1,
      'parent_id': null,
      'rank': 'species',
      'scientific_name': 'Testus fungalis',
      'author_citation': null,
    });
    await db.insert('species', {
      'id': 1,
      'taxon_id': 1,
      'edible_status': 'unknown',
      'toxicity_level': 'unknown',
      'conservation_status': 'EN',
    });
  });

  tearDown(() async {
    await db.close();
  });

  test('normalized IUCN row wins over legacy compatibility field', () async {
    await db.insert('species_conservation_status', {
      'species_id': 1,
      'system': 'iucn_red_list',
      'scope': 'global',
      'jurisdiction_code': '',
      'status': 'VU',
      'source_id': null,
      'source_record_id': null,
    });

    expect(await ConservationStatusRepository.loadIucnStatus(db, 1), 'VU');
  });

  test('legacy field remains a transition fallback', () async {
    expect(await ConservationStatusRepository.loadIucnStatus(db, 1), 'EN');
  });

  test('unrelated scoped status does not replace global IUCN status', () async {
    await db.insert('species_conservation_status', {
      'species_id': 1,
      'system': 'nl_red_list',
      'scope': 'national',
      'jurisdiction_code': 'NL',
      'status': 'KW',
      'source_id': null,
      'source_record_id': null,
    });

    expect(await ConservationStatusRepository.loadIucnStatus(db, 1), 'EN');
  });
}
