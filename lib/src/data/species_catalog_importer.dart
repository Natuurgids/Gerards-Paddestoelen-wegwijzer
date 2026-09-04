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
    final sources = decoded['sources'] as List<dynamic>? ?? const [];
    final taxa = decoded['taxa'] as List<dynamic>? ?? const [];
    final species = decoded['species'] as List<dynamic>? ?? const [];
    _validate(sources, taxa, species);

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final rawSource in sources) {
        final source = rawSource as Map<String, dynamic>;
        batch.insert(
          'reference_source',
          {
            'id': source['id'],
            'title': source['title'],
            'version': source['version'],
            'url': source['url'],
            'license': source['license'],
            'citation': source['citation'],
            'retrieved_at': source['retrieved_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final rawTaxon in taxa) {
        final taxon = rawTaxon as Map<String, dynamic>;
        _queueUpsertById(batch, 'taxon', <String, Object?>{
          'id': taxon['id'],
          'parent_id': taxon['parent_id'],
          'rank': taxon['rank'],
          'scientific_name': taxon['scientific_name'],
          'author_citation': taxon['author_citation'],
        });
      }

      for (final rawSpecies in species) {
        final item = rawSpecies as Map<String, dynamic>;
        final speciesId = item['id'] as int;
        _queueUpsertById(batch, 'species', <String, Object?>{
          'id': speciesId,
          'taxon_id': item['taxon_id'],
          'edible_status': item['edible_status'] ?? 'unknown',
          'toxicity_level': item['toxicity_level'] ?? 'unknown',
          'conservation_status': item['conservation_status'],
          'source_id': item['source_id'],
          'source_record_id': item['source_record_id'],
        });

        batch.delete(
          'species_conservation_status',
          where: 'species_id=?',
          whereArgs: [speciesId],
        );
        for (final status in _conservationStatuses(item)) {
          batch.insert(
            'species_conservation_status',
            {
              'species_id': speciesId,
              'system': status['system'],
              'scope': status['scope'],
              'jurisdiction_code': status['jurisdiction_code'] ?? '',
              'status': status['status'],
              'source_id': status['source_id'],
              'source_record_id': status['source_record_id'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        final texts = item['texts'] as Map<String, dynamic>;
        for (final entry in texts.entries) {
          final text = entry.value as Map<String, dynamic>;
          batch.insert(
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

      await batch.commit(noResult: true);
    });
  }

  static List<Map<String, dynamic>> _conservationStatuses(
    Map<String, dynamic> item,
  ) {
    final explicit = item['conservation_statuses'];
    if (explicit is List<dynamic>) {
      return explicit.cast<Map<String, dynamic>>();
    }
    final legacyStatus = item['conservation_status'];
    if (legacyStatus is String && legacyStatus.trim().isNotEmpty) {
      return [
        <String, dynamic>{
          'system': 'iucn_red_list',
          'scope': item['conservation_scope'] ?? 'global',
          'jurisdiction_code': '',
          'status': legacyStatus,
          'source_id': item['conservation_source_id'],
          'source_record_id': item['conservation_source_record_id'],
        },
      ];
    }
    return const [];
  }

  static void _queueUpsertById(
    Batch batch,
    String table,
    Map<String, Object?> values,
  ) {
    final id = values['id'];
    batch.update(table, values, where: 'id = ?', whereArgs: [id]);
    batch.insert(table, values, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static void _validate(
    List<dynamic> sources,
    List<dynamic> taxa,
    List<dynamic> species,
  ) {
    final sourceIds = <String>{};
    final taxonIds = <int>{};
    final speciesIds = <int>{};

    for (final rawSource in sources) {
      final source = rawSource as Map<String, dynamic>;
      final id = source['id'];
      if (id is! String || id.trim().isEmpty || !sourceIds.add(id)) {
        throw FormatException('Reference source ids must be unique: $id');
      }
      for (final field in const ['title', 'url', 'retrieved_at']) {
        final value = source[field];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('Reference source $id has invalid $field');
        }
      }
    }

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
      if (parentId != null &&
          (parentId is! int || !taxonIds.contains(parentId))) {
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
      final sourceId = item['source_id'];
      if (sourceId != null &&
          (sourceId is! String || !sourceIds.contains(sourceId))) {
        throw FormatException('Species $id references unknown source: $sourceId');
      }
      _validateConservationStatuses(item, id, sourceIds);
      final catalogOnly = item['catalog_only'] == true;
      if (catalogOnly) {
        if (sourceId is! String || sourceId.trim().isEmpty) {
          throw FormatException('Catalog-only species $id requires source_id');
        }
        final sourceRecordId = item['source_record_id'];
        if (sourceRecordId is! String || sourceRecordId.trim().isEmpty) {
          throw FormatException(
            'Catalog-only species $id requires source_record_id',
          );
        }
        if (item['edible_status'] != 'unknown' ||
            item['toxicity_level'] != 'unknown') {
          throw FormatException(
            'Catalog-only species $id must keep safety metadata unknown',
          );
        }
      }
      _validateTexts(
        item['texts'],
        'species $id',
        requireDescription: !catalogOnly,
      );
    }
  }

  static void _validateConservationStatuses(
    Map<String, dynamic> item,
    int speciesId,
    Set<String> sourceIds,
  ) {
    final statuses = _conservationStatuses(item);
    final keys = <String>{};
    for (final status in statuses) {
      for (final field in const ['system', 'scope', 'status']) {
        final value = status[field];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException(
            'Species $speciesId has invalid conservation $field',
          );
        }
      }
      final jurisdiction = status['jurisdiction_code'];
      if (jurisdiction != null && jurisdiction is! String) {
        throw FormatException(
          'Species $speciesId has invalid conservation jurisdiction_code',
        );
      }
      final statusSourceId = status['source_id'];
      if (statusSourceId != null &&
          (statusSourceId is! String || !sourceIds.contains(statusSourceId))) {
        throw FormatException(
          'Species $speciesId references unknown conservation source: $statusSourceId',
        );
      }
      final key = '${status['system']}|${status['scope']}|${jurisdiction ?? ''}';
      if (!keys.add(key)) {
        throw FormatException(
          'Species $speciesId has duplicate conservation status key: $key',
        );
      }
    }
  }

  static void _validateTexts(
    Object? value,
    String context, {
    required bool requireDescription,
  }) {
    if (value is! Map<String, dynamic> || value.isEmpty) {
      throw FormatException('$context must have at least one localized text');
    }
    if (!_languages.any(value.containsKey)) {
      throw FormatException('$context needs at least one nl, en or de text');
    }
    for (final entry in value.entries) {
      final text = entry.value;
      if (text is! Map<String, dynamic>) {
        throw FormatException('$context has invalid ${entry.key} text');
      }
      final commonName = text['common_name'];
      if (commonName is! String || commonName.trim().isEmpty) {
        throw FormatException('$context has invalid ${entry.key} common_name');
      }
      if (requireDescription) {
        final description = text['description'];
        if (description is! String || description.trim().isEmpty) {
          throw FormatException('$context has invalid ${entry.key} description');
        }
      }
    }
  }
}
