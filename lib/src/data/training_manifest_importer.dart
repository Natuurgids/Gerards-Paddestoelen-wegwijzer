import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class TrainingManifestImporter {
  static const _assetPath = 'assets/data/training_content.json';
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
    final lessons = decoded['lessons'] as List<dynamic>? ?? const [];
    _validate(lessons);

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final rawLesson in lessons) {
        final lesson = rawLesson as Map<String, dynamic>;
        final lessonId = lesson['id'] as int;
        _batchUpsertById(batch, 'lesson', {
          'id': lessonId,
          'slug': lesson['slug'],
          'difficulty': lesson['difficulty'] ?? 1,
          'sort_order': lesson['sort_order'] ?? 0,
        });

        final texts = lesson['texts'] as Map<String, dynamic>;
        for (final entry in texts.entries) {
          final text = entry.value as Map<String, dynamic>;
          batch.insert(
            'lesson_text',
            {
              'lesson_id': lessonId,
              'language_code': entry.key,
              'title': text['title'],
              'body': text['body'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        final questions = lesson['questions'] as List<dynamic>;
        for (final rawQuestion in questions) {
          final question = rawQuestion as Map<String, dynamic>;
          final questionId = question['id'] as int;
          _batchUpsertById(batch, 'question', {
            'id': questionId,
            'lesson_id': lessonId,
            'question_type': 'single_choice',
            'sort_order': question['sort_order'] ?? 0,
          });

          final questionTexts = question['texts'] as Map<String, dynamic>;
          for (final entry in questionTexts.entries) {
            final text = entry.value as Map<String, dynamic>;
            batch.insert(
              'question_text',
              {
                'question_id': questionId,
                'language_code': entry.key,
                'prompt': text['prompt'],
                'explanation': text['explanation'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          final answers = question['answers'] as List<dynamic>;
          for (final rawAnswer in answers) {
            final answer = rawAnswer as Map<String, dynamic>;
            final answerId = answer['id'] as int;
            _batchUpsertById(batch, 'answer_option', {
              'id': answerId,
              'question_id': questionId,
              'is_correct': answer['correct'] == true ? 1 : 0,
              'sort_order': answer['sort_order'] ?? 0,
            });

            final labels = answer['labels'] as Map<String, dynamic>;
            for (final entry in labels.entries) {
              batch.insert(
                'answer_option_text',
                {
                  'answer_id': answerId,
                  'language_code': entry.key,
                  'label': entry.value,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }
      await batch.commit(noResult: true);
    });
  }

  static void _batchUpsertById(
    Batch batch,
    String table,
    Map<String, Object?> values,
  ) {
    final id = values['id'];
    batch.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    batch.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static void _validate(List<dynamic> lessons) {
    final lessonIds = <int>{};
    final lessonSlugs = <String>{};
    final questionIds = <int>{};
    final answerIds = <int>{};

    for (final rawLesson in lessons) {
      final lesson = rawLesson as Map<String, dynamic>;
      final lessonId = lesson['id'];
      if (lessonId is! int || !lessonIds.add(lessonId)) {
        throw FormatException('Training lesson ids must be unique integers: $lessonId');
      }
      final slug = lesson['slug'];
      if (slug is! String || slug.trim().isEmpty || slug.trim() != slug ||
          !lessonSlugs.add(slug)) {
        throw FormatException('Training lesson slugs must be unique and non-empty: $slug');
      }
      _validateLocalizedObjects(
        lesson['texts'],
        const ['title', 'body'],
        'lesson $lessonId',
      );

      final questions = lesson['questions'];
      if (questions is! List<dynamic>) {
        throw FormatException('Lesson $lessonId must declare questions');
      }
      for (final rawQuestion in questions) {
        final question = rawQuestion as Map<String, dynamic>;
        final questionId = question['id'];
        if (questionId is! int || !questionIds.add(questionId)) {
          throw FormatException(
            'Training question ids must be unique integers: $questionId',
          );
        }
        _validateLocalizedObjects(
          question['texts'],
          const ['prompt'],
          'question $questionId',
        );

        final answers = question['answers'];
        if (answers is! List<dynamic> || answers.length < 2) {
          throw FormatException(
            'Question $questionId must have at least two answers',
          );
        }
        var correctCount = 0;
        for (final rawAnswer in answers) {
          final answer = rawAnswer as Map<String, dynamic>;
          final answerId = answer['id'];
          if (answerId is! int || !answerIds.add(answerId)) {
            throw FormatException(
              'Training answer ids must be unique integers: $answerId',
            );
          }
          _validateLabels(answer['labels'], 'answer $answerId');
          if (answer['correct'] == true) correctCount++;
        }
        if (correctCount != 1) {
          throw FormatException(
            'Question $questionId must have exactly one correct answer',
          );
        }
      }
    }
  }

  static void _validateLabels(Object? value, String context) {
    if (value is! Map<String, dynamic> ||
        !_languages.every(value.containsKey)) {
      throw FormatException('$context must have nl, en and de labels');
    }
    for (final language in _languages) {
      final label = value[language];
      if (label is! String || label.trim().isEmpty) {
        throw FormatException('$context has an invalid $language label');
      }
    }
  }

  static void _validateLocalizedObjects(
    Object? value,
    List<String> requiredFields,
    String context,
  ) {
    if (value is! Map<String, dynamic> ||
        !_languages.every(value.containsKey)) {
      throw FormatException('$context must have nl, en and de text');
    }
    for (final language in _languages) {
      final object = value[language];
      if (object is! Map<String, dynamic>) {
        throw FormatException('$context has invalid $language text');
      }
      for (final field in requiredFields) {
        final text = object[field];
        if (text is! String || text.trim().isEmpty) {
          throw FormatException(
            '$context has an invalid $language $field',
          );
        }
      }
    }
  }
}
