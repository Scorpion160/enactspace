import 'package:flutter/material.dart';

/// Decorative local illustrations; learning content remains native text.
class AcademyArtwork extends StatelessWidget {
  final String name;
  final double height;
  const AcademyArtwork({super.key, required this.name, this.height = 120});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(height: height, child: LayoutBuilder(
      builder: (context, constraints) {
        final variant = constraints.maxWidth >= 400 ? 'web' : 'mobile';
        return Image.asset('assets/img/academy_${variant}_$name.webp',
          fit: BoxFit.contain, width: double.infinity,
          errorBuilder: (context, error, stack) => Center(
            child: Icon(Icons.auto_stories_rounded, size: 48,
              color: Theme.of(context).colorScheme.primary),
          ),
        );
      },
    )),
  );
}

String academyCourseArtwork(String title, String category) {
  final key = '$title $category'.toLowerCase();
  if (key.contains('design') || key.contains('créativ') || key.contains('idéation')) {
    return 'course_design_thinking';
  }
  if (key.contains('immersion') || key.contains('écout') || key.contains('terrain')) {
    return 'course_immersion';
  }
  return 'course_enactus';
}
