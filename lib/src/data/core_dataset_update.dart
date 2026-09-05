import 'dart:convert';

import 'package:flutter/services.dart';

import 'database_schema.dart';

const coreDatasetKey = 'core-reference-content';
const bundledCoreDatasetVersion = 1;

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
