import 'package:flutter/material.dart';

class NewConversationDialogRegion extends StatelessWidget {
  final Widget child;

  const NewConversationDialogRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Créer une nouvelle conversation',
    child: child,
  );
}
