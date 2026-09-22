import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app/app_router.dart';
import 'core/theme/appearance_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/push/push_lifecycle_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
    'vendor/zxing-wasm/index.js',
  );
  await initializeDateFormatting('fr_FR');
  await AppearanceController.instance.loadCached();
  await PushLifecycleController.instance.initialize();
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
