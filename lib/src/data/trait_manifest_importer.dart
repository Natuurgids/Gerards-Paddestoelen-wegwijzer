import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class TraitManifestImporter {
  static const _assetPath = 'assets/data/identification_traits.json';
  static const _supplementalAssetPath = 'assets/data/species_traits_europe.json';
  static const _languages = {'nl', 'en', 'de'};

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final supplementalRaw = await rootBundle.loadString(_supplementalAssetPath);
    final supplemental = jsonDecode(supplementalRaw) as Map<String, dynamic>;
    await syncDecoded(db, decoded, supplemental: supplemental);
  }

  static Future<void> syncDecoded(
    DatabaseExecutor db,
    Map<String, dynamic> decoded, {
    Map<String, dynamic>? supplemental,
  }) async {
    final traits = decoded['traits'] as List<dynamic>? ?? const [];
    final baseSpeciesTraits =
        decoded['species_traits'] as List<dynamic>? ?? const [];
    final supplementalSpeciesTraits =
        supplemental?['species_traits'] as List<dynamic>? ?? const [];
    final speciesTraits = <dynamic>[
      ...baseSpeciesTraits,
      ...supplementalSpeciesTraits,
    ];
    _validate(traits, speciesTraits);
    _validateSupplementalProvenance(supplementalSpeciesTraits);

    if (db is Database) {
      await db.transaction(
        (txn) => _writeDecoded(txn, traits, speciesTraits),
      );
    } else {
      await _writeDecoded(db, traits, speciesTraits);
    }
  }

  static Future<void> _writeDecoded(
    DatabaseExecutor db,
    List<dynamic> traits,
    List<dynamic> speciesTraits,
  ) async {
    final batch = db.batch();
    for (final item in traits) {
      final trait = item as Map<String, dynamic>;
      final traitId = trait['id'] as int;
      _batchUpsertById(batch, 'trait', {
        'id': traitId,
        'code': trait['code'] as String,
        'category': trait['category'] as String,
        'value_type': 'choice',
      });

      final labels = trait['labels'] as Map<String, dynamic>;
      for (final entry in labels.entries) {
        batch.insert(
          'trait_text',
          {
            'trait_id': traitId,
            'language_code': entry.key,
            'label': entry.value,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final options = trait['options'] as List<dynamic>;
      for (final optionItem in options) {
        final option = optionItem as Map<String, dynamic>;
        final optionId = option['id'] as int;
        _batchUpsertById(batch, 'trait_option', {
          'id': optionId,
          'trait_id': traitId,
          'code': option['code'] as String,
          'sort_order': option['sort_order'] as int? ?? 0,
        });

        final optionLabels = option['labels'] as Map<String, dynamic>;
        for (final entry in optionLabels.entries) {
          batch.insert(
            'trait_option_text',
            {
              'option_id': optionId,
              'language_code': entry.key,
              'label': entry.value,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }

    for (final item in speciesTraits) {
      final relation = item as Map<String, dynamic>;
      batch.insert(
        'species_trait',
        {
          'species_id': relation['species_id'],
          'trait_id': relation['trait_id'],
          'option_id': relation['option_id'],
          'weight': relation['weight'] ?? 1.0,
          'source_id': relation['source_id'],
          'source_record_id': relation['source_record_id'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static void _batchUpsertById(
    Batch batch,
    String table,
    Map<String, Object?> values,
  ) {
    final id = values['id'];
    batch.update(table, values, where: 'id = ?', whereArgs: [id]);
    batch.insert(table, values, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static void _validate(List<dynamic> traits, List<dynamic> speciesTraits) {
    final traitIds = <int>{};
    final traitCodes = <String>{};
    final optionIds = <int>{};
    final optionTraitById = <int, int>{};

    for (final rawTrait in traits) {
      final trait = rawTrait as Map<String, dynamic>;
      final traitId = trait['id'];
      if (traitId is! int || !traitIds.add(traitId)) {
        throw FormatException('Trait ids must be unique integers: $traitId');
      }
      final code = trait['code'];
      if (code is! String ||
          code.trim().isEmpty ||
          code.trim() != code ||
          !traitCodes.add(code)) {
        throw FormatException('Trait codes must be unique and non-empty: $code');
      }
      _validateLabels(trait['labels'], 'trait $traitId');
      final options = trait['options'];
      if (options is! List<dynamic> || options.isEmpty) {
        throw FormatException('Trait $traitId must declare options');
      }
      final optionCodes = <String>{};
      for (final rawOption in options) {
        final option = rawOption as Map<String, dynamic>;
        final optionId = option['id'];
        if (optionId is! int || !optionIds.add(optionId)) {
          throw FormatException(
            'Trait option ids must be unique integers: $optionId',
          );
        }
        final optionCode = option['code'];
        if (optionCode is! String ||
            optionCode.trim().isEmpty ||
            optionCode.trim() != optionCode ||
            !optionCodes.add(optionCode)) {
          throw FormatException(
            'Option codes must be unique per trait and non-empty: $optionCode',
          );
        }
        optionTraitById[optionId] = traitId;
        _validateLabels(option['labels'], 'option $optionId');
      }
    }

    for (final rawRelation in speciesTraits) {
      final relation = rawRelation as Map<String, dynamic>;
      final traitId = relation['trait_id'];
      final optionId = relation['option_id'];
      if (traitId is! int || !traitIds.contains(traitId)) {
        throw FormatException('Species trait references unknown trait: $traitId');
      }
      if (optionId is! int || optionTraitById[optionId] != traitId) {
        throw FormatException(
          'Species trait references option $optionId outside trait $traitId',
        );
      }
      final weight = relation['weight'] ?? 1.0;
      if (weight is! num || !weight.toDouble().isFinite || weight <= 0) {
        throw FormatException('Species trait weight must be positive: $weight');
      }
      if (relation['species_id'] is! int) {
        throw FormatException(
          'Species trait species_id must be an integer: ${relation['species_id']}',
        );
      }
    }
  }

  static void _validateSupplementalProvenance(List<dynamic> speciesTraits) {
    for (final rawRelation in speciesTraits) {
      final relation = rawRelation as Map<String, dynamic>;
      final speciesId = relation['species_id'];
      _validateProvenanceValue(
        relation['source_id'],
        'Supplemental species trait $speciesId source_id',
      );
      _validateProvenanceValue(
        relation['source_record_id'],
        'Supplemental species trait $speciesId source_record_id',
      );
    }
  }

  static void _validateProvenanceValue(Object? value, String context) {
    if (value is! String || value.trim().isEmpty || value.trim() != value) {
      throw FormatException('$context must be a trimmed, non-empty string');
    }
  }

  static void _validateLabels(Object? value, String context) {
    if (value is! Map<String, dynamic> ||
        !_languages.every(value.containsKey)) {
      throw FormatException('$context must have nl, en and de labels');
    }
    for (final language in _languages) {
      final label = value[language];
      if (label is! String || label.trim().isEmpty) {
        throw FormatException('$context has an invalid $language label');
      }
    }
  }
}
