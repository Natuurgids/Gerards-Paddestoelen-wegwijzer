import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';
import 'repositories.dart';

class ResilientSpeciesRepository extends SpeciesRepository {
  ResilientSpeciesRepository({super.databaseProvider});

  static const _databaseBudget = Duration(seconds: 2);

  @override
  Future<SpeciesDetail?> detail(int id, String languageCode) async {
    try {
      return await super.detail(id, languageCode).timeout(_databaseBudget);
    } on Object {
      return _detailFromAssets(id, languageCode);
    }
  }

  Future<SpeciesDetail?> _detailFromAssets(
    int id,
    String languageCode,
  ) async {
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/data/species_catalog.json'),
    ) as Map<String, dynamic>;
    final imageManifest = jsonDecode(
      await rootBundle.loadString('assets/data/species_images.json'),
    ) as Map<String, dynamic>;
    final fieldManifest = jsonDecode(
      await rootBundle.loadString('assets/data/field_data.json'),
    ) as Map<String, dynamic>;

    final taxa = <int, String>{};
    for (final raw in catalog['taxa'] as List<dynamic>? ?? const []) {
      final taxon = raw as Map<String, dynamic>;
      taxa[taxon['id'] as int] = taxon['scientific_name'] as String;
    }

    Map<String, dynamic>? species;
    for (final raw in catalog['species'] as List<dynamic>? ?? const []) {
      final candidate = raw as Map<String, dynamic>;
      if (candidate['id'] == id) {
        species = candidate;
        break;
      }
    }
    if (species == null) return null;

    final texts = species['texts'] as Map<String, dynamic>?;
    final localized =
        (texts?[languageCode] ?? texts?['en'] ?? texts?['nl']) as Map<String, dynamic>?;
    final scientificName = taxa[species['taxon_id'] as int] ?? '';

    final images = <SpeciesImage>[];
    for (final raw in imageManifest['species'] as List<dynamic>? ?? const []) {
      final group = raw as Map<String, dynamic>;
      if (group['speciesId'] != id) continue;
      for (final imageRaw in group['images'] as List<dynamic>? ?? const []) {
        final image = imageRaw as Map<String, dynamic>;
        images.add(
          SpeciesImage(
            path: image['path'] as String,
            angleCode: image['angle'] as String?,
            sortOrder: image['order'] as int? ?? 0,
            photographer: image['photographer'] as String?,
            license: image['license'] as String?,
          ),
        );
      }
      break;
    }
    images.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final measurements = <SpeciesMeasurement>[];
    final season = <SpeciesSeasonMonth>[];
    for (final raw in fieldManifest['species'] as List<dynamic>? ?? const []) {
      final fieldSpecies = raw as Map<String, dynamic>;
      if (fieldSpecies['species_id'] != id) continue;
      for (final measurementRaw
          in fieldSpecies['measurements'] as List<dynamic>? ?? const []) {
        final measurement = measurementRaw as Map<String, dynamic>;
        measurements.add(
          SpeciesMeasurement(
            code: measurement['code'] as String,
            minValue: (measurement['min'] as num?)?.toDouble(),
            maxValue: (measurement['max'] as num?)?.toDouble(),
            unit: measurement['unit'] as String,
          ),
        );
      }
      for (final datasetRaw
          in fieldSpecies['season_datasets'] as List<dynamic>? ?? const []) {
        final dataset = datasetRaw as Map<String, dynamic>;
        final regionCode = dataset['region_code'] as String?;
        for (final monthRaw in dataset['months'] as List<dynamic>? ?? const []) {
          final month = monthRaw as Map<String, dynamic>;
          season.add(
            SpeciesSeasonMonth(
              month: month['month'] as int,
              likelihood: month['likelihood'] as int,
              regionCode: regionCode,
            ),
          );
        }
      }
      break;
    }

    return SpeciesDetail(
      id: id,
      scientificName: scientificName,
      commonName: localized?['common_name']?.toString() ?? scientificName,
      summary: localized?['summary']?.toString(),
      imagePath: images.isEmpty ? null : images.first.path,
      description: localized?['description']?.toString(),
      habitat: localized?['habitat']?.toString() ??
          localized?['habitat_text']?.toString(),
      lookalikes: localized?['lookalikes']?.toString() ??
          localized?['lookalikes_text']?.toString(),
      edibleStatus: species['edible_status']?.toString() ?? 'unknown',
      toxicityLevel: species['toxicity_level']?.toString() ?? 'unknown',
      images: images,
      measurements: measurements,
      season: season,
    );
  }
}
