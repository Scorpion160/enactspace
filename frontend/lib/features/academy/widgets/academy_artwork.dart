import 'package:flutter/material.dart';

/// Decorative local illustrations; learning content remains native text.
class AcademyArtwork extends StatelessWidget {
  final String name;
  final double height;
  final bool panoramic;
  final BoxFit? fit;
  final Alignment alignment;
  const AcademyArtwork({
    super.key,
    required this.name,
    this.height = 120,
    this.panoramic = true,
    this.fit,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = MediaQuery.sizeOf(context).width >= 900;
          final variant = desktop ? 'web' : 'mobile';
          final banner =
              panoramic &&
              desktop &&
              (name.startsWith('course_') || name == 'recommended_path');
          final theme = Theme.of(context).brightness == Brightness.dark
              ? 'dark'
              : 'light';
          final path = banner
              ? 'assets/img/academy_banner_${theme}_$name.webp'
              : 'assets/img/academy_${variant}_$name.webp';
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              path,
              fit: fit ?? (banner ? BoxFit.cover : BoxFit.contain),
              alignment: alignment,
              width: double.infinity,
              errorBuilder: (context, error, stack) => Center(
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

String academyCourseArtwork(String title, String category) {
  final key = '$title $category'.toLowerCase();
  if (key.contains('design') ||
      key.contains('créativ') ||
      key.contains('idéation')) {
    return 'course_design_thinking';
  }
  if (key.contains('immersion') ||
      key.contains('écout') ||
      key.contains('terrain')) {
    return 'course_immersion';
  }
  return 'course_enactus';
}
