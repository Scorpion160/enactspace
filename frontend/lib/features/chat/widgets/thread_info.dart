import 'package:flutter/material.dart';

class ThreadInfoRegion extends StatelessWidget {
  final Widget child;

  const ThreadInfoRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Informations et participants',
    child: child,
  );
}
