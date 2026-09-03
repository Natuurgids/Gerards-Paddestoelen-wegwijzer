import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/training_manifest_importer.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE lesson (
      id INTEGER PRIMARY KEY,
      slug TEXT NOT NULL UNIQUE,
      difficulty INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE lesson_text (
      lesson_id INTEGER NOT NULL REFERENCES lesson(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      PRIMARY KEY(lesson_id, language_code)
    )''');
    await db.execute('''CREATE TABLE question (
      id INTEGER PRIMARY KEY,
      lesson_id INTEGER REFERENCES lesson(id) ON DELETE SET NULL,
      species_id INTEGER,
      question_type TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE question_text (
      question_id INTEGER NOT NULL REFERENCES question(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL,
      prompt TEXT NOT NULL,
      explanation TEXT,
      PRIMARY KEY(question_id, language_code)
    )''');
    await db.execute('''CREATE TABLE answer_option (
      id INTEGER PRIMARY KEY,
      question_id INTEGER NOT NULL REFERENCES question(id) ON DELETE CASCADE,
      is_correct INTEGER NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE answer_option_text (
      answer_id INTEGER NOT NULL REFERENCES answer_option(id) ON DELETE CASCADE,
      language_code TEXT NOT NULL,
      label TEXT NOT NULL,
      PRIMARY KEY(answer_id, language_code)
    )''');
    await db.execute('''CREATE TABLE training_progress (
      lesson_id INTEGER NOT NULL REFERENCES lesson(id) ON DELETE CASCADE,
      completed_at TEXT,
      best_score REAL NOT NULL DEFAULT 0,
      attempts INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(lesson_id)
    )''');
  });

  tearDown(() async {
    await db.close();
  });

  test('invalid training content does not mutate lessons or progress', () async {
    await db.insert('lesson', {
      'id': 99,
      'slug': 'existing',
      'difficulty': 1,
      'sort_order': 0,
    });
    await db.insert('lesson_text', {
      'lesson_id': 99,
      'language_code': 'en',
      'title': 'Existing',
      'body': 'Existing body',
    });
    await db.insert('training_progress', {
      'lesson_id': 99,
      'completed_at': '2026-09-03T12:00:00Z',
      'best_score': 0.8,
      'attempts': 3,
    });

    final malformed = <String, dynamic>{
      'lessons': [
        {
          'id': 1,
          'slug': 'bad-lesson',
          'texts': {
            'nl': {'title': 'Les', 'body': 'Tekst'},
            'en': {'title': 'Lesson', 'body': 'Text'},
            'de': {'title': 'Lektion', 'body': 'Text'},
          },
          'questions': [
            {
              'id': 10,
              'texts': {
                'nl': {'prompt': 'Vraag?'},
                'en': {'prompt': 'Question?'},
                'de': {'prompt': 'Frage?'},
              },
              'answers': [
                {
                  'id': 100,
                  'correct': true,
                  'labels': {
                    'nl': 'Ja',
                    'en': 'Yes',
                    'de': 'Ja',
                  },
                },
                {
                  'id': 101,
                  'correct': true,
                  'labels': {
                    'nl': 'Nee',
                    'en': 'No',
                    'de': 'Nein',
                  },
                },
              ],
            },
          ],
        },
      ],
    };

    await expectLater(
      TrainingManifestImporter.syncDecoded(db, malformed),
      throwsA(isA<FormatException>()),
    );

    expect(await db.query('lesson', where: 'id = 99'), hasLength(1));
    expect(await db.query('lesson_text', where: 'lesson_id = 99'), hasLength(1));
    final progress = await db.query('training_progress', where: 'lesson_id = 99');
    expect(progress, hasLength(1));
    expect(progress.single['best_score'], 0.8);
    expect(progress.single['attempts'], 3);
    expect(await db.query('lesson', where: 'id = 1'), isEmpty);
  });
}
