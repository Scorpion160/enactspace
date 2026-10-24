import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/demo/demo_native_data.dart';
import 'package:frontend/features/demo/demo_native_experience.dart';
import 'package:frontend/features/demo/demo_native_runtime.dart';
import 'package:frontend/features/demo/demo_screen.dart';
import 'package:frontend/features/demo/demo_session.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/alumni/screens/alumni_screen.dart';
import 'package:frontend/features/projects/screens/projects_portfolio_screen.dart';
import 'package:frontend/features/poles/screens/poles_screen.dart';
import 'package:frontend/features/academy/screens/academy_home_screen.dart';
import 'package:frontend/features/chat/screens/chat_screen.dart';
import 'package:frontend/features/events/screens/events_screen.dart';
import 'package:frontend/features/meetings/screens/meetings_screen.dart';
import 'package:frontend/features/notifications/screens/notifications_screen.dart';
import 'package:frontend/features/posts/screens/posts_screen.dart';
import 'package:frontend/features/archives/screens/archives_center_screen.dart';
import 'package:frontend/features/finance/screens/finance_screen.dart';
import 'package:frontend/features/tasks/screens/tasks_screen.dart';
import 'package:frontend/features/tasks/models/task_center_models.dart';
import 'package:frontend/features/documents/screens/institutional_documents_hub_screen.dart';
import 'package:frontend/features/recruitment/screens/internal/internal_recruitment_screen.dart';
import 'package:frontend/features/impact/screens/impact_dashboard_screen.dart';
import 'package:frontend/features/attendance/screens/attendance_screen.dart';
import 'package:frontend/features/members/screens/members_screen.dart';
import 'package:frontend/features/veille/screens/veille_screen.dart';
import 'package:frontend/features/gamification/screens/gamification_screen.dart';
import 'package:frontend/features/profile/screens/my_profile_screen.dart';
import 'package:frontend/features/settings/screens/settings_screen.dart';
import 'package:frontend/features/help/screens/help_screen.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('No real client may be created during a demo visit.');
  }
}

Future<void> _frames(WidgetTester tester) async {
  // A chat GIF can continue animating. Do not wait for animation quiescence.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production router uses the native experience for both public profiles',
    () {
      final source = File('lib/app/app_router.dart').readAsStringSync();
      expect(RegExp('=> DemoNativeExperience\\(').allMatches(source).length, 2);
      expect(
        UserExperience.canAccessPath(
          DemoNativeRuntime(DemoProfile.alumni).user,
          '/finance',
        ),
        isFalse,
      );
    },
  );

  test(
    'all production gateway contracts load without a real HTTP or auth client',
    () async {
      final previous = HttpOverrides.current;
      final network = _NoNetwork();
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previous);
      final r = DemoNativeRuntime(DemoProfile.enacteur);
      addTearDown(r.dispose);
      await r.dashboard.loadSummary();
      expect((await r.alumni.loadCenter()).profiles, hasLength(3));
      expect(await r.projects.loadProjects(), hasLength(5));
      expect(await r.poles.loadPoles(), hasLength(7));
      await r.projects.loadMembers('demo-terrasen');
      await r.tasks.loadCenter(TaskCenterView.mine);
      await r.tasks.loadDetail('demo-task-terrain');
      expect((await r.archives.loadHome()).media, hasLength(40));
      expect((await r.archives.getTimeline()).items, hasLength(25));
      expect((await r.academy.loadHome()).courses, hasLength(3));
      expect(await r.chat.getThreads(), hasLength(3));
      expect(await r.chat.getSharedMessages('demo-generations'), hasLength(1));
      await r.events.loadReferences();
      await r.events.loadEvent('demo-alumni-day');
      await r.meetings.getMeeting('demo-meeting');
      await r.notifications.load();
      await r.impact.loadDashboard();
      await r.gamification.load(month: 10, year: 2026);
      await r.finance.getMyAccount();
      await r.attendance.getMyRecords();
      await r.documents.loadReferences();
      await r.documents.loadDocument('demo-document');
      expect(await r.institutionalDocuments.loadTemplates(), isNotEmpty);
      await r.help.loadTickets();
      await r.help.loadFeedback();
      await r.veille.load(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 24),
      );
      await r.academicProfile.catalog();
      await r.years.canManage();
      await r.settings.load();
      expect(r.settings.error, isNull);
      expect(network.attempts, 0);
      expect(await r.auth.getToken(), startsWith('demo-local-'));
    },
  );

  test(
    'native chat, registration, tasks and profile edits stay inside one visit',
    () async {
      final first = DemoNativeRuntime(DemoProfile.enacteur);
      final second = DemoNativeRuntime(DemoProfile.enacteur);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.chat.sendMessage(
        threadId: 'demo-generations',
        content: 'Bonjour les générations',
      );
      expect(
        (await first.chat.getMessages('demo-generations')).last.content,
        'Bonjour les générations',
      );
      expect(
        (await first.chat.getMessages('demo-generations')).last.authorId,
        first.user.id,
      );
      expect((await first.chat.getMessages('demo-direct')).length, 2);
      expect((await second.chat.getMessages('demo-generations')).length, 2);
      await first.events.register('demo-alumni-day');
      expect(
        (await first.events.loadEvent('demo-alumni-day')).currentUserRegistered,
        isTrue,
      );
      expect(
        (await second.events.loadEvent(
          'demo-alumni-day',
        )).currentUserRegistered,
        isFalse,
      );
      await first.tasks.changeStatus('demo-task-terrain', 'termine');
      expect(
        (await first.tasks.loadDetail('demo-task-terrain')).task.status,
        'termine',
      );
      await first.api.patchJson(
        '/users/me',
        data: {'first_name': 'Prénom d’essai'},
      );
      expect(
        (await first.auth.getCurrentUser())['first_name'],
        'Prénom d’essai',
      );
      expect((await second.auth.getCurrentUser())['first_name'], 'Awa');
      await first.academy.completeLesson('discover-enactus-lesson');
      await first.academy.completeLesson('discover-enactus-lesson');
      expect(first.data.completedLessons, hasLength(1));
      await first.academy.submitQuiz('discover-enactus-quiz', [0]);
      final replay = await first.academy.submitQuiz('discover-enactus-quiz', [
        0,
      ]);
      expect(replay.points, 0);
      expect(
        (await first.academy.getCourse('discover-enactus')).isMastered,
        isTrue,
      );
    },
  );

  test(
    'unknown endpoints, real payments and transport callbacks cannot escape',
    () async {
      final r = DemoNativeRuntime(DemoProfile.enacteur);
      addTearDown(r.dispose);
      await expectLater(
        r.api.get('https://example.org/private'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        r.api.postJson('/finance/mobile-money/initiate', data: {'amount': 200}),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        r.api.postJson('/unregistered-endpoint', data: {}),
        throwsA(isA<ApiException>()),
      );
      var callbackRan = false;
      await expectLater(
        r.api.sendAuthenticated(
          '/users/me',
          token: 'real-token-sentinel',
          send: (_) async {
            callbackRan = true;
            throw StateError('Must never run');
          },
        ),
        throwsA(isA<ApiException>()),
      );
      expect(callbackRan, isFalse);
      await r.auth.logoutAll();
      expect(r.data.rows('/finance/payments'), hasLength(1));
    },
  );

  const screens = <String, Type>{
    'home': DashboardScreen,
    'alumni': AlumniScreen,
    'projects': ProjectsPortfolioScreen,
    'poles': PolesScreen,
    'academy': AcademyHomeScreen,
    'chat': ChatScreen,
    'posts': PostsScreen,
    'events': EventsScreen,
    'meetings': MeetingsScreen,
    'notifications': NotificationsScreen,
    'archives': ArchivesScreen,
    'finance': FinanceScreen,
    'tasks': TasksScreen,
    'documents': InstitutionalDocumentsHubScreen,
    'recruitment': InternalRecruitmentScreen,
    'impact': ImpactDashboardScreen,
    'attendance': AttendanceScreen,
    'members': MembersScreen,
    'veille': VeilleScreen,
    'games': GamificationScreen,
    'profile': MyProfileScreen,
    'settings': SettingsScreen,
    'help': HelpScreen,
  };
  for (final entry in screens.entries) {
    testWidgets('native ${entry.key} uses the production screen on a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: DemoNativeExperience(
            profile: DemoProfile.enacteur,
            initialSection: entry.key,
          ),
        ),
      );
      await _frames(tester);
      expect(find.byType(entry.value), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester);
    });
  }

  testWidgets(
    'native navigation keeps the public URL and exits without logout',
    (tester) async {
      final reports = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(call.arguments);
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
      final router = GoRouter(
        initialLocation: '/demo/enacteur',
        overridePlatformDefaultLocation: true,
        routes: [
          GoRoute(path: '/demo', builder: (_, _) => const DemoScreen()),
          GoRoute(
            path: '/demo/enacteur',
            builder: (_, _) =>
                const DemoNativeExperience(profile: DemoProfile.enacteur),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _frames(tester);
      reports.clear();
      final nativeContext = tester.element(find.byType(DashboardScreen));
      GoRouter.of(nativeContext).go('/projects/demo-terrasen');
      await _frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/demo/enacteur');
      expect(reports, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Changer de profil ou quitter'));
      await _frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/demo');
    },
  );

  test('archive filtering and pagination keep all forty source records', () {
    final store = DemoNativeData(DemoProfile.alumni);
    final page =
        store.handle('GET', '/institutional-memory/timeline?limit=25') as Map;
    final next =
        store.handle(
              'GET',
              '/institutional-memory/timeline?cursor=${page['next_cursor']}&limit=25',
            )
            as Map;
    expect((page['items'] as List).length + (next['items'] as List).length, 40);
    final filtered =
        store.handle('GET', '/institutional-memory/timeline?search=2016')
            as Map;
    expect(filtered['items'], isNotEmpty);
  });
}
