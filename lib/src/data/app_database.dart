import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      onCreate: DatabaseSchema.create,
      onUpgrade: DatabaseSchema.upgrade,
      onOpen: (db) async {
        _lastManifestSyncFailures = await ManifestSyncCoordinator.run(db, [
          (name: 'species-catalogue', sync: SpeciesCatalogImporter.sync),
          (name: 'identification-traits', sync: TraitManifestImporter.sync),
          (name: 'field-data', sync: FieldDataImporter.sync),
          (name: 'species-images', sync: ImageManifestImporter.sync),
          (name: 'training-content', sync: TrainingManifestImporter.sync),
        ]);
      },
    );
  }
}
