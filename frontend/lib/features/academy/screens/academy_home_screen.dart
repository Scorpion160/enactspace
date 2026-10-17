// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/academy_models.dart';
import '../services/academy_gateway.dart';
import '../widgets/academy_quiz_dialog.dart';
import '../widgets/academy_artwork.dart';

class AcademyHomeScreen extends StatefulWidget {
  final AcademyGateway? gateway;
  const AcademyHomeScreen({super.key, this.gateway});

  @override
  State<AcademyHomeScreen> createState() => _AcademyHomeScreenState();
}

class _AcademyHomeScreenState extends State<AcademyHomeScreen> {
  late final AcademyGateway _gateway;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _rewardingActionId;
  String? _error;
  AcademyHomeData? _data;
  String _courseFilter = 'all';
  String _levelFilter = 'all';
  String _categoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiAcademyGateway();
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
      final data = await _gateway.loadHome();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _completeNextLesson(AcademyCourseModel course) {
    context.go(
      '/academy/courses/${course.id}${course.isLocked || course.isMastered ? '' : '?resume=true'}',
      extra: _gateway,
    );
  }

  void _continueLearning() {
    final courses = _data?.courses ?? [];
    final inProgress = courses.where(
      (c) => !c.isLocked && c.lessons.any((l) => l.started && !l.completed),
    );
    final paths =
        _data?.paths.where((p) => p.id == 'new-enacteur').toList() ?? [];
    final ordered = paths.isEmpty
        ? courses
        : [
            for (final id in paths.first.courseIds)
              ...courses.where((c) => c.id == id),
            ...courses.where((c) => !paths.first.courseIds.contains(c.id)),
          ];
    final remaining = ordered.where((c) => !c.isLocked && !c.isMastered);
    final course = inProgress.isNotEmpty
        ? inProgress.first
        : remaining.isNotEmpty
        ? remaining.first
        : null;
    if (course != null) _completeNextLesson(course);
  }

  Future<void> _openQuiz(AcademyCourseModel course) async {
    if (_rewardingActionId != null || !course.canTakeQuiz) return;
    setState(() => _rewardingActionId = 'quiz-${course.id}');
    try {
      final quiz = await _gateway.getQuiz(course.quiz.id);
      if (!mounted) return;
      await showDialog<AcademyQuizResult>(
        context: context,
        builder: (_) => AcademyQuizDialog(
          quiz: quiz,
          submit: (answers) => _gateway.submitQuiz(quiz.id, answers),
        ),
      );
      if (mounted) await _loadAcademy();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
    } finally {
      if (mounted) setState(() => _rewardingActionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadAcademy,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final hero = _AcademyHeader(
            onContinue:
                _loading ||
                    _data == null ||
                    !_data!.courses.any((c) => !c.isLocked && !c.isMastered)
                ? null
                : _continueLearning,
          );
            if (_data == null || _loading || _error != null) return hero;
            final progress = _ProgressPanel(progress: _data!.progress);
            if (constraints.maxWidth >= 1100 &&
                MediaQuery.textScalerOf(context).scale(16) <= 24) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: hero),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: progress),
              ]);
            }
            return Column(children: [hero, const SizedBox(height: 16), progress]);
          }),
          const SizedBox(height: 18),
          if (_data?.offline == true && !_loading && _error == null) ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.offline_bolt_outlined),
                title: Text('Cours disponibles hors connexion'),
                subtitle: Text(
                  'Tu peux lire les contenus conservés et poursuivre les leçons. Tes réponses et ta progression seront synchronisées au retour de la connexion.',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if ((_data?.pendingActions ?? 0) > 0 && !_loading)
            Card(
              child: ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Tes progrès sont conservés'),
                subtitle: Text(
                  'Ils seront envoyés dès que la connexion sera rétablie.',
                ),
                trailing: IconButton(
                  tooltip: 'Réessayer',
                  onPressed: _loadAcademy,
                  icon: const Icon(Icons.sync),
                ),
              ),
            ),
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
              courseFilter: _courseFilter,
              levelFilter: _levelFilter,
              categoryFilter: _categoryFilter,
              onFiltersChanged: () => setState(() {}),
              onCourseFilterChanged: (value) {
                setState(() => _courseFilter = value);
              },
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
  final VoidCallback? onContinue;
  const _AcademyHeader({this.onContinue});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF102B36), Color(0xFF061B28)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF31515D)),
    ),
    child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 650 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ENACTSPACE ACADEMY', style: TextStyle(
          color: Color(0xFFFFD34D), fontWeight: FontWeight.w800, letterSpacing: 1.6,
        )),
        const SizedBox(height: 12),
        Text('Apprendre pour agir.', style: TextStyle(
          color: Colors.white, fontSize: wide ? 36 : 28,
          fontWeight: FontWeight.w900, height: 1.15,
        )),
        const SizedBox(height: 12),
        const Text('Avance à ton rythme, fais grandir ton impact.',
          style: TextStyle(color: Color(0xFFD2E2E8), height: 1.5, fontSize: 16)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD34D),
            foregroundColor: const Color(0xFF151D24),
            disabledBackgroundColor: const Color(0xFF344A54),
            disabledForegroundColor: const Color(0xFFCBDAE0),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
          onPressed: onContinue,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Continuer'),
        ),
      ]);
      if (wide) {
        return Row(children: [
          Expanded(flex: 3, child: copy),
          const SizedBox(width: 16),
          const Expanded(flex: 2, child: AcademyArtwork(
            name: 'hero_learning', height: 210)),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const AcademyArtwork(name: 'hero_learning', height: 130),
        const SizedBox(height: 8), copy,
      ]);
    }),
  );
}

class _AcademyContent extends StatelessWidget {
  final AcademyHomeData data;
  final TextEditingController searchController;
  final String courseFilter;
  final String levelFilter;
  final String categoryFilter;
  final VoidCallback onFiltersChanged;
  final ValueChanged<String> onCourseFilterChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onCategoryChanged;
  final String? rewardingActionId;
  final ValueChanged<AcademyCourseModel> onCompleteNextLesson;
  final ValueChanged<AcademyCourseModel> onPassQuiz;

  const _AcademyContent({
    required this.data,
    required this.searchController,
    required this.courseFilter,
    required this.levelFilter,
    required this.categoryFilter,
    required this.onFiltersChanged,
    required this.onCourseFilterChanged,
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
      final matchesCourseFilter = switch (courseFilter) {
        'required' => course.isRequired,
        'in_progress' => course.isInProgress,
        'completed' => course.isMastered,
        _ => true,
      };

      return matchesQuery &&
          matchesLevel &&
          matchesCategory &&
          matchesCourseFilter;
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

        _AcademyFiltersCard(
          controller: searchController,
          courseFilter: courseFilter,
          levelFilter: levelFilter,
          categoryFilter: categoryFilter,
          onChanged: onFiltersChanged,
          onCourseFilterChanged: onCourseFilterChanged,
          onLevelChanged: onLevelChanged,
          onCategoryChanged: onCategoryChanged,
          categories: data.courses.map((c) => c.category).toSet().toList()
            ..sort(),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Ton parcours recommandé',
          subtitle:
              'Des chemins courts pour intégrer, progresser et préparer les temps forts.',
        ),
        const SizedBox(height: 12),
        _PathGrid(paths: data.paths),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Explore les formations',
          subtitle:
              'Des leçons expliquées, des exemples et des exercices pour apprendre en agissant.',
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
        if (data.caseStudies.isNotEmpty)
          _CaseStudiesGrid(caseStudies: _filteredCaseStudies)
        else
          _CourseGrid(
            courses: _filteredCourses
                .where(
                  (c) =>
                      c.title.startsWith('Étude') ||
                      c.title.startsWith('Histoire'),
                )
                .toList(),
            rewardingActionId: rewardingActionId,
            onCompleteNextLesson: onCompleteNextLesson,
          ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Quiz rapides',
          subtitle: 'Questions, bonnes réponses, explications et niveaux.',
        ),
        const SizedBox(height: 12),
        _QuizStrip(
          courses: data.courses.where((c) => c.quiz.id.isNotEmpty).toList(),
          rewardingActionId: rewardingActionId,
          onPassQuiz: onPassQuiz,
        ),
        const SizedBox(height: 22),
        if (data.badges.isNotEmpty)
          const _SectionTitle(
            title: 'Badges Academy',
            subtitle:
                'Récompenser les apprentissages positifs sans exposer les difficultés.',
          ),
        const SizedBox(height: 12),
        if (data.badges.isNotEmpty) _BadgeGrid(badges: data.badges),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final AcademyProgressModel progress;
  const _ProgressPanel({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = progress.totalLessons == 0 ? 0.0 :
        (progress.completedLessons / progress.totalLessons).clamp(0.0, 1.0);
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ma progression', style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final columns = MediaQuery.textScalerOf(context).scale(16) > 24 ||
              constraints.maxWidth < 260 ? 1 : 3;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final stat in [
              ('${progress.completedLessons}/${progress.totalLessons}', 'Leçons', Icons.menu_book_rounded),
              ('${progress.passedQuizzes}/${progress.totalQuizzes}', 'Quiz réussis', Icons.task_alt_rounded),
              ('${progress.points}', 'Points', Icons.star_outline_rounded),
            ]) SizedBox(width: width, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: BoxDecoration(color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14)),
              child: Column(children: [Icon(stat.$3, color: colors.primary),
                const SizedBox(height: 8),
                Text(stat.$1, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4), Text(stat.$2, textAlign: TextAlign.center),
              ]),
            )),
          ]);
        }),
        const SizedBox(height: 18),
        LinearProgressIndicator(value: ratio, minHeight: 9,
          color: AppTheme.enactusYellow,
          backgroundColor: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99)),
        const SizedBox(height: 10),
        Text('${(ratio * 100).round()} % des leçons terminées · Chaque étape compte.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
      ],
    )));
  }
}

class _AcademyFiltersCard extends StatelessWidget {
  final List<String> categories;
  final TextEditingController controller;
  final String courseFilter;
  final String levelFilter;
  final String categoryFilter;
  final VoidCallback onChanged;
  final ValueChanged<String> onCourseFilterChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onCategoryChanged;

  const _AcademyFiltersCard({
    this.categories = const [],
    required this.controller,
    required this.courseFilter,
    required this.levelFilter,
    required this.categoryFilter,
    required this.onChanged,
    required this.onCourseFilterChanged,
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
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                        icon: Icon(Icons.close_rounded),
                        tooltip: 'Effacer',
                      ),
              ),
            );
            final filters = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AcademyChoiceChip(
                  label: 'Tous',
                  selected: courseFilter == 'all',
                  onSelected: () => onCourseFilterChanged('all'),
                ),
                _AcademyChoiceChip(
                  label: 'Obligatoires',
                  selected: courseFilter == 'required',
                  onSelected: () => onCourseFilterChanged('required'),
                ),
                _AcademyChoiceChip(
                  label: 'En cours',
                  selected: courseFilter == 'in_progress',
                  onSelected: () => onCourseFilterChanged('in_progress'),
                ),
                _AcademyChoiceChip(
                  label: 'Terminés',
                  selected: courseFilter == 'completed',
                  onSelected: () => onCourseFilterChanged('completed'),
                ),
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
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Text('Toutes les catégories'),
                    ),
                    for (final category in categories)
                      PopupMenuItem(
                        value: _academyKey(category),
                        child: Text(category),
                      ),
                  ],
                  child: Chip(
                    avatar: Icon(Icons.tune_rounded, size: 16),
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
            const AcademyArtwork(name: 'recommended_path', height: 100),
            const SizedBox(height: 12),
            Text(
              path.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              path.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: (path.progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              color: AppTheme.enactusYellow,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
            Text(
              '${path.progress.toStringAsFixed(0)}% complété · ${path.courseIds.length} formations',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: path.courseIds.isEmpty
                  ? null
                  : () => context.go('/academy/paths/${path.id}'),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Explorer le parcours'),
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
            AcademyArtwork(name: academyCourseArtwork(course.title, course.category), height: 125),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(course.levelLabel)),
                Chip(label: Text(course.category)),
                if (course.isRequired) Chip(label: Text('Obligatoire')),
                if (course.isLocked)
                  const Chip(
                    avatar: Icon(Icons.lock_outline, size: 18),
                    label: Text('À débloquer'),
                  ),
                if (course.isMastered)
                  const Chip(label: Text('Formation réussie')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              course.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              course.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: course.progress.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              color: AppTheme.enactusYellow,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
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
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/academy/courses/${course.id}'),
                icon: Icon(Icons.open_in_new_rounded),
                label: Text(
                  course.isLocked
                      ? 'Voir les prérequis'
                      : 'Ouvrir la formation',
                ),
              ),
            ),
            if (course.isLocked) ...[
              const SizedBox(height: 10),
              Text(course.lockReason, style: const TextStyle(height: 1.5)),
            ] else ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onCompleteNextLesson(course),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          done ? Icons.check_rounded : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    course.isMastered
                        ? 'Relire les leçons'
                        : done
                        ? 'Passer le quiz'
                        : 'Poursuivre les leçons',
                  ),
                ),
              ),
            ],
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
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                child: Icon(Icons.quiz_rounded),
              ),
              title: Text(
                course.quiz.title,
                style: TextStyle(fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${course.levelLabel} • ${course.quiz.timeLimitMinutes} min${course.quizPassed ? ' • Réussi' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                      onPressed: course.canTakeQuiz
                          ? () => onPassQuiz(course)
                          : null,
                      icon: Icon(Icons.play_circle_fill_rounded),
                      tooltip: course.isLocked
                          ? 'Terminer les formations prérequises'
                          : !course.isCompleted
                          ? 'Terminer les leçons avant le quiz'
                          : 'Commencer le quiz',
                    ),
            ),
        ],
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
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      caseStudy.projectName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                caseStudy.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                caseStudy.context,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${caseStudy.lessons.length} leçons')),
                  Chip(label: Text('${caseStudy.quiz.questions.length} quiz')),
                  Chip(label: Text('Cas pratique')),
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
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    caseStudy.title,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caseStudy.context,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
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
                      icon: Icon(Icons.check_rounded),
                      label: Text('Compris'),
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
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
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
          Text(title, style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Chip(
                    label: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
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
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
              foregroundColor: badge.unlocked
                  ? AppTheme.softBlack
                  : Theme.of(context).colorScheme.onSurface,
              child: Icon(_badgeIcon(badge.iconName)),
            ),
            const SizedBox(height: 12),
            Text(
              badge.label,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              badge.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
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
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final count = (constraints.maxWidth / (minWidth * scale.clamp(1.0, 2.0)))
            .floor().clamp(1, 3);
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
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
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
            Text(
              'Academy indisponible',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Réessayer'),
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
    case 'all':
      return 'Toutes catégories';
    default:
      return value;
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

