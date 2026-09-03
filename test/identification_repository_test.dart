import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/repositories.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late IdentificationRepository repository;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    repository = IdentificationRepository(databaseProvider: () async => db);
    await _createSchema(db);
    await _seed(db);
  });
  tearDown(() async => db.close());

  test('morphology query ranks exact trait match first', () async {
    final candidates = await repository.identify('en', {1: 101});
    expect(candidates, hasLength(1));
    expect(candidates.first.species.id, 1);
    expect(candidates.first.matched, 1);
    expect(candidates.first.requested, 1);
    expect(candidates.first.score, closeTo(1.0, 0.0001));
  });

  test('multiple valid options for one trait do not inflate denominator', () async {
    await db.insert('species_trait', {'species_id': 1, 'trait_id': 1, 'option_id': 103, 'weight': 2.0});
    final candidates = await repository.identify('en', {1: 101});
    expect(candidates, hasLength(1));
    expect(candidates.first.species.id, 1);
    expect(candidates.first.matched, 1);
    expect(candidates.first.score, closeTo(1.0, 0.0001));
  });

  test('field evidence can retain a zero-morphology candidate', () async {
    final candidates = await repository.identify(
      'en',
      {1: 101},
      capDiameterCm: 24,
    );

    expect(candidates, hasLength(2));
    expect(candidates.first.species.id, 1);
    final fieldRescued =
        candidates.singleWhere((candidate) => candidate.species.id == 2);
    expect(fieldRescued.matched, 0);
    expect(fieldRescued.requested, 1);
    expect(fieldRescued.fieldMatched, 1);
    expect(fieldRescued.fieldRequested, 1);
    expect(fieldRescued.fieldScore, closeTo(1.0, 0.0001));
    expect(fieldRescued.score, closeTo(0.2, 0.0001));
  });

  test('field evidence is combined with morphology and remains secondary', () async {
    final candidates = await repository.identify('en', {1: 101}, observationMonth: 10, seasonRegionCode: 'NL', capDiameterCm: 12);
    expect(candidates, hasLength(1));
    final candidate = candidates.first;
    expect(candidate.species.id, 1);
    expect(candidate.fieldRequested, 2);
    expect(candidate.fieldMatched, 2);
    expect(candidate.fieldScore, closeTo(1.0, 0.0001));
    expect(candidate.score, closeTo(1.0, 0.0001));
  });

  test('missing reference data is unknown and does not dilute field score', () async {
    final candidates = await repository.identify(
      'en',
      {1: 101},
      capDiameterCm: 12,
      stemHeightCm: 14,
    );
    expect(candidates, hasLength(1));
    final candidate = candidates.first;
    expect(candidate.species.id, 1);
    expect(candidate.fieldRequested, 1,
        reason: 'Only the available cap reference should be evaluated');
    expect(candidate.fieldMatched, 1);
    expect(candidate.fieldScore, closeTo(1.0, 0.0001));
    expect(candidate.score, closeTo(1.0, 0.0001));
  });

  test('near-boundary measurement receives partial field credit', () async {
    final candidates = await repository.identify('en', {1: 101}, capDiameterCm: 17);
    expect(candidates, hasLength(1));
    final candidate = candidates.first;
    expect(candidate.species.id, 1);
    expect(candidate.fieldRequested, 1);
    expect(candidate.fieldMatched, 1);
    expect(candidate.fieldScore, closeTo(0.5, 0.0001));
    expect(candidate.score, closeTo(0.9, 0.0001));
  });

  test('known measurement beyond shoulder remains negative evidence', () async {
    final candidates = await repository.identify('en', {1: 101}, capDiameterCm: 18);
    expect(candidates, hasLength(1));
    final candidate = candidates.first;
    expect(candidate.species.id, 1);
    expect(candidate.fieldRequested, 1);
    expect(candidate.fieldMatched, 0);
    expect(candidate.fieldScore, closeTo(0.0, 0.0001));
    expect(candidate.score, closeTo(0.8, 0.0001));
  });

  test('regional season lookup does not borrow another region calendar', () async {
    final nl = await repository.identify('en', {}, observationMonth: 10, seasonRegionCode: 'NL');
    final gb = await repository.identify('en', {}, observationMonth: 10, seasonRegionCode: 'GB-IE');
    expect(nl.first.species.id, 1);
    expect(nl.first.fieldScore, closeTo(1.0, 0.0001));
    expect(gb.first.species.id, 2);
    expect(gb.first.fieldScore, closeTo(1.0, 0.0001));
    expect(gb.any((candidate) => candidate.species.id == 1), isFalse);
  });

  test('measurement-only ranking works without morphology', () async {
    final candidates = await repository.identify('en', {}, capDiameterCm: 24);
    expect(candidates, hasLength(1));
    expect(candidates.first.species.id, 2);
    expect(candidates.first.fieldMatched, 1);
    expect(candidates.first.score, closeTo(1.0, 0.0001));
  });
}

Future<void> _createSchema(Database db) async {
  await db.execute('CREATE TABLE taxon (id INTEGER PRIMARY KEY, scientific_name TEXT NOT NULL)');
  await db.execute("CREATE TABLE species (id INTEGER PRIMARY KEY, taxon_id INTEGER NOT NULL, edible_status TEXT NOT NULL DEFAULT 'unknown', toxicity_level TEXT NOT NULL DEFAULT 'unknown')");
  await db.execute('CREATE TABLE species_text (species_id INTEGER NOT NULL, language_code TEXT NOT NULL, common_name TEXT NOT NULL, summary TEXT, description TEXT, habitat_text TEXT, lookalikes_text TEXT, PRIMARY KEY(species_id, language_code))');
  await db.execute('CREATE TABLE species_trait (species_id INTEGER NOT NULL, trait_id INTEGER NOT NULL, option_id INTEGER NOT NULL, weight REAL NOT NULL DEFAULT 1.0)');
  await db.execute('CREATE TABLE species_measurement (species_id INTEGER NOT NULL, measurement_code TEXT NOT NULL, min_value REAL, max_value REAL, unit TEXT NOT NULL, PRIMARY KEY(species_id, measurement_code))');
  await db.execute('CREATE TABLE species_season (species_id INTEGER NOT NULL, region_code TEXT NOT NULL, month INTEGER NOT NULL, likelihood INTEGER NOT NULL, PRIMARY KEY(species_id, region_code, month))');
  await db.execute('CREATE TABLE species_image (id INTEGER PRIMARY KEY, species_id INTEGER NOT NULL, asset_path TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0, is_primary INTEGER NOT NULL DEFAULT 0)');
}

Future<void> _seed(Database db) async {
  await db.insert('taxon', {'id': 11, 'scientific_name': 'Species alpha'});
  await db.insert('taxon', {'id': 12, 'scientific_name': 'Species beta'});
  await db.insert('species', {'id': 1, 'taxon_id': 11});
  await db.insert('species', {'id': 2, 'taxon_id': 12});
  await db.insert('species_text', {'species_id': 1, 'language_code': 'en', 'common_name': 'Alpha mushroom', 'summary': 'Alpha'});
  await db.insert('species_text', {'species_id': 2, 'language_code': 'en', 'common_name': 'Beta mushroom', 'summary': 'Beta'});
  await db.insert('species_trait', {'species_id': 1, 'trait_id': 1, 'option_id': 101, 'weight': 2.0});
  await db.insert('species_trait', {'species_id': 2, 'trait_id': 1, 'option_id': 102, 'weight': 2.0});
  await db.insert('species_measurement', {'species_id': 1, 'measurement_code': 'cap_diameter', 'min_value': 8.0, 'max_value': 16.0, 'unit': 'cm'});
  await db.insert('species_measurement', {'species_id': 2, 'measurement_code': 'cap_diameter', 'min_value': 20.0, 'max_value': 30.0, 'unit': 'cm'});
  await db.insert('species_season', {'species_id': 1, 'region_code': 'NL', 'month': 10, 'likelihood': 3});
  await db.insert('species_season', {'species_id': 2, 'region_code': 'GB-IE', 'month': 10, 'likelihood': 3});
}
