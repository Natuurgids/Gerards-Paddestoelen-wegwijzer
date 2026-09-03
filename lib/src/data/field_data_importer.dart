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
    final speciesIds = <int>{};

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
      final speciesId = item['species_id'] as int;
      if (!speciesIds.add(speciesId)) {
        throw FormatException('Duplicate field-data species entry: $speciesId');
      }
      final measurementCodes = <String>{};
      for (final rawMeasurement
          in item['measurements'] as List<dynamic>? ?? const []) {
        final measurement = rawMeasurement as Map<String, dynamic>;
        final code = measurement['code'];
        if (code is! String || code.trim().isEmpty || code.trim() != code) {
          throw FormatException(
            'Invalid measurement code for species $speciesId: $code',
          );
        }
        if (!measurementCodes.add(code)) {
          throw FormatException(
            'Duplicate measurement code for species $speciesId: $code',
          );
        }
        final min = measurement['min'];
        final max = measurement['max'];
        if (min is! num ||
            max is! num ||
            !min.toDouble().isFinite ||
            !max.toDouble().isFinite ||
            min < 0 ||
            max < min) {
          throw FormatException(
            'Invalid measurement range for species $speciesId, $code: '
            '$min..$max',
          );
        }
        final unit = measurement['unit'];
        if (unit is! String || unit.trim().isEmpty || unit.trim() != unit) {
          throw FormatException(
            'Invalid measurement unit for species $speciesId, $code: $unit',
          );
        }
      }

      final seasonDatasets = item['season_datasets'] as List<dynamic>?;
      if (seasonDatasets != null) {
        final speciesRegions = <String>{};
        for (final rawDataset in seasonDatasets) {
          final dataset = rawDataset as Map<String, dynamic>;
          final regionCode = _canonicalRegionCode(dataset['region_code']);
          if (!declaredRegions.contains(regionCode)) {
            throw FormatException(
              'Undeclared season region code for species '
              '$speciesId: $regionCode',
            );
          }
          if (!speciesRegions.add(regionCode)) {
            throw FormatException(
              'Duplicate season dataset for species $speciesId: $regionCode',
            );
          }
          _validateMonths(speciesId, regionCode, dataset['months']);
        }
      } else {
        final legacySeason = item['season'] as List<dynamic>? ?? const [];
        if (legacySeason.isNotEmpty) {
          final regionCode = _canonicalRegionCode(item['season_region']);
          if (!declaredRegions.contains(regionCode)) {
            throw FormatException(
              'Undeclared legacy season region code for species '
              '$speciesId: $regionCode',
            );
          }
          _validateMonths(speciesId, regionCode, legacySeason);
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
    if (value is! String ||
        value.trim() != value ||
        !_regionCodePattern.hasMatch(value)) {
      throw FormatException(
        'Season region codes must use canonical uppercase two-letter segments: '
        '$value',
      );
    }
    return value;
  }

  static void _validateMonths(int speciesId, String regionCode, Object? value) {
    final months = value as List<dynamic>? ?? const [];
    final seen = <int>{};
    for (final rawMonth in months) {
      final month = rawMonth as Map<String, dynamic>;
      final number = month['month'];
      final likelihood = month['likelihood'] ?? 1;
      if (number is! int || number < 1 || number > 12) {
        throw FormatException(
          'Invalid season month for species $speciesId, $regionCode: $number',
        );
      }
      if (!seen.add(number)) {
        throw FormatException(
          'Duplicate season month for species $speciesId, $regionCode: $number',
        );
      }
      if (likelihood is! int || likelihood < 1 || likelihood > 3) {
        throw FormatException(
          'Invalid season likelihood for species $speciesId, $regionCode, '
          'month $number: $likelihood',
        );
      }
    }
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
