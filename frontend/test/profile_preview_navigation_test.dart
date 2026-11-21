import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/shared/ui/photo_preview.dart';
import 'package:frontend/shared/ui/app_back_button.dart';
import 'package:frontend/features/recruitment/screens/application_tracking_screen.dart';

void main() {
  testWidgets(
    'accessible photo action keeps avatar bounds and opens the preview',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhotoPreviewTap(
                  image: AssetImage(
                    'assets/img/prix_enactus_national_2016.png',
                  ),
                  title: 'Profil test',
                  child: CircleAvatar(radius: 38),
                ),
                Text('Nom du membre'),
                SizedBox(
                  height: 500,
                  width: 300,
                  child: Text('Informations du profil'),
                ),
              ],
            ),
          ),
        ),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Agrandir la photo de Profil test'),
      );
      expect(node.rect.size, const Size(76, 76));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.platformDispatcher.onSemanticsActionEvent!(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer la photo'));
      await tester.pumpAndSettle();
      expect(find.text('Informations du profil'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'photo opens whole image with zoom and closes to the same profile',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhotoPreviewTap(
              image: AssetImage('assets/img/prix_enactus_national_2016.png'),
              title: 'Profil test',
              child: CircleAvatar(child: Text('PT')),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Agrandir la photo'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      await tester.tap(find.byTooltip('Fermer la photo'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('PT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile without photo has no empty preview action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoPreviewTap(
          image: null,
          title: 'Profil',
          child: Text('Initiales'),
        ),
      ),
    );
    expect(find.byTooltip('Agrandir la photo'), findsNothing);
  });
  testWidgets('back from a direct detail URL reaches the parent page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/archives',
          builder: (_, _) => const Scaffold(body: Text('Les archives')),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, _) => const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: AppBackButton(fallbackPath: '/archives'),
            ),
            body: Text('Le détail'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Les archives'), findsOneWidget);
  });
  testWidgets('back preserves the collection search after opening a detail', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: '/archives',
      routes: [
        GoRoute(
          path: '/archives',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextField(controller: controller),
                TextButton(
                  onPressed: () => context.push('/detail'),
                  child: const Text('Découvrir'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, _) =>
              const Scaffold(body: AppBackButton(fallbackPath: '/archives')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField), 'Dimbali');
    await tester.tap(find.text('Découvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Dimbali'), findsOneWidget);
  });
  testWidgets('tracking has a back action even when opened directly', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/application-tracking',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Connexion')),
        ),
        GoRoute(
          path: '/application-tracking',
          builder: (_, _) => const ApplicationTrackingScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
