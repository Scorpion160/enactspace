import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app/app_router.dart';
import 'shared/ui/app_back_button.dart';
import 'core/theme/appearance_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/push/push_lifecycle_controller.dart';
import 'features/finance/screens/finance_screen.dart';

const MethodChannel _receiptShareChannel = MethodChannel(
  'sn.enactusesp.enactspace/receipt_share',
);

void _openFinanceForSharedReceipt() {
  FinanceScreen.incomingReceipts.value++;
  AppRouter.router.go('/finance');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/poppins/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Poppins'], text);
  });

  MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
    'vendor/zxing-wasm/index.js',
  );
  await initializeDateFormatting('fr_FR');
  await AppearanceController.instance.loadCached();
  await PushLifecycleController.instance.initialize();
  _receiptShareChannel.setMethodCallHandler((call) async {
    if (call.method == 'receiptShared') {
      _openFinanceForSharedReceipt();
    }
  });

  runApp(EnactSpaceApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final pending =
          await _receiptShareChannel.invokeMethod<bool>('hasPendingReceipt') ??
          false;
      if (pending) _openFinanceForSharedReceipt();
    } on MissingPluginException {
      // Web and desktop do not expose the Android share bridge.
    }
  });
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
        onNavigationNotification: (notification) =>
            handleAppNavigationNotification(AppRouter.router, notification),
      ),
    );
  }
}
