import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';
import 'reference_asset_store.dart';
import 'repositories.dart';

class ResilientIdentificationRepository extends IdentificationRepository {
  ResilientIdentificationRepository({super.databaseProvider})
      : _preferDatabase = databaseProvider != null;

  static const _databaseBudget = Duration(seconds: 2);
  static const _supplementalTraitsAsset =
      'assets/data/species_traits_europe.json';

  final bool _preferDatabase;

  @override
  Future<List<TraitChoice>> choices(String languageCode) async {
    if (!_preferDatabase) {
      return ReferenceAssetStore.instance.traitChoices(languageCode);
    }
    try {
      return await super.choices(languageCode).timeout(_databaseBudget);
    } on Object {
      return ReferenceAssetStore.instance.traitChoices(languageCode);
    }
  }

  @override
  Future<List<IdentificationCandidate>> identify(
    String languageCode,
    Map<int, int> selected, {
    int? observationMonth,
    String? seasonRegionCode,
    double? capDiameterCm,
    double? stemHeightCm,
    double? stemDiameterCm,
  }) async {
    final hasFieldEvidence =
        (observationMonth != null && seasonRegionCode != null) ||
            capDiameterCm != null ||
            stemHeightCm != null ||
            stemDiameterCm != null;

    if (!_preferDatabase && !hasFieldEvidence) {
      return _identifyFromAssets(languageCode, selected);
    }

    try {
      return await super
          .identify(
            languageCode,
            selected,
            observationMonth: observationMonth,
            seasonRegionCode: seasonRegionCode,
            capDiameterCm: capDiameterCm,
            stemHeightCm: stemHeightCm,
            stemDiameterCm: stemDiameterCm,
          )
          .timeout(_databaseBudget);
    } on Object {
      return _identifyFromAssets(languageCode, selected);
    }
  }

  Future<List<Map<String, dynamic>>> _assetRelations() async {
    final manifest = await ReferenceAssetStore.instance.traits;
    final relations = <Map<String, dynamic>>[
      ...(manifest['species_traits'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
    ];
    final raw = await rootBundle.loadString(_supplementalTraitsAsset);
    final supplemental = jsonDecode(raw) as Map<String, dynamic>;
    relations.addAll(
      (supplemental['species_traits'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
    );
    return relations;
  }

  Future<List<IdentificationCandidate>> _identifyFromAssets(
    String languageCode,
    Map<int, int> selected,
  ) async {
    final species = await ReferenceAssetStore.instance.speciesPage(
      languageCode,
      limit: 100000,
    );
    if (selected.isEmpty) {
      return species
          .take(50)
          .map(
            (item) => IdentificationCandidate(
              species: item,
              score: 0,
              matched: 0,
              requested: 0,
            ),
          )
          .toList();
    }

    final relations = await _assetRelations();
    final bySpecies = <int, Map<int, List<Map<String, dynamic>>>>{};
    for (final relation in relations) {
      final speciesId = relation['species_id'] as int;
      final traitId = relation['trait_id'] as int;
      bySpecies
          .putIfAbsent(speciesId, () => {})
          .putIfAbsent(traitId, () => [])
          .add(relation);
    }

    final candidates = <IdentificationCandidate>[];
    for (final item in species) {
      var matched = 0;
      var matchedWeight = 0.0;
      var totalWeight = 0.0;
      final Map<int, List<Map<String, dynamic>>> relationsByTrait =
          bySpecies[item.id] ?? const {};
      for (final selectedEntry in selected.entries) {
        final traitRelations =
            relationsByTrait[selectedEntry.key] ?? const <Map<String, dynamic>>[];
        var traitMaxWeight = 1.0;
        var traitMatchedWeight = 0.0;
        for (final relation in traitRelations) {
          final weight = (relation['weight'] as num?)?.toDouble() ?? 1.0;
          if (weight > traitMaxWeight) traitMaxWeight = weight;
          if (relation['option_id'] == selectedEntry.value &&
              weight > traitMatchedWeight) {
            traitMatchedWeight = weight;
          }
        }
        totalWeight += traitMaxWeight;
        if (traitMatchedWeight > 0) {
          matched++;
          matchedWeight += traitMatchedWeight;
        }
      }
      if (matched == 0) continue;
      candidates.add(
        IdentificationCandidate(
          species: item,
          score: totalWeight == 0 ? 0 : matchedWeight / totalWeight,
          matched: matched,
          requested: selected.length,
        ),
      );
    }
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return b.matched.compareTo(a.matched);
    });
    return candidates.take(50).toList();
  }
}
