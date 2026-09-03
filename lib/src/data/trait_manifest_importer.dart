import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class TraitManifestImporter {
  static const _assetPath = 'assets/data/identification_traits.json';
  static const _languages = {'nl', 'en', 'de'};

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    await syncDecoded(db, decoded);
  }

  static Future<void> syncDecoded(
    Database db,
    Map<String, dynamic> decoded,
  ) async {
    final traits = decoded['traits'] as List<dynamic>? ?? const [];
    final speciesTraits = decoded['species_traits'] as List<dynamic>? ?? const [];
    _validate(traits, speciesTraits);

    await db.transaction((txn) async {
      for (final item in traits) {
        final trait = item as Map<String, dynamic>;
        final traitId = trait['id'] as int;
        await _upsertById(txn, 'trait', {
          'id': traitId,
          'code': trait['code'] as String,
          'category': trait['category'] as String,
          'value_type': 'choice',
        });

        final labels = trait['labels'] as Map<String, dynamic>;
        for (final entry in labels.entries) {
          await txn.insert(
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
          await _upsertById(txn, 'trait_option', {
            'id': optionId,
            'trait_id': traitId,
            'code': option['code'] as String,
            'sort_order': option['sort_order'] as int? ?? 0,
          });

          final optionLabels = option['labels'] as Map<String, dynamic>;
          for (final entry in optionLabels.entries) {
            await txn.insert(
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
        await txn.insert(
          'species_trait',
          {
            'species_id': relation['species_id'],
            'trait_id': relation['trait_id'],
            'option_id': relation['option_id'],
            'weight': relation['weight'] ?? 1.0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<void> _upsertById(
    Transaction txn,
    String table,
    Map<String, Object?> values,
  ) async {
    final id = values['id'];
    final updated = await txn.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await txn.insert(table, values);
    }
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
      if (code is! String || code.trim().isEmpty || code.trim() != code ||
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
          throw FormatException('Trait option ids must be unique integers: $optionId');
        }
        final optionCode = option['code'];
        if (optionCode is! String || optionCode.trim().isEmpty ||
            optionCode.trim() != optionCode || !optionCodes.add(optionCode)) {
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
