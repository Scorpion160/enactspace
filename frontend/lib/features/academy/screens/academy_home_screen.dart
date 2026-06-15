import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/academy_models.dart';
import '../services/academy_service.dart';

class AcademyHomeScreen extends StatefulWidget {
  const AcademyHomeScreen({super.key});

  @override
  State<AcademyHomeScreen> createState() => _AcademyHomeScreenState();
}

class _AcademyHomeScreenState extends State<AcademyHomeScreen> {
  final AcademyService _service = AcademyService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _rewardingActionId;
  String? _error;
  AcademyHomeData? _data;
  String _levelFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAcademy();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademy() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getHome();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeNextLesson(AcademyCourseModel course) async {
    final pendingLessons = course.lessons
        .where((lesson) => !lesson.completed)
        .toList();
    if (pendingLessons.isEmpty) {
      _showRewardSnack(
        const AcademyRewardResult(
          points: 0,
          label: 'Toutes les leçons sont déjà terminées',
          syncedWithGamification: true,
        ),
      );
      return;
    }

    final lesson = pendingLessons.first;
    final actionId = 'lesson-${course.id}';
    setState(() => _rewardingActionId = actionId);

    final result = await _service.completeLesson(
      course: course,
      lesson: lesson,
    );
    final data = await _service.getHome();

    if (!mounted) return;
    setState(() {
      _data = data;
      _rewardingActionId = null;
    });
    _showRewardSnack(result);
  }

  Future<void> _passQuiz(AcademyCourseModel course) async {
    final actionId = 'quiz-${course.id}';
    setState(() => _rewardingActionId = actionId);

    final result = await _service.passQuiz(course: course);
    final data = await _service.getHome();

    if (!mounted) return;
    setState(() {
      _data = data;
      _rewardingActionId = null;
    });
    _showRewardSnack(result);
  }

  Future<void> _openQuiz(AcademyCourseModel course) async {
    final passed = await showDialog<bool>(
      context: context,
      builder: (context) => _AcademyQuizDialog(course: course),
    );

    if (!mounted || passed == null) return;
    if (passed) {
      await _passQuiz(course);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quiz a reprendre. Tu peux retenter quand tu veux.'),
      ),
    );
  }

  void _showRewardSnack(AcademyRewardResult result) {
    final suffix = result.syncedWithGamification
        ? 'Synchronisé avec Gamification.'
        : 'Progression locale enregistrée, synchro Gamification à réessayer.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.points > 0
              ? '${result.label}: +${result.points} points. $suffix'
              : '${result.label}. $suffix',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAcademy,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _AcademyHeader(),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _AcademyErrorCard(message: _error!, onRetry: _loadAcademy)
          else
            _AcademyContent(
              data: _data!,
              searchController: _searchController,
              levelFilter: _levelFilter,
              categoryFilter: _categoryFilter,
              onFiltersChanged: () => setState(() {}),
              onLevelChanged: (value) => setState(() => _levelFilter = value),
              onCategoryChanged: (value) {
                setState(() => _categoryFilter = value);
              },
              rewardingActionId: _rewardingActionId,
              onCompleteNextLesson: _completeNextLesson,
              onPassQuiz: _openQuiz,
            ),
        ],
      ),
    );
  }
}

class _AcademyHeader extends StatelessWidget {
  const _AcademyHeader();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: wide
          ? Row(
              children: [
                const _HeaderIcon(),
                const SizedBox(width: 18),
                const Expanded(child: _HeaderCopy()),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continuer'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _HeaderIcon(),
                    SizedBox(width: 18),
                    Expanded(child: _HeaderCopy()),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Continuer'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.school_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EnactSpace Academy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Cours courts, quiz, badges et parcours pour maîtriser la culture Enactus et préparer la compétition.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _AcademyContent extends StatelessWidget {
  final AcademyHomeData data;
  final TextEditingController searchController;
  final String levelFilter;
  final String categoryFilter;
  final VoidCallback onFiltersChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onCategoryChanged;
  final String? rewardingActionId;
  final ValueChanged<AcademyCourseModel> onCompleteNextLesson;
  final ValueChanged<AcademyCourseModel> onPassQuiz;

  const _AcademyContent({
    required this.data,
    required this.searchController,
    required this.levelFilter,
    required this.categoryFilter,
    required this.onFiltersChanged,
    required this.onLevelChanged,
    required this.onCategoryChanged,
    required this.rewardingActionId,
    required this.onCompleteNextLesson,
    required this.onPassQuiz,
  });

  List<AcademyCourseModel> get _filteredCourses {
    final query = searchController.text.trim().toLowerCase();

    return data.courses.where((course) {
      final searchable = [
        course.title,
        course.description,
        course.category,
        course.level,
        ...course.lessons.map((lesson) => lesson.title),
        ...course.lessons.map((lesson) => lesson.summary),
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || searchable.contains(query);
      final matchesLevel =
          levelFilter == 'all' || _academyKey(course.level) == levelFilter;
      final matchesCategory =
          categoryFilter == 'all' ||
          _academyKey(course.category) == categoryFilter;

      return matchesQuery && matchesLevel && matchesCategory;
    }).toList();
  }

  List<AcademyCaseStudyModel> get _filteredCaseStudies {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return data.caseStudies;

    return data.caseStudies.where((caseStudy) {
      final searchable = [
        caseStudy.projectName,
        caseStudy.title,
        caseStudy.context,
        caseStudy.problem,
        caseStudy.solution,
        caseStudy.impact,
        caseStudy.difficulties,
        ...caseStudy.lessons,
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressPanel(progress: data.progress),
        const SizedBox(height: 22),
        _AcademyFiltersCard(
          controller: searchController,
          levelFilter: levelFilter,
          categoryFilter: categoryFilter,
          onChanged: onFiltersChanged,
          onLevelChanged: onLevelChanged,
          onCategoryChanged: onCategoryChanged,
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Parcours recommandés',
          subtitle:
              'Des chemins courts pour intégrer, progresser et préparer les temps forts.',
        ),
        const SizedBox(height: 12),
        _PathGrid(paths: data.paths),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Catalogue de cours',
          subtitle:
              'Leçons courtes, quiz et points Academy connectables à la gamification.',
        ),
        const SizedBox(height: 12),
        _CourseGrid(
          courses: _filteredCourses,
          rewardingActionId: rewardingActionId,
          onCompleteNextLesson: onCompleteNextLesson,
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Études de cas Enactus ESP',
          subtitle:
              'Apprendre à partir des anciens projets, de leurs impacts et de leurs difficultés.',
        ),
        const SizedBox(height: 12),
        _CaseStudiesGrid(caseStudies: _filteredCaseStudies),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Quiz rapides',
          subtitle: 'Questions, bonnes réponses, explications et niveaux.',
        ),
        const SizedBox(height: 12),
        _QuizStrip(
          courses: data.courses,
          rewardingActionId: rewardingActionId,
          onPassQuiz: onPassQuiz,
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Badges Academy',
          subtitle:
              'Récompenser les apprentissages positifs sans exposer les difficultés.',
        ),
        const SizedBox(height: 12),
        _BadgeGrid(badges: data.badges),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final AcademyProgressModel progress;

  const _ProgressPanel({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ma progression Academy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Un suivi personnel et positif: leçons terminées, quiz réussis, points et badges.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('${progress.points} points')),
                    Chip(label: Text('Rang positif #${progress.rank}')),
                    Chip(
                      label: Text(
                        '${progress.monthlyProgress.toStringAsFixed(0)}% ce mois',
                      ),
                    ),
                  ],
                ),
              ],
            );
            final meters = Column(
              children: [
                _ProgressMeter(
                  label: 'Leçons',
                  value: progress.lessonsProgress,
                  detail:
                      '${progress.completedLessons}/${progress.totalLessons}',
                ),
                const SizedBox(height: 12),
                _ProgressMeter(
                  label: 'Quiz',
                  value: progress.quizProgress,
                  detail: '${progress.passedQuizzes}/${progress.totalQuizzes}',
                ),
              ],
            );

            if (wide) {
              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 22),
                  SizedBox(width: 280, child: meters),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summary, const SizedBox(height: 18), meters],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressMeter extends StatelessWidget {
  final String label;
  final double value;
  final String detail;

  const _ProgressMeter({
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(detail, style: const TextStyle(color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 9,
          borderRadius: BorderRadius.circular(99),
          color: AppTheme.enactusYellow,
          backgroundColor: Colors.black.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _AcademyFiltersCard extends StatelessWidget {
  final TextEditingController controller;
  final String levelFilter;
  final String categoryFilter;
  final VoidCallback onChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onCategoryChanged;

  const _AcademyFiltersCard({
    required this.controller,
    required this.levelFilter,
    required this.categoryFilter,
    required this.onChanged,
    required this.onLevelChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final search = TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: 'Rechercher cours, quiz, cas pratique',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Effacer',
                      ),
              ),
            );
            final filters = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AcademyChoiceChip(
                  label: 'Tous niveaux',
                  selected: levelFilter == 'all',
                  onSelected: () => onLevelChanged('all'),
                ),
                _AcademyChoiceChip(
                  label: 'Débutant',
                  selected: levelFilter == 'debutant',
                  onSelected: () => onLevelChanged('debutant'),
                ),
                _AcademyChoiceChip(
                  label: 'Intermédiaire',
                  selected: levelFilter == 'intermediaire',
                  onSelected: () => onLevelChanged('intermediaire'),
                ),
                _AcademyChoiceChip(
                  label: 'Avancé',
                  selected: levelFilter == 'avance',
                  onSelected: () => onLevelChanged('avance'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Catégorie',
                  onSelected: onCategoryChanged,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'all', child: Text('Toutes')),
                    PopupMenuItem(
                      value: 'culture_enactus',
                      child: Text('Culture Enactus'),
                    ),
                    PopupMenuItem(value: 'impact', child: Text('Impact')),
                    PopupMenuItem(
                      value: 'business_principles',
                      child: Text('Business Principles'),
                    ),
                    PopupMenuItem(
                      value: 'competition',
                      child: Text('Compétition'),
                    ),
                    PopupMenuItem(
                      value: 'leadership',
                      child: Text('Leadership'),
                    ),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(_academyCategoryLabel(categoryFilter)),
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 14),
                  Flexible(child: filters),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), filters],
            );
          },
        ),
      ),
    );
  }
}

class _AcademyChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _AcademyChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.enactusYellow.withAlpha(120),
      onSelected: (_) => onSelected(),
    );
  }
}

class _PathGrid extends StatelessWidget {
  final List<AcademyPathModel> paths;

  const _PathGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    return _ResponsiveWrap(
      minWidth: 280,
      children: [for (final path in paths) _PathCard(path: path)],
    );
  }
}

class _PathCard extends StatelessWidget {
  final AcademyPathModel path;

  const _PathCard({required this.path});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              path.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              path.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: (path.progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              color: AppTheme.enactusYellow,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
            Text(
              '${path.progress.toStringAsFixed(0)}% complété',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseGrid extends StatelessWidget {
  final List<AcademyCourseModel> courses;
  final String? rewardingActionId;
  final ValueChanged<AcademyCourseModel> onCompleteNextLesson;

  const _CourseGrid({
    required this.courses,
    required this.rewardingActionId,
    required this.onCompleteNextLesson,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const _AcademyEmptyCard(
        message: 'Aucun cours ne correspond aux filtres.',
      );
    }

    return _ResponsiveWrap(
      minWidth: 300,
      children: [
        for (final course in courses)
          _CourseCard(
            course: course,
            busy: rewardingActionId == 'lesson-${course.id}',
            onCompleteNextLesson: onCompleteNextLesson,
          ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final AcademyCourseModel course;
  final bool busy;
  final ValueChanged<AcademyCourseModel> onCompleteNextLesson;

  const _CourseCard({
    required this.course,
    required this.busy,
    required this.onCompleteNextLesson,
  });

  @override
  Widget build(BuildContext context) {
    final completed = course.lessons.where((lesson) => lesson.completed).length;
    final done = completed == course.lessonCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(course.level)),
                Chip(label: Text(course.category)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              course.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              course.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${course.lessonCount} leçons')),
                Chip(label: Text('${course.durationMinutes} min')),
                Chip(label: Text('+${course.points} pts')),
                Chip(label: Text('$completed/${course.lessonCount} fait')),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy || done
                    ? null
                    : () => onCompleteNextLesson(course),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        done ? Icons.check_rounded : Icons.play_arrow_rounded,
                      ),
                label: Text(done ? 'Cours terminé' : 'Terminer une leçon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizStrip extends StatelessWidget {
  final List<AcademyCourseModel> courses;
  final String? rewardingActionId;
  final ValueChanged<AcademyCourseModel> onPassQuiz;

  const _QuizStrip({
    required this.courses,
    required this.rewardingActionId,
    required this.onPassQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final course in courses)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.24),
                foregroundColor: AppTheme.softBlack,
                child: const Icon(Icons.quiz_rounded),
              ),
              title: Text(
                course.quiz.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${course.quiz.level} • ${course.quiz.questions.length} question(s) • ${course.quiz.timeLimitMinutes} min',
              ),
              trailing: rewardingActionId == 'quiz-${course.id}'
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: () => onPassQuiz(course),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      tooltip: 'Commencer le quiz',
                    ),
            ),
        ],
      ),
    );
  }
}

class _AcademyQuizDialog extends StatefulWidget {
  final AcademyCourseModel course;

  const _AcademyQuizDialog({required this.course});

  @override
  State<_AcademyQuizDialog> createState() => _AcademyQuizDialogState();
}

class _AcademyQuizDialogState extends State<_AcademyQuizDialog> {
  final Map<int, int> _answers = {};
  bool _submitted = false;

  int get _correctAnswers {
    var total = 0;
    final questions = widget.course.quiz.questions;
    for (var index = 0; index < questions.length; index++) {
      if (_answers[index] == questions[index].correctIndex) {
        total++;
      }
    }
    return total;
  }

  int get _score {
    final total = widget.course.quiz.questions.length;
    if (total == 0) return 0;
    return ((_correctAnswers / total) * 100).round();
  }

  bool get _passed => _score >= 60;

  void _submit() {
    if (_answers.length < widget.course.quiz.questions.length) return;
    setState(() => _submitted = true);
  }

  void _retry() {
    setState(() {
      _answers.clear();
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.course.quiz;
    final canSubmit = _answers.length == quiz.questions.length;

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.24),
            foregroundColor: AppTheme.softBlack,
            child: const Icon(Icons.quiz_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quiz.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${quiz.level} • ${quiz.questions.length} question(s) • ${quiz.timeLimitMinutes} min',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (_submitted) _QuizResultBanner(score: _score, passed: _passed),
              if (_submitted) const SizedBox(height: 14),
              for (var index = 0; index < quiz.questions.length; index++)
                _QuizQuestionBlock(
                  index: index,
                  question: quiz.questions[index],
                  selectedIndex: _answers[index],
                  submitted: _submitted,
                  onChanged: (value) {
                    if (_submitted || value == null) return;
                    setState(() => _answers[index] = value);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        if (_submitted && !_passed)
          TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reprendre'),
          ),
        if (_submitted)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_passed),
            icon: Icon(_passed ? Icons.check_rounded : Icons.close_rounded),
            label: Text(_passed ? 'Terminer' : 'Quitter'),
          )
        else
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Valider'),
          ),
      ],
    );
  }
}

class _QuizResultBanner extends StatelessWidget {
  final int score;
  final bool passed;

  const _QuizResultBanner({required this.score, required this.passed});

  @override
  Widget build(BuildContext context) {
    final color = passed ? Colors.green.shade700 : Colors.orange.shade800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.verified_rounded : Icons.school_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              passed
                  ? 'Score $score%. Quiz reussi, les points vont etre ajoutes.'
                  : 'Score $score%. Relis les corrections puis retente.',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestionBlock extends StatelessWidget {
  final int index;
  final AcademyQuestionModel question;
  final int? selectedIndex;
  final bool submitted;
  final ValueChanged<int?> onChanged;

  const _QuizQuestionBlock({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.submitted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCorrect = selectedIndex == question.correctIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.question}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (
            var choiceIndex = 0;
            choiceIndex < question.choices.length;
            choiceIndex++
          )
            _QuizChoiceTile(
              label: question.choices[choiceIndex],
              value: choiceIndex,
              groupValue: selectedIndex,
              submitted: submitted,
              correctIndex: question.correctIndex,
              onChanged: onChanged,
            ),
          if (submitted) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selectedCorrect
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color: selectedCorrect
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.explanation,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizChoiceTile extends StatelessWidget {
  final String label;
  final int value;
  final int? groupValue;
  final bool submitted;
  final int correctIndex;
  final ValueChanged<int?> onChanged;

  const _QuizChoiceTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.submitted,
    required this.correctIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    final correct = correctIndex == value;
    final color = submitted && correct
        ? Colors.green.shade700
        : submitted && selected
        ? Colors.orange.shade800
        : AppTheme.softBlack;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: submitted ? null : () => onChanged(value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected || (submitted && correct)
                ? color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected || (submitted && correct)
                  ? color.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                submitted && correct
                    ? Icons.check_circle_rounded
                    : selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: selected || (submitted && correct)
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseStudiesGrid extends StatelessWidget {
  final List<AcademyCaseStudyModel> caseStudies;

  const _CaseStudiesGrid({required this.caseStudies});

  @override
  Widget build(BuildContext context) {
    if (caseStudies.isEmpty) {
      return const _AcademyEmptyCard(
        message: 'Aucun cas pratique ne correspond à la recherche.',
      );
    }

    return _ResponsiveWrap(
      minWidth: 300,
      children: [
        for (final item in caseStudies) _CaseStudyCard(caseStudy: item),
      ],
    );
  }
}

class _CaseStudyCard extends StatelessWidget {
  final AcademyCaseStudyModel caseStudy;

  const _CaseStudyCard({required this.caseStudy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _showCaseStudy(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow,
                    foregroundColor: AppTheme.softBlack,
                    child: Text(
                      caseStudy.projectName.characters.first,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      caseStudy.projectName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                caseStudy.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                caseStudy.context,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${caseStudy.lessons.length} leçons')),
                  Chip(label: Text('${caseStudy.quiz.questions.length} quiz')),
                  const Chip(label: Text('Cas pratique')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCaseStudy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CaseStudyDetails(caseStudy: caseStudy),
    );
  }
}

class _CaseStudyDetails extends StatelessWidget {
  final AcademyCaseStudyModel caseStudy;

  const _CaseStudyDetails({required this.caseStudy});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    caseStudy.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caseStudy.context,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  _CaseDetailTile(
                    title: 'Problème',
                    body: caseStudy.problem,
                    icon: Icons.report_problem_rounded,
                  ),
                  _CaseDetailTile(
                    title: 'Solution',
                    body: caseStudy.solution,
                    icon: Icons.lightbulb_rounded,
                  ),
                  _CaseDetailTile(
                    title: 'Impact',
                    body: caseStudy.impact,
                    icon: Icons.insights_rounded,
                  ),
                  _CaseDetailTile(
                    title: 'Difficultés',
                    body: caseStudy.difficulties,
                    icon: Icons.terrain_rounded,
                  ),
                  _CaseChipBlock(
                    title: 'Leçons apprises',
                    items: caseStudy.lessons,
                  ),
                  _CaseChipBlock(
                    title: 'Questions de réflexion',
                    items: caseStudy.reflectionQuestions,
                  ),
                  _CaseChipBlock(
                    title: caseStudy.quiz.title,
                    items: [
                      for (final question in caseStudy.quiz.questions)
                        question.question,
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Compris'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CaseDetailTile extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _CaseDetailTile({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.22),
          foregroundColor: AppTheme.softBlack,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(body),
      ),
    );
  }
}

class _CaseChipBlock extends StatelessWidget {
  final String title;
  final List<String> items;

  const _CaseChipBlock({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in items) Chip(label: Text(item))],
          ),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<AcademyBadgeModel> badges;

  const _BadgeGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    return _ResponsiveWrap(
      minWidth: 220,
      children: [for (final badge in badges) _BadgeCard(badge: badge)],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final AcademyBadgeModel badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: badge.unlocked
                  ? AppTheme.enactusYellow
                  : Colors.black.withValues(alpha: 0.08),
              foregroundColor: AppTheme.softBlack,
              child: Icon(_badgeIcon(badge.iconName)),
            ),
            const SizedBox(height: 12),
            Text(
              badge.label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              badge.description,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 10),
            Chip(label: Text(badge.unlocked ? 'Débloqué' : 'À gagner')),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveWrap extends StatelessWidget {
  final double minWidth;
  final List<Widget> children;

  const _ResponsiveWrap({required this.minWidth, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / minWidth).floor().clamp(1, 4);
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _AcademyEmptyCard extends StatelessWidget {
  final String message;

  const _AcademyEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message, style: const TextStyle(color: Colors.black54)),
        ),
      ),
    );
  }
}

class _AcademyErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AcademyErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Academy indisponible',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _badgeIcon(String name) {
  switch (name) {
    case 'explore':
      return Icons.explore_rounded;
    case 'public':
      return Icons.public_rounded;
    case 'insights':
      return Icons.insights_rounded;
    case 'record_voice_over':
      return Icons.record_voice_over_rounded;
    default:
      return Icons.workspace_premium_rounded;
  }
}

String _academyCategoryLabel(String value) {
  switch (value) {
    case 'culture_enactus':
      return 'Culture Enactus';
    case 'impact':
      return 'Impact';
    case 'business_principles':
      return 'Business Principles';
    case 'competition':
      return 'Compétition';
    case 'leadership':
      return 'Leadership';
    default:
      return 'Toutes catégories';
  }
}

String _academyKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('Ã©', 'e')
      .replaceAll('Ã¨', 'e')
      .replaceAll('Ãª', 'e')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('Ã ', 'a')
      .replaceAll('Ã¢', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('Ã®', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('Ã´', 'o')
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
}
