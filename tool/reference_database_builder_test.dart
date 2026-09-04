import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/bundled_content_sync.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/field_data_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/image_manifest_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/species_catalog_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/training_manifest_importer.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/trait_manifest_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('build packaged reference database', () async {
    final output = Platform.environment['REFERENCE_DATABASE_OUTPUT'];
    if (output == null || output.isEmpty) {
      fail('REFERENCE_DATABASE_OUTPUT must point to the generated SQLite file');
    }

    final file = File(output).absolute;
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();

    final db = await databaseFactoryFfi.openDatabase(
      file.path,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.currentVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, _) => DatabaseSchema.create(database),
      ),
    );

    try {
      await SpeciesCatalogImporter.syncDecoded(
        db,
        await _manifest('assets/data/species_catalog.json'),
      );
      await TraitManifestImporter.syncDecoded(
        db,
        await _manifest('assets/data/identification_traits.json'),
        supplemental: await _manifest('assets/data/species_traits_europe.json'),
      );
      await FieldDataImporter.syncDecoded(
        db,
        await _manifest('assets/data/field_data.json'),
      );
      await ImageManifestImporter.syncDecoded(
        db,
        await _manifest('assets/data/species_images.json'),
      );
      await TrainingManifestImporter.syncDecoded(
        db,
        await _manifest('assets/data/training_content.json'),
      );

      await db.insert(
        'bundled_content_state',
        {
          'content_key': BundledContentSync.contentKey,
          'revision': BundledContentSync.revision,
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final speciesCount =
          (await db.rawQuery('SELECT COUNT(*) n FROM species')).single['n'] as int;
      expect(speciesCount, greaterThanOrEqualTo(10000));
      expect(
        (await db.rawQuery(
          "SELECT COUNT(*) n FROM species WHERE source_id='nsr-dutch-species-register'",
        ))
            .single['n'],
        greaterThan(9000),
      );
      expect(
        (await db.rawQuery('SELECT COUNT(*) n FROM trait_option')).single['n'],
        139,
      );
      expect(
        (await db.rawQuery('SELECT COUNT(*) n FROM species_trait')).single['n'],
        greaterThan(60),
      );
      expect(
        (await db.rawQuery('SELECT COUNT(*) n FROM reference_source')).single['n'],
        greaterThanOrEqualTo(2),
      );
      expect((await db.rawQuery('SELECT COUNT(*) n FROM lesson')).single['n'], 12);
      expect(await db.query('training_progress'), isEmpty);
    } finally {
      await db.close();
    }

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });
}

Future<Map<String, dynamic>> _manifest(String path) async {
  final raw = await File(path).readAsString();
  return jsonDecode(raw) as Map<String, dynamic>;
}
