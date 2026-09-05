import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/training_data_repository.dart';
import '../../widgets/safety_notice.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    required this.locale,
    this.repository,
    this.lessonIds,
    this.title,
  });

  final Locale locale;
  final TrainingDataRepository? repository;
  final Set<int>? lessonIds;
  final String? title;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final TrainingDataRepository _repo;
  late Future<List<LessonSummary>> _lessons;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TrainingDataRepository();
    _reload();
  }

  void _reload() => _lessons = _loadLessons();

  Future<List<LessonSummary>> _loadLessons() async {
    final lessons = await _repo.lessons(widget.locale.languageCode);
    final lessonIds = widget.lessonIds;
    if (lessonIds == null) return lessons;
    return lessons.where((lesson) => lessonIds.contains(lesson.id)).toList();
  }

  void _retry() {
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.trainingTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<LessonSummary>>(
                future: _lessons,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: IconButton(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        iconSize: 40,
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lessons = snapshot.data ?? const <LessonSummary>[];
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: lessons
                        .map(
                          (lesson) => Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(lesson.title),
                              subtitle: Text(
                                '${lesson.body}\n\n${l10n.trainingBestScore}: ${(lesson.bestScore * 100).round()}% · ${l10n.trainingAttempts}: ${lesson.attempts}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LessonScreen(
                                      locale: widget.locale,
                                      lesson: lesson,
                                      repository: _repo,
                                    ),
                                  ),
                                );
                                if (mounted) setState(_reload);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            const SafetyNotice(),
          ],
        ),
      ),
    );
  }
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.locale,
    required this.lesson,
    this.repository,
  });

  final Locale locale;
  final LessonSummary lesson;
  final TrainingDataRepository? repository;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final TrainingDataRepository _repo;
  late Future<List<QuizQuestion>> _future;
  final Map<int, int> _answers = {};
  double? _score;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TrainingDataRepository();
    _loadQuestions();
  }

  void _loadQuestions() {
    _future = _repo.questions(widget.lesson.id, widget.locale.languageCode);
  }

  void _retry() {
    setState(_loadQuestions);
  }

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<QuizQuestion>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: IconButton(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        iconSize: 40,
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final questions = snapshot.data ?? const <QuizQuestion>[];
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
                        child: Text(l10n.trainingCheckAnswers),
                      ),
                      if (_score != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '${l10n.trainingScore}: ${(_score! * 100).round()}%',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SafetyNotice(),
          ],
        ),
      ),
    );
  }
}
