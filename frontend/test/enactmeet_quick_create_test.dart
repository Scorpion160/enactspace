import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/demo/demo_native_runtime.dart';
import 'package:frontend/features/demo/demo_session.dart';
import 'package:frontend/features/meetings/screens/meetings_screen.dart';

void main() {
  testWidgets(
    'EnactMeet: création rapide épurée; options avancées dans les paramètres',
    (tester) async {
      final runtime = DemoNativeRuntime(DemoProfile.enacteur);
      addTearDown(runtime.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeetingsScreen(
              service: runtime.meetings,
              authService: runtime.auth,
              membersService: runtime.members,
              polesService: runtime.polesService,
              projectsService: runtime.projectsService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle réunion'));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle réunion EnactMeet'), findsOneWidget);
      expect(find.text('Titre de la réunion'), findsOneWidget);
      expect(find.text('Description / ordre du jour'), findsOneWidget);
      expect(find.text('Qui peut rejoindre ?'), findsOneWidget);
      expect(find.text('Planifier pour plus tard'), findsOneWidget);

      expect(find.text('Micro coupé au démarrage'), findsNothing);
      expect(find.text('Caméra coupée au démarrage'), findsNothing);
      expect(find.text('Autoriser le contrôle lobby'), findsNothing);
      expect(find.text('Enregistrement de la réunion'), findsNothing);
      expect(
        find.textContaining('dans les paramètres de la réunion'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
