import 'learning_access.dart';

const downloadableLearningLessonIdFloor = 1000;
const learningPackageLanguages = {'nl', 'en', 'de'};
const _forbiddenPriceFields = {
  'price',
  'price_amount',
  'display_price',
  'currency',
  'currency_code',
};

class LearningPackageText {
  const LearningPackageText({required this.title, required this.summary});

  final String title;
  final String summary;
}

class LearningPackageDescriptor {
  const LearningPackageDescriptor({
    required this.packageKey,
    required this.courseKey,
    required this.entitlementKey,
    required this.productKey,
    required this.contentVersion,
    required this.packagePath,
    required this.packageSha256,
    required this.packageSizeBytes,
    required this.sortOrder,
    required this.texts,
  });

  final String packageKey;
  final String courseKey;
  final String entitlementKey;
  final String productKey;
  final int contentVersion;
  final String packagePath;
  final String packageSha256;
  final int packageSizeBytes;
  final int sortOrder;
  final Map<String, LearningPackageText> texts;
}

class LearningPackageCatalog {
  const LearningPackageCatalog(this.packages);

  final List<LearningPackageDescriptor> packages;

  factory LearningPackageCatalog.fromDecoded(Map<String, dynamic> decoded) {
    if (decoded['catalog_version'] != 1) {
      throw const FormatException('Learning package catalog version must be 1');
    }
    final rawPackages = decoded['packages'];
    if (rawPackages is! List<dynamic> || rawPackages.isEmpty) {
      throw const FormatException('Learning package catalog must declare packages');
    }

    final result = <LearningPackageDescriptor>[];
    final packageKeys = <String>{};
    final courseKeys = <String>{};
    final entitlementKeys = <String>{};
    final productKeys = <String>{};
    final packagePaths = <String>{};

    for (final raw in rawPackages) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Each learning package descriptor must be an object');
      }
      _rejectPriceFields(raw, 'learning package descriptor');
      final packageKey = _requiredKey(raw['package_key'], 'package_key');
      final courseKey = _requiredKey(raw['course_key'], 'course_key');
      final entitlementKey = _requiredKey(raw['entitlement_key'], 'entitlement_key');
      final productKey = _requiredKey(raw['product_key'], 'product_key');
      final packagePath = _packagePath(raw['package_path']);

      if (!packageKeys.add(packageKey)) {
        throw FormatException('Duplicate package key: $packageKey');
      }
      if (!courseKeys.add(courseKey)) {
        throw FormatException('Duplicate course key: $courseKey');
      }
      if (!entitlementKeys.add(entitlementKey)) {
        throw FormatException('Duplicate entitlement key: $entitlementKey');
      }
      if (!productKeys.add(productKey)) {
        throw FormatException('Duplicate product key: $productKey');
      }
      if (!packagePaths.add(packagePath)) {
        throw FormatException('Duplicate package path: $packagePath');
      }

      final sha = raw['package_sha256'];
      if (sha is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
        throw FormatException('Package $packageKey has invalid SHA-256');
      }

      result.add(
        LearningPackageDescriptor(
          packageKey: packageKey,
          courseKey: courseKey,
          entitlementKey: entitlementKey,
          productKey: productKey,
          contentVersion: _positiveInt(raw['content_version'], 'content_version'),
          packagePath: packagePath,
          packageSha256: sha,
          packageSizeBytes: _positiveInt(raw['package_size_bytes'], 'package_size_bytes'),
          sortOrder: _intOrZero(raw['sort_order'], 'sort_order'),
          texts: _localizedTexts(raw['texts']),
        ),
      );
    }

    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return LearningPackageCatalog(List.unmodifiable(result));
  }
}

class DownloadableLearningPackage {
  const DownloadableLearningPackage({
    required this.packageKey,
    required this.contentVersion,
    required this.course,
    required this.modules,
    required this.trainingContent,
  });

  final String packageKey;
  final int contentVersion;
  final CourseMetadata course;
  final List<LearningModuleMetadata> modules;
  final Map<String, dynamic> trainingContent;

  factory DownloadableLearningPackage.fromDecoded(
    Map<String, dynamic> decoded, {
    required LearningPackageDescriptor expected,
  }) {
    if (decoded['package_version'] != 1) {
      throw const FormatException('Learning package version must be 1');
    }
    if (decoded['package_key'] != expected.packageKey) {
      throw FormatException('Learning package key does not match ${expected.packageKey}');
    }
    final contentVersion = _positiveInt(decoded['content_version'], 'content_version');
    if (contentVersion != expected.contentVersion) {
      throw const FormatException('Learning package content version does not match catalog');
    }

    final rawCourse = decoded['course'];
    if (rawCourse is! Map<String, dynamic>) {
      throw const FormatException('Learning package must declare a course object');
    }
    _rejectPriceFields(rawCourse, 'learning package course');
    if (rawCourse['key'] != expected.courseKey ||
        rawCourse['access'] != 'entitlement_required' ||
        rawCourse['delivery'] != 'downloadable' ||
        rawCourse['entitlement_key'] != expected.entitlementKey ||
        rawCourse['product_key'] != expected.productKey) {
      throw const FormatException('Learning package course metadata does not match catalog');
    }

    final course = CourseMetadata(
      key: expected.courseKey,
      accessRequirement: LearningAccessRequirement.entitlementRequired,
      delivery: LearningContentDelivery.downloadable,
      entitlementKey: expected.entitlementKey,
      productKey: expected.productKey,
      groupKey: _optionalKey(rawCourse['group_key'], 'group_key'),
      sortOrder: _intOrZero(rawCourse['sort_order'], 'course sort_order'),
      prerequisiteCourseKeys: _keyList(
        rawCourse['prerequisite_course_keys'],
        'course prerequisites',
      ),
    );

    final rawModules = decoded['modules'];
    if (rawModules is! List<dynamic> || rawModules.isEmpty) {
      throw const FormatException('Learning package must declare modules');
    }
    final modules = <LearningModuleMetadata>[];
    final moduleKeys = <String>{};
    final assignedLessons = <int>{};
    for (final rawModule in rawModules) {
      if (rawModule is! Map<String, dynamic>) {
        throw const FormatException('Learning package module must be an object');
      }
      final key = _requiredKey(rawModule['key'], 'module key');
      if (!moduleKeys.add(key)) {
        throw FormatException('Duplicate learning package module: $key');
      }
      if (rawModule['course_key'] != expected.courseKey) {
        throw FormatException('Module $key references the wrong course');
      }
      final rawLessonIds = rawModule['lesson_ids'];
      if (rawLessonIds is! List<dynamic> || rawLessonIds.isEmpty) {
        throw FormatException('Module $key must declare lesson ids');
      }
      final lessonIds = <int>[];
      for (final rawId in rawLessonIds) {
        if (rawId is! int || rawId < downloadableLearningLessonIdFloor) {
          throw FormatException('Module $key has invalid downloadable lesson id: $rawId');
        }
        if (!assignedLessons.add(rawId)) {
          throw FormatException('Lesson $rawId is assigned to more than one module');
        }
        lessonIds.add(rawId);
      }
      modules.add(
        LearningModuleMetadata(
          key: key,
          courseKey: expected.courseKey,
          lessonIds: List.unmodifiable(lessonIds),
          sortOrder: _intOrZero(rawModule['sort_order'], 'module sort_order'),
          prerequisiteModuleKeys: _keyList(
            rawModule['prerequisite_module_keys'],
            'module prerequisites',
          ),
        ),
      );
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

    final rawTraining = decoded['training_content'];
    if (rawTraining is! Map<String, dynamic> || rawTraining['version'] != 2) {
      throw const FormatException('Learning package training content must use version 2');
    }
    final rawLessons = rawTraining['lessons'];
    if (rawLessons is! List<dynamic> || rawLessons.isEmpty) {
      throw const FormatException('Learning package training content must contain lessons');
    }
    final trainingLessonIds = <int>{};
    for (final rawLesson in rawLessons) {
      if (rawLesson is! Map<String, dynamic>) {
        throw const FormatException('Learning package lesson must be an object');
      }
      final id = rawLesson['id'];
      if (id is! int || id < downloadableLearningLessonIdFloor || !trainingLessonIds.add(id)) {
        throw FormatException('Learning package has invalid or duplicate lesson id: $id');
      }
    }
    if (trainingLessonIds.length != assignedLessons.length ||
        !trainingLessonIds.containsAll(assignedLessons)) {
      throw const FormatException('Learning package module lessons must exactly match training lessons');
    }

    return DownloadableLearningPackage(
      packageKey: expected.packageKey,
      contentVersion: contentVersion,
      course: course,
      modules: List.unmodifiable(modules),
      trainingContent: Map.unmodifiable(rawTraining),
    );
  }
}

Map<String, LearningPackageText> _localizedTexts(Object? value) {
  if (value is! Map<String, dynamic> || !learningPackageLanguages.every(value.containsKey)) {
    throw const FormatException('Learning package texts must contain nl, en and de');
  }
  final result = <String, LearningPackageText>{};
  for (final language in learningPackageLanguages) {
    final raw = value[language];
    if (raw is! Map<String, dynamic>) {
      throw FormatException('Invalid $language learning package text');
    }
    result[language] = LearningPackageText(
      title: _requiredKey(raw['title'], '$language title'),
      summary: _requiredKey(raw['summary'], '$language summary'),
    );
  }
  return Map.unmodifiable(result);
}

void _rejectPriceFields(Map<String, dynamic> value, String context) {
  for (final field in _forbiddenPriceFields) {
    if (value.containsKey(field)) {
      throw FormatException('$context must not embed store pricing: $field');
    }
  }
}

String _packagePath(Object? value) {
  final path = _requiredKey(value, 'package_path');
  final uri = Uri.tryParse(path);
  if (uri == null ||
      uri.isAbsolute ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.startsWith('/') ||
      !uri.path.startsWith('packages/') ||
      uri.pathSegments.any((segment) => segment == '..' || segment.isEmpty)) {
    throw FormatException('package_path must be a safe relative packages/ path: $path');
  }
  return path;
}

String _requiredKey(Object? value, String context) {
  final key = _optionalKey(value, context);
  if (key == null) throw FormatException('$context must be a non-empty string');
  return key;
}

String? _optionalKey(Object? value, String context) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value.trim() != value) {
    throw FormatException('$context must be a trimmed, non-empty string');
  }
  return value;
}

int _positiveInt(Object? value, String context) {
  if (value is! int || value <= 0) {
    throw FormatException('$context must be a positive integer');
  }
  return value;
}

int _intOrZero(Object? value, String context) {
  if (value == null) return 0;
  if (value is! int) throw FormatException('$context must be an integer');
  return value;
}

List<String> _keyList(Object? value, String context) {
  if (value == null) return const [];
  if (value is! List<dynamic>) throw FormatException('$context must be a list');
  final result = <String>[];
  final seen = <String>{};
  for (final raw in value) {
    final key = _requiredKey(raw, context);
    if (!seen.add(key)) throw FormatException('$context contains duplicate $key');
    result.add(key);
  }
  return List.unmodifiable(result);
}
