import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class FieldDataImporter {
  static const _assetPath = 'assets/data/field_data.json';
  static final RegExp _regionCodePattern = RegExp(r'^[A-Z]{2}(?:-[A-Z]{2})*$');

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    await syncDecoded(db, decoded);
  }

  static Future<void> syncDecoded(
    Database db,
    Map<String, dynamic> decoded,
  ) async {
    final species = decoded['species'] as List<dynamic>? ?? const [];
    final declaredRegions = <String>{};

    for (final rawRegion
        in decoded['season_regions'] as List<dynamic>? ?? const []) {
      final region = rawRegion as Map<String, dynamic>;
      final code = _canonicalRegionCode(region['code']);
      if (!declaredRegions.add(code)) {
        throw FormatException('Duplicate season region code: $code');
      }
    }

    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      final seasonDatasets = item['season_datasets'] as List<dynamic>?;
      if (seasonDatasets != null) {
        for (final rawDataset in seasonDatasets) {
          final dataset = rawDataset as Map<String, dynamic>;
          final regionCode = _canonicalRegionCode(dataset['region_code']);
          if (!declaredRegions.contains(regionCode)) {
            throw FormatException(
              'Undeclared season region code for species '
              '${item['species_id']}: $regionCode',
            );
          }
        }
      } else {
        final legacySeason = item['season'] as List<dynamic>? ?? const [];
        if (legacySeason.isNotEmpty) {
          final regionCode = _canonicalRegionCode(item['season_region']);
          if (!declaredRegions.contains(regionCode)) {
            throw FormatException(
              'Undeclared legacy season region code for species '
              '${item['species_id']}: $regionCode',
            );
          }
        }
      }
    }

    await db.transaction((txn) async {
      // These tables contain developer-managed reference content only. Treat
      // the manifest as authoritative so removed measurements, calendars,
      // regions or species entries cannot survive as stale SQLite rows.
      await txn.delete('species_measurement');
      await txn.delete('species_season');

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

  static String _canonicalRegionCode(Object? value) {
    if (value is! String || value.trim() != value ||
        !_regionCodePattern.hasMatch(value)) {
      throw FormatException(
        'Season region codes must use canonical uppercase two-letter segments: '
        '$value',
      );
    }
    return value;
  }

  static Future<void> _syncSeasonDataset(
    Transaction txn,
    int speciesId,
    Map<String, dynamic> dataset,
  ) async {
    final regionCode = _canonicalRegionCode(dataset['region_code']);
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
