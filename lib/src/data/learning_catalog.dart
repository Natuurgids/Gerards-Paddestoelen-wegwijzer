import 'learning_access.dart';

class LearningCatalog {
  const LearningCatalog({
    required this.courses,
    required this.modules,
  });

  final List<CourseMetadata> courses;
  final List<LearningModuleMetadata> modules;

  factory LearningCatalog.fromDecoded(Map<String, dynamic> decoded) {
    if (decoded['version'] != 1) {
      throw const FormatException('Learning catalog version must be 1');
    }

    final rawCourses = decoded['courses'];
    final rawModules = decoded['modules'];
    if (rawCourses is! List<dynamic> || rawModules is! List<dynamic>) {
      throw const FormatException('Learning catalog must declare courses and modules');
    }

    final courses = <CourseMetadata>[];
    final courseKeys = <String>{};
    for (final rawCourse in rawCourses) {
      if (rawCourse is! Map<String, dynamic>) {
        throw const FormatException('Each course must be an object');
      }
      final key = _requiredKey(rawCourse['key'], 'course key');
      if (!courseKeys.add(key)) {
        throw FormatException('Duplicate course key: $key');
      }

      final accessValue = rawCourse['access'];
      final accessRequirement = switch (accessValue) {
        'free' => LearningAccessRequirement.free,
        'entitlement_required' => LearningAccessRequirement.entitlementRequired,
        _ => throw FormatException('Invalid access requirement for course $key: $accessValue'),
      };
      final deliveryValue = rawCourse['delivery'];
      final delivery = switch (deliveryValue) {
        'built_in' => LearningContentDelivery.builtIn,
        'downloadable' => LearningContentDelivery.downloadable,
        _ => throw FormatException('Invalid delivery for course $key: $deliveryValue'),
      };
      final entitlementKey = _optionalKey(rawCourse['entitlement_key'], 'entitlement key');
      if (accessRequirement == LearningAccessRequirement.entitlementRequired &&
          entitlementKey == null) {
        throw FormatException('Course $key requires a non-empty entitlement_key');
      }
      if (delivery == LearningContentDelivery.builtIn &&
          accessRequirement != LearningAccessRequirement.free) {
        throw FormatException('Built-in course $key must remain free');
      }

      courses.add(
        CourseMetadata(
          key: key,
          accessRequirement: accessRequirement,
          delivery: delivery,
          entitlementKey: entitlementKey,
          productKey: _optionalKey(rawCourse['product_key'], 'product key'),
          groupKey: _optionalKey(rawCourse['group_key'], 'group key'),
          sortOrder: _sortOrder(rawCourse['sort_order'], 'course $key'),
          prerequisiteCourseKeys: _keyList(
            rawCourse['prerequisite_course_keys'],
            'course prerequisites for $key',
          ),
        ),
      );
    }

    final modules = <LearningModuleMetadata>[];
    final moduleKeys = <String>{};
    final assignedLessons = <int>{};
    for (final rawModule in rawModules) {
      if (rawModule is! Map<String, dynamic>) {
        throw const FormatException('Each module must be an object');
      }
      final key = _requiredKey(rawModule['key'], 'module key');
      if (!moduleKeys.add(key)) {
        throw FormatException('Duplicate module key: $key');
      }
      final courseKey = _requiredKey(rawModule['course_key'], 'course key for module $key');
      if (!courseKeys.contains(courseKey)) {
        throw FormatException('Module $key references unknown course $courseKey');
      }

      final rawLessonIds = rawModule['lesson_ids'];
      if (rawLessonIds is! List<dynamic> || rawLessonIds.isEmpty) {
        throw FormatException('Module $key must declare at least one lesson id');
      }
      final lessonIds = <int>[];
      for (final rawLessonId in rawLessonIds) {
        if (rawLessonId is! int || rawLessonId <= 0) {
          throw FormatException('Module $key has invalid lesson id: $rawLessonId');
        }
        if (!assignedLessons.add(rawLessonId)) {
          throw FormatException(
            'Lesson $rawLessonId is assigned to more than one learning module',
          );
        }
        lessonIds.add(rawLessonId);
      }

      modules.add(
        LearningModuleMetadata(
          key: key,
          courseKey: courseKey,
          lessonIds: List<int>.unmodifiable(lessonIds),
          sortOrder: _sortOrder(rawModule['sort_order'], 'module $key'),
          prerequisiteModuleKeys: _keyList(
            rawModule['prerequisite_module_keys'],
            'module prerequisites for $key',
          ),
        ),
      );
    }

    for (final course in courses) {
      for (final prerequisite in course.prerequisiteCourseKeys) {
        if (prerequisite == course.key || !courseKeys.contains(prerequisite)) {
          throw FormatException(
            'Course ${course.key} has invalid prerequisite $prerequisite',
          );
        }
      }
    }
    for (final module in modules) {
      for (final prerequisite in module.prerequisiteModuleKeys) {
        if (prerequisite == module.key || !moduleKeys.contains(prerequisite)) {
          throw FormatException(
            'Module ${module.key} has invalid prerequisite $prerequisite',
          );
        }
      }
    }

    courses.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    modules.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return LearningCatalog(
      courses: List<CourseMetadata>.unmodifiable(courses),
      modules: List<LearningModuleMetadata>.unmodifiable(modules),
    );
  }

  static String _requiredKey(Object? value, String context) {
    final key = _optionalKey(value, context);
    if (key == null) throw FormatException('$context must be a non-empty string');
    return key;
  }

  static String? _optionalKey(Object? value, String context) {
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty || value.trim() != value) {
      throw FormatException('$context must be a trimmed, non-empty string');
    }
    return value;
  }

  static int _sortOrder(Object? value, String context) {
    if (value == null) return 0;
    if (value is! int) throw FormatException('$context sort_order must be an integer');
    return value;
  }

  static List<String> _keyList(Object? value, String context) {
    if (value == null) return const [];
    if (value is! List<dynamic>) throw FormatException('$context must be a list');
    final result = <String>[];
    final seen = <String>{};
    for (final rawKey in value) {
      final key = _requiredKey(rawKey, context);
      if (!seen.add(key)) throw FormatException('$context contains duplicate $key');
      result.add(key);
    }
    return List<String>.unmodifiable(result);
  }
}
