import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

class ReferenceAssetStore {
  ReferenceAssetStore._();

  static final instance = ReferenceAssetStore._();

  Future<Map<String, dynamic>>? _speciesCatalog;
  Future<Map<String, dynamic>>? _speciesImages;
  Future<Map<String, dynamic>>? _traits;
  Future<Map<String, dynamic>>? _training;

  Future<Map<String, dynamic>> _load(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> get speciesCatalog =>
      _speciesCatalog ??= _load('assets/data/species_catalog.json');

  Future<Map<String, dynamic>> get speciesImages =>
      _speciesImages ??= _load('assets/data/species_images.json');

  Future<Map<String, dynamic>> get traits =>
      _traits ??= _load('assets/data/identification_traits.json');

  Future<Map<String, dynamic>> get training =>
      _training ??= _load('assets/data/training_content.json');

  String _localized(Map<String, dynamic>? values, String languageCode) {
    if (values == null) return '';
    return (values[languageCode] ?? values['en'] ?? values['nl'] ?? '')
        .toString();
  }

  Future<List<SpeciesSummary>> speciesPage(
    String languageCode, {
    String query = '',
    int offset = 0,
    int limit = 50,
  }) async {
    final catalog = await speciesCatalog;
    final imagesManifest = await speciesImages;
    final taxa = <int, String>{};
    for (final raw in catalog['taxa'] as List<dynamic>? ?? const []) {
      final item = raw as Map<String, dynamic>;
      taxa[item['id'] as int] = item['scientific_name'] as String;
    }

    final primaryImages = <int, String>{};
    for (final raw in imagesManifest['species'] as List<dynamic>? ?? const []) {
      final item = raw as Map<String, dynamic>;
      final speciesId = item['speciesId'] as int;
      final images = item['images'] as List<dynamic>? ?? const [];
      Map<String, dynamic>? primary;
      for (final imageRaw in images) {
        final image = imageRaw as Map<String, dynamic>;
        if (image['primary'] == true) {
          primary = image;
          break;
        }
      }
      primary ??= images.isEmpty ? null : images.first as Map<String, dynamic>;
      if (primary != null) primaryImages[speciesId] = primary['path'] as String;
    }

    final needle = query.trim().toLowerCase();
    final results = <SpeciesSummary>[];
    for (final raw in catalog['species'] as List<dynamic>? ?? const []) {
      final item = raw as Map<String, dynamic>;
      final id = item['id'] as int;
      final scientificName = taxa[item['taxon_id'] as int] ?? '';
      final texts = item['texts'] as Map<String, dynamic>?;
      final localized =
          (texts?[languageCode] ?? texts?['en'] ?? texts?['nl']) as Map<String, dynamic>?;
      final commonName = localized?['common_name']?.toString() ?? scientificName;
      if (needle.isNotEmpty &&
          !commonName.toLowerCase().contains(needle) &&
          !scientificName.toLowerCase().contains(needle)) {
        continue;
      }
      results.add(
        SpeciesSummary(
          id: id,
          scientificName: scientificName,
          commonName: commonName,
          summary: localized?['summary']?.toString(),
          imagePath: primaryImages[id],
        ),
      );
    }
    results.sort(
      (a, b) => a.commonName.toLowerCase().compareTo(b.commonName.toLowerCase()),
    );
    if (offset >= results.length) return const [];
    final requestedEnd = offset + limit;
    final end = requestedEnd < results.length ? requestedEnd : results.length;
    return results.sublist(offset, end);
  }

  Future<List<TraitChoice>> traitChoices(String languageCode) async {
    final manifest = await traits;
    final result = <TraitChoice>[];
    for (final raw in manifest['traits'] as List<dynamic>? ?? const []) {
      final trait = raw as Map<String, dynamic>;
      final traitId = trait['id'] as int;
      final traitCode = trait['code'] as String;
      final traitLabel = _localized(
        trait['labels'] as Map<String, dynamic>?,
        languageCode,
      );
      final options = trait['options'] as List<dynamic>? ?? const [];
      final sorted = options.cast<Map<String, dynamic>>().toList()
        ..sort(
          (a, b) => (a['sort_order'] as int? ?? 0)
              .compareTo(b['sort_order'] as int? ?? 0),
        );
      for (final option in sorted) {
        result.add(
          TraitChoice(
            traitId: traitId,
            traitCode: traitCode,
            traitLabel: traitLabel,
            optionId: option['id'] as int,
            optionLabel: _localized(
              option['labels'] as Map<String, dynamic>?,
              languageCode,
            ),
          ),
        );
      }
    }
    return result;
  }

  Future<List<LessonSummary>> lessons(
    String languageCode, {
    Map<int, ({double bestScore, int attempts})> progress = const {},
  }) async {
    final manifest = await training;
    final lessons = (manifest['lessons'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0)
            .compareTo(b['sort_order'] as int? ?? 0),
      );
    return lessons.map((lesson) {
      final id = lesson['id'] as int;
      final texts = lesson['texts'] as Map<String, dynamic>?;
      final localized =
          (texts?[languageCode] ?? texts?['en'] ?? texts?['nl']) as Map<String, dynamic>?;
      final p = progress[id] ?? (bestScore: 0.0, attempts: 0);
      return LessonSummary(
        id: id,
        title: localized?['title']?.toString() ?? '',
        body: localized?['body']?.toString() ?? '',
        difficulty: lesson['difficulty'] as int? ?? 1,
        bestScore: p.bestScore,
        attempts: p.attempts,
      );
    }).toList();
  }

  Future<List<QuizQuestion>> questions(
    int lessonId,
    String languageCode,
  ) async {
    final manifest = await training;
    final lessons = manifest['lessons'] as List<dynamic>? ?? const [];
    Map<String, dynamic>? lesson;
    for (final raw in lessons) {
      final candidate = raw as Map<String, dynamic>;
      if (candidate['id'] == lessonId) {
        lesson = candidate;
        break;
      }
    }
    if (lesson == null) return const [];
    final questions = (lesson['questions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0)
            .compareTo(b['sort_order'] as int? ?? 0),
      );
    return questions.map((question) {
      final texts = question['texts'] as Map<String, dynamic>?;
      final localized =
          (texts?[languageCode] ?? texts?['en'] ?? texts?['nl']) as Map<String, dynamic>?;
      final answers = (question['answers'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort(
          (a, b) => (a['sort_order'] as int? ?? 0)
              .compareTo(b['sort_order'] as int? ?? 0),
        );
      return QuizQuestion(
        id: question['id'] as int,
        prompt: localized?['prompt']?.toString() ?? '',
        explanation: localized?['explanation']?.toString(),
        answers: answers
            .map(
              (answer) => QuizAnswer(
                id: answer['id'] as int,
                label: _localized(
                  answer['labels'] as Map<String, dynamic>?,
                  languageCode,
                ),
                isCorrect: answer['correct'] == true,
              ),
            )
            .toList(),
      );
    }).toList();
  }
}
