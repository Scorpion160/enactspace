import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/push/push_navigation_resolver.dart';
import 'package:frontend/features/notifications/models/notification_presentation.dart';
import 'package:frontend/features/veille/screens/veille_screen.dart';
import 'package:frontend/features/veille/screens/veille_record_screen.dart';
import 'package:frontend/features/veille/services/veille_gateway.dart';
import 'package:frontend/features/veille/widgets/veille_form.dart';

VeilleJson clone(VeilleJson value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
late VeilleJson fixture;

class FakeVeilleGateway implements VeilleGateway {
  VeilleJson bundle = clone(fixture['bundle'] as VeilleJson);
  final List<VeilleJson> saves = [];
  bool failLoad = false, failSave = false;
  VeilleJson? taskOverride;
  int loads = 0;
  String? lastKind;
  @override
  Future<VeilleJson> load({
    required DateTime start,
    required DateTime end,
    String? poleId,
    String? projectId,
    String? memberId,
    String? seasonId,
  }) async {
    loads++;
    if (failLoad) throw Exception('Connexion interrompue.');
    return clone(bundle);
  }

  @override
  Future<VeilleJson> detail(String kind, String id) async {
    lastKind = kind;
    if (kind == 'task' && taskOverride != null) return clone(taskOverride!);
    return clone((fixture['details'] as Map)[kind] as VeilleJson);
  }

  @override
  Future<VeilleJson> save(
    String path,
    VeilleJson data, {
    String method = 'POST',
  }) async {
    if (failSave) throw Exception('Le dossier a changé. Actualisez-le.');
    saves.add({'path': path, 'method': method, 'payload': clone(data)});
    return {'id': 'saved'};
  }

  @override
  Future<VeilleJson> taskStatus(String id, String status) async {
    saves.add({'status': status});
    return {};
  }

  @override
  Future<VeilleJson> taskProof(String id, String url) async => {};
  @override
  Future<VeilleJson> taskChecklist(String id, bool done) async {
    saves.add({'checklist': id, 'done': done});
    return {};
  }

  @override
  Future<VeilleJson> taskComment(String id, String content) async {
    saves.add({'comment': content});
    return {};
  }

  @override
  Future<Uint8List> exportReport(String id) async =>
      Uint8List.fromList(utf8.encode('Membre;Livrables'));
  @override
  Future<Uint8List> downloadProof(String url) async => Uint8List(0);
}

Future<void> display(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double scale = 1.6,
  bool dark = true,
  GlobalKey? captureKey,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: RepaintBoundary(key: captureKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> visibleTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      for (
        var attempt = 0;
        attempt < 80 && finder.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(scrollable, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
    }
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> fillEmpty(WidgetTester tester) async {
  for (final element in find.byType(TextFormField).evaluate().toList()) {
    final field = element.widget as TextFormField;
    if (field.enabled != false &&
        (field.controller?.text.trim().isEmpty ?? false)) {
      final finder = find.byWidget(field);
      await tester.ensureVisible(finder);
      await tester.enterText(
        finder,
        'Les résultats et les prochaines étapes ont été discutés avec l’équipe.',
      );
    }
  }
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['ENACTSPACE_VISUAL_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    fixture = Map<String, dynamic>.from(
      jsonDecode(
            await File('test/fixtures/veille_contract.json').readAsString(),
          )
          as Map,
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in FontWeight.values) {
      GoogleFonts.poppins(fontWeight: weight);
      GoogleFonts.poppins(fontWeight: weight, fontStyle: FontStyle.italic);
    }
    await GoogleFonts.pendingFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });
  for (final scenario in [
    (360.0, 1.6, true),
    (768.0, 1.0, false),
    (1440.0, 1.0, true),
  ]) {
    testWidgets(
      'Veille tabs remain usable at ${scenario.$1} dark=${scenario.$3}',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = FakeVeilleGateway();
        final key = GlobalKey();
        await display(
          tester,
          VeilleScreen(gateway: gateway),
          width: scenario.$1,
          scale: scenario.$2,
          dark: scenario.$3,
          captureKey: key,
        );
        expect(find.text('Pôle Veille'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'veille-${scenario.$1.toInt()}');
        for (final label in [
          'Enacteurs',
          'Pôles et projets',
          'Engagements',
          'Blocages',
          'Bilans',
          'Indisponibilités',
          'Dossiers',
          'Règles et réglages',
          'Vue d’ensemble',
        ]) {
          await visibleTap(tester, find.widgetWithText(ChoiceChip, label));
          expect(tester.takeException(), isNull, reason: label);
        }
        expect(gateway.loads, 1);
      },
    );
  }
  for (final kind in ['task', 'plan', 'blocker', 'leave', 'case', 'report']) {
    testWidgets('$kind detail remains readable with dark mode and large text', (
      tester,
    ) async {
      final key = GlobalKey();
      await display(
        tester,
        VeilleRecordScreen(
          kind: kind,
          id: 'record',
          gateway: FakeVeilleGateway(),
        ),
        captureKey: key,
      );
      expect(find.text('Retour au suivi Veille'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'veille-detail-$kind');
      await tester.drag(find.byType(ListView).first, const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('member has personal follow-up without decision controls', (
    tester,
  ) async {
    final gateway = FakeVeilleGateway();
    final context = gateway.bundle['context'] as Map;
    context['can_coordinate'] = false;
    context['global_scope'] = false;
    context['can_manage_settings'] = false;
    context['can_decide'] = false;
    await display(tester, VeilleScreen(gateway: gateway));
    expect(find.text('Mon suivi'), findsOneWidget);
    expect(find.text('Confier une action'), findsNothing);
    expect(find.text('Règles et réglages'), findsNothing);
    await visibleTap(tester, find.widgetWithText(ChoiceChip, 'Dossiers'));
    expect(find.text('Ouvrir un dossier'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('network error is visible and retry reloads actual data', (
    tester,
  ) async {
    final gateway = FakeVeilleGateway()..failLoad = true;
    await display(tester, VeilleScreen(gateway: gateway));
    expect(find.text('Connexion interrompue.'), findsOneWidget);
    gateway.failLoad = false;
    await visibleTap(tester, find.text('Réessayer'));
    expect(find.text('Connexion interrompue.'), findsNothing);
    expect(gateway.loads, 2);
  });
  testWidgets('task detail navigation and return preserve follow-up', (
    tester,
  ) async {
    final gateway = FakeVeilleGateway();
    final router = GoRouter(
      initialLocation: '/veille',
      routes: [
        GoRoute(
          path: '/veille',
          builder: (_, _) => Scaffold(body: VeilleScreen(gateway: gateway)),
          routes: [
            GoRoute(
              path: 'records/:kind/:id',
              builder: (_, s) => Scaffold(
                body: VeilleRecordScreen(
                  kind: s.pathParameters['kind']!,
                  id: s.pathParameters['id']!,
                  gateway: gateway,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.lightTheme),
    );
    await tester.pumpAndSettle();
    await visibleTap(tester, find.text('Ouvrir le suivi de la tâche'));
    expect(gateway.lastKind, 'task');
    await visibleTap(tester, find.text('Retour au suivi Veille'));
    expect(find.byType(VeilleScreen), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/veille');
    expect(tester.takeException(), isNull);
  });
  final formKinds = [
    'plan',
    'action',
    'blocker',
    'review',
    'deadline',
    'report',
    'leave',
    'leave_action',
    'case',
    'case_action',
    'rule',
    'settings',
  ];
  for (final kind in formKinds) {
    testWidgets('$kind form submits and handles large text without overflow', (
      tester,
    ) async {
      final gateway = FakeVeilleGateway();
      final details = fixture['details'] as Map;
      final source =
          {
            'action': 'task',
            'review': 'task',
            'deadline': 'task',
            'leave_action': 'leave',
            'case_action': 'case',
          }[kind] ??
          kind;
      final initial = source == 'settings'
          ? clone((gateway.bundle['context'] as Map)['settings'] as VeilleJson)
          : source == 'rule'
          ? <String, dynamic>{
              'title': 'Une règle adoptée',
              'content': 'Le suivi prévoit une écoute et une décision humaine.',
            }
          : clone(details[source] as VeilleJson);
      if (kind == 'action') {
        initial['owner_id'] = (details['plan'] as Map)['owner_id'];
      }
      await display(
        tester,
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showVeilleForm(
                context,
                kind: kind,
                gateway: gateway,
                data: gateway.bundle,
                initial: initial,
                action: kind == 'leave_action'
                    ? 'approved'
                    : kind == 'case_action'
                    ? 'comment'
                    : null,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      );
      await visibleTap(tester, find.text('Ouvrir'));
      expect(tester.takeException(), isNull);
      await fillEmpty(tester);
      await visibleTap(tester, find.byKey(const Key('veille-form-submit')));
      expect(gateway.saves, hasLength(1));
      expect(find.byType(VeilleForm), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed save retains the form and entered explanation', (
    tester,
  ) async {
    final gateway = FakeVeilleGateway()..failSave = true;
    await display(
      tester,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => showVeilleForm(
            context,
            kind: 'review',
            gateway: gateway,
            data: gateway.bundle,
            initial: clone((fixture['details'] as Map)['task'] as VeilleJson),
          ),
          child: const Text('Ouvrir'),
        ),
      ),
    );
    await visibleTap(tester, find.text('Ouvrir'));
    await fillEmpty(tester);
    await visibleTap(tester, find.byKey(const Key('veille-form-submit')));
    expect(find.byType(VeilleForm), findsOneWidget);
    expect(find.text('Le dossier a changé. Actualisez-le.'), findsOneWidget);
    expect(gateway.saves, isEmpty);
    gateway.failSave = false;
    await visibleTap(tester, find.byKey(const Key('veille-form-submit')));
    expect(gateway.saves, hasLength(1));
  });
  testWidgets('financial decision keeps bureau amount as an integer', (
    tester,
  ) async {
    final gateway = FakeVeilleGateway();
    final initial = clone((fixture['details'] as Map)['case'] as VeilleJson);
    initial['proposed_action'] = 'penalite_financiere';
    initial['amount'] = 1000.0;
    initial['rule'] = {
      'allowed_actions': ['penalite_financiere'],
    };
    await display(
      tester,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => showVeilleForm(
            context,
            kind: 'case_action',
            gateway: gateway,
            data: gateway.bundle,
            initial: initial,
            action: 'decide',
          ),
          child: const Text('Ouvrir'),
        ),
      ),
    );
    await visibleTap(tester, find.text('Ouvrir'));
    await fillEmpty(tester);
    await visibleTap(tester, find.byKey(const Key('veille-form-submit')));
    expect(gateway.saves.single['payload']['amount'], 1000);
    expect(gateway.saves.single['payload']['outcome'], 'penalite_financiere');
  });
  testWidgets(
    'assigned member can complete a checklist step and share a return',
    (tester) async {
      final gateway = FakeVeilleGateway();
      gateway.taskOverride = clone(
        (fixture['details'] as Map)['task'] as VeilleJson,
      );
      gateway.taskOverride!.addAll({
        'can_manage': false,
        'current_user_assigned': true,
        'status': 'en_cours',
        'checklist': [
          {'id': 'step', 'title': 'Préparer les entretiens', 'is_done': false},
        ],
        'comments': [],
      });
      await display(
        tester,
        VeilleRecordScreen(kind: 'task', id: 'task', gateway: gateway),
      );
      await visibleTap(tester, find.byType(Checkbox));
      expect(gateway.saves.single['done'], true);
      final input = find.widgetWithText(
        TextField,
        'Un retour ou une aide à partager',
      );
      if (input.evaluate().isEmpty) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Le partenaire a confirmé la rencontre.');
      await visibleTap(tester, find.text('Partager mon retour'));
      expect(
        gateway.saves.last['comment'],
        'Le partenaire a confirmé la rencontre.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('notifications open only known Veille record types', () {
    for (final kind in ['task', 'plan', 'blocker', 'report', 'leave', 'case']) {
      expect(
        PushNavigationResolver.resolve(
          type: 'veille_update',
          relatedType: 'veille_$kind',
          relatedId: 'id',
        ),
        '/veille/records/$kind/id',
      );
    }
    expect(
      PushNavigationResolver.resolve(
        type: 'veille_update',
        relatedType: 'veille_unknown',
        relatedId: 'id',
      ),
      '/veille',
    );
    expect(
      notificationPresentation('veille_deadline').family,
      NotificationFamily.veille,
    );
    final member = UserExperience.fromJson({
      'status': 'active',
      'roles': ['enacteur'],
    });
    expect(
      UserExperience.canAccessPath(member, '/veille/records/task/id'),
      isTrue,
    );
    final alumni = UserExperience.fromJson({
      'status': 'alumni',
      'roles': ['alumni'],
    });
    expect(UserExperience.canAccessPath(alumni, '/veille'), isFalse);
  });
  test('Veille role has a human readable member label', () {
    const member = MemberModel(
      id: 'm',
      email: 'm@example.test',
      roles: ['enacteur', 'pole_veille'],
    );
    expect(member.primaryRoleLabel, 'Pôle Veille');
    expect(member.rolesLabel, contains('Pôle Veille'));
  });
}
