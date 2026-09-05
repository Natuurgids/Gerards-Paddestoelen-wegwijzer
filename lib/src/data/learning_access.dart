enum LearningAccessRequirement {
  free,
  entitlementRequired,
}

enum LearningContentDelivery {
  builtIn,
  downloadable,
}

class CourseMetadata {
  const CourseMetadata({
    required this.key,
    required this.accessRequirement,
    required this.delivery,
    required this.sortOrder,
    this.entitlementKey,
    this.productKey,
    this.groupKey,
    this.prerequisiteCourseKeys = const [],
  })  : assert(
          accessRequirement == LearningAccessRequirement.free ||
              entitlementKey != null,
          'Entitlement-required courses need an entitlement key.',
        ),
        assert(
          delivery != LearningContentDelivery.builtIn ||
              accessRequirement == LearningAccessRequirement.free,
          'Built-in product content must always remain free.',
        );

  final String key;
  final LearningAccessRequirement accessRequirement;

  /// Whether the course ships as part of the standard product or is obtained
  /// separately as downloadable material.
  ///
  /// Built-in material is a permanent free part of the product. Downloadable
  /// material may still be free, or may require a logical entitlement.
  final LearningContentDelivery delivery;

  /// Stable logical entitlement understood by the app.
  ///
  /// This is deliberately not a Google Play, App Store, web-payment, or other
  /// provider identifier. Multiple commerce providers may grant the same key.
  final String? entitlementKey;

  /// Optional commerce catalogue key for future mapping outside content logic.
  /// It is metadata only and is never consulted by [LearningAccessPolicy].
  final String? productKey;

  final String? groupKey;
  final int sortOrder;
  final List<String> prerequisiteCourseKeys;
}

class LearningModuleMetadata {
  const LearningModuleMetadata({
    required this.key,
    required this.courseKey,
    required this.lessonIds,
    required this.sortOrder,
    this.prerequisiteModuleKeys = const [],
  });

  final String key;
  final String courseKey;
  final List<int> lessonIds;
  final int sortOrder;
  final List<String> prerequisiteModuleKeys;
}

class EntitlementSnapshot {
  EntitlementSnapshot(Iterable<String> keys)
      : keys = Set<String>.unmodifiable(keys);

  final Set<String> keys;

  bool grants(String entitlementKey) => keys.contains(entitlementKey);
}

abstract interface class EntitlementRepository {
  Future<EntitlementSnapshot> loadEntitlements();
}

class LearningAccessPolicy {
  const LearningAccessPolicy(this._entitlements);

  final EntitlementRepository _entitlements;

  Future<bool> canAccessCourse(CourseMetadata course) async {
    if (course.accessRequirement == LearningAccessRequirement.free) {
      return true;
    }
    final key = course.entitlementKey;
    if (key == null || key.trim().isEmpty) return false;
    final snapshot = await _entitlements.loadEntitlements();
    return snapshot.grants(key);
  }

  /// Returns only lesson ids belonging to courses the current entitlement
  /// snapshot permits. This is the boundary repositories/UI can use to avoid
  /// leaking locked premium lesson content.
  Future<Set<int>> accessibleLessonIds({
    required Iterable<CourseMetadata> courses,
    required Iterable<LearningModuleMetadata> modules,
  }) async {
    final courseByKey = <String, CourseMetadata>{
      for (final course in courses) course.key: course,
    };
    final snapshot = await _entitlements.loadEntitlements();
    final accessibleCourses = <String>{};

    for (final course in courses) {
      if (course.accessRequirement == LearningAccessRequirement.free) {
        accessibleCourses.add(course.key);
        continue;
      }
      final key = course.entitlementKey;
      if (key != null && key.trim().isNotEmpty && snapshot.grants(key)) {
        accessibleCourses.add(course.key);
      }
    }

    return {
      for (final module in modules)
        if (courseByKey.containsKey(module.courseKey) &&
            accessibleCourses.contains(module.courseKey))
          ...module.lessonIds,
    };
  }
}
