import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import 'models.dart';

class SpeciesRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<SpeciesSummary>> search(String languageCode, {String query = ''}) async {
    final db = await _db;
    final like = '%${query.trim()}%';
    final rows = await db.rawQuery('''
      SELECT s.id, t.scientific_name, st.common_name, st.summary,
             (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path
      FROM species s
      JOIN taxon t ON t.id=s.taxon_id
      JOIN species_text st ON st.species_id=s.id AND st.language_code=?
      WHERE ?='' OR st.common_name LIKE ? COLLATE NOCASE OR t.scientific_name LIKE ? COLLATE NOCASE
      ORDER BY st.common_name COLLATE NOCASE
    ''', [languageCode, query.trim(), like, like]);
    return rows.map(_summary).toList();
  }

  Future<SpeciesDetail?> detail(int id, String languageCode) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.id, s.edible_status, s.toxicity_level, t.scientific_name,
             st.common_name, st.summary, st.description, st.habitat_text, st.lookalikes_text,
             (SELECT asset_path FROM species_image si WHERE si.species_id=s.id ORDER BY si.is_primary DESC, si.sort_order LIMIT 1) image_path
      FROM species s JOIN taxon t ON t.id=s.taxon_id
      JOIN species_text st ON st.species_id=s.id AND st.language_code=?
      WHERE s.id=? LIMIT 1
    ''', [languageCode, id]);
    if (rows.isEmpty) return null;
    final images = await db.query('species_image', where: 'species_id=?', whereArgs: [id], orderBy: 'sort_order');
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
      images: images.map((m) => SpeciesImage(path: m['asset_path'] as String, angleCode: m['angle_code'] as String?, sortOrder: m['sort_order'] as int, photographer: m['photographer'] as String?, license: m['license'] as String?)).toList(),
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
  Future<List<TraitChoice>> choices(String languageCode) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT tr.id trait_id, tr.code trait_code, tr.category trait_label,
             o.id option_id, txt.label option_label
      FROM trait tr JOIN trait_option o ON o.trait_id=tr.id
      JOIN trait_option_text txt ON txt.option_id=o.id AND txt.language_code=?
      WHERE tr.value_type='choice'
      ORDER BY tr.id, o.sort_order
    ''', [languageCode]);
    return rows.map((r) => TraitChoice(traitId:r['trait_id'] as int, traitCode:r['trait_code'] as String, traitLabel:r['trait_label'] as String, optionId:r['option_id'] as int, optionLabel:r['option_label'] as String)).toList();
  }

  Future<List<IdentificationCandidate>> identify(String languageCode, Map<int,int> selected) async {
    final species = await SpeciesRepository().search(languageCode);
    if (selected.isEmpty) return species.take(20).map((s) => IdentificationCandidate(species:s, score:0, matched:0, requested:0)).toList();
    final db = await AppDatabase.instance.database;
    final candidates = <IdentificationCandidate>[];
    for (final s in species) {
      double matchedWeight = 0;
      double totalWeight = 0;
      var matched = 0;
      for (final entry in selected.entries) {
        final rows = await db.query('species_trait', columns:['option_id','weight'], where:'species_id=? AND trait_id=?', whereArgs:[s.id, entry.key]);
        final weight = rows.isEmpty ? 1.0 : (rows.first['weight'] as num).toDouble();
        totalWeight += weight;
        if (rows.any((r) => r['option_id'] == entry.value)) { matched++; matchedWeight += weight; }
      }
      candidates.add(IdentificationCandidate(species:s, score: totalWeight == 0 ? 0 : matchedWeight / totalWeight, matched:matched, requested:selected.length));
    }
    candidates.sort((a,b) => b.score.compareTo(a.score));
    return candidates.where((c) => c.score > 0).toList();
  }
}

class TrainingRepository {
  Future<List<LessonSummary>> lessons(String languageCode) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT l.id,l.difficulty,lt.title,lt.body,COALESCE(p.best_score,0) best_score,COALESCE(p.attempts,0) attempts
      FROM lesson l JOIN lesson_text lt ON lt.lesson_id=l.id AND lt.language_code=?
      LEFT JOIN training_progress p ON p.lesson_id=l.id ORDER BY l.sort_order
    ''',[languageCode]);
    return rows.map((r)=>LessonSummary(id:r['id'] as int,title:r['title'] as String,body:r['body'] as String,difficulty:r['difficulty'] as int,bestScore:(r['best_score'] as num).toDouble(),attempts:r['attempts'] as int)).toList();
  }

  Future<List<QuizQuestion>> questions(int lessonId, String languageCode) async {
    final db = await AppDatabase.instance.database;
    final qs = await db.rawQuery('''SELECT q.id,qt.prompt,qt.explanation FROM question q JOIN question_text qt ON qt.question_id=q.id AND qt.language_code=? WHERE q.lesson_id=? ORDER BY q.sort_order''',[languageCode,lessonId]);
    final result=<QuizQuestion>[];
    for(final q in qs){
      final answers=await db.rawQuery('''SELECT a.id,a.is_correct,t.label FROM answer_option a JOIN answer_option_text t ON t.answer_id=a.id AND t.language_code=? WHERE a.question_id=? ORDER BY a.sort_order''',[languageCode,q['id']]);
      result.add(QuizQuestion(id:q['id'] as int,prompt:q['prompt'] as String,explanation:q['explanation'] as String?,answers:answers.map((a)=>QuizAnswer(id:a['id'] as int,label:a['label'] as String,isCorrect:(a['is_correct'] as int)==1)).toList()));
    }
    return result;
  }

  Future<void> saveScore(int lessonId,double score) async {
    final db=await AppDatabase.instance.database;
    final current=await db.query('training_progress',where:'lesson_id=?',whereArgs:[lessonId],limit:1);
    final oldBest=current.isEmpty?0.0:(current.first['best_score'] as num).toDouble();
    final attempts=current.isEmpty?0:current.first['attempts'] as int;
    await db.insert('training_progress',{'lesson_id':lessonId,'completed_at':DateTime.now().toIso8601String(),'best_score':score>oldBest?score:oldBest,'attempts':attempts+1},conflictAlgorithm:ConflictAlgorithm.replace);
  }
}
