import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('species catalogue has valid taxonomy and sourced locale fallback', () async {
    final decoded = await _asset('assets/data/species_catalog.json');
    final taxa = decoded['taxa'] as List<dynamic>;
    final species = decoded['species'] as List<dynamic>;
    final taxonIds = <int>{};
    final speciesIds = <int>{};

    for (final rawTaxon in taxa) {
      final taxon = rawTaxon as Map<String, dynamic>;
      expect(taxonIds.add(taxon['id'] as int), isTrue,
          reason: 'Taxon ids must be unique');
      expect((taxon['scientific_name'] as String).trim(), isNotEmpty);
    }

    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      expect(speciesIds.add(item['id'] as int), isTrue,
          reason: 'Species ids must be unique');
      expect(taxonIds, contains(item['taxon_id']));
      final texts = item['texts'] as Map<String, dynamic>;
      expect(
        const {'nl', 'en', 'de'}.any(texts.containsKey),
        isTrue,
        reason: 'Each species needs at least one app-language source text',
      );
      final catalogOnly = item['catalog_only'] == true;
      for (final entry in texts.entries) {
        final text = entry.value as Map<String, dynamic>;
        expect((text['common_name'] as String).trim(), isNotEmpty);
        if (!catalogOnly) {
          expect((text['description'] as String).trim(), isNotEmpty);
        }
      }
      if (catalogOnly) {
        expect((item['source_id'] as String).trim(), isNotEmpty);
        expect((item['source_record_id'] as String).trim(), isNotEmpty);
        expect(item['edible_status'], 'unknown');
        expect(item['toxicity_level'], 'unknown');
      }
    }
  });

  test('identification traits have unique ids and all translations', () async {
    final decoded = await _asset('assets/data/identification_traits.json');
    final traits = decoded['traits'] as List<dynamic>;
    final speciesTraits = decoded['species_traits'] as List<dynamic>;
    final traitIds = <int>{};
    final optionIds = <int>{};

    for (final item in traits) {
      final trait = item as Map<String, dynamic>;
      expect(traitIds.add(trait['id'] as int), isTrue);
      _expectLanguages(trait['labels'] as Map<String, dynamic>);
      for (final rawOption in trait['options'] as List<dynamic>) {
        final option = rawOption as Map<String, dynamic>;
        expect(optionIds.add(option['id'] as int), isTrue);
        _expectLanguages(option['labels'] as Map<String, dynamic>);
      }
    }

    for (final rawRelation in speciesTraits) {
      final relation = rawRelation as Map<String, dynamic>;
      expect(traitIds, contains(relation['trait_id']));
      expect(optionIds, contains(relation['option_id']));
      expect((relation['weight'] as num).toDouble(), greaterThan(0));
    }
  });

  test('species galleries declare five validated image slots', () async {
    final decoded = await _asset('assets/data/species_images.json');
    final species = decoded['species'] as List<dynamic>;
    final allPaths = <String>{};
    const requiredAngles = {'top', 'underside', 'side', 'base', 'habitat'};
    const requiredOrders = {0, 1, 2, 3, 4};

    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      final images = item['images'] as List<dynamic>;
      expect(images, hasLength(5));
      final orders = <int>{};
      final angles = <String>{};
      var primaryCount = 0;
      for (final rawImage in images) {
        final image = rawImage as Map<String, dynamic>;
        final path = (image['path'] as String).trim();
        final angle = (image['angle'] as String).trim();
        expect(orders.add(image['order'] as int), isTrue);
        expect(allPaths.add(path), isTrue);
        expect(path, startsWith('assets/images/species/'));
        expect(requiredAngles, contains(angle));
        expect(angles.add(angle), isTrue);
        if (image['primary'] == true) primaryCount++;
        if (image['placeholder'] != true) {
          expect((image['photographer'] as String).trim(), isNotEmpty);
          expect((image['license'] as String).trim(), isNotEmpty);
        }
      }
      expect(orders, requiredOrders);
      expect(angles, requiredAngles);
      expect(primaryCount, 1);
    }
  });

  test('field data has valid localized regions, ranges and calendars', () async {
    final decoded = await _asset('assets/data/field_data.json');
    final declaredRegions = <String>{};
    final regionCodePattern = RegExp(r'^[A-Z]{2}(?:-[A-Z]{2})*$');

    for (final rawRegion
        in decoded['season_regions'] as List<dynamic>? ?? const []) {
      final region = rawRegion as Map<String, dynamic>;
      final code = (region['code'] as String).trim();
      expect(code, matches(regionCodePattern));
      expect(declaredRegions.add(code), isTrue);
      _expectLanguages(region['labels'] as Map<String, dynamic>);
      _expectLanguages(region['notes'] as Map<String, dynamic>);
    }

    for (final rawSpecies in decoded['species'] as List<dynamic>) {
      final item = rawSpecies as Map<String, dynamic>;
      final measurementCodes = <String>{};
      for (final rawMeasurement
          in item['measurements'] as List<dynamic>? ?? const []) {
        final measurement = rawMeasurement as Map<String, dynamic>;
        expect(measurementCodes.add(measurement['code'] as String), isTrue);
        final min = (measurement['min'] as num).toDouble();
        final max = (measurement['max'] as num).toDouble();
        expect(min, greaterThanOrEqualTo(0));
        expect(max, greaterThanOrEqualTo(min));
        expect((measurement['unit'] as String).trim(), isNotEmpty);
      }
      final regionCodes = <String>{};
      for (final rawDataset
          in item['season_datasets'] as List<dynamic>? ?? const []) {
        final dataset = rawDataset as Map<String, dynamic>;
        final regionCode = (dataset['region_code'] as String).trim();
        expect(declaredRegions, contains(regionCode));
        expect(regionCodes.add(regionCode), isTrue);
        final months = <int>{};
        for (final rawMonth in dataset['months'] as List<dynamic>? ?? const []) {
          final month = rawMonth as Map<String, dynamic>;
          final value = month['month'] as int;
          expect(months.add(value), isTrue);
          expect(value, inInclusiveRange(1, 12));
          expect(month['likelihood'] as int, inInclusiveRange(1, 3));
        }
      }
    }
  });

  test('all species references resolve to catalogue species', () async {
    final catalogue = await _asset('assets/data/species_catalog.json');
    final catalogueIds = (catalogue['species'] as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['id'] as int)
        .toSet();

    final traits = await _asset('assets/data/identification_traits.json');
    final supplemental = await _asset('assets/data/species_traits_europe.json');
    for (final rawRelation in <dynamic>[
      ...(traits['species_traits'] as List<dynamic>),
      ...(supplemental['species_traits'] as List<dynamic>),
    ]) {
      final relation = rawRelation as Map<String, dynamic>;
      expect(catalogueIds, contains(relation['species_id']));
    }

    final fieldData = await _asset('assets/data/field_data.json');
    for (final rawSpecies in fieldData['species'] as List<dynamic>) {
      expect(
        catalogueIds,
        contains((rawSpecies as Map<String, dynamic>)['species_id']),
      );
    }

    final images = await _asset('assets/data/species_images.json');
    for (final rawSpecies in images['species'] as List<dynamic>) {
      expect(
        catalogueIds,
        contains((rawSpecies as Map<String, dynamic>)['speciesId']),
      );
    }
  });

  test('training content has complete translations and one correct answer',
      () async {
    final decoded = await _asset('assets/data/training_content.json');
    final lessonIds = <int>{};
    final questionIds = <int>{};
    final answerIds = <int>{};

    for (final rawLesson in decoded['lessons'] as List<dynamic>) {
      final lesson = rawLesson as Map<String, dynamic>;
      expect(lessonIds.add(lesson['id'] as int), isTrue);
      _expectLocalizedObjects(
        lesson['texts'] as Map<String, dynamic>,
        ['title', 'body'],
      );
      for (final rawQuestion in lesson['questions'] as List<dynamic>) {
        final question = rawQuestion as Map<String, dynamic>;
        expect(questionIds.add(question['id'] as int), isTrue);
        _expectLocalizedObjects(
          question['texts'] as Map<String, dynamic>,
          ['prompt'],
        );
        final answers = question['answers'] as List<dynamic>;
        expect(answers.length, greaterThanOrEqualTo(2));
        var correctCount = 0;
        for (final rawAnswer in answers) {
          final answer = rawAnswer as Map<String, dynamic>;
          expect(answerIds.add(answer['id'] as int), isTrue);
          _expectLanguages(answer['labels'] as Map<String, dynamic>);
          if (answer['correct'] == true) correctCount++;
        }
        expect(correctCount, 1);
      }
    }
  });
}

Future<Map<String, dynamic>> _asset(String path) async {
  final raw = await rootBundle.loadString(path);
  return jsonDecode(raw) as Map<String, dynamic>;
}

void _expectLanguages(Map<String, dynamic> labels) {
  for (final language in const ['nl', 'en', 'de']) {
    expect(labels[language], isA<String>());
    expect((labels[language] as String).trim(), isNotEmpty);
  }
}

void _expectLocalizedObjects(
  Map<String, dynamic> values,
  List<String> requiredFields,
) {
  for (final language in const ['nl', 'en', 'de']) {
    expect(values, contains(language));
    final object = values[language] as Map<String, dynamic>;
    for (final field in requiredFields) {
      expect(object[field], isA<String>());
      expect((object[field] as String).trim(), isNotEmpty);
    }
  }
}
