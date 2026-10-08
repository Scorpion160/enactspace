import 'package:flutter/material.dart';

/// Short reading sections with a visual rhythm and accessible text scaling.
class ReadingBlocks extends StatelessWidget {
  final String text;
  const ReadingBlocks(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty);
    const headings = [
      'Objectif',
      'Comprendre',
      'Sur le terrain',
      'À toi de jouer',
      'Avant de continuer',
      'Pour aller plus loin',
    ];
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final paragraph in paragraphs)
            Builder(
              builder: (context) {
                final lines = paragraph.trim().split('\n');
                final heading = lines.first.startsWith('### ')
                    ? lines.first.substring(4)
                    : headings.contains(lines.first)
                    ? lines.first
                    : null;
                final body = heading == null
                    ? paragraph.trim()
                    : lines.skip(1).join('\n');
                final active =
                    heading == 'À toi de jouer' || heading == 'Sur le terrain';
                final colors = Theme.of(context).colorScheme;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(heading == null ? 4 : 20),
                  decoration: heading == null
                      ? null
                      : BoxDecoration(
                          color: active
                              ? colors.secondaryContainer
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (heading != null) ...[
                        Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              heading == 'À toi de jouer'
                                  ? Icons.edit_note_rounded
                                  : heading == 'Sur le terrain'
                                  ? Icons.explore_rounded
                                  : Icons.auto_stories_rounded,
                              color: active
                                  ? colors.onSecondaryContainer
                                  : colors.primary,
                            ),
                            Text(
                              heading,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        body,
                        textAlign:
                            MediaQuery.sizeOf(context).width >= 600 &&
                                MediaQuery.textScalerOf(context).scale(1) <= 1.3
                            ? TextAlign.justify
                            : TextAlign.start,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.7,
                          color: active
                              ? colors.onSecondaryContainer
                              : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
