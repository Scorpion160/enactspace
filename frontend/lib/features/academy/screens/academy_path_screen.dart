import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/academy_models.dart';
import '../services/academy_gateway.dart';
import '../widgets/academy_style.dart';
import '../widgets/academy_artwork.dart';

class AcademyPathScreen extends StatefulWidget {
  final String pathId;
  final AcademyGateway? gateway;
  const AcademyPathScreen({super.key, required this.pathId, this.gateway});
  @override
  State<AcademyPathScreen> createState() => _AcademyPathScreenState();
}

class _AcademyPathScreenState extends State<AcademyPathScreen> {
  late final AcademyGateway _gateway = widget.gateway ?? ApiAcademyGateway();
  AcademyHomeData? _data;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _gateway.loadHome();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_data == null) return const Center(child: CircularProgressIndicator());
    final paths = _data!.paths.where((p) => p.id == widget.pathId);
    if (paths.isEmpty) {
      return const Center(
        child: Text('Ce parcours n’est pas disponible actuellement.'),
      );
    }
    final path = paths.first;
    final courses = [
      for (final id in path.courseIds)
        ..._data!.courses.where((c) => c.id == id),
    ];
    return AcademyStyle(
      child: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'TON PARCOURS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  path.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  path.description,
                                  style: const TextStyle(height: 1.6),
                                ),
                                const SizedBox(height: 18),
                                AcademyProgressBar(
                                  value: path.progress / 100,
                                  label:
                                      '${path.courseIds.length} ${path.courseIds.length == 1 ? 'formation' : 'formations'} · ${path.progress.toStringAsFixed(0)} % complété',
                                ),
                              ],
                            );
                            if (constraints.maxWidth >= 650 &&
                                MediaQuery.textScalerOf(context).scale(1) <=
                                    1.3) {
                              return Row(
                                children: [
                                  Expanded(child: details),
                                  const SizedBox(width: 22),
                                  const SizedBox(
                                    width: 240,
                                    child: AcademyArtwork(
                                      name: 'recommended_path',
                                      height: 170,
                                      panoramic: false,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                details,
                                const SizedBox(height: 12),
                                const AcademyArtwork(
                                  name: 'recommended_path',
                                  height: 115,
                                  panoramic: false,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Une étape après l’autre',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Termine les leçons et réussis le quiz pour débloquer la suite. Tu peux relire tes formations à tout moment.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      if (courses.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Les formations de ce parcours ne sont pas encore disponibles.',
                            ),
                          ),
                        ),
                      for (var index = 0; index < courses.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PathStep(
                            index: index,
                            course: courses[index],
                            gateway: _gateway,
                          ),
                        ),
                      if (courses.length < path.courseIds.length)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'D’autres formations de ce parcours seront accessibles après leur publication.',
                          ),
                        ),
                    ],
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

class _PathStep extends StatelessWidget {
  final int index;
  final AcademyCourseModel course;
  final AcademyGateway gateway;
  const _PathStep({
    required this.index,
    required this.course,
    required this.gateway,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final action = FilledButton.tonalIcon(
      onPressed: () => context.go(
        '/academy/courses/${course.id}${course.isLocked || course.isMastered ? '' : '?resume=true'}',
        extra: gateway,
      ),
      icon: Icon(
        course.isLocked
            ? Icons.lock_outline
            : course.isMastered
            ? Icons.menu_book_rounded
            : Icons.play_arrow,
      ),
      label: Text(
        course.isLocked
            ? 'Voir les prérequis'
            : course.isMastered
            ? 'Relire la formation'
            : 'Continuer cette formation',
        textAlign: TextAlign.center,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${index + 1}. ${course.title}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AcademyPill(
              course.isLocked
                  ? 'À débloquer'
                  : course.isMastered
                  ? 'Terminé'
                  : course.lessons.any((l) => l.started)
                  ? 'En cours'
                  : 'À commencer',
              warm: course.isLocked,
            ),
            AcademyPill(course.levelLabel),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          course.description,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
        ),
        if (course.isLocked && course.lockReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(course.lockReason, style: const TextStyle(height: 1.5)),
        ],
        const SizedBox(height: 14),
        AcademyProgressBar(
          value: course.progress,
          label:
              '${course.completedLessonCount}/${course.lessonCount} leçons terminées${course.quizPassed ? ' · Quiz réussi' : ''}',
        ),
        const SizedBox(height: 14),
        action,
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 720 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
              return Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: AcademyArtwork(
                      name: academyCourseArtwork(course.title, course.category),
                      height: 145,
                      panoramic: false,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: details),
                ],
              );
            }
            return details;
          },
        ),
      ),
    );
  }
}
