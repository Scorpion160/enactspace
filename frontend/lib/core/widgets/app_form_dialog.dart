import 'package:flutter/material.dart';

/// Shared presentation for secondary create and edit flows.
class AppFormDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;
  final String? description;
  final EdgeInsets? insetPadding;

  const AppFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon = Icons.edit_note_rounded,
    this.description,
    this.insetPadding,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: insetPadding,
      title: AppFormHeader(title: title, icon: icon),
      content: description == null
          ? content
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Flexible(child: content),
              ],
            ),
      actions: actions,
    );
  }
}

/// Header shared with full-sized secondary forms.
class AppFormHeader extends StatelessWidget {
  final Widget title;
  final IconData icon;

  const AppFormHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.secondary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onSurface),
        ),
        const SizedBox(width: 12),
        Expanded(child: title),
      ],
    );
  }
}
