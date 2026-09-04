import 'dart:async';

import 'models.dart';
import 'reference_asset_store.dart';
import 'repositories.dart';

class ResilientIdentificationRepository extends IdentificationRepository {
  ResilientIdentificationRepository({DatabaseProvider? databaseProvider})
      : super(databaseProvider: databaseProvider);

  static const _databaseBudget = Duration(seconds: 2);

  @override
  Future<List<TraitChoice>> choices(String languageCode) async {
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

    final manifest = await ReferenceAssetStore.instance.traits;
    final relations = manifest['species_traits'] as List<dynamic>? ?? const [];
    final bySpecies = <int, Map<int, List<Map<String, dynamic>>>>{};
    for (final raw in relations) {
      final relation = raw as Map<String, dynamic>;
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
      final relationsByTrait = bySpecies[item.id] ?? const {};
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
