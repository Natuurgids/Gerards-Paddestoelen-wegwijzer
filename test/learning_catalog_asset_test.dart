import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog keeps every current packaged lesson free', () async {
    final trainingRaw = await rootBundle.loadString(
      'assets/data/training_content.json',
    );
    final training = jsonDecode(trainingRaw) as Map<String, dynamic>;
    final packagedLessonIds = {
      for (final rawLesson in training['lessons'] as List<dynamic>)
        (rawLesson as Map<String, dynamic>)['id'] as int,
    };

    final catalog = await LearningCatalog.loadBundled();
    final catalogLessonIds = {
      for (final module in catalog.modules) ...module.lessonIds,
    };

    expect(packagedLessonIds, isNotEmpty);
    expect(catalogLessonIds, packagedLessonIds);
    expect(
      catalog.courses.map((course) => course.accessRequirement),
      everyElement(LearningAccessRequirement.free),
    );
    expect(
      catalog.courses.map((course) => course.entitlementKey),
      everyElement(isNull),
    );
  });

  test('empty entitlement state still exposes all bundled free lessons',
      () async {
    final catalog = await LearningCatalog.loadBundled();
    final policy = LearningAccessPolicy(_EmptyEntitlementRepository());

    final accessible = await policy.accessibleLessonIds(
      courses: catalog.courses,
      modules: catalog.modules,
    );
    final bundled = {
      for (final module in catalog.modules) ...module.lessonIds,
    };

    expect(accessible, bundled);
  });

  test('bundled modules form an explicit learning sequence', () async {
    final catalog = await LearningCatalog.loadBundled();

    expect(
      catalog.modules.map((module) => module.key),
      [
        'observe-structures',
        'field-evidence-and-context',
        'documentation-and-safety',
      ],
    );
    expect(
      catalog.modules[1].prerequisiteModuleKeys,
      ['observe-structures'],
    );
    expect(
      catalog.modules[2].prerequisiteModuleKeys,
      ['field-evidence-and-context'],
    );
  });
}

class _EmptyEntitlementRepository implements EntitlementRepository {
  @override
  Future<EntitlementSnapshot> loadEntitlements() async =>
      EntitlementSnapshot(const []);
}
