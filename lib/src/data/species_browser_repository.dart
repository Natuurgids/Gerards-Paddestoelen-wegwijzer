import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models.dart';
import 'reference_asset_store.dart';

typedef SpeciesBrowserDatabaseProvider = Future<Database> Function();

Future<Database> _defaultDatabaseProvider() => AppDatabase.instance.database;

class SpeciesBrowserRepository {
  SpeciesBrowserRepository({SpeciesBrowserDatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _defaultDatabaseProvider,
        _preferDatabase = databaseProvider != null;

  static const defaultPageSize = 50;
  static const _databaseBudget = Duration(seconds: 2);

  final SpeciesBrowserDatabaseProvider _databaseProvider;
  final bool _preferDatabase;

  Future<List<SpeciesSummary>> searchPage(
    String languageCode, {
    String query = '',
    int offset = 0,
    int limit = defaultPageSize,
  }) async {
    if (!_preferDatabase) {
      return ReferenceAssetStore.instance.speciesPage(
        languageCode,
        query: query,
        offset: offset,
        limit: limit,
      );
    }

    try {
      final db = await _databaseProvider().timeout(_databaseBudget);
      final trimmed = query.trim();
      final like = '%$trimmed%';
      final rows = await db
          .rawQuery(
            '''SELECT s.id, t.scientific_name, st.common_name, st.summary,
      (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path
      FROM species s
      JOIN taxon t ON t.id=s.taxon_id
      JOIN species_text st ON st.species_id=s.id AND st.language_code=?
      WHERE ?='' OR t.scientific_name LIKE ? COLLATE NOCASE OR EXISTS(
        SELECT 1 FROM species_text alias
        WHERE alias.species_id=s.id AND alias.common_name LIKE ? COLLATE NOCASE
      )
      ORDER BY st.common_name COLLATE NOCASE
      LIMIT ? OFFSET ?''',
            [languageCode, trimmed, like, like, limit, offset],
          )
          .timeout(_databaseBudget);
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
    } on Object {
      return ReferenceAssetStore.instance.speciesPage(
        languageCode,
        query: query,
        offset: offset,
        limit: limit,
      );
    }
  }
}
