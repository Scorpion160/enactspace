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

  bool _loading = true;
  String? _rewardingActionId;
  String? _error;
  AcademyHomeData? _data;

  @override
  void initState() {
    super.initState();
    _loadAcademy();
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
              rewardingActionId: _rewardingActionId,
              onCompleteNextLesson: _completeNextLesson,
              onPassQuiz: _passQuiz,
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
  final String? rewardingActionId;
  final ValueChanged<AcademyCourseModel> onCompleteNextLesson;
  final ValueChanged<AcademyCourseModel> onPassQuiz;

  const _AcademyContent({
    required this.data,
    required this.rewardingActionId,
    required this.onCompleteNextLesson,
    required this.onPassQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProgressPanel(progress: data.progress),
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
          courses: data.courses,
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
                      icon: const Icon(Icons.check_circle_rounded),
                      tooltip: 'Valider le quiz',
                    ),
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
