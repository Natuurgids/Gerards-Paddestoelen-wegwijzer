import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'field_measurement_contract.dart';
import 'identification_scoring.dart';
import 'models.dart';

typedef DatabaseProvider = Future<Database> Function();

Future<Database> _defaultDatabaseProvider() => AppDatabase.instance.database;

class FieldDataRepository {
  static const _assetPath = 'assets/data/field_data.json';

  Future<List<SeasonRegionOption>> seasonRegions(String languageCode) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final regions = decoded['season_regions'] as List<dynamic>? ?? const [];
    return regions.map((rawRegion) {
      final region = rawRegion as Map<String, dynamic>;
      final labels = region['labels'] as Map<String, dynamic>? ?? const {};
      final notes = region['notes'] as Map<String, dynamic>? ?? const {};
      String localized(Map<String, dynamic> values) =>
          (values[languageCode] ?? values['en'] ?? values['nl'] ?? '').toString();
      return SeasonRegionOption(
        code: region['code'] as String,
        label: localized(labels),
        note: localized(notes),
      );
    }).toList();
  }
}

class SpeciesRepository {
  SpeciesRepository({DatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _defaultDatabaseProvider;

  final DatabaseProvider _databaseProvider;

  Future<List<SpeciesSummary>> search(
    String languageCode, {
    String query = '',
  }) async {
    final db = await _databaseProvider();
    final like = '%${query.trim()}%';
    final rows = await db.rawQuery(
      '''SELECT s.id, t.scientific_name, st.common_name, st.summary,
      (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path
      FROM species s JOIN taxon t ON t.id=s.taxon_id JOIN species_text st ON st.species_id=s.id AND st.language_code=?
      WHERE ?='' OR st.common_name LIKE ? COLLATE NOCASE OR t.scientific_name LIKE ? COLLATE NOCASE ORDER BY st.common_name COLLATE NOCASE''',
      [languageCode, query.trim(), like, like],
    );
    return rows.map(_summary).toList();
  }

  Future<SpeciesDetail?> detail(int id, String languageCode) async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''SELECT s.id, s.edible_status, s.toxicity_level, t.scientific_name,
      st.common_name, st.summary, st.description, st.habitat_text, st.lookalikes_text,
      (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path
      FROM species s JOIN taxon t ON t.id=s.taxon_id JOIN species_text st ON st.species_id=s.id AND st.language_code=? WHERE s.id=? LIMIT 1''',
      [languageCode, id],
    );
    if (rows.isEmpty) return null;
    final images = await db.query(
      'species_image',
      where: 'species_id=?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    final measurements = await db.query(
      'species_measurement',
      where: 'species_id=?',
      whereArgs: [id],
      orderBy: 'measurement_code',
    );
    final season = await db.query(
      'species_season',
      where: 'species_id=?',
      whereArgs: [id],
      orderBy: 'region_code, month',
    );
    final row = rows.first;
    return SpeciesDetail(
      id: row['id'] as int,
      scientificName: row['scientific_name'] as String,
      commonName: row['common_name'] as String,
      summary: row['summary'] as String?,
      imagePath: row['image_path'] as String?,
      description: row['description'] as String?,
      habitat: row['habitat_text'] as String?,
      lookalikes: row['lookalikes_text'] as String?,
      edibleStatus: row['edible_status'] as String,
      toxicityLevel: row['toxicity_level'] as String,
      images: images
          .map(
            (m) => SpeciesImage(
              path: m['asset_path'] as String,
              angleCode: m['angle_code'] as String?,
              sortOrder: m['sort_order'] as int,
              photographer: m['photographer'] as String?,
              license: m['license'] as String?,
            ),
          )
          .toList(),
      measurements: measurements
          .map(
            (m) => SpeciesMeasurement(
              code: m['measurement_code'] as String,
              minValue: (m['min_value'] as num?)?.toDouble(),
              maxValue: (m['max_value'] as num?)?.toDouble(),
              unit: m['unit'] as String,
            ),
          )
          .toList(),
      season: season
          .map(
            (m) => SpeciesSeasonMonth(
              month: m['month'] as int,
              likelihood: m['likelihood'] as int,
              regionCode: m['region_code'] as String?,
            ),
          )
          .toList(),
    );
  }

  SpeciesSummary _summary(Map<String, Object?> row) => SpeciesSummary(
        id: row['id'] as int,
        scientificName: row['scientific_name'] as String,
        commonName: row['common_name'] as String,
        summary: row['summary'] as String?,
        imagePath: row['image_path'] as String?,
      );
}

class IdentificationRepository {
  IdentificationRepository({DatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _defaultDatabaseProvider;

  final DatabaseProvider _databaseProvider;

  Future<List<TraitChoice>> choices(String languageCode) async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''SELECT tr.id trait_id, tr.code trait_code, COALESCE(tt.label, tr.category) trait_label,
      o.id option_id, txt.label option_label FROM trait tr JOIN trait_option o ON o.trait_id=tr.id
      JOIN trait_option_text txt ON txt.option_id=o.id AND txt.language_code=? LEFT JOIN trait_text tt ON tt.trait_id=tr.id AND tt.language_code=?
      WHERE tr.value_type='choice' ORDER BY tr.id, o.sort_order''',
      [languageCode, languageCode],
    );
    return rows
        .map(
          (r) => TraitChoice(
            traitId: r['trait_id'] as int,
            traitCode: r['trait_code'] as String,
            traitLabel: r['trait_label'] as String,
            optionId: r['option_id'] as int,
            optionLabel: r['option_label'] as String,
          ),
        )
        .toList();
  }

  Future<List<IdentificationCandidate>> identify(
    String languageCode,
    Map<int, int> selected, {
    int? observationMonth,
    String? seasonRegionCode,
    double? capDiameterCm,
    double? stemHeightCm,
    double? stemDiameterCm,
  }) async {
    final fieldRequested =
        (observationMonth != null && seasonRegionCode != null ? 1 : 0) +
            (capDiameterCm != null ? 1 : 0) +
            (stemHeightCm != null ? 1 : 0) +
            (stemDiameterCm != null ? 1 : 0);
    final morphology = await _morphologyCandidates(
      languageCode,
      selected,
      includeZeroMatches: fieldRequested > 0,
    );
    if (fieldRequested == 0) return morphology;

    final db = await _databaseProvider();
    final evidenceRows = await db.rawQuery(
      '''SELECT s.id,
      CASE WHEN ? IS NULL OR ? IS NULL THEN NULL
        WHEN EXISTS(SELECT 1 FROM species_season ss WHERE ss.species_id=s.id AND ss.region_code=? LIMIT 1)
          THEN COALESCE((SELECT ss.likelihood / 3.0 FROM species_season ss WHERE ss.species_id=s.id AND ss.month=? AND ss.region_code=? LIMIT 1), 0.0)
        ELSE NULL END season_score,
      (SELECT sm.min_value FROM species_measurement sm WHERE sm.species_id=s.id AND sm.measurement_code='$capDiameterMeasurementCode' LIMIT 1) cap_min,
      (SELECT sm.max_value FROM species_measurement sm WHERE sm.species_id=s.id AND sm.measurement_code='$capDiameterMeasurementCode' LIMIT 1) cap_max,
      (SELECT sm.min_value FROM species_measurement sm WHERE sm.species_id=s.id AND sm.measurement_code='$stemHeightMeasurementCode' LIMIT 1) stem_height_min,
      (SELECT sm.max_value FROM species_measurement sm WHERE sm.species_id=s.id AND sm.measurement_code='$stemHeightMeasurementCode' LIMIT 1) stem_height_max,
      (SELECT sm.min_value FROM species_measurement sm WHERE sm.species_id=s.id AND sm.measurement_code='$stemDiameterMeasurementCode' LIMIT 1) stem_diameter_min,
      (SELECT sm.max_value FROM species_measurement sm WHERE sm.species_id=s.id AND sm.measurement_code='$stemDiameterMeasurementCode' LIMIT 1) stem_diameter_max
      FROM species s''',
      [
        observationMonth,
        seasonRegionCode,
        seasonRegionCode,
        observationMonth,
        seasonRegionCode,
      ],
    );

    final evidenceBySpecies =
        <int, ({double score, int matched, int evaluated})>{};
    for (final row in evidenceRows) {
      final scores = <double>[];
      var matched = 0;

      final rawSeasonScore = row['season_score'] as num?;
      if (rawSeasonScore != null) {
        final score = rawSeasonScore.toDouble();
        scores.add(score);
        if (score > 0) matched++;
      }

      void addMeasurement(
        double? observedValue,
        String minKey,
        String maxKey,
      ) {
        if (observedValue == null) return;
        final minValue = (row[minKey] as num?)?.toDouble();
        final maxValue = (row[maxKey] as num?)?.toDouble();
        if (minValue == null || maxValue == null) return;
        final score = measurementMatchScore(
          observedValue: observedValue,
          minValue: minValue,
          maxValue: maxValue,
        );
        scores.add(score);
        if (score > 0) matched++;
      }

      addMeasurement(capDiameterCm, 'cap_min', 'cap_max');
      addMeasurement(stemHeightCm, 'stem_height_min', 'stem_height_max');
      addMeasurement(stemDiameterCm, 'stem_diameter_min', 'stem_diameter_max');

      final evaluated = scores.length;
      final score = evaluated == 0
          ? 0.0
          : scores.reduce((a, b) => a + b) / evaluated;
      evidenceBySpecies[row['id'] as int] = (
        score: score,
        matched: matched,
        evaluated: evaluated,
      );
    }

    final hasMorphology = selected.isNotEmpty;
    final combined = morphology.map((candidate) {
      final field = evidenceBySpecies[candidate.species.id] ??
          (score: 0.0, matched: 0, evaluated: 0);
      final breakdown = combineIdentificationScores(
        morphologyScore: candidate.score,
        fieldScore: field.score,
        hasMorphology: hasMorphology,
      );
      return IdentificationCandidate(
        species: candidate.species,
        score: breakdown.combinedScore,
        matched: candidate.matched,
        requested: candidate.requested,
        fieldScore: breakdown.fieldScore,
        fieldMatched: field.matched,
        fieldRequested: field.evaluated,
      );
    }).where((candidate) => candidate.score > 0).toList();

    combined.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byMorphology = b.matched.compareTo(a.matched);
      if (byMorphology != 0) return byMorphology;
      return b.fieldMatched.compareTo(a.fieldMatched);
    });
    return combined;
  }

  Future<List<IdentificationCandidate>> _morphologyCandidates(
    String languageCode,
    Map<int, int> selected, {
    bool includeZeroMatches = false,
  }) async {
    if (selected.isEmpty) {
      final species = await SpeciesRepository(
        databaseProvider: _databaseProvider,
      ).search(languageCode);
      return species
          .take(50)
          .map(
            (s) => IdentificationCandidate(
              species: s,
              score: 0,
              matched: 0,
              requested: 0,
            ),
          )
          .toList();
    }

    final db = await _databaseProvider();
    final valueSql = List.filled(selected.length, '(?, ?)').join(', ');
    final args = <Object?>[];
    for (final entry in selected.entries) {
      args
        ..add(entry.key)
        ..add(entry.value);
    }
    args.add(languageCode);

    final matchFilter =
        includeZeroMatches ? '' : 'WHERE scores.matched_weight > 0';
    final rows = await db.rawQuery(
      '''WITH selected(trait_id, option_id) AS (VALUES $valueSql),
      per_trait AS (
        SELECT s.id species_id, sel.trait_id,
          MAX(CASE WHEN st.option_id = sel.option_id THEN COALESCE(st.weight, 1.0) ELSE 0 END) matched_weight,
          COALESCE(MAX(st.weight), 1.0) total_weight,
          MAX(CASE WHEN st.option_id = sel.option_id THEN 1 ELSE 0 END) matched
        FROM species s CROSS JOIN selected sel LEFT JOIN species_trait st ON st.species_id=s.id AND st.trait_id=sel.trait_id
        GROUP BY s.id, sel.trait_id
      ), scores AS (
        SELECT species_id, SUM(matched_weight) matched_weight, SUM(total_weight) total_weight, SUM(matched) matched_count
        FROM per_trait GROUP BY species_id
      )
      SELECT s.id, t.scientific_name, txt.common_name, txt.summary,
        (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path,
        scores.matched_weight / NULLIF(scores.total_weight, 0) score, scores.matched_count
      FROM scores JOIN species s ON s.id=scores.species_id JOIN taxon t ON t.id=s.taxon_id JOIN species_text txt ON txt.species_id=s.id AND txt.language_code=?
      $matchFilter ORDER BY score DESC, scores.matched_count DESC, txt.common_name COLLATE NOCASE LIMIT 50''',
      args,
    );
    return rows
        .map(
          (r) => IdentificationCandidate(
            species: SpeciesSummary(
              id: r['id'] as int,
              scientificName: r['scientific_name'] as String,
              commonName: r['common_name'] as String,
              summary: r['summary'] as String?,
              imagePath: r['image_path'] as String?,
            ),
            score: (r['score'] as num).toDouble(),
            matched: (r['matched_count'] as num).toInt(),
            requested: selected.length,
          ),
        )
        .toList();
  }
}

class TrainingRepository {
  TrainingRepository({DatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _defaultDatabaseProvider;

  final DatabaseProvider _databaseProvider;

  Future<List<LessonSummary>> lessons(String languageCode) async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''SELECT l.id,l.difficulty,lt.title,lt.body,COALESCE(p.best_score,0) best_score,COALESCE(p.attempts,0) attempts FROM lesson l JOIN lesson_text lt ON lt.lesson_id=l.id AND lt.language_code=? LEFT JOIN training_progress p ON p.lesson_id=l.id ORDER BY l.sort_order''',
      [languageCode],
    );
    return rows
        .map(
          (r) => LessonSummary(
            id: r['id'] as int,
            title: r['title'] as String,
            body: r['body'] as String,
            difficulty: r['difficulty'] as int,
            bestScore: (r['best_score'] as num).toDouble(),
            attempts: r['attempts'] as int,
          ),
        )
        .toList();
  }

  Future<List<QuizQuestion>> questions(
    int lessonId,
    String languageCode,
  ) async {
    final db = await _databaseProvider();
    final qs = await db.rawQuery(
      '''SELECT q.id,qt.prompt,qt.explanation FROM question q JOIN question_text qt ON qt.question_id=q.id AND qt.language_code=? WHERE q.lesson_id=? ORDER BY q.sort_order''',
      [languageCode, lessonId],
    );
    final result = <QuizQuestion>[];
    for (final q in qs) {
      final answers = await db.rawQuery(
        '''SELECT a.id,a.is_correct,t.label FROM answer_option a JOIN answer_option_text t ON t.answer_id=a.id AND t.language_code=? WHERE a.question_id=? ORDER BY a.sort_order''',
        [languageCode, q['id']],
      );
      result.add(
        QuizQuestion(
          id: q['id'] as int,
          prompt: q['prompt'] as String,
          explanation: q['explanation'] as String?,
          answers: answers
              .map(
                (a) => QuizAnswer(
                  id: a['id'] as int,
                  label: a['label'] as String,
                  isCorrect: (a['is_correct'] as int) == 1,
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<void> saveScore(int lessonId, double score) async {
    final db = await _databaseProvider();
    final current = await db.query(
      'training_progress',
      where: 'lesson_id=?',
      whereArgs: [lessonId],
      limit: 1,
    );
    final oldBest = current.isEmpty
        ? 0.0
        : (current.first['best_score'] as num).toDouble();
    final attempts =
        current.isEmpty ? 0 : current.first['attempts'] as int;
    await db.insert(
      'training_progress',
      {
        'lesson_id': lessonId,
        'completed_at': DateTime.now().toIso8601String(),
        'best_score': score > oldBest ? score : oldBest,
        'attempts': attempts + 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
