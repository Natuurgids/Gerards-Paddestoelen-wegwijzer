import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public catalog exposes exactly seven safe learning offerings', () async {
    final raw = await File(LearningOfferingCatalog.assetPath).readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final catalog = LearningOfferingCatalog.fromDecoded(decoded);

    expect(catalog.offerings, hasLength(7));
    expect(
      catalog.offerings.map((item) => item.packageKey).toSet(),
      {
        'boletes-pores',
        'gilled-mushrooms',
        'amanitas-dangerous-lookalikes',
        'russulas-milkcaps',
        'bracket-fungi-wood-decay',
        'small-brown-mushrooms',
        'field-microscopy-spores',
      },
    );
    for (final offering in catalog.offerings) {
      expect(offering.entitlementKey, startsWith('learning.specialist.'));
      expect(offering.productKey, startsWith('learning_pack_'));
      expect(offering.groupKey, 'specializations');
      for (final language in learningOfferingLanguages) {
        final text = offering.textFor(language);
        expect(text.title, isNotEmpty);
        expect(text.summary, isNotEmpty);
      }
    }
  });

  test('current public tree contains no paid learning payload or delivery catalog', () {
    expect(
      Directory('distribution/learning/packages').existsSync(),
      isFalse,
      reason: 'Paid learning payloads must live on controlled content hosting, not in the public app repository.',
    );
    expect(
      File('distribution/learning/learning_package_catalog.json').existsSync(),
      isFalse,
      reason: 'Remote delivery metadata belongs on the controlled learning content origin.',
    );
  });

  test('public offering catalog rejects delivery and pricing fields', () {
    final decoded = <String, dynamic>{
      'catalog_version': 1,
      'offerings': [
        {
          'package_key': 'test-pack',
          'course_key': 'test-course',
          'entitlement_key': 'learning.test',
          'product_key': 'learning_pack_test',
          'group_key': 'specializations',
          'sort_order': 1,
          'package_path': 'packages/test.json',
          'texts': {
            'nl': {'title': 'Test', 'summary': 'Test'},
            'en': {'title': 'Test', 'summary': 'Test'},
            'de': {'title': 'Test', 'summary': 'Test'},
          },
        },
      ],
    };

    expect(
      () => LearningOfferingCatalog.fromDecoded(decoded),
      throwsFormatException,
    );
  });

  test('remote package contract still rejects embedded store pricing', () {
    final catalogWithPrice = <String, dynamic>{
      'catalog_version': 1,
      'packages': [
        {
          'package_key': 'test-pack',
          'course_key': 'test-course',
          'entitlement_key': 'learning.test',
          'product_key': 'learning_pack_test',
          'content_version': 1,
          'package_path': 'packages/test.json',
          'package_sha256': List.filled(64, 'a').join(),
          'package_size_bytes': 1,
          'display_price': '2.99',
          'texts': {
            'nl': {'title': 'Test', 'summary': 'Test'},
            'en': {'title': 'Test', 'summary': 'Test'},
            'de': {'title': 'Test', 'summary': 'Test'},
          },
        },
      ],
    };

    expect(
      () => LearningPackageCatalog.fromDecoded(catalogWithPrice),
      throwsFormatException,
    );
  });

  test('remote catalog rejects paths that escape its package directory', () {
    final decoded = <String, dynamic>{
      'catalog_version': 1,
      'packages': [
        {
          'package_key': 'test-pack',
          'course_key': 'test-course',
          'entitlement_key': 'learning.test',
          'product_key': 'learning_pack_test',
          'content_version': 1,
          'package_path': 'packages/../secret.json',
          'package_sha256': List.filled(64, 'a').join(),
          'package_size_bytes': 1,
          'texts': {
            'nl': {'title': 'Test', 'summary': 'Test'},
            'en': {'title': 'Test', 'summary': 'Test'},
            'de': {'title': 'Test', 'summary': 'Test'},
          },
        },
      ],
    };

    expect(
      () => LearningPackageCatalog.fromDecoded(decoded),
      throwsFormatException,
    );
  });
}
