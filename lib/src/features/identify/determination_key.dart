import 'dart:convert';
import 'package:flutter/services.dart';
import '../../data/dutch_identification_scope.dart';
import '../../data/reference_asset_store.dart';

class KeyChoice {
  KeyChoice(Map<String, dynamic> data)
      : id = data['id'] as String, text = data['text'] as String,
        target = data['target'] as String, page = data['page'] as int,
        image = data['image'] as String;
  final String id, text, target, image;
  final int page;
}
class KeyQuestion {
  KeyQuestion(Map<String, dynamic> data)
      : id = data['id'] as String, title = data['title'] as String,
        source = data['source'] as String, couplet = data['couplet'] as int,
        choices = (data['choices'] as List<dynamic>)
            .map((e) => KeyChoice(e as Map<String, dynamic>)).toList();
  final String id, title, source;
  final int couplet;
  final List<KeyChoice> choices;
}
class KeyEndpoint {
  KeyEndpoint(Map<String, dynamic> data)
      : id = data['id'] as String, name = data['name'] as String,
        kind = data['kind'] as String, detail = data['detail'] as String,
        source = data['source'] as String, page = data['page'] as int;
  final String id, name, kind, detail, source;
  final int page;
}
class KeyChecklistSpecies {
  const KeyChecklistSpecies(this.id, this.name, this.recordId);
  final int id;
  final String name, recordId;
}
class DeterminationKeyBook {
  DeterminationKeyBook(Map<String, dynamic> data, Map<String, dynamic> catalog)
      : start = data['start'] as String,
        questions = {for (final e in data['nodes'] as List<dynamic>)
          (e as Map<String, dynamic>)['id'] as String: KeyQuestion(e)},
        endpoints = {for (final e in data['endpoints'] as List<dynamic>)
          (e as Map<String, dynamic>)['id'] as String: KeyEndpoint(e)},
        sources = {for (final e in data['sources'] as List<dynamic>)
          (e as Map<String, dynamic>)['id'] as String: e['title'] as String},
        checklist = checklistIndex(catalog) {
    if (!questions.containsKey(start)) throw const FormatException('Missing start');
    for (final q in questions.values) {
      if (q.choices.length < 2) throw FormatException('Unpaired question ${q.id}');
      for (final c in q.choices) {
        if (!questions.containsKey(c.target) && !endpoints.containsKey(c.target)) {
          throw FormatException('Missing destination ${c.target}');
        }
      }
    }
  }
  final String start;
  final Map<String, KeyQuestion> questions;
  final Map<String, KeyEndpoint> endpoints;
  final Map<String, String> sources;
  final Map<String, List<KeyChecklistSpecies>> checklist;
  static Future<DeterminationKeyBook> load() async => DeterminationKeyBook(
    jsonDecode(await rootBundle.loadString('assets/data/determination_keys.json'))
        as Map<String, dynamic>,
    await ReferenceAssetStore.instance.speciesCatalog);
  static Map<String, List<KeyChecklistSpecies>> checklistIndex(
      Map<String, dynamic> catalog) {
    final taxa = <int, String>{};
    for (final raw in catalog['taxa'] as List<dynamic>) {
      final t = raw as Map<String, dynamic>;
      if (t['rank'] == 'species') {
        final name = DutchIdentificationScope.canonicalSpeciesName(t['scientific_name'] as String);
        if (name != null) taxa[t['id'] as int] = name;
      }
    }
    final index = <String, List<KeyChecklistSpecies>>{};
    for (final raw in catalog['species'] as List<dynamic>) {
      final s = raw as Map<String, dynamic>;
      if (s['source_id'] != DutchIdentificationScope.sourceId) continue;
      final name = taxa[s['taxon_id'] as int];
      if (name != null) {
        index.putIfAbsent(name, () => []).add(
          KeyChecklistSpecies(s['id'] as int, name, s['source_record_id'] as String));
      }
    }
    return index;
  }
  KeyChecklistSpecies? resolve(KeyEndpoint endpoint) {
    if (endpoint.kind != 'species') return null;
    final matches = checklist[endpoint.name];
    return matches?.length == 1 ? matches!.single : null;
  }
}
class KeyStep {
  const KeyStep(this.question, this.choice);
  final String question;
  final int choice;
}
/// A source-directed route. No trait profile, score or inferred branch is used.
class DeterminationKeySession {
  DeterminationKeySession(this.book) : current = book.start;
  final DeterminationKeyBook book;
  String current;
  final List<KeyStep> steps = [];
  KeyQuestion? get question => book.questions[current];
  KeyEndpoint? get endpoint => book.endpoints[current];
  void choose(int index) {
    final q = question;
    if (q == null || index < 0 || index >= q.choices.length) {
      throw StateError('Invalid key choice');
    }
    steps.add(KeyStep(current, index));
    current = q.choices[index].target;
  }
  void back() { if (steps.isNotEmpty) revisit(steps.length - 1); }
  void revisit(int index) {
    if (index < 0 || index >= steps.length) throw RangeError.index(index, steps);
    current = steps[index].question;
    steps.removeRange(index, steps.length);
  }
  void reset() { steps.clear(); current = book.start; }
}
