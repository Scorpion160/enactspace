import 'package:flutter/material.dart';

class MessageListRegion extends StatelessWidget {
  final Widget child;

  const MessageListRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'Messages de la conversation',
    child: child,
  );
}
