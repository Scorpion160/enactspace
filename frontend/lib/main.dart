import 'package:flutter/material.dart';
import 'app/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const EnactSpaceApp());
}

class EnactSpaceApp extends StatelessWidget {
  const EnactSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EnactSpace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}