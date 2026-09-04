import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/training_data_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('questions and answers are assembled from one joined result set', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseSchema.create(db);

    await db.insert('lesson', {
      'id': 1,
      'slug': 'test',
      'difficulty': 1,
      'sort_order': 0,
    });
    await db.insert('lesson_text', {
      'lesson_id': 1,
      'language_code': 'en',
      'title': 'Test lesson',
      'body': 'Body',
    });
    for (var questionId = 1; questionId <= 2; questionId++) {
      await db.insert('question', {
        'id': questionId,
        'lesson_id': 1,
        'question_type': 'single_choice',
        'sort_order': questionId,
      });
      await db.insert('question_text', {
        'question_id': questionId,
        'language_code': 'en',
        'prompt': 'Question $questionId',
      });
      for (var answer = 1; answer <= 2; answer++) {
        final answerId = questionId * 10 + answer;
        await db.insert('answer_option', {
          'id': answerId,
          'question_id': questionId,
          'is_correct': answer == 1 ? 1 : 0,
          'sort_order': answer,
        });
        await db.insert('answer_option_text', {
          'answer_id': answerId,
          'language_code': 'en',
          'label': 'Answer $answerId',
        });
      }
    }

    final repository = TrainingDataRepository(databaseProvider: () async => db);
    final questions = await repository.questions(1, 'en');

    expect(questions.length, 2);
    expect(questions.first.answers.length, 2);
    expect(questions.first.answers.first.isCorrect, isTrue);
    expect(questions.last.answers.last.isCorrect, isFalse);
  });
}
