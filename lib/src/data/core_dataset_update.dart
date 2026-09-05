import 'dart:convert';

import 'package:flutter/services.dart';

import 'database_schema.dart';

const coreDatasetKey = 'core-reference-content';

const coreDatasetComponents = <String>{
  'species_catalog',
  'identification_traits',
  'supplemental_species_traits',
  'field_data',
  'species_images',
  'training_content',
  'learning_catalog',
};

class CoreDatasetMetadata {
  const CoreDatasetMetadata({
    required this.datasetVersion,
    required this.databaseSchemaVersion,
  });

  static const _assetPath = 'assets/data/dataset_metadata.json';

  final int datasetVersion;
  final int databaseSchemaVersion;

  static Future<CoreDatasetMetadata> loadBundled() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Dataset metadata root must be an object');
    }
    return CoreDatasetMetadata.fromDecoded(decoded);
  }

  factory CoreDatasetMetadata.fromDecoded(Map<String, dynamic> decoded) {
    if (decoded['metadata_version'] != 1) {
      throw const FormatException('Dataset metadata version must be 1');
    }
    if (decoded['dataset_key'] != coreDatasetKey) {
      throw const FormatException('Dataset metadata has an unknown dataset key');
    }

    return CoreDatasetMetadata(
      datasetVersion: _positiveInt(decoded['dataset_version'], 'dataset_version'),
      databaseSchemaVersion: _positiveInt(
        decoded['database_schema_version'],
        'database_schema_version',
      ),
    );
  }
}

class CoreDatasetUpdateManifest {
  CoreDatasetUpdateManifest({
    required this.datasetVersion,
    required this.databaseSchemaVersion,
    required this.publishedAt,
    required this.packageUri,
    required this.packageSha256,
    required this.packageSizeBytes,
    required Iterable<String> components,
  }) : components = Set<String>.unmodifiable(components);

  final int datasetVersion;
  final int databaseSchemaVersion;
  final DateTime publishedAt;
  final Uri packageUri;
  final String packageSha256;
  final int packageSizeBytes;
  final Set<String> components;

  factory CoreDatasetUpdateManifest.fromDecoded(Map<String, dynamic> decoded) {
    if (decoded['manifest_version'] != 1) {
      throw const FormatException('Dataset update manifest version must be 1');
    }
    if (decoded['dataset_key'] != coreDatasetKey) {
      throw const FormatException('Dataset update manifest has an unknown dataset key');
    }

    final publishedAtRaw = decoded['published_at'];
    if (publishedAtRaw is! String || !publishedAtRaw.endsWith('Z')) {
      throw const FormatException('published_at must be an explicit UTC timestamp');
    }
    final publishedAt = DateTime.tryParse(publishedAtRaw);
    if (publishedAt == null || !publishedAt.isUtc) {
      throw const FormatException('published_at must be a valid UTC timestamp');
    }

    final packageUrl = decoded['package_url'];
    final packageUri = packageUrl is String ? Uri.tryParse(packageUrl) : null;
    if (packageUri == null ||
        packageUri.scheme != 'https' ||
        packageUri.host.isEmpty ||
        packageUri.userInfo.isNotEmpty) {
      throw const FormatException('package_url must be an HTTPS URL without user info');
    }

    final sha256 = decoded['package_sha256'];
    if (sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const FormatException('package_sha256 must be 64 lowercase hex characters');
    }

    final rawComponents = decoded['components'];
    if (rawComponents is! List<dynamic> || rawComponents.isEmpty) {
      throw const FormatException('components must be a non-empty list');
    }
    final components = <String>{};
    for (final component in rawComponents) {
      if (component is! String ||
          !coreDatasetComponents.contains(component) ||
          !components.add(component)) {
        throw FormatException('Invalid or duplicate core dataset component: $component');
      }
    }

    return CoreDatasetUpdateManifest(
      datasetVersion: _positiveInt(decoded['dataset_version'], 'dataset_version'),
      databaseSchemaVersion: _positiveInt(
        decoded['database_schema_version'],
        'database_schema_version',
      ),
      publishedAt: publishedAt,
      packageUri: packageUri,
      packageSha256: sha256,
      packageSizeBytes: _positiveInt(
        decoded['package_size_bytes'],
        'package_size_bytes',
      ),
      components: components,
    );
  }
}

enum CoreDatasetUpdateDisposition {
  upToDate,
  updateAvailable,
  incompatibleSchema,
}

class CoreDatasetUpdateCheck {
  const CoreDatasetUpdateCheck({
    required this.disposition,
    required this.installed,
    required this.latest,
  });

  final CoreDatasetUpdateDisposition disposition;
  final CoreDatasetMetadata installed;
  final CoreDatasetUpdateManifest latest;
}

abstract interface class CoreDatasetUpdateSource {
  Future<CoreDatasetUpdateManifest> loadLatestManifest();
}

class CoreDatasetUpdateChecker {
  const CoreDatasetUpdateChecker(this._source);

  final CoreDatasetUpdateSource _source;

  Future<CoreDatasetUpdateCheck> check(CoreDatasetMetadata installed) async {
    final latest = await _source.loadLatestManifest();

    if (latest.datasetVersion <= installed.datasetVersion) {
      return CoreDatasetUpdateCheck(
        disposition: CoreDatasetUpdateDisposition.upToDate,
        installed: installed,
        latest: latest,
      );
    }

    if (installed.databaseSchemaVersion != DatabaseSchema.currentVersion ||
        latest.databaseSchemaVersion != DatabaseSchema.currentVersion) {
      return CoreDatasetUpdateCheck(
        disposition: CoreDatasetUpdateDisposition.incompatibleSchema,
        installed: installed,
        latest: latest,
      );
    }

    return CoreDatasetUpdateCheck(
      disposition: CoreDatasetUpdateDisposition.updateAvailable,
      installed: installed,
      latest: latest,
    );
  }
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('$field must be a positive integer');
  }
  return value;
}
