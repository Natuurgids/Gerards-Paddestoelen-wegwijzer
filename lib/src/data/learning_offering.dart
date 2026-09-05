import 'dart:convert';

import 'package:flutter/services.dart';

const learningOfferingLanguages = {'nl', 'en', 'de'};
const _forbiddenOfferingFields = {
  'price',
  'price_amount',
  'display_price',
  'currency',
  'currency_code',
  'content_version',
  'package_path',
  'package_sha256',
  'package_size_bytes',
  'modules',
  'lessons',
  'training_content',
};

class LearningOfferingText {
  const LearningOfferingText({required this.title, required this.summary});

  final String title;
  final String summary;
}

class LearningOffering {
  const LearningOffering({
    required this.packageKey,
    required this.courseKey,
    required this.entitlementKey,
    required this.productKey,
    required this.groupKey,
    required this.sortOrder,
    required this.texts,
  });

  final String packageKey;
  final String courseKey;
  final String entitlementKey;
  final String productKey;
  final String groupKey;
  final int sortOrder;
  final Map<String, LearningOfferingText> texts;

  LearningOfferingText textFor(String languageCode) =>
      texts[languageCode] ?? texts['nl']!;
}

class LearningOfferingCatalog {
  const LearningOfferingCatalog(this.offerings);

  static const assetPath = 'assets/data/learning_offerings.json';

  final List<LearningOffering> offerings;

  static Future<LearningOfferingCatalog> loadBundled() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Learning offering catalog root must be an object');
    }
    return LearningOfferingCatalog.fromDecoded(decoded);
  }

  factory LearningOfferingCatalog.fromDecoded(Map<String, dynamic> decoded) {
    if (decoded['catalog_version'] != 1) {
      throw const FormatException('Learning offering catalog version must be 1');
    }
    final rawOfferings = decoded['offerings'];
    if (rawOfferings is! List<dynamic> || rawOfferings.isEmpty) {
      throw const FormatException('Learning offering catalog must declare offerings');
    }

    final offerings = <LearningOffering>[];
    final packageKeys = <String>{};
    final courseKeys = <String>{};
    final entitlementKeys = <String>{};
    final productKeys = <String>{};
    for (final raw in rawOfferings) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Learning offering must be an object');
      }
      for (final field in _forbiddenOfferingFields) {
        if (raw.containsKey(field)) {
          throw FormatException(
            'Public learning offering must not contain delivery or pricing field: $field',
          );
        }
      }

      final packageKey = _requiredString(raw['package_key'], 'package_key');
      final courseKey = _requiredString(raw['course_key'], 'course_key');
      final entitlementKey =
          _requiredString(raw['entitlement_key'], 'entitlement_key');
      final productKey = _requiredString(raw['product_key'], 'product_key');
      if (!packageKeys.add(packageKey) ||
          !courseKeys.add(courseKey) ||
          !entitlementKeys.add(entitlementKey) ||
          !productKeys.add(productKey)) {
        throw const FormatException('Learning offering keys must be unique');
      }

      offerings.add(
        LearningOffering(
          packageKey: packageKey,
          courseKey: courseKey,
          entitlementKey: entitlementKey,
          productKey: productKey,
          groupKey: _requiredString(raw['group_key'], 'group_key'),
          sortOrder: _integer(raw['sort_order'], 'sort_order'),
          texts: _localizedTexts(raw['texts']),
        ),
      );
    }
    offerings.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return LearningOfferingCatalog(List.unmodifiable(offerings));
  }
}

Map<String, LearningOfferingText> _localizedTexts(Object? value) {
  if (value is! Map<String, dynamic> ||
      !learningOfferingLanguages.every(value.containsKey)) {
    throw const FormatException('Learning offering texts must contain nl, en and de');
  }
  return Map.unmodifiable({
    for (final language in learningOfferingLanguages)
      language: _parseText(value[language], language),
  });
}

LearningOfferingText _parseText(Object? value, String language) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Invalid $language learning offering text');
  }
  return LearningOfferingText(
    title: _requiredString(value['title'], '$language title'),
    summary: _requiredString(value['summary'], '$language summary'),
  );
}

String _requiredString(Object? value, String context) {
  if (value is! String || value.trim().isEmpty || value.trim() != value) {
    throw FormatException('$context must be a trimmed non-empty string');
  }
  return value;
}

int _integer(Object? value, String context) {
  if (value is! int) throw FormatException('$context must be an integer');
  return value;
}
