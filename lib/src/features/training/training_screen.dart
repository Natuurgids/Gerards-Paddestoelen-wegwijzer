import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/safety_notice.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, required this.locale});
  final Locale locale;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _repo = TrainingRepository();
  late Future<List<LessonSummary>> _lessons;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _lessons = _repo.lessons(widget.locale.languageCode);

  String t(String nl, String en, String de) =>
      widget.locale.languageCode == 'nl'
          ? nl
          : widget.locale.languageCode == 'de'
              ? de
              : en;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Leren', 'Learn', 'Lernen'))),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<LessonSummary>>(
                  future: _lessons,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: snapshot.data!
                          .map(
                            (lesson) => Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(lesson.title),
                                subtitle: Text(
                                  '${lesson.body}\n\n${t('Beste score', 'Best score', 'Beste Punktzahl')}: ${(lesson.bestScore * 100).round()}% · ${t('Pogingen', 'Attempts', 'Versuche')}: ${lesson.attempts}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LessonScreen(
                                        locale: widget.locale,
                                        lesson: lesson,
                                      ),
                                    ),
                                  );
                                  setState(_reload);
                                },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
              SafetyNotice(locale: widget.locale),
            ],
          ),
        ),
      );
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.locale, required this.lesson});
  final Locale locale;
  final LessonSummary lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _repo = TrainingRepository();
  late Future<List<QuizQuestion>> _future;
  final Map<int, int> _answers = {};
  double? _score;

  @override
  void initState() {
    super.initState();
    _future = _repo.questions(widget.lesson.id, widget.locale.languageCode);
  }

  String t(String nl, String en, String de) =>
      widget.locale.languageCode == 'nl'
          ? nl
          : widget.locale.languageCode == 'de'
              ? de
              : en;

  Future<void> _submit(List<QuizQuestion> questions) async {
    if (questions.isEmpty) return;
    var correct = 0;
    for (final q in questions) {
      final selected = _answers[q.id];
      if (selected != null &&
          q.answers.any((a) => a.id == selected && a.isCorrect)) {
        correct++;
      }
    }
    final score = correct / questions.length;
    await _repo.saveScore(widget.lesson.id, score);
    if (mounted) setState(() => _score = score);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.lesson.title)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<QuizQuestion>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final questions = snapshot.data!;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          widget.lesson.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        ...questions.map(
                          (question) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.prompt,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  RadioGroup<int>(
                                    groupValue: _answers[question.id],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _answers[question.id] = value);
                                    },
                                    child: Column(
                                      children: question.answers
                                          .map(
                                            (answer) => RadioListTile<int>(
                                              title: Text(answer.label),
                                              value: answer.id,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  if (_score != null &&
                                      question.explanation != null)
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(question.explanation!),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _submit(questions),
                          child: Text(
                            t(
                              'Nakijken',
                              'Check answers',
                              'Antworten prüfen',
                            ),
                          ),
                        ),
                        if (_score != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              '${t('Score', 'Score', 'Punktzahl')}: ${(_score! * 100).round()}%',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SafetyNotice(locale: widget.locale),
            ],
          ),
        ),
      );
}
