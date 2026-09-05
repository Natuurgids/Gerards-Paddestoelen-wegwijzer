import 'package:sqflite/sqflite.dart';

import 'core_dataset_update.dart';
import 'database_schema.dart';
import 'field_data_importer.dart';
import 'image_manifest_importer.dart';
import 'species_catalog_importer.dart';
import 'training_manifest_importer.dart';
import 'trait_manifest_importer.dart';

const coreDatasetSqliteComponents = <String>{
  'species_catalog',
  'identification_traits',
  'supplemental_species_traits',
  'field_data',
  'species_images',
  'training_content',
};

class CoreDatasetPackage {
  CoreDatasetPackage._({
    required this.datasetVersion,
    required this.databaseSchemaVersion,
    required this.components,
  });

  final int datasetVersion;
  final int databaseSchemaVersion;
  final Map<String, Map<String, dynamic>> components;

  factory CoreDatasetPackage.fromDecoded(
    Map<String, dynamic> decoded,
    CoreDatasetUpdateManifest manifest,
  ) {
    if (decoded['package_version'] != 1) {
      throw const FormatException('Core dataset package version must be 1');
    }
    if (decoded['dataset_key'] != coreDatasetKey) {
      throw const FormatException('Core dataset package has an unknown dataset key');
    }

    final datasetVersion = _positiveInt(
      decoded['dataset_version'],
      'dataset_version',
    );
    final databaseSchemaVersion = _positiveInt(
      decoded['database_schema_version'],
      'database_schema_version',
    );
    if (datasetVersion != manifest.datasetVersion ||
        databaseSchemaVersion != manifest.databaseSchemaVersion) {
      throw const FormatException(
        'Core dataset package metadata does not match the update manifest',
      );
    }
    if (databaseSchemaVersion != DatabaseSchema.currentVersion) {
      throw const FormatException(
        'Core dataset package is incompatible with the current database schema',
      );
    }

    if (manifest.components.contains('learning_catalog')) {
      throw const FormatException(
        'learning_catalog needs staged file activation and cannot be applied by the SQLite package applier',
      );
    }
    if (!manifest.components.every(coreDatasetSqliteComponents.contains)) {
      throw const FormatException(
        'Core dataset manifest contains a non-SQLite component',
      );
    }

    final rawComponents = decoded['components'];
    if (rawComponents is! Map<String, dynamic>) {
      throw const FormatException('Core dataset package components must be an object');
    }
    final packageKeys = rawComponents.keys.toSet();
    if (packageKeys.length != manifest.components.length ||
        !packageKeys.containsAll(manifest.components) ||
        !manifest.components.containsAll(packageKeys)) {
      throw const FormatException(
        'Core dataset package components must exactly match the update manifest',
      );
    }

    final hasTraits = packageKeys.contains('identification_traits');
    final hasSupplemental = packageKeys.contains('supplemental_species_traits');
    if (hasTraits != hasSupplemental) {
      throw const FormatException(
        'Identification and supplemental trait components must be updated together',
      );
    }

    final components = <String, Map<String, dynamic>>{};
    for (final key in packageKeys) {
      if (!coreDatasetSqliteComponents.contains(key)) {
        throw FormatException('Unsupported SQLite core dataset component: $key');
      }
      final value = rawComponents[key];
      if (value is! Map<String, dynamic>) {
        throw FormatException('Core dataset component $key must be an object');
      }
      components[key] = Map<String, dynamic>.unmodifiable(value);
    }

    return CoreDatasetPackage._(
      datasetVersion: datasetVersion,
      databaseSchemaVersion: databaseSchemaVersion,
      components: Map<String, Map<String, dynamic>>.unmodifiable(components),
    );
  }
}

class CoreDatasetInstalledState {
  const CoreDatasetInstalledState._();

  static Future<CoreDatasetMetadata> load(DatabaseExecutor db) async {
    final bundled = await CoreDatasetMetadata.loadBundled();
    final rows = await db.query(
      'bundled_content_state',
      columns: const ['revision'],
      where: 'content_key=?',
      whereArgs: const [coreDatasetKey],
      limit: 1,
    );
    if (rows.isEmpty) return bundled;

    final revision = rows.single['revision'];
    if (revision is! int || revision <= 0) {
      throw StateError('Installed core dataset revision is invalid: $revision');
    }
    if (revision < bundled.datasetVersion) {
      return bundled;
    }
    return CoreDatasetMetadata(
      datasetVersion: revision,
      databaseSchemaVersion: DatabaseSchema.currentVersion,
    );
  }
}

class CoreDatasetPackageApplier {
  const CoreDatasetPackageApplier._();

  static Future<void> apply(
    Database db,
    CoreDatasetUpdateManifest manifest,
    Map<String, dynamic> decoded, {
    DateTime? appliedAt,
  }) async {
    final package = CoreDatasetPackage.fromDecoded(decoded, manifest);
    final installed = await CoreDatasetInstalledState.load(db);
    if (manifest.datasetVersion <= installed.datasetVersion) {
      throw StateError(
        'Refusing to install core dataset ${manifest.datasetVersion} over ${installed.datasetVersion}',
      );
    }
    if (installed.databaseSchemaVersion != DatabaseSchema.currentVersion) {
      throw StateError('Installed core dataset schema is incompatible');
    }

    final syncedAt = (appliedAt ?? DateTime.now()).toUtc().toIso8601String();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'bundled_content_state',
        columns: const ['revision'],
        where: 'content_key=?',
        whereArgs: const [coreDatasetKey],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final revision = rows.single['revision'];
        if (revision is! int || revision <= 0) {
          throw StateError('Installed core dataset revision is invalid: $revision');
        }
        if (manifest.datasetVersion <= revision) {
          throw StateError(
            'Refusing to install core dataset ${manifest.datasetVersion} over $revision',
          );
        }
      }

      final components = package.components;
      final speciesCatalog = components['species_catalog'];
      if (speciesCatalog != null) {
        await SpeciesCatalogImporter.syncDecoded(txn, speciesCatalog);
      }

      final traits = components['identification_traits'];
      if (traits != null) {
        await TraitManifestImporter.syncDecoded(
          txn,
          traits,
          supplemental: components['supplemental_species_traits'],
        );
      }

      final fieldData = components['field_data'];
      if (fieldData != null) {
        await FieldDataImporter.syncDecoded(txn, fieldData);
      }

      final speciesImages = components['species_images'];
      if (speciesImages != null) {
        await ImageManifestImporter.syncDecoded(txn, speciesImages);
      }

      final training = components['training_content'];
      if (training != null) {
        await TrainingManifestImporter.syncDecoded(txn, training);
      }

      await txn.insert(
        'bundled_content_state',
        {
          'content_key': coreDatasetKey,
          'revision': package.datasetVersion,
          'synced_at': syncedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('$field must be a positive integer');
  }
  return value;
}
