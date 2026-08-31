import 'package:flutter/material.dart';

class ChatMediaRegion extends StatelessWidget {
  final Widget child;

  const ChatMediaRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, label: 'Média de conversation', child: child);
}
