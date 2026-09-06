import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app_router.dart';
import 'core/theme/appearance_controller.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await AppearanceController.instance.loadCached();
  runApp(EnactSpaceApp());
}

class EnactSpaceApp extends StatelessWidget {
  final AppearanceController appearanceController;

  EnactSpaceApp({super.key, AppearanceController? appearanceController})
    : appearanceController =
          appearanceController ?? AppearanceController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appearanceController,
      builder: (context, _) => MaterialApp.router(
        title: 'EnactSpace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: appearanceController.themeMode,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
