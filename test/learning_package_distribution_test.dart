import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/training_manifest_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('distribution publishes seven integrity-locked specialist packs', () async {
    final catalogFile = File(
      'distribution/learning/learning_package_catalog.json',
    );
    final catalogDecoded = jsonDecode(await catalogFile.readAsString());
    expect(catalogDecoded, isA<Map<String, dynamic>>());
    final catalog = LearningPackageCatalog.fromDecoded(
      catalogDecoded as Map<String, dynamic>,
    );

    expect(catalog.packages, hasLength(7));
    expect(
      catalog.packages.map((item) => item.packageKey).toSet(),
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

    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseSchema.create(db);
    addTearDown(db.close);

    final lessonIds = <int>{};
    final questionIds = <int>{};
    final answerIds = <int>{};

    for (final descriptor in catalog.packages) {
      final packageFile = File(
        'distribution/learning/${descriptor.packagePath}',
      );
      final bytes = await packageFile.readAsBytes();
      expect(bytes.length, descriptor.packageSizeBytes);
      expect(sha256.convert(bytes).toString(), descriptor.packageSha256);

      final decoded = jsonDecode(utf8.decode(bytes));
      expect(decoded, isA<Map<String, dynamic>>());
      final learningPackage = DownloadableLearningPackage.fromDecoded(
        decoded as Map<String, dynamic>,
        expected: descriptor,
      );

      expect(
        learningPackage.course.accessRequirement,
        LearningAccessRequirement.entitlementRequired,
      );
      expect(
        learningPackage.course.delivery,
        LearningContentDelivery.downloadable,
      );
      expect(learningPackage.course.entitlementKey, descriptor.entitlementKey);
      expect(learningPackage.course.productKey, descriptor.productKey);
      expect(
        learningPackage.course.prerequisiteCourseKeys,
        contains('determination-foundations'),
      );
      expect(learningPackage.modules, hasLength(3));

      final lessons = learningPackage.trainingContent['lessons'] as List<dynamic>;
      expect(lessons, hasLength(3));
      for (final rawLesson in lessons.cast<Map<String, dynamic>>()) {
        final lessonId = rawLesson['id'] as int;
        expect(lessonId, greaterThanOrEqualTo(downloadableLearningLessonIdFloor));
        expect(lessonIds.add(lessonId), isTrue, reason: 'duplicate lesson $lessonId');

        final questions = rawLesson['questions'] as List<dynamic>;
        for (final rawQuestion in questions.cast<Map<String, dynamic>>()) {
          final questionId = rawQuestion['id'] as int;
          expect(
            questionIds.add(questionId),
            isTrue,
            reason: 'duplicate question $questionId',
          );
          final answers = rawQuestion['answers'] as List<dynamic>;
          for (final rawAnswer in answers.cast<Map<String, dynamic>>()) {
            final answerId = rawAnswer['id'] as int;
            expect(
              answerIds.add(answerId),
              isTrue,
              reason: 'duplicate answer $answerId',
            );
          }
        }
      }

      await TrainingManifestImporter.syncDecoded(
        db,
        learningPackage.trainingContent,
      );
    }

    expect(lessonIds, hasLength(21));
    expect(await db.query('lesson'), hasLength(21));
    expect(await db.query('training_progress'), isEmpty);
  });

  test('catalog and package contracts reject embedded store pricing', () {
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
          'display_price': '€2.99',
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

  test('catalog rejects package paths that can escape the trusted directory', () {
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
