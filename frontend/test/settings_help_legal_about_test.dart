import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:frontend/app/app_router.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/appearance_controller.dart';
import 'package:frontend/features/about/screens/about_screen.dart';
import 'package:frontend/features/about/services/app_info_provider.dart';
import 'package:frontend/features/help/models/help_models.dart';
import 'package:frontend/features/help/screens/help_screen.dart';
import 'package:frontend/features/help/services/help_gateway.dart';
import 'package:frontend/features/legal/models/legal_models.dart';
import 'package:frontend/features/legal/screens/public_legal_screen.dart';
import 'package:frontend/features/legal/services/legal_gateway.dart';
import 'package:frontend/features/legal/widgets/legal_acceptance_gate.dart';
import 'package:frontend/features/settings/controllers/settings_controller.dart';
import 'package:frontend/features/settings/models/settings_models.dart';
import 'package:frontend/features/settings/screens/settings_screen.dart';
import 'package:frontend/features/settings/services/settings_gateway.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('routes utilitaires', () {
    test(
      'settings/help sont authentifiés sans modifier les modules métier',
      () {
        final member = _user();
        final alumni = _user(status: 'alumni', roles: const {'alumni'});
        expect(AppRouter.isPublicPath('/settings'), isFalse);
        expect(AppRouter.isPublicPath('/help'), isFalse);
        expect(UserExperience.canAccessPath(null, '/settings'), isFalse);
        expect(UserExperience.canAccessPath(member, '/settings'), isTrue);
        expect(UserExperience.canAccessPath(member, '/help'), isTrue);
        expect(UserExperience.canAccessPath(alumni, '/settings'), isTrue);
        expect(
          UserExperience.visibleRoutesFor(member),
          isNot(contains('/settings')),
        );
        expect(
          UserExperience.visibleRoutesFor(member),
          isNot(contains('/help')),
        );
      },
    );

    test('legal et about sont publics', () {
      expect(AppRouter.isPublicPath('/legal/privacy'), isTrue);
      expect(AppRouter.isPublicPath('/legal/terms'), isTrue);
      expect(AppRouter.isPublicPath('/about'), isTrue);
      expect(AppRouter.isPublicPath('/dashboard'), isFalse);
    });
  });

  group('apparence et préférences', () {
    test(
      'cache, serveur et changements light/dark/system sont immédiats',
      () async {
        final store = _AppearanceStore('dark');
        final appearance = AppearanceController(store: store);
        await appearance.loadCached();
        expect(appearance.themeMode, ThemeMode.dark);

        final gateway = _SettingsGateway(
          preferences: const UserPreferences(
            locale: 'fr',
            theme: 'light',
            inAppNotifications: true,
            emailNotifications: true,
            pushNotifications: true,
          ),
        );
        final controller = SettingsController(
          gateway: gateway,
          appearance: appearance,
        );
        await controller.load();
        expect(appearance.themeMode, ThemeMode.light);
        await controller.setTheme(AppAppearance.dark);
        expect(appearance.themeMode, ThemeMode.dark);
        expect(gateway.patches.last, {'theme': 'dark'});
        await controller.setTheme(AppAppearance.system);
        expect(appearance.themeMode, ThemeMode.system);
        expect(store.writes.last, 'system');
      },
    );

    test(
      'chaque notification PATCH est isolé et préserve push/locale',
      () async {
        final gateway = _SettingsGateway();
        final controller = SettingsController(
          gateway: gateway,
          appearance: AppearanceController(store: _AppearanceStore()),
        );
        await controller.load();
        await controller.setInAppNotifications(false);
        await controller.setEmailNotifications(false);
        expect(gateway.patches[0], {'notification_in_app_enabled': false});
        expect(gateway.patches[1], {'notification_email_enabled': false});
        expect(
          gateway.patches.expand((item) => item.keys),
          isNot(contains('notification_push_enabled')),
        );
        expect(
          gateway.patches.expand((item) => item.keys),
          isNot(contains('locale')),
        );
      },
    );

    test('un échec de lecture du cache conserve le thème système', () async {
      final appearance = AppearanceController(
        store: _AppearanceStore('dark', true),
      );
      await appearance.loadCached();
      expect(appearance.themeMode, ThemeMode.system);
    });

    test(
      'un échec d’écriture conserve le thème choisi et tente le PATCH',
      () async {
        final gateway = _SettingsGateway();
        final appearance = AppearanceController(
          store: _AppearanceStore(null, false, true),
        );
        final controller = SettingsController(
          gateway: gateway,
          appearance: appearance,
        );
        await controller.setTheme(AppAppearance.dark);
        expect(appearance.themeMode, ThemeMode.dark);
        expect(gateway.patches, [
          {'theme': 'dark'},
        ]);
      },
    );

    test('les erreurs de synchronisation décrivent le vrai état', () async {
      final gateway = _SettingsGateway()..failPatches = true;
      final appearance = AppearanceController(store: _AppearanceStore());
      final controller = SettingsController(
        gateway: gateway,
        appearance: appearance,
      );

      expect(await controller.setTheme(AppAppearance.dark), isFalse);
      expect(appearance.themeMode, ThemeMode.dark);
      expect(controller.error, contains('thème est appliqué'));

      expect(await controller.setInAppNotifications(false), isFalse);
      expect(controller.error, contains('n’a pas pu être enregistrée'));
      expect(controller.error, isNot(contains('appliqué sur cet appareil')));

      expect(await controller.setEmailNotifications(false), isFalse);
      expect(gateway.patches, [
        {'theme': 'dark'},
        {'notification_in_app_enabled': false},
        {'notification_email_enabled': false},
      ]);
      expect(
        gateway.patches.expand((patch) => patch.keys),
        isNot(containsAll(['notification_push_enabled', 'locale'])),
      );
    });

    test(
      'le cache d’apparence ne contient aucun secret d’authentification',
      () {
        final source = File(
          'lib/core/theme/appearance_controller.dart',
        ).readAsStringSync();
        expect(
          SharedPreferencesAppearanceStore.key,
          'enactspace.appearance.theme',
        );
        expect(source, isNot(contains('access_token')));
        expect(source, isNot(contains('refresh_token')));
      },
    );
  });

  group('écran réglages', () {
    testWidgets('dark/narrow reste lisible, sans push et avec français', (
      tester,
    ) async {
      _narrow(tester);
      final appearance = AppearanceController(store: _AppearanceStore('dark'));
      await appearance.loadCached();
      final controller = SettingsController(
        gateway: _SettingsGateway(),
        appearance: appearance,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Réglages'), findsWidgets);
      expect(find.text('Français'), findsOneWidget);
      expect(find.textContaining('push', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('export ne copie rien avant confirmation explicite', (
      tester,
    ) async {
      final gateway = _SettingsGateway();
      final controller = SettingsController(
        gateway: gateway,
        appearance: AppearanceController(store: _AppearanceStore()),
      );
      var clipboardWrites = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') clipboardWrites++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.text('Exporter mes données'),
        const Key('settings-scroll'),
      );
      await tester.tap(find.text('Exporter mes données'));
      await tester.pumpAndSettle();
      expect(gateway.exportRequests, 1);
      expect(find.textContaining('informations sensibles'), findsOneWidget);
      expect(clipboardWrites, 0);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(clipboardWrites, 0);
    });

    testWidgets('demande de suppression confirmée, affichée puis annulée', (
      tester,
    ) async {
      final gateway = _SettingsGateway();
      final controller = SettingsController(
        gateway: gateway,
        appearance: AppearanceController(store: _AppearanceStore()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.text('Demander la suppression de mon compte'),
        const Key('settings-scroll'),
      );
      await tester.tap(find.text('Demander la suppression de mon compte'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pas supprimé immédiatement'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Je quitte le club');
      await tester.tap(find.text('Envoyer la demande'));
      await tester.pumpAndSettle();
      expect(gateway.deletionReason, 'Je quitte le club');
      expect(find.text('État : En attente'), findsOneWidget);
      expect(find.text('Envoyer une nouvelle demande'), findsNothing);
      expect(find.textContaining('admin_note'), findsNothing);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();
      expect(find.text('État : Annulée'), findsOneWidget);
      expect(find.text('Envoyer une nouvelle demande'), findsOneWidget);
    });

    testWidgets('une demande rejetée peut être renouvelée', (tester) async {
      final gateway = _SettingsGateway()
        ..deletion = AccountDeletionRequest(
          id: 'd-rejected',
          status: 'rejected',
          requestedAt: DateTime(2026, 9, 5),
        );
      final controller = SettingsController(
        gateway: gateway,
        appearance: AppearanceController(store: _AppearanceStore()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('État : Refusée'), findsOneWidget);
      expect(find.text('Envoyer une nouvelle demande'), findsOneWidget);
      expect(find.textContaining('admin_note'), findsNothing);
    });

    testWidgets('pending et approved ne proposent aucun doublon', (
      tester,
    ) async {
      for (final status in const ['pending', 'approved']) {
        final gateway = _SettingsGateway()
          ..deletion = AccountDeletionRequest(
            id: 'd-$status',
            status: status,
            requestedAt: DateTime(2026, 9, 5),
          );
        final controller = SettingsController(
          gateway: gateway,
          appearance: AppearanceController(store: _AppearanceStore()),
        );
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(status),
            home: Scaffold(body: SettingsScreen(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Envoyer une nouvelle demande'),
          findsNothing,
          reason: status,
        );
      }
    });

    testWidgets(
      'actions de sécurité utilisent AuthService après confirmation',
      (tester) async {
        final auth = _AuthService();
        final controller = SettingsController(
          gateway: _SettingsGateway(),
          appearance: AppearanceController(store: _AppearanceStore()),
        );
        final router = GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => Scaffold(
                body: SettingsScreen(controller: controller, authService: auth),
              ),
            ),
            GoRoute(
              path: '/login',
              builder: (_, _) => const Scaffold(body: Text('Connexion')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.text('Déconnecter tous mes appareils'),
          const Key('settings-scroll'),
        );
        await tester.tap(find.text('Déconnecter tous mes appareils'));
        await tester.pumpAndSettle();
        expect(auth.logoutAllCalls, 0);
        await tester.tap(find.text('Déconnecter'));
        await tester.pump();
        expect(auth.logoutAllCalls, 1);
      },
    );
  });

  group('aide, tickets et avis', () {
    testWidgets('les avis affichent un chargement avant un vrai état vide', (
      tester,
    ) async {
      final gateway = _HelpGateway()
        ..feedbackCompleter = Completer<List<ProductFeedback>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HelpScreen(gateway: gateway)),
        ),
      );
      await tester.pump();
      expect(find.text('Chargement de vos avis…'), findsOneWidget);
      expect(find.text('Aucun avis envoyé pour le moment.'), findsNothing);
      expect(find.text('Aucun ticket pour le moment.'), findsOneWidget);

      gateway.feedbackCompleter!.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('Chargement de vos avis…'), findsNothing);
      expect(find.text('Aucun avis envoyé pour le moment.'), findsOneWidget);
    });

    testWidgets('une erreur des avis est explicite et réessayable', (
      tester,
    ) async {
      final gateway = _HelpGateway()..failFeedback = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HelpScreen(gateway: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Impossible de charger vos avis.'), findsOneWidget);
      expect(find.text('Aucun avis envoyé pour le moment.'), findsNothing);
      expect(find.text('Aucun ticket pour le moment.'), findsOneWidget);

      gateway.failFeedback = false;
      await _scrollTo(tester, find.text('Réessayer'), const Key('help-scroll'));
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(gateway.feedbackLoads, 2);
      expect(find.text('Impossible de charger vos avis.'), findsNothing);
      expect(find.text('Aucun avis envoyé pour le moment.'), findsOneWidget);
    });

    testWidgets('liste vide, création ticket et avis sans note', (
      tester,
    ) async {
      final gateway = _HelpGateway();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: HelpScreen(gateway: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aucun ticket pour le moment.'), findsOneWidget);
      expect(find.text('Aucun avis envoyé pour le moment.'), findsOneWidget);
      await _scrollTo(
        tester,
        find.text('Nouvelle demande'),
        const Key('help-scroll'),
      );
      await tester.tap(find.text('Nouvelle demande'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Connexion');
      await tester.enterText(
        find.byType(TextField).last,
        'Je ne peux pas entrer',
      );
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(gateway.createdTickets, 1);
      expect(find.text('Connexion'), findsOneWidget);

      await _scrollTo(
        tester,
        find.text('Donner mon avis'),
        const Key('help-scroll'),
      );
      await tester.tap(find.text('Donner mon avis'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('feedback-message-field')),
        'Une idée utile',
      );
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();
      expect(gateway.createdFeedback, 1);
      expect(gateway.lastRating, isNull);
    });

    testWidgets('détail actif affiche conversation et permet une réponse', (
      tester,
    ) async {
      final gateway = _HelpGateway.withTicket(closed: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HelpScreen(gateway: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Besoin d’aide'), findsOneWidget);
      await _scrollTo(
        tester,
        find.text('Besoin d’aide'),
        const Key('help-scroll'),
      );
      await tester.tap(find.text('Besoin d’aide'));
      await tester.pumpAndSettle();
      expect(find.text('Premier message'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ticket-reply-field')),
        'Merci',
      );
      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();
      expect(gateway.replies, 1);
      expect(find.text('Merci'), findsOneWidget);
    });

    testWidgets(
      'ticket fermé désactive la réponse et aide supporte le sombre étroit',
      (tester) async {
        _narrow(tester);
        final gateway = _HelpGateway.withTicket(closed: true);
        await tester.pumpWidget(
          MaterialApp(
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: Scaffold(body: HelpScreen(gateway: gateway)),
          ),
        );
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.text('Besoin d’aide'),
          const Key('help-scroll'),
        );
        await tester.tap(find.text('Besoin d’aide'));
        await tester.pumpAndSettle();
        expect(
          find.text('Ce ticket est fermé. Les réponses sont désactivées.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ticket-reply-field')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    test('feedback utilisateur accepte 1 à 5 et ignore admin_note', () {
      final item = ProductFeedback.fromJson({
        'id': 'f1',
        'category': 'idea',
        'message': 'Avis',
        'rating': 5,
        'status': 'new',
        'created_at': '2026-09-06T10:00:00',
        'admin_note': 'interne',
      });
      expect(item.rating, 5);
      expect(item.categoryLabel, 'Idée');
      expect(ProductFeedback.fromJson({'rating': 1}).rating, 1);
      expect(
        File('lib/features/help/models/help_models.dart').readAsStringSync(),
        isNot(contains('admin_note')),
      );
    });
  });

  group('documents légaux', () {
    testWidgets(
      'privacy et terms affichent le contenu serveur long et scrollable',
      (tester) async {
        _narrow(tester);
        final gateway = _LegalGateway.withDocuments();
        await tester.pumpWidget(
          MaterialApp(
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: PublicLegalScreen(
              documentType: 'privacy_policy',
              gateway: gateway,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Confidentialité EnactSpace'), findsWidgets);
        expect(find.textContaining('Contenu officiel'), findsOneWidget);
        expect(find.byKey(const Key('legal-document-scroll')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            home: PublicLegalScreen(
              documentType: 'terms_of_use',
              gateway: gateway,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Conditions EnactSpace'), findsWidgets);
      },
    );

    testWidgets('absence et erreur ont des états explicites avec retry', (
      tester,
    ) async {
      final empty = _LegalGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicLegalScreen(
            documentType: 'privacy_policy',
            gateway: empty,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Aucun document actif'), findsOneWidget);

      final failing = _LegalGateway()..failDocuments = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PublicLegalScreen(
            documentType: 'terms_of_use',
            gateway: failing,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Impossible de charger'), findsOneWidget);
    });

    testWidgets('un document actif différent ne peut jamais être accepté', (
      tester,
    ) async {
      const pending = LegalStatus(
        type: 'privacy_policy',
        documentId: 'privacy-p1',
        version: '1',
        requiresAcceptance: true,
        accepted: false,
      );
      final activeP2 = _LegalGateway._document(
        'privacy_policy',
        'Politique active P2',
        id: 'privacy-p2',
        version: '2',
      );
      final gateway = _LegalGateway()
        ..documents = {'privacy_policy': activeP2}
        ..publishedDocuments = [activeP2]
        ..statuses = const [pending];

      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceGate(
            gateway: gateway,
            onLogout: () async {},
            child: const Text('Application'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Application'), findsNothing);
      expect(find.text('Politique active P2'), findsNothing);
      expect(find.text('J’accepte'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(gateway.acceptances, 0);
    });

    testWidgets('la gate affiche et accepte exactement P1 v1', (tester) async {
      const pending = LegalStatus(
        type: 'privacy_policy',
        documentId: 'privacy-p1',
        version: '1',
        requiresAcceptance: true,
        accepted: false,
      );
      final p1 = _LegalGateway._document(
        'privacy_policy',
        'Politique référencée P1',
        id: 'privacy-p1',
        version: '1',
      );
      final activeP2 = _LegalGateway._document(
        'privacy_policy',
        'Politique active P2',
        id: 'privacy-p2',
        version: '2',
      );
      final gateway = _LegalGateway()
        ..documents = {'privacy_policy': activeP2}
        ..publishedDocuments = [activeP2, p1]
        ..statuses = const [pending];

      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceGate(
            gateway: gateway,
            child: const Text('Application'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Politique référencée P1'), findsOneWidget);
      expect(find.text('Politique active P2'), findsNothing);
      expect(find.text('Version 1'), findsOneWidget);
      expect(gateway.acceptances, 0);

      await tester.tap(find.text('J’accepte'));
      await tester.pumpAndSettle();
      expect(gateway.acceptances, 1);
      expect(gateway.acceptedStatuses.single.documentId, 'privacy-p1');
      expect(gateway.acceptedStatuses.single.version, '1');
      expect(find.text('Application'), findsOneWidget);
    });

    testWidgets('une référence indisponible bloque avec retry et logout', (
      tester,
    ) async {
      final gateway = _LegalGateway()
        ..statuses = const [
          LegalStatus(
            type: 'privacy_policy',
            documentId: 'privacy-missing',
            version: '7',
            requiresAcceptance: true,
            accepted: false,
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceGate(
            gateway: gateway,
            onLogout: () async {},
            child: const Text('Application'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Application'), findsNothing);
      expect(find.text('J’accepte'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(gateway.acceptances, 0);
    });

    testWidgets('plusieurs documents requis sont traités séquentiellement', (
      tester,
    ) async {
      final privacy = _LegalGateway._document(
        'privacy_policy',
        'Politique P1',
        id: 'privacy-p1',
        version: '1',
      );
      final terms = _LegalGateway._document(
        'terms_of_use',
        'Conditions T3',
        id: 'terms-t3',
        version: '3',
      );
      final gateway = _LegalGateway()
        ..publishedDocuments = [privacy, terms]
        ..statuses = const [
          LegalStatus(
            type: 'privacy_policy',
            documentId: 'privacy-p1',
            version: '1',
            requiresAcceptance: true,
            accepted: false,
          ),
          LegalStatus(
            type: 'terms_of_use',
            documentId: 'terms-t3',
            version: '3',
            requiresAcceptance: true,
            accepted: false,
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: LegalAcceptanceGate(
            gateway: gateway,
            child: const Text('Application'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Politique P1'), findsOneWidget);
      await tester.tap(find.text('J’accepte'));
      await tester.pumpAndSettle();
      expect(find.text('Conditions T3'), findsOneWidget);
      expect(find.text('Application'), findsNothing);
      await tester.tap(find.text('J’accepte'));
      await tester.pumpAndSettle();
      expect(find.text('Application'), findsOneWidget);
      expect(gateway.acceptedStatuses.map((status) => status.documentId), [
        'privacy-p1',
        'terms-t3',
      ]);
    });

    testWidgets(
      'acceptation requise bloque puis libère seulement après action',
      (tester) async {
        final gateway = _LegalGateway.pending();
        await tester.pumpWidget(
          MaterialApp(
            home: LegalAcceptanceGate(
              gateway: gateway,
              testIsWeb: false,
              testPlatform: TargetPlatform.android,
              child: const Text('Coquille authentifiée'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Coquille authentifiée'), findsNothing);
        expect(find.text('J’accepte'), findsOneWidget);
        expect(gateway.acceptances, 0);
        await tester.tap(find.text('J’accepte'));
        await tester.pumpAndSettle();
        expect(gateway.acceptances, 1);
        expect(gateway.lastSource, 'android');
        expect(find.text('Coquille authentifiée'), findsOneWidget);
      },
    );

    testWidgets('non requis et déjà accepté ne bloquent pas', (tester) async {
      for (final status in [
        const LegalStatus(
          type: 'privacy_policy',
          documentId: 'p1',
          version: '1',
          requiresAcceptance: false,
          accepted: true,
        ),
        const LegalStatus(
          type: 'terms_of_use',
          documentId: 't1',
          version: '1',
          requiresAcceptance: true,
          accepted: true,
        ),
      ]) {
        final gateway = _LegalGateway()..statuses = [status];
        await tester.pumpWidget(
          MaterialApp(
            home: LegalAcceptanceGate(
              gateway: gateway,
              child: const Text('Application'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Application'), findsOneWidget);
      }
    });

    testWidgets(
      'échec de statut ne simule pas un accord et offre retry/logout',
      (tester) async {
        final gateway = _LegalGateway()..failStatus = true;
        await tester.pumpWidget(
          MaterialApp(
            home: LegalAcceptanceGate(
              gateway: gateway,
              onLogout: () async {},
              child: const Text('Application'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Application'), findsNothing);
        expect(find.text('Réessayer'), findsOneWidget);
        expect(find.text('Se déconnecter'), findsOneWidget);
        expect(gateway.acceptances, 0);
      },
    );

    test('source web/android/ios/debug est correcte', () {
      expect(
        legalAcceptanceSource(isWeb: true, platform: TargetPlatform.windows),
        'web',
      );
      expect(
        legalAcceptanceSource(isWeb: false, platform: TargetPlatform.android),
        'android',
      );
      expect(
        legalAcceptanceSource(isWeb: false, platform: TargetPlatform.iOS),
        'ios',
      );
      expect(
        legalAcceptanceSource(isWeb: false, platform: TargetPlatform.windows),
        'api',
      );
    });
  });

  testWidgets(
    'About affiche identité, version injectée et liens légaux sans faux contact',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AboutScreen(infoProvider: _AppInfoProvider())),
      );
      await tester.pumpAndSettle();
      expect(find.text('EnactSpace'), findsOneWidget);
      expect(find.text('L’impact en mouvement'), findsOneWidget);
      expect(find.text('Enactus ESP'), findsOneWidget);
      expect(
        find.text('V1 conçue et développée par Chicodev — 2026'),
        findsOneWidget,
      );
      expect(find.text('Maintenance : Pôle IT — Enactus ESP'), findsOneWidget);
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
      expect(find.text('Politique de confidentialité'), findsOneWidget);
      expect(find.text('Conditions d’utilisation'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('http'), findsNothing);
    },
  );
}

void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder target,
  Key scrollKey,
) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.descendant(
      of: find.byKey(scrollKey),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

UserExperience _user({
  String status = 'active',
  Set<String> roles = const {'enacteur'},
}) => UserExperience(
  id: 'u1',
  email: 'member@example.test',
  displayName: 'Membre',
  status: status,
  gender: null,
  profileType: status == 'alumni' ? 'alumni' : 'enacteur',
  roles: roles,
  canReviewJoinRequests: false,
);

class _AppearanceStore implements AppearancePreferenceStore {
  String? value;
  final List<String> writes = [];
  final bool throwOnRead;
  final bool throwOnWrite;

  _AppearanceStore([
    this.value,
    this.throwOnRead = false,
    this.throwOnWrite = false,
  ]);
  @override
  Future<String?> read() async {
    if (throwOnRead) throw Exception('cache read unavailable');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (throwOnWrite) throw Exception('cache write unavailable');
    this.value = value;
    writes.add(value);
  }
}

class _SettingsGateway implements SettingsGateway {
  UserPreferences preferences;
  AccountDeletionRequest? deletion;
  final List<Map<String, dynamic>> patches = [];
  int exportRequests = 0;
  String? deletionReason;
  bool failPatches = false;

  _SettingsGateway({
    this.preferences = const UserPreferences(
      locale: 'fr',
      theme: 'system',
      inAppNotifications: true,
      emailNotifications: true,
      pushNotifications: true,
    ),
  });

  @override
  Future<UserPreferences> loadPreferences() async => preferences;
  @override
  Future<UserPreferences> updatePreferences(
    Map<String, dynamic> changes,
  ) async {
    patches.add(Map.of(changes));
    if (failPatches) throw Exception('sync unavailable');
    preferences = UserPreferences(
      locale: preferences.locale,
      theme: changes['theme']?.toString() ?? preferences.theme,
      inAppNotifications:
          changes['notification_in_app_enabled'] as bool? ??
          preferences.inAppNotifications,
      emailNotifications:
          changes['notification_email_enabled'] as bool? ??
          preferences.emailNotifications,
      pushNotifications: preferences.pushNotifications,
    );
    return preferences;
  }

  @override
  Future<AccountDataExport> requestDataExport() async {
    exportRequests++;
    return const AccountDataExport({
      'metadata': {
        'generated_at': '2026-09-06T10:00:00Z',
        'schema_version': '1.1',
      },
      'data': {
        'profile': {'name': 'Membre'},
      },
    });
  }

  @override
  Future<AccountDeletionRequest?> loadDeletionRequest() async => deletion;
  @override
  Future<AccountDeletionRequest> requestDeletion(String? reason) async {
    deletionReason = reason;
    deletion = AccountDeletionRequest(
      id: 'd1',
      status: 'pending',
      requestedAt: DateTime(2026, 9, 6),
      reason: reason,
    );
    return deletion!;
  }

  @override
  Future<AccountDeletionRequest> cancelDeletionRequest() async {
    deletion = AccountDeletionRequest(
      id: 'd1',
      status: 'cancelled',
      requestedAt: DateTime(2026, 9, 6),
      cancelledAt: DateTime(2026, 9, 6, 11),
      reason: deletion?.reason,
    );
    return deletion!;
  }
}

class _AuthService extends AuthService {
  int logoutCalls = 0;
  int logoutAllCalls = 0;
  @override
  Future<void> logout() async => logoutCalls++;
  @override
  Future<void> logoutAll() async => logoutAllCalls++;
}

class _HelpGateway implements HelpGateway {
  List<SupportTicket> tickets = [];
  List<ProductFeedback> feedback = [];
  int createdTickets = 0;
  int createdFeedback = 0;
  int replies = 0;
  int? lastRating;
  bool failFeedback = false;
  Completer<List<ProductFeedback>>? feedbackCompleter;
  int feedbackLoads = 0;

  _HelpGateway();
  _HelpGateway.withTicket({required bool closed}) {
    tickets = [
      SupportTicket(
        id: 't1',
        subject: 'Besoin d’aide',
        category: 'account',
        status: closed ? 'closed' : 'open',
        priority: 'normal',
        updatedAt: DateTime(2026, 9, 6),
        messages: [
          SupportMessage(
            id: 'm1',
            authorId: 'u1',
            message: 'Premier message',
            createdAt: DateTime(2026, 9, 6),
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<SupportTicket>> loadTickets() async => tickets;
  @override
  Future<SupportTicket> loadTicket(String id) async =>
      tickets.firstWhere((item) => item.id == id);
  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String message,
  }) async {
    createdTickets++;
    final ticket = SupportTicket(
      id: 'created',
      subject: subject,
      category: category,
      status: 'open',
      priority: priority,
      updatedAt: DateTime(2026, 9, 6),
    );
    tickets = [ticket, ...tickets];
    return ticket;
  }

  @override
  Future<SupportMessage> replyToTicket(String id, String message) async {
    replies++;
    return SupportMessage(
      id: 'm2',
      authorId: 'u1',
      message: message,
      createdAt: DateTime(2026, 9, 6),
    );
  }

  @override
  Future<List<ProductFeedback>> loadFeedback() async {
    feedbackLoads++;
    if (failFeedback) throw Exception('feedback unavailable');
    if (feedbackCompleter case final completer?) return completer.future;
    return feedback;
  }

  @override
  Future<ProductFeedback> createFeedback({
    required String category,
    required String message,
    int? rating,
    String? platform,
    String? appVersion,
    int? buildNumber,
  }) async {
    createdFeedback++;
    lastRating = rating;
    final item = ProductFeedback(
      id: 'f1',
      category: category,
      message: message,
      rating: rating,
      status: 'new',
      createdAt: DateTime(2026, 9, 6),
    );
    feedback = [item, ...feedback];
    return item;
  }
}

class _LegalGateway implements LegalGateway {
  Map<String, LegalDocument> documents = {};
  List<LegalDocument> publishedDocuments = [];
  List<LegalStatus> statuses = [];
  bool failDocuments = false;
  bool failStatus = false;
  int acceptances = 0;
  String? lastSource;
  final List<LegalStatus> acceptedStatuses = [];

  _LegalGateway();
  _LegalGateway.withDocuments() {
    documents = {
      'privacy_policy': _document(
        'privacy_policy',
        'Confidentialité EnactSpace',
      ),
      'terms_of_use': _document('terms_of_use', 'Conditions EnactSpace'),
    };
    publishedDocuments = documents.values.toList();
  }
  _LegalGateway.pending() {
    documents = {
      'privacy_policy': _document(
        'privacy_policy',
        'Confidentialité EnactSpace',
      ),
    };
    publishedDocuments = documents.values.toList();
    statuses = const [
      LegalStatus(
        type: 'privacy_policy',
        documentId: 'privacy_policy-id',
        version: '1.0',
        requiresAcceptance: true,
        accepted: false,
      ),
    ];
  }

  static LegalDocument _document(
    String type,
    String title, {
    String? id,
    String version = '1.0',
  }) => LegalDocument(
    id: id ?? '$type-id',
    type: type,
    version: version,
    title: title,
    content: List.filled(
      20,
      'Contenu officiel fourni par Enactus ESP.',
    ).join('\n'),
    effectiveAt: DateTime(2026, 9, 6),
    requiresAcceptance: true,
  );

  @override
  Future<LegalDocument?> loadPublicDocument(String type) async {
    if (failDocuments) throw Exception('offline');
    return documents[type];
  }

  @override
  Future<LegalDocument?> loadDocumentForAcceptance(LegalStatus status) async {
    if (failDocuments) throw Exception('offline');
    return publishedDocuments
        .where((document) => document.matchesStatus(status))
        .firstOrNull;
  }

  @override
  Future<List<LegalStatus>> loadStatus() async {
    if (failStatus) throw Exception('offline');
    return statuses;
  }

  @override
  Future<void> accept(LegalStatus status, String source) async {
    acceptances++;
    lastSource = source;
    acceptedStatuses.add(status);
    statuses = statuses
        .map(
          (item) => item.documentId == status.documentId
              ? LegalStatus(
                  type: item.type,
                  documentId: item.documentId,
                  version: item.version,
                  requiresAcceptance: item.requiresAcceptance,
                  accepted: true,
                )
              : item,
        )
        .toList();
  }
}

class _AppInfoProvider implements AppInfoProvider {
  @override
  Future<AppInfo> load() async =>
      const AppInfo(version: '1.0.0', buildNumber: '1');
}
