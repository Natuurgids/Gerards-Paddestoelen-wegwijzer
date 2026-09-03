import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalogue species has exactly one field and gallery entry',
      () async {
    final catalogue = jsonDecode(
      await rootBundle.loadString('assets/data/species_catalog.json'),
    ) as Map<String, dynamic>;
    final catalogueIds = (catalogue['species'] as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['id'] as int)
        .toSet();

    final fieldData = jsonDecode(
      await rootBundle.loadString('assets/data/field_data.json'),
    ) as Map<String, dynamic>;
    final fieldIds = <int>{};
    for (final rawSpecies in fieldData['species'] as List<dynamic>) {
      final speciesId = (rawSpecies as Map<String, dynamic>)['species_id'] as int;
      expect(fieldIds.add(speciesId), isTrue,
          reason: 'Field data may define each species only once');
    }
    expect(fieldIds, catalogueIds,
        reason: 'Every catalogue species must have one field-data entry');

    final galleries = jsonDecode(
      await rootBundle.loadString('assets/data/species_images.json'),
    ) as Map<String, dynamic>;
    final galleryIds = <int>{};
    for (final rawSpecies in galleries['species'] as List<dynamic>) {
      final speciesId = (rawSpecies as Map<String, dynamic>)['speciesId'] as int;
      expect(galleryIds.add(speciesId), isTrue,
          reason: 'Gallery manifest may define each species only once');
    }
    expect(galleryIds, catalogueIds,
        reason: 'Every catalogue species must have one gallery entry');
  });
}
