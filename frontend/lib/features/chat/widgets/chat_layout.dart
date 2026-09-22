import 'package:flutter/material.dart';

class ChatResponsiveLayout extends StatelessWidget {
  final WidgetBuilder desktopBuilder;
  final WidgetBuilder mobileBuilder;

  const ChatResponsiveLayout({
    super.key,
    required this.desktopBuilder,
    required this.mobileBuilder,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 900
        ? desktopBuilder(context)
        : mobileBuilder(context),
  );
}
