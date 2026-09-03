import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class SpeciesCatalogImporter {
  static const _assetPath = 'assets/data/species_catalog.json';

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final taxa = decoded['taxa'] as List<dynamic>? ?? const [];
    final species = decoded['species'] as List<dynamic>? ?? const [];

    await db.transaction((txn) async {
      for (final rawTaxon in taxa) {
        final taxon = rawTaxon as Map<String, dynamic>;
        await txn.insert(
          'taxon',
          {
            'id': taxon['id'],
            'parent_id': taxon['parent_id'],
            'rank': taxon['rank'],
            'scientific_name': taxon['scientific_name'],
            'author_citation': taxon['author_citation'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final rawSpecies in species) {
        final item = rawSpecies as Map<String, dynamic>;
        final speciesId = item['id'] as int;
        await txn.insert(
          'species',
          {
            'id': speciesId,
            'taxon_id': item['taxon_id'],
            'edible_status': item['edible_status'] ?? 'unknown',
            'toxicity_level': item['toxicity_level'] ?? 'unknown',
            'conservation_status': item['conservation_status'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final texts = item['texts'] as Map<String, dynamic>? ?? const {};
        for (final entry in texts.entries) {
          final text = entry.value as Map<String, dynamic>;
          await txn.insert(
            'species_text',
            {
              'species_id': speciesId,
              'language_code': entry.key,
              'common_name': text['common_name'],
              'summary': text['summary'],
              'description': text['description'],
              'habitat_text': text['habitat'],
              'lookalikes_text': text['lookalikes'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
