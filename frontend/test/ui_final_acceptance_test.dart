import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/app_router.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/academy/models/academy_models.dart';
import 'package:frontend/features/academy/screens/academy_course_screen.dart';
import 'package:frontend/features/academy/services/academy_gateway.dart';
import 'package:frontend/features/archives/models/archive_contract_models.dart';
import 'package:frontend/features/archives/screens/archive_detail_screens.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/chat/models/chat_models.dart';
import 'package:frontend/features/chat/screens/chat_screen.dart';
import 'package:frontend/features/chat/services/chat_gateway.dart';
import 'package:frontend/features/chat/services/chat_service.dart';
import 'package:frontend/features/dashboard/models/dashboard_summary_model.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/dashboard/services/dashboard_gateway.dart';
import 'package:frontend/features/finance/models/payment_model.dart';
import 'package:frontend/features/finance/screens/finance_screen.dart';
import 'package:frontend/features/impact/models/impact_record_models.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/tasks/models/task_model.dart';
import 'package:frontend/shared/layout/app_shell.dart';

void main() {
  group('matrice routes', () {
    test('le router déclare les 43 routes finales attendues', () {
      final source = File('lib/app/app_router.dart').readAsStringSync();
      final declared = RegExp(
        r"path:\s*'([^']+)'",
      ).allMatches(source).map((match) => match.group(1)!).toList();

      expect(declared, hasLength(43));
      for (final path in const [
        '/splash',
        '/login',
        '/legal/privacy',
        '/legal/terms',
        '/about',
        '/application-tracking',
        '/recruitment/apply',
        ':campaignId',
        '/settings',
        '/help',
        '/dashboard',
        '/members',
        '/attendance',
        '/attendance/scan',
        '/attendance/nfc',
        '/tasks',
        ':taskId',
        '/finance',
        '/recruitment',
        '/documents',
        ':documentId',
        '/notifications',
        '/posts',
        '/chat',
        '/poles',
        ':poleId',
        '/projects',
        ':projectId',
        '/events',
        ':eventId',
        '/alumni',
        ':profileId',
        '/gamification',
        '/academy',
        'courses/:courseId',
        'admin',
        '/archives',
        'items/:archiveId',
        'projects/:projectId',
        'hall-of-fame/:entryId',
        '/impact',
        'records',
        ':impactRecordId',
      ]) {
        expect(declared, contains(path), reason: 'route absente : $path');
      }
    });

    test('les routes publiques restent strictement bornées', () {
      for (final path in const [
        '/splash',
        '/login',
        '/application-tracking',
        '/recruitment/apply',
        '/recruitment/apply/campagne-2026',
        '/legal/privacy',
        '/legal/terms',
        '/about',
      ]) {
        expect(AppRouter.isPublicPath(path), isTrue, reason: path);
      }
      for (final path in const [
        '/dashboard',
        '/tasks/task-1',
        '/archives/hall-of-fame/entry-1',
        '/recruitment',
        '/settings',
        '/help',
      ]) {
        expect(AppRouter.isPublicPath(path), isFalse, reason: path);
      }
    });

    test('les deep-links dynamiques suivent les gardes du module parent', () {
      final member = _user('membre', const {'enacteur'});
      final lead = _user('chef-projet', const {'chef_projet'});
      final alumni = _user('alumni', const {'alumni'}, status: 'alumni');

      for (final path in const [
        '/tasks/task-1',
        '/documents/document-1',
        '/events/event-1',
        '/academy/courses/course-1',
        '/archives/items/archive-1',
        '/archives/projects/project-1',
        '/archives/hall-of-fame/entry-1',
      ]) {
        expect(
          UserExperience.canAccessPath(member, path),
          isTrue,
          reason: path,
        );
      }
      expect(
        UserExperience.canAccessPath(member, '/projects/project-1'),
        isFalse,
      );
      expect(UserExperience.canAccessPath(lead, '/projects/project-1'), isTrue);
      expect(UserExperience.canAccessPath(alumni, '/tasks/task-1'), isFalse);
      expect(
        UserExperience.canAccessPath(alumni, '/archives/hall-of-fame/entry-1'),
        isTrue,
      );
      expect(UserExperience.canAccessPath(member, '/academy/admin'), isFalse);
      expect(UserExperience.canAccessPath(lead, '/academy/admin'), isFalse);
      expect(
        UserExperience.canAccessPath(
          _user('admin', const {'administrateur'}),
          '/academy/admin',
        ),
        isTrue,
      );
    });
  });

  group('matrice des 13 profils', () {
    test('utilisateur non connecté refusé sur toutes les routes internes', () {
      expect(UserExperience.canAccessPath(null, '/dashboard'), isFalse);
      expect(UserExperience.canAccessPath(null, '/posts'), isFalse);
      expect(UserExperience.canAccessPath(null, '/archives'), isFalse);
    });

    final profiles = <_ProfileExpectation>[
      _ProfileExpectation(
        'membre / enacteur',
        _user('membre', const {'enacteur'}),
        requiredRoutes: const {'/tasks', '/attendance', '/finance', '/events'},
        deniedRoutes: const {
          '/members',
          '/projects',
          '/impact',
          '/recruitment',
        },
      ),
      _ProfileExpectation(
        'chef de pôle',
        _user('chef-pole', const {'chef_pole'}),
        requiredRoutes: const {'/members', '/poles', '/projects', '/impact'},
      ),
      _ProfileExpectation(
        'adjoint chef de pôle',
        _user('adjoint-pole', const {'adjoint_chef_pole'}),
        requiredRoutes: const {'/members', '/poles', '/projects', '/impact'},
      ),
      _ProfileExpectation(
        'chef de projet',
        _user('chef-projet', const {'chef_projet'}),
        requiredRoutes: const {'/members', '/poles', '/projects', '/impact'},
      ),
      _ProfileExpectation(
        'adjoint chef de projet',
        _user('adjoint-projet', const {'adjoint_chef_projet'}),
        requiredRoutes: const {'/members', '/poles', '/projects', '/impact'},
      ),
      _ProfileExpectation(
        'financier',
        _user('finance', const {'financier'}),
        requiredRoutes: const {'/finance', '/poles', '/projects', '/impact'},
        deniedRoutes: const {'/members', '/alumni'},
      ),
      _ProfileExpectation(
        'Secrétaire Générale',
        _user('sg', const {'secretaire_generale'}),
        requiredRoutes: const {
          '/members',
          '/recruitment',
          '/impact',
          '/alumni',
        },
      ),
      _ProfileExpectation(
        'Team Leader',
        _user('tl', const {'team_leader'}),
        requiredRoutes: const {
          '/members',
          '/recruitment',
          '/impact',
          '/alumni',
        },
      ),
      _ProfileExpectation(
        'administrateur',
        _user('admin', const {'administrateur'}),
        requiredRoutes: const {
          '/members',
          '/finance',
          '/recruitment',
          '/impact',
          '/alumni',
        },
      ),
      _ProfileExpectation(
        'alumni',
        _user('alumni', const {'alumni'}, status: 'alumni'),
        requiredRoutes: const {
          '/posts',
          '/chat',
          '/events',
          '/academy',
          '/archives',
          '/alumni',
        },
        deniedRoutes: const {
          '/tasks',
          '/attendance',
          '/finance',
          '/projects',
          '/impact',
        },
      ),
      _ProfileExpectation(
        'recruteur',
        _user('recruteur', const {'recrutement'}),
        requiredRoutes: const {'/recruitment', '/events', '/attendance'},
        deniedRoutes: const {'/members', '/projects', '/impact'},
      ),
      _ProfileExpectation(
        'faculty advisor',
        _user('faculty', const {'faculty_advisor'}),
        requiredRoutes: const {'/poles', '/projects', '/impact'},
        deniedRoutes: const {'/members', '/alumni'},
      ),
    ];

    for (final profile in profiles) {
      test(profile.label, () {
        final routes = UserExperience.visibleRoutesFor(profile.user).toSet();
        expect(routes, containsAll({'/dashboard', '/posts', '/archives'}));
        expect(routes, containsAll(profile.requiredRoutes));
        for (final path in profile.deniedRoutes) {
          expect(routes, isNot(contains(path)), reason: '$path exposée');
          expect(
            UserExperience.canAccessPath(profile.user, path),
            isFalse,
            reason: '$path accessible directement',
          );
        }
      });
    }
  });

  group('navigation mobile et responsive', () {
    for (final scenario in const [
      (Size(390, 844), '/events', 'Événements'),
      (Size(375, 812), '/finance', 'Finance'),
    ]) {
      testWidgets(
        'la route secondaire ${scenario.$2} est sélectionnée à ${scenario.$1.width.toInt()} px',
        (tester) async {
          tester.view.physicalSize = scenario.$1;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                bottomNavigationBar: MobileBottomNavigation(
                  currentPath: scenario.$2,
                  userExperience: _user('membre', const {'enacteur'}),
                  unreadNotifications: 3,
                  unreadChatMessages: 2,
                  lateTasks: 1,
                ),
              ),
            ),
          );

          final navigation = tester.widget<NavigationBar>(
            find.byType(NavigationBar),
          );
          final selected =
              navigation.destinations[navigation.selectedIndex]
                  as NavigationDestination;
          expect(selected.label, scenario.$3);
          expect(tester.takeException(), isNull);
        },
      );
    }

    test(
      'le drawer reste le point d’entrée de toutes les routes autorisées',
      () {
        final source = File(
          'lib/shared/layout/app_shell.dart',
        ).readAsStringSync();
        expect(source, contains('drawer: Drawer('));
        for (final path in const [
          '/attendance',
          '/poles',
          '/projects',
          '/events',
          '/finance',
          '/alumni',
          '/recruitment',
        ]) {
          expect(source, contains("path: '$path'"), reason: path);
        }
      },
    );
  });

  group('login responsive et accessibilité', () {
    for (final viewport in const [
      Size(375, 812),
      Size(390, 844),
      Size(768, 1024),
      Size(1366, 768),
      Size(1440, 900),
    ]) {
      testWidgets(
        'login utilisable à ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
          await _pumpLogin(tester, viewport);
          expect(find.text('Connexion des comptes validés'), findsOneWidget);
          expect(find.text('Email'), findsOneWidget);
          expect(find.text('Mot de passe'), findsOneWidget);
          expect(find.text('Se connecter'), findsOneWidget);
          expect(find.text('Mot de passe oublié ?'), findsOneWidget);
          expect(find.text('Postuler'), findsOneWidget);
          expect(find.text('Suivre ma candidature'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('login reste exploitable avec un text scale de 2', (
      tester,
    ) async {
      await _pumpLogin(
        tester,
        const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Postuler'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mot de passe expose un libellé accessible dynamique', (
      tester,
    ) async {
      await _pumpLogin(tester, const Size(390, 844));
      final show = find.byTooltip('Afficher le mot de passe');
      expect(show, findsOneWidget);
      expect(tester.getSize(show).height, greaterThanOrEqualTo(44));

      await tester.tap(show);
      await tester.pump();
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
    });

    testWidgets('le formulaire de demande de compte conserve ce tooltip', (
      tester,
    ) async {
      await _pumpLogin(tester, const Size(390, 844));
      final accountAction = find.text('Compte Enacteur / Enactrice');
      await tester.ensureVisible(accountAction);
      await tester.pumpAndSettle();
      await tester.tap(accountAction);
      await tester.pumpAndSettle();
      expect(find.text('Rejoindre Enactus ESP'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byTooltip('Afficher le mot de passe'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('humanisation et absence de données démo', () {
    test(
      'les types Archives et Hall of Fame ne montrent pas de snake_case',
      () {
        const document = ArchiveDocumentModel(
          id: 'archive-document',
          title: 'Rapport',
          documentType: 'annual_report',
        );
        const entry = HallOfFameEntryModel(
          id: 'hall-entry',
          title: 'Finale nationale',
          entryType: 'competition_win',
        );

        expect(document.documentTypeLabel, 'Rapport annuel');
        expect(entry.entryTypeLabel, 'Compétition');
        expect(
          archiveTechnicalValueLabel('project_milestone'),
          'Project milestone',
        );
      },
    );

    test('les statuts critiques restent humanisés', () {
      const task = TaskModel(
        id: 'task',
        title: 'Recette',
        priority: 'urgente',
        status: 'en_cours',
        proofRequired: false,
        canManage: false,
        currentUserAssigned: true,
      );
      expect(task.statusLabel, 'En cours');
      expect(task.priorityLabel, 'Urgente');
      expect(archiveStatusLabel('under_review'), 'En vérification');
      expect(impactStatusLabel('under_review'), 'En vérification');
    });

    test('les libellés recrutement ne contiennent aucun encodage cassé', () {
      const application = ApplicationModel(
        id: 'candidate',
        campaignId: 'campaign',
        firstName: 'Awa',
        lastName: 'Diop',
        email: 'awa@example.test',
        studyLevel: 'L1',
        status: 'submitted',
        isAnonymized: false,
        canConvert: false,
      );
      expect(application.stabilityLabel, 'Stabilité forte');
      expect(application.stabilityLabel, isNot(contains('Ã')));

      for (final path in const [
        'lib/features/recruitment/services/recruitment_service.dart',
        'lib/features/members/services/members_service.dart',
        'lib/features/documents/services/documents_service.dart',
        'lib/features/posts/services/posts_service.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('connectÃ')), reason: path);
        expect(source, isNot(contains('Reponse')), reason: path);
        expect(source, isNot(contains('l upload')), reason: path);
      }
    });

    test('frontend/lib ne contient aucun dataset démo silencieux nommé', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      const forbidden = [
        '_demo',
        'demodata',
        'mockdata',
        'fakedata',
        'fixture',
        'hardcoded',
        'sampledata',
      ];
      for (final file in files) {
        final source = file.readAsStringSync().toLowerCase();
        for (final marker in forbidden) {
          expect(
            source,
            isNot(contains(marker)),
            reason: '${file.path}: $marker',
          );
        }
      }
    });
  });

  group('polling et actions accessibles', () {
    testWidgets('Dashboard reste exploitable sur mobile à zoom 200 %', (
      tester,
    ) async {
      await _pumpScaled(
        tester,
        DashboardScreen(gateway: _DashboardAcceptanceGateway()),
      );
      expect(find.text('À suivre aujourd’hui'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Chat reste exploitable sur mobile à zoom 200 %', (
      tester,
    ) async {
      await _pumpScaled(
        tester,
        ChatScreen(
          initialThreadId: 'thread-acceptance',
          gateway: _ChatAcceptanceGateway(),
        ),
      );
      expect(find.byTooltip('Envoyer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Finance reste exploitable sur mobile à zoom 200 %', (
      tester,
    ) async {
      await _pumpScaled(
        tester,
        const PaymentDecisionDialog(
          payment: PaymentModel(
            id: 'payment',
            userId: 'member',
            amount: 2500,
            method: 'wave',
            status: 'pending',
            canValidate: true,
            canReject: true,
            canCancel: false,
          ),
          memberName: 'Aminata Diop',
          approve: false,
        ),
        scaffold: false,
      );
      expect(find.text('Motif du rejet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hall of Fame reste exploitable sur mobile à zoom 200 %', (
      tester,
    ) async {
      await _pumpScaled(
        tester,
        HallOfFameDetailScreen(
          entryId: 'hall-entry',
          gateway: _ArchivesAcceptanceGateway(),
        ),
      );
      expect(find.text('Prix de l’innovation sociale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gestion Academy est réservée à l’administrateur', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademyCourseScreen(
              key: const ValueKey('academy-member'),
              courseId: 'course',
              gateway: _AcademyAcceptanceGateway(),
              currentUser: _user('membre', const {'enacteur'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gestion Academy'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademyCourseScreen(
              key: const ValueKey('academy-admin'),
              courseId: 'course',
              gateway: _AcademyAcceptanceGateway(),
              currentUser: _user('admin', const {'administrateur'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gestion Academy'), findsOneWidget);
    });

    testWidgets('Academy admin reste exploitable sur mobile à zoom 200 %', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: AcademyCourseScreen(
              courseId: 'course',
              gateway: _AcademyAcceptanceGateway(),
              currentUser: _user('admin', const {'administrateur'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gestion Academy'), findsOneWidget);
      expect(find.text('Culture Enactus'), findsWidgets);
      expect(find.text('Team Leader'), findsOneWidget);
      expect(find.text('Pôle associé'), findsOneWidget);
      expect(find.text('Projet associé'), findsOneWidget);
      expect(find.text('culture_enactus'), findsNothing);
      expect(find.text('team_leader'), findsNothing);
      expect(find.text('00000000-0000-4000-8000-000000000001'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('chaque surface avec Timer.periodic annule son timer au dispose', () {
      for (final path in const [
        'lib/shared/layout/app_shell.dart',
        'lib/features/posts/screens/posts_screen.dart',
        'lib/features/chat/screens/chat_screen.dart',
        'lib/features/notifications/screens/notifications_screen.dart',
        'lib/features/attendance/screens/attendance_session_detail_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('Timer.periodic'), reason: path);
        expect(source, contains('void dispose()'), reason: path);
        expect(source, contains('.cancel()'), reason: path);
      }
    });

    test('les commandes Chat ambiguës disposent de tooltips', () {
      final source = File(
        'lib/features/chat/screens/chat_screen.dart',
      ).readAsStringSync();
      expect(source, contains("tooltip: 'Annuler la réponse'"));
      expect(
        RegExp("tooltip: 'Rechercher des membres'").allMatches(source),
        hasLength(2),
      );
    });
  });
}

Future<void> _pumpLogin(
  WidgetTester tester,
  Size viewport, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const LoginScreen(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpScaled(
  WidgetTester tester,
  Widget child, {
  bool scaffold = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: content!,
      ),
      home: scaffold ? Scaffold(body: child) : child,
    ),
  );
  await tester.pumpAndSettle();
}

UserExperience _user(
  String id,
  Set<String> roles, {
  String status = 'active',
}) => UserExperience(
  id: id,
  email: '$id@enactspace.test',
  displayName: id,
  status: status,
  gender: null,
  profileType: status == 'alumni' ? 'alumni' : 'enacteur',
  roles: roles,
  canReviewJoinRequests: false,
);

class _ProfileExpectation {
  final String label;
  final UserExperience user;
  final Set<String> requiredRoutes;
  final Set<String> deniedRoutes;

  const _ProfileExpectation(
    this.label,
    this.user, {
    this.requiredRoutes = const {},
    this.deniedRoutes = const {},
  });
}

class _AcademyAcceptanceGateway implements AcademyGateway {
  @override
  Future<AcademyCourseModel> getCourse(String courseId) async =>
      const AcademyCourseModel(
        id: 'course',
        title: 'Culture Enactus',
        category: 'culture_enactus',
        level: 'debutant',
        description: 'Formation institutionnelle.',
        durationMinutes: 20,
        points: 40,
        isRequired: true,
        targetRoles: ['team_leader'],
        poleId: '00000000-0000-4000-8000-000000000001',
        projectId: '00000000-0000-4000-8000-000000000002',
        lessons: [],
        quiz: AcademyQuizModel(
          id: '',
          title: 'Quiz',
          category: 'culture_enactus',
          level: 'debutant',
          timeLimitMinutes: 5,
          questions: [],
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DashboardAcceptanceGateway implements DashboardGateway {
  @override
  Future<DashboardSummaryModel> loadSummary() async =>
      DashboardSummaryModel.fromJson({
        'profile': {
          'id': 'member',
          'display_name': 'Aminata Diop',
          'status': 'active',
          'profile_type': 'enacteur',
          'roles': ['enacteur'],
          'can_view_attendance': true,
          'can_view_finance': true,
        },
        'counts': {
          'tasks_assigned': 3,
          'tasks_late': 1,
          'notifications_unread': 2,
          'messages_unread': 4,
          'events_upcoming': 1,
        },
        'recent_activity': [
          {
            'type': 'task',
            'title': 'Compte rendu terrain',
            'created_at': '2026-09-01T08:00:00Z',
            'route': '/tasks/task-1',
          },
        ],
      });
}

class _ArchivesAcceptanceGateway implements ArchivesGateway {
  @override
  Future<HallOfFameEntryModel> getHallOfFameEntry(String entryId) async =>
      const HallOfFameEntryModel(
        id: 'hall-entry',
        title: 'Prix de l’innovation sociale',
        subtitle: 'Une reconnaissance nationale documentée',
        entryType: 'competition_win',
        year: 2024,
        description: 'Le jury distingue la qualité de la démarche.',
        scoreValue: 92,
        scoreLabel: 'points',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatAcceptanceGateway implements ChatGateway {
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<void> startRealtime() async {}
  @override
  Future<void> disposeRealtime() => _events.close();
  @override
  void sendRealtime(Map<String, dynamic> event) {}
  @override
  Future<UserExperience> getCurrentUser() async =>
      _user('member', const {'enacteur'});
  @override
  Future<List<ChatContactModel>> getContacts({String? search}) async => [];
  @override
  Future<List<PoleModel>> getPoles() async => [];
  @override
  Future<List<ProjectModel>> getProjects() async => [];
  @override
  Future<List<ChatThreadModel>> getThreads() async => [_thread];
  @override
  Future<List<ChatThreadModel>> getCachedThreads({
    required String userId,
  }) async => [_thread];
  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async => [
    _message,
  ];
  @override
  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  }) async => [_message];
  @override
  Future<Set<String>> getPinnedThreadIds({required String userId}) async => {};
  @override
  Future<Set<String>> getHiddenThreadIds({required String userId}) async => {};
  @override
  Future<Set<String>> getPinnedMessageIds({
    required String userId,
    required String threadId,
  }) async => {};
  @override
  Future<ChatMediaCacheSettings> getMediaCacheSettings({
    required String userId,
  }) async => const ChatMediaCacheSettings();
  @override
  Future<int> estimateLocalMediaCacheBytes({required String userId}) async => 0;
  @override
  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  }) async {}
  @override
  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  }) async {}
  @override
  Future<void> markThreadAsRead(String threadId) async {}

  ChatThreadModel get _thread => ChatThreadModel.fromJson({
    'id': 'thread-acceptance',
    'title': 'Équipe projet',
    'thread_type': 'group',
    'created_at': '2026-08-31T10:00:00Z',
    'updated_at': '2026-09-01T08:00:00Z',
    'participants_count': 2,
    'unread_count': 1,
    'last_message': 'Point terrain à 14 h',
    'last_message_at': '2026-09-01T08:00:00Z',
    'current_user_role': 'member',
  });

  ChatMessageModel get _message => ChatMessageModel.fromJson({
    'id': 'message-acceptance',
    'thread_id': 'thread-acceptance',
    'author_id': 'member-2',
    'content': 'Message existant',
    'message_type': 'text',
    'created_at': '2026-09-01T08:00:00Z',
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
