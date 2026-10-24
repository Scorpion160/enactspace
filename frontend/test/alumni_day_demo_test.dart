import 'package:frontend/features/demo/demo_native_experience.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/app_router.dart';
import 'package:frontend/features/alumni/widgets/alumni_community_hero.dart';
import 'package:frontend/features/demo/demo_screen.dart';
import 'package:frontend/features/demo/demo_session.dart';
import 'package:frontend/features/demo/demo_recruitment.dart';
import 'package:frontend/features/demo/demo_recruitment_gateway.dart';
import 'package:frontend/features/demo/demo_heritage_data.dart';
import 'package:frontend/features/recruitment/models/public_application_draft.dart';
import 'package:frontend/features/recruitment/screens/public/public_application_flow_screen.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('The public demo must use bundled resources.');
  }
}

Future<void> _mount(
  WidgetTester tester, {
  DemoProfile? profile = DemoProfile.enacteur,
  String section = 'home',
  double width = 390,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DemoScreen(
        key: ValueKey('$profile-$section'),
        profile: profile,
        initialSection: section,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo routes are public without exposing authenticated routes', () {
    for (final path in ['/demo', '/demo/enacteur', '/demo/alumni']) {
      expect(AppRouter.isPublicPath(path), isTrue);
    }
    for (final path in [
      '/demo/admin',
      '/democracy',
      '/finance',
      '/alumni',
      '/archives',
    ]) {
      expect(AppRouter.isPublicPath(path), isFalse);
    }
  });

  test('every real module route is covered by the public demo inventory', () {
    final source = File('lib/app/app_router.dart').readAsStringSync();
    final paths = RegExp(
      r"path:\s*'(/[^']*)'",
    ).allMatches(source).map((m) => m[1]!);
    final ids = demoModules.map((m) => m.id).toSet();
    for (final path in paths) {
      if (path == '/login' ||
          path == '/splash' ||
          path == '/demo' ||
          path.startsWith('/demo/')) {
        continue;
      }
      final module = demoModuleForPath(path);
      expect(module, isNotNull, reason: 'Missing demo for $path');
      expect(ids, contains(module), reason: path);
    }
    expect(demoModuleForPath('/recruitment/apply/example'), 'recruitment');
    expect(demoModuleForPath('/poles/example'), 'poles');
    expect(demoModuleForPath('/projects/example'), 'projects');
    expect(demoModuleForPath('/chat'), 'chat');
  });

  test(
    'chat histories and media stay inside their own fictional conversation',
    () {
      final visit = DemoSession(DemoProfile.enacteur);
      addTearDown(visit.dispose);
      visit.send('Bonjour les générations');
      visit.share(const DemoSharedItem('photo', 'Photo publique'));
      visit.selectConversation('direct');
      expect(visit.messages, isEmpty);
      expect(visit.sharedItems, isEmpty);
      visit.send('Échange privé fictif');
      visit.selectConversation('generations');
      expect(visit.messages, ['Bonjour les générations']);
      expect(visit.sharedItems.single.label, 'Photo publique');
    },
  );

  test(
    'recruitment preserves metadata and updates only in-memory tracking',
    () async {
      final gateway = DemoRecruitmentGateway();
      addTearDown(gateway.dispose);
      const draft = PublicApplicationDraft(
        campaignId: 'demo-alumni-day',
        firstName: 'Awa',
        lastName: 'Démo',
        email: 'essai@example.test',
        className: '2025-2026',
        department: 'Génie Électrique',
        studyLevel: 'DIC2',
        knownEnactusFrom: 'Une affiche ou un support imprimé',
      );
      final result = await gateway.submitApplication(draft);
      expect(result.className, '2025-2026');
      expect(result.knownEnactusFrom, draft.knownEnactusFrom);
      expect(result.canConvert, isFalse);
      expect(result.cvUrl, isNull);
      gateway.changeStatus('Ma candidature d’essai', 'accepted');
      final tracking = await gateway.trackApplication(
        code: DemoRecruitmentGateway.code,
        email: draft.email,
      );
      expect(tracking.status, 'accepted');
      expect(tracking.accountCreated, isFalse);
      await expectLater(
        gateway.trackApplication(code: 'BAD', email: draft.email),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'visits are independent and repeated actions do not invent money or points',
    () {
      final first = DemoSession(DemoProfile.enacteur);
      final second = DemoSession(DemoProfile.alumni);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first.send('  Bonjour les générations !  ');
      first.send('   ');
      first.completeLesson('ecouter');
      first.completeLesson('ecouter');
      first.passQuiz();
      first.passQuiz();
      first.simulatePayment();
      first.simulatePayment();
      first.toggle(first.joinedEvents, 'atelier');
      first.toggle(first.joinedEvents, 'atelier');
      expect(first.messages, ['Bonjour les générations !']);
      expect(first.points, 70);
      expect(first.simulatedPaid, 1000);
      expect(first.joinedEvents, isEmpty);
      expect(second.messages, isEmpty);
      expect(second.points, 0);
      expect(second.simulatedPaid, 0);
      expect(second.savedMemories, isEmpty);
    },
  );

  test('the Alumni itinerary preserves a distinct community focus', () {
    final alumni = modulesFor(DemoProfile.alumni).map((m) => m.id);
    expect(
      alumni,
      containsAll(['archives', 'alumni', 'academy', 'chat', 'events']),
    );
    expect(alumni, isNot(contains('finance')));
    expect(alumni, isNot(contains('tasks')));
    expect(
      modulesFor(DemoProfile.enacteur).map((m) => m.id),
      containsAll(['finance', 'tasks', 'projects', 'documents']),
    );
  });

  test(
    'all forty memories are bundled public photos with attribution',
    () async {
      final rows =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/img/alumni_day_heritage.json',
                ),
              )
              as List;
      expect(
        demoHeritage,
        equals(rows),
        reason: 'Compiled metadata must match the bundled public catalog.',
      );
      expect(rows, hasLength(40));
      expect(rows.map((r) => r['id']).toSet(), hasLength(40));
      for (final raw in rows) {
        final row = raw as Map;
        final asset = row['image_asset'] as String;
        expect(
          asset,
          anyOf(startsWith('assets/heritage/'), startsWith('assets/img/')),
        );
        expect(asset, isNot(contains('..')));
        expect(row['source_label'], isNotEmpty);
        expect(row['description'], isNotEmpty);
        expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(100));
      }
    },
  );

  test(
    'demo implementation cannot write through authentication or API clients',
    () {
      for (final path in [
        'lib/features/demo/demo_screen.dart',
        'lib/features/demo/demo_session.dart',
        'lib/features/demo/demo_recruitment.dart',
        'lib/features/demo/demo_recruitment_gateway.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('AuthService(')));
        expect(source, isNot(contains('ApiClient(')));
        expect(source, isNot(contains('SharedPreferences')));
        expect(source, isNot(contains('SecureStorage')));
      }
    },
  );

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'entry and alumni hero fit width=$width dark=$dark at 200% text',
        (tester) async {
          await _mount(
            tester,
            profile: null,
            width: width,
            dark: dark,
            scale: 2,
          );
          expect(
            find.byKey(const ValueKey('demo-enter-enacteur')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('demo-enter-alumni')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _mount(
            tester,
            profile: DemoProfile.alumni,
            section: 'alumni',
            width: width,
            dark: dark,
            scale: 2,
          );
          expect(find.byType(AlumniCommunityHero), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final module in demoModules) {
    testWidgets(
      '${module.id} renders on a small phone with large text and no network',
      (tester) async {
        final previous = HttpOverrides.current;
        final offline = _NoNetwork();
        HttpOverrides.global = offline;
        addTearDown(() => HttpOverrides.global = previous);
        await _mount(
          tester,
          section: module.id,
          width: 320,
          scale: 2,
          dark: true,
        );
        expect(
          find.byKey(const ValueKey('demo-content-scroll')),
          findsOneWidget,
        );
        expect(offline.attempts, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'login discovery opens both public role itineraries and exits to login',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: DemoLoginEntry()),
          ),
          GoRoute(path: '/demo', builder: (_, _) => const DemoScreen()),
          GoRoute(
            path: '/demo/enacteur',
            builder: (_, _) =>
                const DemoNativeExperience(profile: DemoProfile.enacteur),
          ),
          GoRoute(
            path: '/demo/alumni',
            builder: (_, state) => DemoNativeExperience(
              profile: DemoProfile.alumni,
              initialSection: state.uri.queryParameters['section'] ?? 'home',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Découvrir la démo'));
      await _tap(tester, find.byKey(const ValueKey('demo-enter-enacteur')));
      expect(find.byType(DashboardScreen), findsOneWidget);
      await _tap(tester, find.byTooltip('Changer de profil ou quitter'));
      await _tap(tester, find.byKey(const ValueKey('demo-enter-alumni')));
      expect(find.byType(DashboardScreen), findsOneWidget);
      await _tap(tester, find.byTooltip('Changer de profil ou quitter'));
      await _tap(tester, find.byTooltip('Quitter la démo'));
      expect(find.text('Découvrir la démo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('private Alumni sections fall back to the community home', (
    tester,
  ) async {
    await _mount(tester, profile: DemoProfile.alumni, section: 'finance');
    expect(find.byKey(const ValueKey('demo-simulate-payment')), findsNothing);
    expect(find.text('Toujours Enactus.\nToujours ensemble.'), findsOneWidget);
  });

  testWidgets('chat sends a local message and a new visit starts empty', (
    tester,
  ) async {
    await _mount(tester, section: 'chat');
    final input = find.byKey(const ValueKey('demo-chat-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Quel plaisir de vous retrouver !');
    await _tap(tester, find.byKey(const ValueKey('demo-chat-send')));
    expect(find.text('Quel plaisir de vous retrouver !'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await _mount(tester, section: 'chat');
    expect(find.text('Quel plaisir de vous retrouver !'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat offers local photo sharing and a shared media view', (
    tester,
  ) async {
    await _mount(tester, section: 'chat');
    await _tap(tester, find.byKey(const ValueKey('demo-share-photo')));
    expect(find.textContaining('Vous · World Cup 2022'), findsOneWidget);
    await _tap(tester, find.byTooltip('Informations et médias partagés'));
    await _tap(tester, find.text('Voir les éléments partagés'));
    expect(find.text('Médias et documents partagés'), findsOneWidget);
    expect(find.text('Lire le dossier public de Terrasen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pole cards open their fictional team and roadmap', (
    tester,
  ) async {
    await _mount(tester, section: 'poles');
    await _tap(tester, find.byKey(const ValueKey('demo-pole-Veille')));
    expect(find.text('Pôle Veille'), findsOneWidget);
    expect(find.textContaining('Feuille de route d’exemple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native recruitment uses only the demo gateway and never reports a live browser URL',
    (tester) async {
      final gateway = DemoRecruitmentGateway();
      addTearDown(gateway.dispose);
      final outer = GoRouter(
        initialLocation: '/demo/alumni',
        overridePlatformDefaultLocation: true,
        routes: [
          GoRoute(
            path: '/demo/alumni',
            builder: (_, _) => Scaffold(
              body: DemoRecruitmentExperience(gateway: gateway, onClose: () {}),
            ),
          ),
        ],
      );
      addTearDown(outer.dispose);
      final reports = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(call.arguments.toString());
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: outer));
      await tester.pumpAndSettle();
      // The outer app is expected to report its initial /demo/alumni location.
      // Only subsequent changes from the nested recruitment flow are forbidden.
      expect(outer.routeInformationProvider.value.uri.path, '/demo/alumni');
      reports.clear();
      await _tap(tester, find.text('Commencer ma candidature'));
      final flow = tester.widget<PublicApplicationFlowScreen>(
        find.byType(PublicApplicationFlowScreen),
      );
      expect(identical(flow.gateway, gateway), isTrue);
      expect(flow.demoMode, isTrue);
      expect(find.text('Étape 1 sur 6'), findsOneWidget);
      expect(outer.routeInformationProvider.value.uri.path, '/demo/alumni');
      expect(reports, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prefilled native recruitment completes all six steps without a real submission',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/demo/alumni';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final gateway = DemoRecruitmentGateway();
      addTearDown(gateway.dispose);
      final outer = GoRouter(
        initialLocation: '/demo/alumni',
        overridePlatformDefaultLocation: true,
        routes: [
          GoRoute(
            path: '/demo/alumni',
            builder: (_, _) => Scaffold(
              body: DemoRecruitmentExperience(
                gateway: gateway,
                initialLocation: '/recruitment/apply/demo-alumni-day',
                onClose: () {},
              ),
            ),
          ),
        ],
      );
      addTearDown(outer.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: outer));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await _tap(tester, find.byKey(const ValueKey('application-next')));
      }
      expect(find.text('Étape 6 sur 6'), findsOneWidget);
      expect(gateway.submissions, 0);
      await _tap(tester, find.byType(CheckboxListTile));
      await _tap(tester, find.byKey(const ValueKey('application-submit')));
      expect(find.text('Simulation terminée'), findsOneWidget);
      expect(find.text(DemoRecruitmentGateway.code), findsOneWidget);
      expect(gateway.submissions, 1);
      expect(gateway.lastApplication?.canConvert, isFalse);
      expect(outer.routeInformationProvider.value.uri.path, '/demo/alumni');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a lesson and a correct quiz answer update the visible progression',
    (tester) async {
      await _mount(tester, section: 'academy');
      await _tap(tester, find.text('Commencer la première leçon'));
      await _tap(tester, find.text('Terminer cette leçon'));
      expect(
        find.text('1/3 leçons · 20 points de démonstration'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const ValueKey('demo-open-quiz')));
      await _tap(tester, find.text('Écouter les personnes concernées'));
      await _tap(tester, find.text('Vérifier ma réponse'));
      await _tap(tester, find.text('Fermer'));
      expect(
        find.text('1/3 leçons · 70 points de démonstration'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft preview and editing preserve entered text before local saving',
    (tester) async {
      await _mount(tester, section: 'documents');
      await _tap(tester, find.text('Essayer un brouillon'));
      final field = find.byKey(const ValueKey('demo-draft-subject'));
      await tester.enterText(field, 'Rencontre entre générations');
      await _tap(tester, find.text('Aperçu'));
      expect(find.text('Rencontre entre générations'), findsOneWidget);
      await _tap(tester, find.text('Modifier'));
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Rencontre entre générations',
      );
      await _tap(tester, find.text('Garder dans la démo'));
      expect(
        find.textContaining('BROUILLON D’EXEMPLE\nRencontre entre générations'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archive search filters the local corpus and a photo reveals its source',
    (tester) async {
      await _mount(tester, profile: DemoProfile.alumni, section: 'archives');
      final input = find.byKey(const ValueKey('demo-archive-search'));
      await tester.ensureVisible(input);
      await tester.enterText(input, 'aucun-souvenir-correspondant-xyz');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Aucun souvenir avec ce filtre.'),
        findsOneWidget,
      );
      await tester.enterText(input, '');
      await tester.pumpAndSettle();
      final photo = find
          .byWidgetPredicate(
            (widget) =>
                widget is InkWell &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith('memory-'),
          )
          .first;
      await _tap(tester, photo);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.textContaining('Source :'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a simulated payment can be recorded only once in the visit', (
    tester,
  ) async {
    await _mount(tester, section: 'finance');
    final button = find.byKey(const ValueKey('demo-simulate-payment'));
    await _tap(tester, button);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      find.text('Simulation terminée. Aucun paiement réel effectué.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
