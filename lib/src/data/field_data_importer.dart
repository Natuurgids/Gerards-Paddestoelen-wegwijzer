import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class FieldDataImporter {
  static const _assetPath = 'assets/data/field_data.json';

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final species = decoded['species'] as List<dynamic>? ?? const [];

    await db.transaction((txn) async {
      for (final rawSpecies in species) {
        final item = rawSpecies as Map<String, dynamic>;
        final speciesId = item['species_id'] as int;

        final measurements = item['measurements'] as List<dynamic>? ?? const [];
        for (final rawMeasurement in measurements) {
          final measurement = rawMeasurement as Map<String, dynamic>;
          await txn.insert(
            'species_measurement',
            {
              'species_id': speciesId,
              'measurement_code': measurement['code'],
              'min_value': measurement['min'],
              'max_value': measurement['max'],
              'unit': measurement['unit'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        final seasonDatasets = item['season_datasets'] as List<dynamic>?;
        if (seasonDatasets != null) {
          for (final rawDataset in seasonDatasets) {
            final dataset = rawDataset as Map<String, dynamic>;
            await _syncSeasonDataset(txn, speciesId, dataset);
          }
        } else {
          final legacySeason = item['season'] as List<dynamic>? ?? const [];
          if (legacySeason.isNotEmpty) {
            await _syncSeasonDataset(txn, speciesId, {
              'region_code': item['season_region'],
              'months': legacySeason,
            });
          }
        }
      }
    });
  }

  static Future<void> _syncSeasonDataset(
    Transaction txn,
    int speciesId,
    Map<String, dynamic> dataset,
  ) async {
    final regionCode = dataset['region_code'] as String?;
    if (regionCode == null || regionCode.trim().isEmpty) return;
    final months = dataset['months'] as List<dynamic>? ?? const [];
    for (final rawMonth in months) {
      final month = rawMonth as Map<String, dynamic>;
      await txn.insert(
        'species_season',
        {
          'species_id': speciesId,
          'region_code': regionCode,
          'month': month['month'],
          'likelihood': month['likelihood'] ?? 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
