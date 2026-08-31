import 'package:flutter/material.dart';

class ConversationHeaderRegion extends StatelessWidget {
  final Widget child;

  const ConversationHeaderRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'En-tête de la conversation',
    child: child,
  );
}
