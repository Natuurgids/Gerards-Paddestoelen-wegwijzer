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
      for (final rawText in texts.values) {
        final text = rawText as Map<String, dynamic>;
        expect(text.keys, unorderedEquals(const ['common_name']));
        expect((text['common_name'] as String).trim(), isNotEmpty);
      }
    }
  });
}
