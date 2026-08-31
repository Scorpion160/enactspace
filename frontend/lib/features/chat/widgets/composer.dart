import 'package:flutter/material.dart';

class ChatComposerRegion extends StatelessWidget {
  final Widget child;

  const ChatComposerRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, label: 'Composer un message', child: child);
}
