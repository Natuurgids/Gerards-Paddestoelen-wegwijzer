import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models.dart';

typedef SpeciesBrowserDatabaseProvider = Future<Database> Function();

Future<Database> _defaultDatabaseProvider() => AppDatabase.instance.database;

class SpeciesBrowserRepository {
  SpeciesBrowserRepository({SpeciesBrowserDatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _defaultDatabaseProvider;

  static const defaultPageSize = 50;

  final SpeciesBrowserDatabaseProvider _databaseProvider;

  Future<List<SpeciesSummary>> searchPage(
    String languageCode, {
    String query = '',
    int offset = 0,
    int limit = defaultPageSize,
  }) async {
    final db = await _databaseProvider();
    final trimmed = query.trim();
    final like = '%$trimmed%';
    final rows = await db.rawQuery(
      '''SELECT s.id, t.scientific_name, st.common_name, st.summary,
      (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path
      FROM species s
      JOIN taxon t ON t.id=s.taxon_id
      JOIN species_text st ON st.species_id=s.id AND st.language_code=?
      WHERE ?='' OR st.common_name LIKE ? COLLATE NOCASE OR t.scientific_name LIKE ? COLLATE NOCASE
      ORDER BY st.common_name COLLATE NOCASE
      LIMIT ? OFFSET ?''',
      [languageCode, trimmed, like, like, limit, offset],
    );
    return rows
        .map(
          (row) => SpeciesSummary(
            id: row['id'] as int,
            scientificName: row['scientific_name'] as String,
            commonName: row['common_name'] as String,
            summary: row['summary'] as String?,
            imagePath: row['image_path'] as String?,
          ),
        )
        .toList();
  }
}
