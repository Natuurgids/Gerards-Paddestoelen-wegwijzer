import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/reference_asset_store.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/resilient_identification_repository.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/resilient_species_repository.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/species_browser_repository.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/training_data_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Database> failingDatabase() async => throw StateError('db unavailable');

  test('species browser falls back to bundled catalogue', () async {
    final repo = SpeciesBrowserRepository(databaseProvider: failingDatabase);

    final all = await repo.searchPage('nl', limit: 10);
    expect(all, hasLength(3));

    final filtered = await repo.searchPage('nl', query: 'vlieg', limit: 10);
    expect(filtered, hasLength(1));
    expect(filtered.single.scientificName, 'Amanita muscaria');
  });

  test('bundled species detail contains gallery and field data', () async {
    final detail = await ReferenceAssetStore.instance.speciesDetail(1, 'nl');

    expect(detail, isNotNull);
    expect(detail!.scientificName, 'Amanita muscaria');
    expect(detail.images, hasLength(5));
    expect(detail.measurements, isNotEmpty);
    expect(detail.season, isNotEmpty);
  });

  test('species detail falls back when database is unavailable', () async {
    final repo = ResilientSpeciesRepository(databaseProvider: failingDatabase);

    final detail = await repo.detail(2, 'en');

    expect(detail, isNotNull);
    expect(detail!.scientificName, 'Amanita phalloides');
    expect(detail.images, hasLength(5));
  });

  test('determination falls back to bundled traits and mappings', () async {
    final repo = ResilientIdentificationRepository(
      databaseProvider: failingDatabase,
    );

    final choices = await repo.choices('nl');
    expect(choices, hasLength(139));

    final candidates = await repo.identify('nl', {1: 1});
    expect(candidates, isNotEmpty);
    expect(
      candidates.any((candidate) =>
          candidate.species.scientificName == 'Amanita muscaria'),
      isTrue,
    );
  });

  test('training falls back to bundled lessons and questions', () async {
    final repo = TrainingDataRepository(databaseProvider: failingDatabase);

    final lessons = await repo.lessons('nl');
    expect(lessons, hasLength(12));

    final questions = await repo.questions(1, 'nl');
    expect(questions, hasLength(5));
    expect(questions.every((question) => question.answers.length == 3), isTrue);
  });

  test('species browser does not wait forever for a stuck database', () async {
    final never = Completer<Database>();
    final repo = SpeciesBrowserRepository(databaseProvider: () => never.future);
    final stopwatch = Stopwatch()..start();

    final rows = await repo.searchPage('en', limit: 10);

    stopwatch.stop();
    expect(rows, hasLength(3));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)));
  });
}
