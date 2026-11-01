import 'package:flutter/material.dart';

enum RecruitmentSection {
  applications('Candidatures', Icons.inbox_outlined),
  campaigns('Campagnes', Icons.campaign_outlined),
  jury('Jury', Icons.groups_outlined),
  interviews('Entretiens', Icons.event_available_outlined);

  const RecruitmentSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class RecruitmentWorkspaceNav extends StatelessWidget {
  final RecruitmentSection selected;
  final ValueChanged<RecruitmentSection> onSelected;
  final bool canManageCampaigns;
  final bool hasJury;
  const RecruitmentWorkspaceNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.canManageCampaigns = true,
    this.hasJury = true,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final section in RecruitmentSection.values)
              if ((section != RecruitmentSection.campaigns ||
                      canManageCampaigns) &&
                  (section != RecruitmentSection.jury || hasJury))
                Semantics(
                  selected: selected == section,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected == section
                              ? colors.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: TextButton.icon(
                      key: ValueKey('recruitment-nav-${section.name}'),
                      onPressed: selected == section
                          ? null
                          : () => onSelected(section),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        disabledForegroundColor: colors.primary,
                        minimumSize: const Size(44, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      icon: Icon(section.icon, size: 19),
                      label: Text(section.label),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class RecruitmentPageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const RecruitmentPageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
      final buttons = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
      if (constraints.maxWidth < 740 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (actions.isNotEmpty) ...[const SizedBox(height: 14), buttons],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 20),
            Flexible(
              child: Align(alignment: Alignment.topRight, child: buttons),
            ),
          ],
        ],
      );
    },
  );
}

class RecruitmentStats extends StatelessWidget {
  final List<({String label, int count, IconData icon})> values;
  const RecruitmentStats({super.key, required this.values});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
      final columns = constraints.maxWidth >= 900 && !largeText
          ? values.length
          : constraints.maxWidth >= 300 && !largeText
          ? 2
          : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      final colors = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: width < 200
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${value.count}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              value.label,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(value.icon, color: colors.primary, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${value.count}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    value.label,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// No scrolling text: expand a long description on demand, at any text scale.
class RecruitmentDescription extends StatefulWidget {
  final String text;
  final int collapsedLines;
  const RecruitmentDescription(this.text, {super.key, this.collapsedLines = 3});
  @override
  State<RecruitmentDescription> createState() => _RecruitmentDescriptionState();
}

class _RecruitmentDescriptionState extends State<RecruitmentDescription> {
  bool _expanded = false;
  @override
  void didUpdateWidget(RecruitmentDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(
          text: widget.text,
          style: DefaultTextStyle.of(context).style,
        ),
        maxLines: widget.collapsedLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_expanded)
            SelectableText(widget.text)
          else
            Text(
              widget.text,
              maxLines: widget.collapsedLines,
              overflow: TextOverflow.ellipsis,
            ),
          if (long)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                alignment: Alignment.centerLeft,
              ),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 19,
              ),
              label: Text(_expanded ? 'Réduire' : 'Lire la suite'),
            ),
        ],
      );
    },
  );
}

class RecruitmentNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  const RecruitmentNotice(
    this.message, {
    super.key,
    this.icon = Icons.info_outline,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
