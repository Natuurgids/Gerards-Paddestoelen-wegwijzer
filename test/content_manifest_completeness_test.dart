import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every curated species has field data and gallery references are valid', () async {
    final catalogue = jsonDecode(
      await rootBundle.loadString('assets/data/species_catalog.json'),
    ) as Map<String, dynamic>;
    final catalogueIds = (catalogue['species'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((item) => item['id'] as int)
        .toSet();
    final curatedIds = (catalogue['species'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((item) => item['catalog_only'] != true)
        .map((item) => item['id'] as int)
        .toSet();
    expect(curatedIds, isNotEmpty);

    final fieldData = jsonDecode(
      await rootBundle.loadString('assets/data/field_data.json'),
    ) as Map<String, dynamic>;
    final fieldIds = <int>{};
    for (final rawSpecies in fieldData['species'] as List<dynamic>) {
      final speciesId = (rawSpecies as Map<String, dynamic>)['species_id'] as int;
      expect(fieldIds.add(speciesId), isTrue,
          reason: 'Field data may define each species only once');
    }
    expect(fieldIds, containsAll(curatedIds),
        reason: 'Every curated species must have field-data coverage');

    final galleries = jsonDecode(
      await rootBundle.loadString('assets/data/species_images.json'),
    ) as Map<String, dynamic>;
    final galleryIds = <int>{};
    for (final rawSpecies in galleries['species'] as List<dynamic>) {
      final item = rawSpecies as Map<String, dynamic>;
      final speciesId = item['speciesId'] as int;
      expect(galleryIds.add(speciesId), isTrue,
          reason: 'Gallery manifest may define each species only once');
      expect(catalogueIds, contains(speciesId),
          reason: 'Gallery species must exist in the catalogue');
      expect(item['images'] as List<dynamic>, isNotEmpty,
          reason: 'A gallery entry must contain at least one collected image');
    }
    expect(galleryIds, isNotEmpty,
        reason: 'The bundled collection should contain offline reference images');
  });
}
