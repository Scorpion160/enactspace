import 'package:flutter/material.dart';

/// Keeps questions and guidance outside the input border so neither is ellipsized.
class PublicApplicationField extends StatelessWidget {
  final String label;
  final String? help;
  final Widget child;
  const PublicApplicationField({super.key, required this.label, this.help, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, softWrap: true, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600, height: 1.4,
      )),
      const SizedBox(height: 8),
      Semantics(label: label, child: child),
      if (help != null && help!.trim().isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(help!, softWrap: true, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4,
        )),
      ],
    ],
  );
}

/// Lets the candidate swipe a long selected value without moving the whole form.
class PublicApplicationChoiceText extends StatelessWidget {
  final String text;
  const PublicApplicationChoiceText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}
