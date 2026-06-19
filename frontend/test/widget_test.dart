import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/recruitment/screens/application_tracking_screen.dart';

void main() {
  testWidgets('login screen renders expected actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('candidate tracking fits a compact mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ApplicationTrackingScreen()),
    );
    await tester.pump();

    expect(find.text('Suivre ma candidature'), findsOneWidget);
    expect(find.text('Afficher mon suivi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
