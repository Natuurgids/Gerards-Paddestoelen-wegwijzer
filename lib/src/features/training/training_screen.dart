import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/training_data_repository.dart';
import '../../theme/app_theme.dart';
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

  ShapeBorder get _cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      );

  Widget _lessonCard(
    BuildContext context,
    AppLocalizations l10n,
    LessonSummary lesson,
    int index,
  ) {
    final score = (lesson.bestScore * 100).round();
    return Card(
      elevation: 0,
      color: AppTheme.creamStrong,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.moss.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.forest,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lesson.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.ink.withValues(alpha: .78),
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ProgressBadge(
                          icon: Icons.workspace_premium_outlined,
                          label: '${l10n.trainingBestScore}: $score%',
                        ),
                        _ProgressBadge(
                          icon: Icons.replay,
                          label:
                              '${l10n.trainingAttempts}: ${lesson.attempts}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.chevron_right, color: AppTheme.forest),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title ?? l10n.trainingTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth >= 900
                          ? 32.0
                          : 16.0;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          16,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: _LearningHeader(title: title),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(
                            lessons.length,
                            (index) => Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 900),
                                child: _lessonCard(
                                  context,
                                  l10n,
                                  lessons[index],
                                  index,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
    for (final question in questions) {
      final selected = _answers[question.id];
      if (selected != null &&
          question.answers.any(
            (answer) => answer.id == selected && answer.isCorrect,
          )) {
        correct++;
      }
    }
    final score = correct / questions.length;
    await _repo.saveScore(widget.lesson.id, score);
    if (mounted) setState(() => _score = score);
  }

  ShapeBorder get _cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      );

  Widget _questionCard(
    BuildContext context,
    QuizQuestion question,
    int index,
  ) =>
      Card(
        elevation: 0,
        color: AppTheme.creamStrong,
        shape: _cardShape,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.moss.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.forest,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        question.prompt,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(answer.label),
                          value: answer.id,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_score != null && question.explanation != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.moss.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    question.explanation!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink,
                          height: 1.4,
                        ),
                  ),
                ),
            ],
          ),
        ),
      );

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
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontalPadding = constraints.maxWidth >= 900
                          ? 32.0
                          : 16.0;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          16,
                          horizontalPadding,
                          16,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.moss.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppTheme.forest,
                                            borderRadius:
                                                BorderRadius.circular(13),
                                          ),
                                          child: const Icon(
                                            Icons.menu_book_outlined,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            widget.lesson.body,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: AppTheme.ink,
                                                  height: 1.5,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...List.generate(
                                    questions.length,
                                    (index) => _questionCard(
                                      context,
                                      questions[index],
                                      index,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 48,
                                    child: FilledButton.icon(
                                      onPressed: () => _submit(questions),
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: Text(l10n.trainingCheckAnswers),
                                    ),
                                  ),
                                  if (_score != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 14),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.forest,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.school_outlined,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${l10n.trainingScore}: ${(_score! * 100).round()}%',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

class _LearningHeader extends StatelessWidget {
  const _LearningHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.forest, AppTheme.forestDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school_outlined, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.moss.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.forest),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.forest,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
}
