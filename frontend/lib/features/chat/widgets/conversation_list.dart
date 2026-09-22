import 'package:flutter/material.dart';

class ConversationListRegion extends StatelessWidget {
  final Widget child;

  const ConversationListRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Liste des conversations',
    child: child,
  );
}
