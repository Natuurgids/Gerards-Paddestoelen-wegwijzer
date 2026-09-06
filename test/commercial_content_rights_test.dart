import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('First Nature catalogue references do not redistribute prose', () async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/species_catalog.json'),
    ) as Map<String, dynamic>;
    final referenced = (decoded['species'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((item) => item['source_id'] == 'first-nature')
        .toList();

    expect(referenced, isNotEmpty);
    for (final item in referenced) {
      expect(item['catalog_only'], isTrue);
      expect(item['edible_status'], 'unknown');
      expect(item['toxicity_level'], 'unknown');
      final texts = item['texts'] as Map<String, dynamic>;
      for (final entry in texts.entries) {
        final text = entry.value as Map<String, dynamic>;
        final isReviewedDutchEcology =
            entry.key == 'nl' && text['habitat_basis'] == 'species';
        final isGenusEcology =
            entry.key == 'nl' &&
            text['habitat_basis'] == 'genus' &&
            text['habitat_source_id'] == 'fungaltraits-globi';
        if (isReviewedDutchEcology) {
          expect(
            text.keys,
            unorderedEquals(const [
              'common_name',
              'habitat',
              'habitat_source_id',
              'habitat_basis',
              'lookalikes',
              'lookalikes_source_id',
              'lookalikes_source_record_id',
            ]),
          );
          expect(text['habitat_source_id'], 'first-nature');
          expect(text['lookalikes_source_id'], 'first-nature');
          expect(
            (text['lookalikes_source_record_id'] as String).trim(),
            isNotEmpty,
          );
          expect((text['habitat'] as String).trim(), isNotEmpty);
          expect((text['lookalikes'] as String).trim(), isNotEmpty);
        } else if (isGenusEcology) {
          expect(
            text.keys,
            unorderedEquals(const [
              'common_name',
              'habitat',
              'habitat_source_id',
              'habitat_basis',
            ]),
          );
          expect((text['habitat'] as String).trim(), isNotEmpty);
        } else {
          expect(text.keys, unorderedEquals(const ['common_name']));
        }
        expect((text['common_name'] as String).trim(), isNotEmpty);
      }
    }
  });
}
