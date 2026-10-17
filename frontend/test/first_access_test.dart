import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/first_access/screens/activation_screen.dart';
import 'package:frontend/features/first_access/screens/first_access_gate.dart';
import 'package:frontend/features/first_access/screens/first_access_management_screen.dart';
import 'package:frontend/features/first_access/services/first_access_service.dart';

class FakeFirstAccess extends FirstAccessService {
  bool pending = true, failLoad = false, failSave = false;
  int saveAttempts = 0;
  bool loggedOut = false;
  Map<String, dynamic>? saved;
  List<String> requested = [];
  List<String>? activated;
  List<String>? recovered;
  List<Map<String, dynamic>>? customInventory;
  @override
  Future<String> recoverContact(
    String id,
    String email,
    String phone,
    String note,
    String expectedEmail,
  ) async {
    recovered = [id, email, phone, note, expectedEmail];
    return 'Accès préparé.';
  }

  Map<String, dynamic> profile = {
    'profile_type': 'enacteur',
    'first_name': 'Synthetic',
    'last_name': 'Member',
    'email': 'member@example.com',
    'username': 'synthetic.member',
    'phone': '+221 770000000',
    'gender': 'femme',
    'enactus_join_year': 2020,
    'department': 'Gestion',
    'cursus': 'DUT',
    'study_level': 'DUT2',
  };
  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<bool> needsOnboarding() async {
    if (failLoad) throw Exception('unavailable');
    return pending;
  }

  @override
  Future<Map<String, dynamic>> status() async => profile;
  @override
  Future<Map<String, dynamic>> catalog() async => {
    'departments': {
      'Gestion': {
        'DUT': ['DUT1', 'DUT2'],
        'Licence': ['Licence1', 'Licence2', 'Licence3'],
      },
    },
  };
  @override
  Future<void> complete(Map<String, dynamic> data) async {
    saveAttempts++;
    if (failSave) throw Exception('Enregistrement impossible.');
    saved = data;
    pending = false;
  }

  @override
  Future<String> requestActivation(String identifier) async {
    requested.add(identifier);
    return 'Si votre compte est prêt, un code vous sera envoyé.';
  }

  @override
  Future<void> activate(String identifier, String code, String password) async {
    activated = [identifier, code, password];
  }

  @override
  Future<List<Map<String, dynamic>>> inventory() async =>
      customInventory ??
      [
        {
          'id': 'one',
          'display_name': 'Membre sans contact',
          'email': 'placeholder@enactspace.local',
          'username': 'member.one',
          'state': 'contact_missing',
          'can_invite': false,
          'can_prepare_contact': true,
        },
        {
          'id': 'two',
          'display_name': 'Membre prêt',
          'email': 'member@example.com',
          'username': 'member.two',
          'state': 'ready',
          'can_invite': true,
          'can_prepare_contact': true,
        },
      ];
}

Future<void> pumpGate(
  WidgetTester tester,
  FakeFirstAccess service, {
  bool dark = false,
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: FirstAccessGate(
        service: service,
        child: const Scaffold(body: Text('ACTIVITIES')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openProfile(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Compléter mon profil'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Compléter mon profil'));
  await tester.pumpAndSettle();
}

Future<void> saveProfile(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Enregistrer mon profil'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Enregistrer mon profil'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mandatory profile prevents access until saved and tour finished',
    (tester) async {
      final service = FakeFirstAccess();
      await pumpGate(tester, service);
      expect(find.text('ACTIVITIES'), findsNothing);
      await openProfile(tester);
      expect(find.byKey(const ValueKey('first_name')), findsOneWidget);
      await saveProfile(tester);
      expect(service.saved?['enactus_join_year'], 2020);
      expect(service.saved?['study_level'], 'DUT2');
      expect(find.text('ACTIVITIES'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Entrer dans mon espace'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrer dans mon espace'));
      await tester.pumpAndSettle();
      expect(find.text('ACTIVITIES'), findsOneWidget);
    },
  );
  testWidgets('completed users retain immediate access', (tester) async {
    await pumpGate(tester, FakeFirstAccess()..pending = false);
    expect(find.text('ACTIVITIES'), findsOneWidget);
  });
  testWidgets('failed loading blocks private content and supports retry', (
    tester,
  ) async {
    final service = FakeFirstAccess()..failLoad = true;
    await pumpGate(tester, service);
    expect(find.text('ACTIVITIES'), findsNothing);
    service.failLoad = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Compléter mon profil'), findsOneWidget);
  });
  testWidgets(
    'alumni welcome and graduation field replace current study level',
    (tester) async {
      final service = FakeFirstAccess();
      service.profile.addAll({
        'profile_type': 'alumni',
        'graduation_year': 2024,
      });
      await pumpGate(tester, service);
      await openProfile(tester);
      expect(find.text('Niveau actuel'), findsNothing);
      expect(find.byKey(const ValueKey('graduation_year')), findsOneWidget);
      await saveProfile(tester);
      expect(service.saved?['graduation_year'], 2024);
    },
  );
  testWidgets('unknown imported academic values do not crash dropdowns', (
    tester,
  ) async {
    final service = FakeFirstAccess();
    service.profile.addAll({
      'cursus': 'old unknown',
      'study_level': 'old unknown',
    });
    await pumpGate(tester, service);
    await openProfile(tester);
    await saveProfile(tester);
    expect(service.saved, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed save retains profile and does not unlock access', (
    tester,
  ) async {
    final service = FakeFirstAccess()..failSave = true;
    await pumpGate(tester, service);
    await openProfile(tester);
    await saveProfile(tester);
    expect(find.text('ACTIVITIES'), findsNothing);
    expect(service.saved, isNull);
    expect(service.saveAttempts, 1);
    final name = tester.widget<TextFormField>(
      find.byKey(const ValueKey('first_name')),
    );
    expect(name.controller!.text, 'Synthetic');
  });
  testWidgets('current academic year is submitted with the profile', (
    tester,
  ) async {
    final service = FakeFirstAccess();
    service.profile.addAll({
      'academic_year_id': 'current-year',
      'academic_year_name': '2026–2027',
    });
    await pumpGate(tester, service);
    await openProfile(tester);
    await saveProfile(tester);
    expect(service.saved?['academic_year_id'], 'current-year');
  });
  testWidgets(
    'already-confirmed academic choices cannot be rewritten during welcome',
    (tester) async {
      final service = FakeFirstAccess();
      service.profile.addAll({
        'academic_year_id': 'current-year',
        'academic_year_name': '2026–2027',
        'academic_year_confirmed': true,
      });
      await pumpGate(tester, service);
      await openProfile(tester);
      for (final label in ['Département ESP', 'Cursus', 'Niveau actuel']) {
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(
            ValueKey(
              '$label:${{'Département ESP': 'Gestion', 'Cursus': 'DUT', 'Niveau actuel': 'DUT2'}[label]!}',
            ),
          ),
        );
        expect(dropdown.onChanged, isNull);
      }
      await saveProfile(tester);
      expect(service.saved?['study_level'], 'DUT2');
    },
  );
  testWidgets('missing trusted email cannot skip the profile prerequisite', (
    tester,
  ) async {
    final service = FakeFirstAccess();
    service.profile['contact_ready'] = false;
    await pumpGate(tester, service);
    await tester.scrollUntilVisible(
      find.text('Compléter mon profil'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Compléter mon profil'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('ACTIVITIES'), findsNothing);
  });
  for (final width in [320.0, 1024.0]) {
    testWidgets('dark welcome profile and tour fit width $width at 200% text', (
      tester,
    ) async {
      final service = FakeFirstAccess();
      await pumpGate(tester, service, dark: true, width: width, scale: 2);
      expect(tester.takeException(), isNull);
      await openProfile(tester);
      expect(tester.takeException(), isNull);
      await saveProfile(tester);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('activation confirms password and returns to regular login', (
    tester,
  ) async {
    final service = FakeFirstAccess();
    final router = GoRouter(
      initialLocation: '/activate',
      routes: [
        GoRoute(
          path: '/activate',
          builder: (context, state) => ActivationScreen(service: service),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('LOGIN')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'synthetic.member',
    );
    await tester.tap(find.text('Recevoir mon code'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '12345678');
    await tester.enterText(fields.at(2), 'My own password 2026');
    await tester.enterText(fields.at(3), 'different password');
    await tester.ensureVisible(find.text('Créer mon mot de passe'));
    await tester.tap(find.text('Créer mon mot de passe'));
    await tester.pumpAndSettle();
    expect(service.activated, isNull);
    await tester.enterText(fields.at(3), 'My own password 2026');
    await tester.ensureVisible(find.text('Créer mon mot de passe'));
    await tester.tap(find.text('Créer mon mot de passe'));
    await tester.pumpAndSettle();
    expect(service.activated, [
      'synthetic.member',
      '12345678',
      'My own password 2026',
    ]);
    expect(find.text('LOGIN'), findsOneWidget);
  });
  testWidgets(
    'management hides placeholder and disables invitation without verified contact',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FirstAccessManagementScreen(service: FakeFirstAccess()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('placeholder@enactspace.local'), findsNothing);
      expect(find.text('Adresse à compléter'), findsOneWidget);
      final buttons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      expect(buttons.first.onPressed, isNull);
      expect(buttons.last.onPressed, isNotNull);
    },
  );
  testWidgets(
    'used-account recovery requires identity acknowledgment and a meaningful note',
    (tester) async {
      final service = FakeFirstAccess()
        ..customInventory = [
          {
            'id': 'used',
            'display_name': 'Compte utilisé',
            'email': 'old@example.com',
            'username': 'used.member',
            'state': 'contact_missing',
            'can_invite': false,
            'can_prepare_contact': false,
            'can_prepare_recovery': true,
          },
        ];
      await tester.pumpWidget(
        MaterialApp(home: FirstAccessManagementScreen(service: service)),
      );
      await tester.pumpAndSettle();
      final contact = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Vérifier le contact'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(contact.onPressed, isNull);
      await tester.tap(find.text('Récupérer l’accès'));
      await tester.pumpAndSettle();
      final submit = find.ancestor(
        of: find.text('Enregistrer'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(service.recovered, isNull);
      expect(find.text('Décrivez la vérification réalisée.'), findsOneWidget);
      await tester.enterText(
        fields.at(1),
        'Identité confirmée en personne avec le membre.',
      );
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(service.recovered, [
        'used',
        'new@example.com',
        '',
        'Identité confirmée en personne avec le membre.',
        'old@example.com',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
