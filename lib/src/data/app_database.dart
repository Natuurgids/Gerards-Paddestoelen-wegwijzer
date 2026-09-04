import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'bundled_content_sync.dart';
import 'database_schema.dart';
import 'field_data_importer.dart';
import 'image_manifest_importer.dart';
import 'manifest_sync_coordinator.dart';
import 'species_catalog_importer.dart';
import 'training_manifest_importer.dart';
import 'trait_manifest_importer.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;
  Future<Database>? _opening;
  List<String> _lastManifestSyncFailures = const [];

  List<String> get lastManifestSyncFailures =>
      List.unmodifiable(_lastManifestSyncFailures);

  Future<Database> get database {
    final existing = _db;
    if (existing != null) return Future.value(existing);
    return _opening ??= _open().then((db) {
      _db = db;
      return db;
    }).whenComplete(() {
      _opening = null;
    });
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'mycology.sqlite');
    return openDatabase(
      path,
      version: DatabaseSchema.currentVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA busy_timeout = 5000');
      },
      onCreate: (db, version) => DatabaseSchema.create(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          DatabaseSchema.upgrade(db, oldVersion, newVersion),
      onOpen: (db) async {
        _lastManifestSyncFailures = await BundledContentSync.runIfNeeded(
          db,
          () => ManifestSyncCoordinator.run(db, [
            (
              name: 'species-catalogue',
              sync: SpeciesCatalogImporter.sync,
              dependsOn: const [],
            ),
            (
              name: 'identification-traits',
              sync: TraitManifestImporter.sync,
              dependsOn: const ['species-catalogue'],
            ),
            (
              name: 'field-data',
              sync: FieldDataImporter.sync,
              dependsOn: const ['species-catalogue'],
            ),
            (
              name: 'species-images',
              sync: ImageManifestImporter.sync,
              dependsOn: const ['species-catalogue'],
            ),
            (
              name: 'training-content',
              sync: TrainingManifestImporter.sync,
              dependsOn: const [],
            ),
          ]),
        );
      },
    );
  }
}
