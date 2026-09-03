import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('species catalogue has valid taxonomy and all translations', () async {
    final raw = await rootBundle.loadString('assets/data/species_catalog.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
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
      for (final language in const ['nl', 'en', 'de']) {
        expect(texts, contains(language));
        final text = texts[language] as Map<String, dynamic>;
        expect((text['common_name'] as String).trim(), isNotEmpty);
        expect((text['description'] as String).trim(), isNotEmpty);
      }
    }
  });

  test('identification traits have unique ids and all translations', () async {
    final raw = await rootBundle.loadString('assets/data/identification_traits.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final traits = decoded['traits'] as List<dynamic>;
    final speciesTraits = decoded['species_traits'] as List<dynamic>;
    final traitIds = <int>{};
    final optionIds = <int>{};

    for (final item in traits) {
      final trait = item as Map<String, dynamic>;
      expect(traitIds.add(trait['id'] as int), isTrue,
          reason: 'Trait ids must be unique');
      _expectLanguages(trait['labels'] as Map<String, dynamic>);

      for (final rawOption in trait['options'] as List<dynamic>) {
        final option = rawOption as Map<String, dynamic>;
        expect(optionIds.add(option['id'] as int), isTrue,
            reason: 'Trait option ids must be unique');
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

  test('seed species galleries declare five ordered image slots', () async {
    final raw = await rootBundle.loadString('assets/data/species_images.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final species = decoded['species'] as List<dynamic>;

    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      final images = item['images'] as List<dynamic>;
      expect(images.length, 5,
          reason: 'Each seeded species should expose five gallery slots');

      final orders = <int>{};
      var primaryCount = 0;
      for (final rawImage in images) {
        final image = rawImage as Map<String, dynamic>;
        expect(orders.add(image['order'] as int), isTrue,
            reason: 'Gallery sort orders must be unique per species');
        final path = image['path'] as String;
        expect(path, startsWith('assets/images/species/'));
        if (image['primary'] == true) primaryCount++;
      }
      expect(primaryCount, 1,
          reason: 'Each seeded species should have exactly one primary image');
    }
  });
}

void _expectLanguages(Map<String, dynamic> labels) {
  for (final language in const ['nl', 'en', 'de']) {
    expect(labels[language], isA<String>());
    expect((labels[language] as String).trim(), isNotEmpty);
  }
}
