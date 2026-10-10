import 'reference_asset_store.dart';

/// A national checklist membership link, not an occurrence or trait assertion.
class DutchChecklistRecord {
  const DutchChecklistRecord(this.speciesId, this.recordId);
  final int speciesId;
  final String recordId;
}

class IdentificationCoverage {
  const IdentificationCoverage({required this.total, required this.assessable,
    required this.selected, required this.mapped});
  final int total, assessable, selected, mapped;
  int get unassessed => total - assessable;
}

class DutchIdentificationScope {
  DutchIdentificationScope._();
  static final instance = DutchIdentificationScope._();
  static const sourceId = 'nsr-dutch-species-register';
  static const datasetUrl =
      'https://www.gbif.org/dataset/4dd32523-a3a3-43b7-84df-4cda02f15cf7';
  Future<Map<int, DutchChecklistRecord>>? _links;
  Future<Map<int, DutchChecklistRecord>> get links => _links ??= _load();

  /// Species-rank binomial only; no fuzzy, genus or synonym inference.
  /// Authorship varies between the curated descriptions and the checklist.
  static String? canonicalSpeciesName(String name) {
    final match = RegExp(r'^([A-Z][a-zA-Zëïéäöü-]+)\s+([a-z][a-zëïéäöü-]+)(?:\s|$)')
        .firstMatch(name.trim());
    if (match == null) return null;
    final tail = name.substring(match.end).trim();
    if (RegExp(r'^(?:var\.|subsp\.|f\.|×)\s').hasMatch(tail)) return null;
    return '${match[1]} ${match[2]}';
  }

  Future<Map<int, DutchChecklistRecord>> _load() async {
    final catalog = await ReferenceAssetStore.instance.speciesCatalog;
    final taxa = <int, String>{};
    for (final raw in catalog['taxa'] as List<dynamic>) {
      final taxon = raw as Map<String, dynamic>;
      if (taxon['rank'] == 'species') {
        final name = canonicalSpeciesName(taxon['scientific_name'] as String);
        if (name != null) taxa[taxon['id'] as int] = name;
      }
    }
    final byName = <String, List<DutchChecklistRecord>>{};
    final links = <int, DutchChecklistRecord>{};
    for (final raw in catalog['species'] as List<dynamic>) {
      final species = raw as Map<String, dynamic>;
      if (species['source_id'] != sourceId) continue;
      final id = species['id'] as int;
      final record = DutchChecklistRecord(id, species['source_record_id'] as String);
      links[id] = record;
      final name = taxa[species['taxon_id'] as int];
      if (name != null) byName.putIfAbsent(name, () => []).add(record);
    }
    for (final raw in catalog['species'] as List<dynamic>) {
      final species = raw as Map<String, dynamic>;
      final name = taxa[species['taxon_id'] as int];
      final records = byName[name];
      if (records != null && records.length == 1) {
        links[species['id'] as int] = records.single;
      }
    }
    return links;
  }
}
