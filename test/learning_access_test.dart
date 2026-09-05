import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';

void main() {
  const freeCourse = CourseMetadata(
    key: 'basics',
    accessRequirement: LearningAccessRequirement.free,
    delivery: LearningContentDelivery.builtIn,
    sortOrder: 10,
    groupKey: 'foundation',
  );
  const premiumCourse = CourseMetadata(
    key: 'advanced-genera',
    accessRequirement: LearningAccessRequirement.entitlementRequired,
    delivery: LearningContentDelivery.downloadable,
    entitlementKey: 'course.advanced-genera',
    productKey: 'advanced-genera-single',
    sortOrder: 20,
    groupKey: 'advanced',
    prerequisiteCourseKeys: ['basics'],
  );
  const modules = [
    LearningModuleMetadata(
      key: 'basics-1',
      courseKey: 'basics',
      lessonIds: [1, 2],
      sortOrder: 10,
    ),
    LearningModuleMetadata(
      key: 'advanced-genera-1',
      courseKey: 'advanced-genera',
      lessonIds: [100, 101],
      sortOrder: 10,
      prerequisiteModuleKeys: ['basics-1'],
    ),
  ];

  test('built-in lessons remain accessible without entitlements', () async {
    final policy = LearningAccessPolicy(_FakeEntitlementRepository(const []));

    expect(freeCourse.delivery, LearningContentDelivery.builtIn);
    expect(await policy.canAccessCourse(freeCourse), isTrue);
    expect(
      await policy.accessibleLessonIds(
        courses: const [freeCourse, premiumCourse],
        modules: modules,
      ),
      {1, 2},
    );
  });

  test('locked downloadable lessons do not leak without entitlement', () async {
    final repository = _FakeEntitlementRepository(const []);
    final policy = LearningAccessPolicy(repository);

    expect(premiumCourse.delivery, LearningContentDelivery.downloadable);
    expect(await policy.canAccessCourse(premiumCourse), isFalse);
    final lessonIds = await policy.accessibleLessonIds(
      courses: const [freeCourse, premiumCourse],
      modules: modules,
    );

    expect(lessonIds, containsAll(<int>[1, 2]));
    expect(lessonIds, isNot(contains(100)));
    expect(lessonIds, isNot(contains(101)));
  });

  test('the same logical entitlement unlocks downloadable content', () async {
    final policy = LearningAccessPolicy(
      _FakeEntitlementRepository(const ['course.advanced-genera']),
    );

    expect(await policy.canAccessCourse(premiumCourse), isTrue);
    expect(
      await policy.accessibleLessonIds(
        courses: const [freeCourse, premiumCourse],
        modules: modules,
      ),
      {1, 2, 100, 101},
    );
  });

  test('product key is metadata and cannot grant access', () async {
    final policy = LearningAccessPolicy(
      _FakeEntitlementRepository(const ['advanced-genera-single']),
    );

    expect(await policy.canAccessCourse(premiumCourse), isFalse);
  });

  test('course and module ordering/prerequisite metadata stays data-driven', () {
    expect(premiumCourse.groupKey, 'advanced');
    expect(premiumCourse.sortOrder, 20);
    expect(premiumCourse.prerequisiteCourseKeys, ['basics']);
    expect(modules.last.sortOrder, 10);
    expect(modules.last.prerequisiteModuleKeys, ['basics-1']);
  });
}

class _FakeEntitlementRepository implements EntitlementRepository {
  _FakeEntitlementRepository(Iterable<String> keys)
      : _snapshot = EntitlementSnapshot(keys);

  final EntitlementSnapshot _snapshot;

  @override
  Future<EntitlementSnapshot> loadEntitlements() async => _snapshot;
}
