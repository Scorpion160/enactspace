import 'package:flutter/material.dart';

/// A compact catalogue toolbar. Search stays visible when advanced filters close.
/// Only the presentation changes: each screen owns its controllers and queries.
class AppFilterToolbar extends StatefulWidget {
  final Widget? search;
  final List<Widget> quickFilters;
  final List<Widget> filters;
  final List<Widget> actions;
  final int activeFilterCount;
  final VoidCallback? onReset;
  final Widget? details;
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final double filterWidth;
  final bool collapsible;
  final double? quickFiltersWidth;

  const AppFilterToolbar({
    super.key,
    this.search,
    this.quickFilters = const [],
    this.filters = const [],
    this.actions = const [],
    this.activeFilterCount = 0,
    this.onReset,
    this.details,
    this.expanded,
    this.onExpandedChanged,
    this.filterWidth = 180,
    this.collapsible = true,
    this.quickFiltersWidth,
  });

  @override
  State<AppFilterToolbar> createState() => _AppFilterToolbarState();
}

class _AppFilterToolbarState extends State<AppFilterToolbar> {
  bool _expanded = false;

  bool get expanded => widget.expanded ?? _expanded;

  void _toggle() {
    final next = !expanded;
    setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyLarge: theme.textTheme.bodyMedium,
          titleMedium: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          constraints: const BoxConstraints(minHeight: 48),
        ),
        chipTheme: theme.chipTheme.copyWith(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          labelStyle: textStyle?.copyWith(color: colors.onSurface),
          secondaryLabelStyle: textStyle?.copyWith(
            color: const Color(0xFF101820),
          ),
          selectedColor: const Color(0xFFFFC629),
          backgroundColor: colors.surfaceContainerLow,
          side: BorderSide(color: colors.outlineVariant),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final fieldWidth = widget.filterWidth * scale.clamp(1.0, 1.5);
          // Reserve room for the search instead of squeezing chips into two lines.
          final inlineWidth =
              (widget.search == null ? 0 : 260) +
              (widget.quickFiltersWidth ?? widget.quickFilters.length * 112) *
                  scale +
              widget.filters.length * (fieldWidth + 8) +
              widget.actions.length * 160 * scale +
              (widget.onReset == null ? 0 : 56) +
              (widget.details == null ? 0 : 110) +
              24;
          final inline = scale <= 1.3 && width >= inlineWidth;
          final showFilters = inline || expanded || !widget.collapsible;
          final canExpand =
              widget.collapsible &&
              (widget.details != null ||
                  (!inline && widget.filters.isNotEmpty));
          final toggle = Semantics(
            button: true,
            expanded: expanded,
            label:
                'Filtres${widget.activeFilterCount == 0 ? '' : ', ${widget.activeFilterCount} actifs'}',
            child: Tooltip(
              message: expanded
                  ? 'Masquer les filtres'
                  : 'Afficher les filtres',
              child: OutlinedButton(
                key: const ValueKey('app-filter-toggle'),
                onPressed: _toggle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: colors.onSurface,
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 20),
                    if (width >= 600) ...[
                      const SizedBox(width: 8),
                      const Text('Filtres'),
                    ],
                    if (widget.activeFilterCount > 0) ...[
                      const SizedBox(width: 6),
                      Badge(label: Text('${widget.activeFilterCount}')),
                    ],
                  ],
                ),
              ),
            ),
          );
          final quick = AppQuickFilters(children: widget.quickFilters);
          final actions = widget.actions;
          final reset = widget.onReset != null && widget.activeFilterCount > 0
              ? IconButton.outlined(
                  tooltip: 'Effacer les filtres',
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 20),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                )
              : null;
          final filterGrid = LayoutBuilder(
            builder: (context, bounds) {
              final columns =
                  ((bounds.maxWidth + 8) / (152 * scale.clamp(1.0, 2.0) + 8))
                      .floor()
                      .clamp(1, 4);
              final cellWidth = (bounds.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final filter in widget.filters)
                    SizedBox(width: cellWidth, child: filter),
                ],
              );
            },
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (inline)
                Row(
                  children: [
                    if (widget.search != null) Expanded(child: widget.search!),
                    if (widget.search != null && widget.quickFilters.isNotEmpty)
                      const SizedBox(width: 10),
                    if (widget.quickFilters.isNotEmpty) Flexible(child: quick),
                    for (final filter in widget.filters) ...[
                      const SizedBox(width: 8),
                      SizedBox(width: fieldWidth, child: filter),
                    ],
                    if (canExpand) ...[const SizedBox(width: 8), toggle],
                    if (reset != null) ...[const SizedBox(width: 8), reset],
                    for (final action in actions) ...[
                      const SizedBox(width: 8),
                      action,
                    ],
                  ],
                )
              else ...[
                if (widget.search != null || canExpand)
                  Row(
                    children: [
                      if (widget.search != null)
                        Expanded(child: widget.search!)
                      else if (widget.quickFilters.isNotEmpty)
                        Expanded(child: quick)
                      else
                        const Spacer(),
                      if (canExpand) ...[const SizedBox(width: 8), toggle],
                      if (reset != null) ...[const SizedBox(width: 8), reset],
                    ],
                  ),
                if (widget.quickFilters.isNotEmpty &&
                    (widget.search != null || !canExpand)) ...[
                  if (widget.search != null || canExpand)
                    const SizedBox(height: 8),
                  quick,
                ],
                // Offstage preserves text field state without leaving invisible controls focusable.
                Visibility(
                  visible: showFilters && widget.filters.isNotEmpty,
                  maintainState: true,
                  child: ExcludeFocus(
                    excluding: !showFilters,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: filterGrid,
                    ),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
              if (widget.details != null)
                Visibility(
                  visible: expanded,
                  maintainState: true,
                  child: ExcludeFocus(
                    excluding: !expanded,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: widget.details!,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Quick choices keep their full labels. Large text wraps instead of clipping.
class AppQuickFilters extends StatelessWidget {
  final List<Widget> children;
  const AppQuickFilters({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(14) > 19) {
      return Wrap(spacing: 8, runSpacing: 6, children: children);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}
