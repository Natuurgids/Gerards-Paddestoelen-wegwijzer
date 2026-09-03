import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class TrainingManifestImporter {
  static const _assetPath = 'assets/data/training_content.json';

  static Future<void> sync(Database db) async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final lessons = decoded['lessons'] as List<dynamic>? ?? const [];

    await db.transaction((txn) async {
      for (final rawLesson in lessons) {
        final lesson = rawLesson as Map<String, dynamic>;
        final lessonId = lesson['id'] as int;
        await txn.insert(
          'lesson',
          {
            'id': lessonId,
            'slug': lesson['slug'],
            'difficulty': lesson['difficulty'] ?? 1,
            'sort_order': lesson['sort_order'] ?? 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final texts = lesson['texts'] as Map<String, dynamic>? ?? const {};
        for (final entry in texts.entries) {
          final text = entry.value as Map<String, dynamic>;
          await txn.insert(
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

        final questions = lesson['questions'] as List<dynamic>? ?? const [];
        for (final rawQuestion in questions) {
          final question = rawQuestion as Map<String, dynamic>;
          final questionId = question['id'] as int;
          await txn.insert(
            'question',
            {
              'id': questionId,
              'lesson_id': lessonId,
              'question_type': 'single_choice',
              'sort_order': question['sort_order'] ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          final questionTexts =
              question['texts'] as Map<String, dynamic>? ?? const {};
          for (final entry in questionTexts.entries) {
            final text = entry.value as Map<String, dynamic>;
            await txn.insert(
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

          final answers = question['answers'] as List<dynamic>? ?? const [];
          for (final rawAnswer in answers) {
            final answer = rawAnswer as Map<String, dynamic>;
            final answerId = answer['id'] as int;
            await txn.insert(
              'answer_option',
              {
                'id': answerId,
                'question_id': questionId,
                'is_correct': answer['correct'] == true ? 1 : 0,
                'sort_order': answer['sort_order'] ?? 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            final labels =
                answer['labels'] as Map<String, dynamic>? ?? const {};
            for (final entry in labels.entries) {
              await txn.insert(
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
    });
  }
}
