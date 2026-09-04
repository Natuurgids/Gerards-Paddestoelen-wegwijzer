import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'models.dart';

typedef TrainingDatabaseProvider = Future<Database> Function();

Future<Database> _defaultDatabaseProvider() => AppDatabase.instance.database;

class TrainingDataRepository {
  TrainingDataRepository({TrainingDatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _defaultDatabaseProvider;

  final TrainingDatabaseProvider _databaseProvider;

  Future<List<LessonSummary>> lessons(String languageCode) async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''SELECT l.id,l.difficulty,lt.title,lt.body,
      COALESCE(p.best_score,0) best_score,COALESCE(p.attempts,0) attempts
      FROM lesson l
      JOIN lesson_text lt ON lt.lesson_id=l.id AND lt.language_code=?
      LEFT JOIN training_progress p ON p.lesson_id=l.id
      ORDER BY l.sort_order''',
      [languageCode],
    );
    return rows
        .map(
          (row) => LessonSummary(
            id: row['id'] as int,
            title: row['title'] as String,
            body: row['body'] as String,
            difficulty: row['difficulty'] as int,
            bestScore: (row['best_score'] as num).toDouble(),
            attempts: row['attempts'] as int,
          ),
        )
        .toList();
  }

  Future<List<QuizQuestion>> questions(
    int lessonId,
    String languageCode,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery(
      '''SELECT q.id question_id, qt.prompt, qt.explanation,
      a.id answer_id, a.is_correct, at.label answer_label
      FROM question q
      JOIN question_text qt
        ON qt.question_id=q.id AND qt.language_code=?
      LEFT JOIN answer_option a ON a.question_id=q.id
      LEFT JOIN answer_option_text at
        ON at.answer_id=a.id AND at.language_code=?
      WHERE q.lesson_id=?
      ORDER BY q.sort_order, a.sort_order''',
      [languageCode, languageCode, lessonId],
    );

    final grouped = <int, _QuestionBuilder>{};
    for (final row in rows) {
      final questionId = row['question_id'] as int;
      final builder = grouped.putIfAbsent(
        questionId,
        () => _QuestionBuilder(
          id: questionId,
          prompt: row['prompt'] as String,
          explanation: row['explanation'] as String?,
        ),
      );
      final answerId = row['answer_id'] as int?;
      if (answerId != null) {
        builder.answers.add(
          QuizAnswer(
            id: answerId,
            label: row['answer_label'] as String,
            isCorrect: (row['is_correct'] as int) == 1,
          ),
        );
      }
    }

    return grouped.values
        .map(
          (builder) => QuizQuestion(
            id: builder.id,
            prompt: builder.prompt,
            explanation: builder.explanation,
            answers: builder.answers,
          ),
        )
        .toList();
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
    final attempts = current.isEmpty ? 0 : current.first['attempts'] as int;
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

class _QuestionBuilder {
  _QuestionBuilder({
    required this.id,
    required this.prompt,
    required this.explanation,
  });

  final int id;
  final String prompt;
  final String? explanation;
  final List<QuizAnswer> answers = [];
}
