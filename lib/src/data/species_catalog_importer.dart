import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class SpeciesCatalogImporter {
  static const _assetPath = 'assets/data/species_catalog.json';
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
    final taxa = decoded['taxa'] as List<dynamic>? ?? const [];
    final species = decoded['species'] as List<dynamic>? ?? const [];
    _validate(taxa, species);

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

        final texts = item['texts'] as Map<String, dynamic>;
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

  static void _validate(List<dynamic> taxa, List<dynamic> species) {
    final taxonIds = <int>{};
    final speciesIds = <int>{};

    for (final rawTaxon in taxa) {
      final taxon = rawTaxon as Map<String, dynamic>;
      final id = taxon['id'];
      if (id is! int || !taxonIds.add(id)) {
        throw FormatException('Taxon ids must be unique integers: $id');
      }
      final scientificName = taxon['scientific_name'];
      if (scientificName is! String || scientificName.trim().isEmpty) {
        throw FormatException('Taxon $id must have a scientific name');
      }
    }

    for (final rawTaxon in taxa) {
      final taxon = rawTaxon as Map<String, dynamic>;
      final parentId = taxon['parent_id'];
      if (parentId != null && (parentId is! int || !taxonIds.contains(parentId))) {
        throw FormatException(
          'Taxon ${taxon['id']} references unknown parent taxon: $parentId',
        );
      }
    }

    for (final rawSpecies in species) {
      final item = rawSpecies as Map<String, dynamic>;
      final id = item['id'];
      if (id is! int || !speciesIds.add(id)) {
        throw FormatException('Species ids must be unique integers: $id');
      }
      final taxonId = item['taxon_id'];
      if (taxonId is! int || !taxonIds.contains(taxonId)) {
        throw FormatException('Species $id references unknown taxon: $taxonId');
      }
      _validateTexts(item['texts'], 'species $id');
    }
  }

  static void _validateTexts(Object? value, String context) {
    if (value is! Map<String, dynamic> || value.keys.toSet() != _languages) {
      throw FormatException('$context must have nl, en and de text');
    }
    for (final language in _languages) {
      final text = value[language];
      if (text is! Map<String, dynamic>) {
        throw FormatException('$context has invalid $language text');
      }
      for (final field in const ['common_name', 'description']) {
        final content = text[field];
        if (content is! String || content.trim().isEmpty) {
          throw FormatException('$context has invalid $language $field');
        }
      }
    }
  }
}
