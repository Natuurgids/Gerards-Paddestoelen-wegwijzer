import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class TraitManifestImporter {
  static const _assetPath = 'assets/data/identification_traits.json';

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final traits = decoded['traits'] as List<dynamic>? ?? const [];
    final speciesTraits = decoded['species_traits'] as List<dynamic>? ?? const [];

    await db.transaction((txn) async {
      for (final item in traits) {
        final trait = item as Map<String, dynamic>;
        final traitId = trait['id'] as int;
        await txn.insert(
          'trait',
          {
            'id': traitId,
            'code': trait['code'] as String,
            'category': trait['category'] as String,
            'value_type': 'choice',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final labels = trait['labels'] as Map<String, dynamic>? ?? const {};
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

        final options = trait['options'] as List<dynamic>? ?? const [];
        for (final optionItem in options) {
          final option = optionItem as Map<String, dynamic>;
          final optionId = option['id'] as int;
          await txn.insert(
            'trait_option',
            {
              'id': optionId,
              'trait_id': traitId,
              'code': option['code'] as String,
              'sort_order': option['sort_order'] as int? ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          final optionLabels = option['labels'] as Map<String, dynamic>? ?? const {};
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
}
