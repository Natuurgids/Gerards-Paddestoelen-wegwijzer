import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class ImageManifestImporter {
  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString('assets/data/species_images.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final species = (json['species'] as List<dynamic>? ?? const []);
    await db.transaction((txn) async {
      for (final item in species) {
        final map = item as Map<String, dynamic>;
        final speciesId = map['speciesId'] as int;
        await txn.delete('species_image', where: 'species_id=?', whereArgs: [speciesId]);
        for (final image in (map['images'] as List<dynamic>? ?? const [])) {
          final m = image as Map<String, dynamic>;
          await txn.insert('species_image', {
            'species_id': speciesId,
            'asset_path': m['path'] as String,
            'thumbnail_path': m['thumbnailPath'] as String?,
            'angle_code': m['angle'] as String?,
            'photographer': m['photographer'] as String?,
            'license': m['license'] as String?,
            'sort_order': (m['order'] as num?)?.toInt() ?? 0,
            'is_primary': m['primary'] == true ? 1 : 0,
          });
        }
      }
    });
  }
}
