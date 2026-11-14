import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/gamification/screens/games_screen.dart';
import 'package:frontend/features/gamification/services/games_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Jeux du club reste lisible en sombre sur mobile avec texte agrandi',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          builder: (context, child) {
            final data = MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6));
            return MediaQuery(data: data, child: child!);
          },
          home: GamesScreen(service: _GamesFake()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jeux du club'), findsOneWidget);
      expect(find.text('Quiz de culture générale'), findsOneWidget);
      expect(find.text('Undercover'), findsOneWidget);
      expect(find.text('Icebreakers'), findsOneWidget);
      expect(find.text('Loup garou'), findsOneWidget);
      expect(find.text('Créer la session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _GamesFake extends GamesService {
  @override
  Future<List<Map<String, dynamic>>> mine() async => const [];

  @override
  Future<List<Map<String, dynamic>>> leaderboard({String? game}) async =>
      const [];
}
