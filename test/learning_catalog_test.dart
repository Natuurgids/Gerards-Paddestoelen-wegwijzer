import 'package:flutter_test/flutter_test.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_catalog.dart';

void main() {
  test('parses free and entitlement-required courses without provider coupling', () async {
    final catalog = LearningCatalog.fromDecoded({
      'version': 1,
      'courses': [
        {
          'key': 'basics',
          'access': 'free',
          'group_key': 'foundation',
          'sort_order': 10,
        },
        {
          'key': 'advanced',
          'access': 'entitlement_required',
          'entitlement_key': 'course.advanced',
          'product_key': 'advanced-single',
          'group_key': 'advanced',
          'sort_order': 20,
          'prerequisite_course_keys': ['basics'],
        },
      ],
      'modules': [
        {
          'key': 'basics-1',
          'course_key': 'basics',
          'lesson_ids': [1, 2],
          'sort_order': 10,
        },
        {
          'key': 'advanced-1',
          'course_key': 'advanced',
          'lesson_ids': [100],
          'sort_order': 20,
          'prerequisite_module_keys': ['basics-1'],
        },
      ],
    });

    expect(catalog.courses.map((course) => course.key), ['basics', 'advanced']);
    expect(catalog.modules.map((module) => module.key), ['basics-1', 'advanced-1']);
    expect(catalog.courses.last.productKey, 'advanced-single');
    expect(catalog.courses.last.entitlementKey, 'course.advanced');

    final policy = LearningAccessPolicy(_FakeEntitlements(const []));
    expect(
      await policy.accessibleLessonIds(
        courses: catalog.courses,
        modules: catalog.modules,
      ),
      {1, 2},
    );
  });

  test('rejects premium course without a logical entitlement key', () {
    expect(
      () => LearningCatalog.fromDecoded({
        'version': 1,
        'courses': [
          {
            'key': 'premium',
            'access': 'entitlement_required',
          },
        ],
        'modules': const [],
      }),
      throwsFormatException,
    );
  });

  test('rejects assigning one lesson to multiple access modules', () {
    expect(
      () => LearningCatalog.fromDecoded({
        'version': 1,
        'courses': [
          {'key': 'free', 'access': 'free'},
          {
            'key': 'premium',
            'access': 'entitlement_required',
            'entitlement_key': 'course.premium',
          },
        ],
        'modules': [
          {
            'key': 'free-module',
            'course_key': 'free',
            'lesson_ids': [7],
          },
          {
            'key': 'premium-module',
            'course_key': 'premium',
            'lesson_ids': [7],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects unknown course and module prerequisites', () {
    expect(
      () => LearningCatalog.fromDecoded({
        'version': 1,
        'courses': [
          {
            'key': 'basics',
            'access': 'free',
            'prerequisite_course_keys': ['missing'],
          },
        ],
        'modules': const [],
      }),
      throwsFormatException,
    );

    expect(
      () => LearningCatalog.fromDecoded({
        'version': 1,
        'courses': [
          {'key': 'basics', 'access': 'free'},
        ],
        'modules': [
          {
            'key': 'module',
            'course_key': 'basics',
            'lesson_ids': [1],
            'prerequisite_module_keys': ['missing'],
          },
        ],
      }),
      throwsFormatException,
    );
  });
}

class _FakeEntitlements implements EntitlementRepository {
  _FakeEntitlements(Iterable<String> keys) : _snapshot = EntitlementSnapshot(keys);

  final EntitlementSnapshot _snapshot;

  @override
  Future<EntitlementSnapshot> loadEntitlements() async => _snapshot;
}
