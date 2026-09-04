import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every curated species has field and gallery coverage', () async {
    final catalogue = jsonDecode(
      await rootBundle.loadString('assets/data/species_catalog.json'),
    ) as Map<String, dynamic>;
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
      final speciesId = (rawSpecies as Map<String, dynamic>)['speciesId'] as int;
      expect(galleryIds.add(speciesId), isTrue,
          reason: 'Gallery manifest may define each species only once');
    }
    expect(galleryIds, containsAll(curatedIds),
        reason: 'Every curated species must have gallery coverage');
  });
}
