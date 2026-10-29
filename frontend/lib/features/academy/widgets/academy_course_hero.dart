import 'package:flutter/material.dart';
import '../models/academy_models.dart';
import 'academy_artwork.dart';
import 'academy_style.dart';

class AcademyCourseHero extends StatelessWidget {
  final AcademyCourseModel course;
  final String actionLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onManage;
  const AcademyCourseHero({
    super.key,
    required this.course,
    required this.actionLabel,
    this.onContinue,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.secondaryContainer, colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final sideArt = constraints.maxWidth >= 530 && scale <= 1.4;
          if (constraints.maxWidth < 530 && scale <= 1.3) {
            final compactTitle = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${course.lessonCount} leçons · ${course.durationMinutes} min · ${course.points} points',
                  style: const TextStyle(height: 1.5),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AcademyPill(course.levelLabel),
                    AcademyPill(course.categoryLabel, warm: true),
                    if (course.isRequired)
                      const AcademyPill('Obligatoire', warm: true),
                  ],
                ),
                const SizedBox(height: 16),
                if (constraints.maxWidth >= 280)
                  Row(
                    children: [
                      Expanded(child: compactTitle),
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 100,
                        child: AcademyArtwork(
                          name: 'hero_learning',
                          height: 150,
                          panoramic: false,
                        ),
                      ),
                    ],
                  )
                else
                  compactTitle,
                const SizedBox(height: 16),
                AcademyProgressBar(
                  value: course.progress,
                  label:
                      '${course.completedLessonCount}/${course.lessonCount} leçons terminées · ${(course.progress * 100).round()} %',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('academy-course-continue'),
                  onPressed: onContinue,
                  icon: Icon(
                    course.isLocked
                        ? Icons.lock_outline_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(actionLabel, textAlign: TextAlign.center),
                ),
                if (onManage != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Gestion Academy'),
                  ),
                ],
              ],
            );
          }
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AcademyPill(course.levelLabel),
                  AcademyPill(course.categoryLabel, warm: true),
                  if (course.isRequired)
                    const AcademyPill('Obligatoire', warm: true),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                course.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: constraints.maxWidth >= 800 ? 32 : 25,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                course.description,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                '${course.lessonCount} leçons · ${course.durationMinutes} min · ${course.points} points',
              ),
              const SizedBox(height: 14),
              AcademyProgressBar(
                value: course.progress,
                label:
                    '${course.completedLessonCount}/${course.lessonCount} leçons terminées · ${(course.progress * 100).round()} %',
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sideArt)
                Row(
                  children: [
                    Expanded(flex: 3, child: copy),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: AcademyArtwork(
                        name: academyCourseArtwork(
                          course.title,
                          course.category,
                        ),
                        height: 190,
                        panoramic: false,
                      ),
                    ),
                  ],
                )
              else ...[
                copy,
                const SizedBox(height: 12),
                AcademyArtwork(
                  name: academyCourseArtwork(course.title, course.category),
                  height: 115,
                  panoramic: false,
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const Key('academy-course-continue'),
                    onPressed: onContinue,
                    icon: Icon(
                      course.isLocked
                          ? Icons.lock_outline_rounded
                          : course.isMastered
                          ? Icons.menu_book_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(actionLabel, textAlign: TextAlign.center),
                  ),
                  if (onManage != null)
                    OutlinedButton.icon(
                      onPressed: onManage,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Gestion Academy'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
