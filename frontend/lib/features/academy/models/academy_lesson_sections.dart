/// Presentation-only parsing. No lesson paragraphs are omitted or summarized.
class AcademyLessonSection {
  final String? heading;
  final List<String> paragraphs;
  const AcademyLessonSection({this.heading, required this.paragraphs});
  String get body => paragraphs.join('\n\n');

  static List<AcademyLessonSection> parse(String content) {
    final sections = <AcademyLessonSection>[];
    String? heading;
    var body = <String>[];
    void flush() {
      if (heading != null || body.isNotEmpty) {
        sections.add(
          AcademyLessonSection(
            heading: heading,
            paragraphs: List.unmodifiable(body),
          ),
        );
      }
      body = [];
    }

    const known = {
      'objectif',
      'l’objectif',
      "l'objectif",
      'comprendre',
      'approfondir',
      'sur le terrain',
      'à toi de jouer',
      'avant de continuer',
      'pour aller plus loin',
      'en pratique',
      'à retenir',
    };
    for (final paragraph
        in content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
      if (paragraph.trim().isEmpty) continue;
      final lines = paragraph.trim().split('\n');
      final markdown = RegExp(
        r'^#{1,6}\s+(.+)$',
      ).firstMatch(lines.first.trim());
      final title =
          markdown?.group(1) ??
          (known.contains(lines.first.trim().toLowerCase())
              ? lines.first.trim()
              : null);
      if (title != null) {
        flush();
        heading = title;
        if (lines.length > 1) body.add(lines.skip(1).join('\n'));
      } else {
        body.add(paragraph.trim());
      }
    }
    flush();
    return sections;
  }
}
