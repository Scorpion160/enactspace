import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/appearance_controller.dart';
import '../../../core/widgets/preview_mode_scope.dart';
import '../../../shared/layout/app_shell.dart';
import '../about/screens/about_screen.dart';
import '../academy/screens/academy_course_screen.dart';
import '../academy/screens/academy_home_screen.dart';
import '../academy/screens/academy_path_screen.dart';
import '../alumni/screens/alumni_profile_detail_screen.dart';
import '../alumni/screens/alumni_screen.dart';
import '../archives/screens/archive_detail_screens.dart';
import '../archives/screens/archive_minutes_screen.dart';
import '../archives/screens/archives_center_screen.dart';
import '../attendance/screens/attendance_screen.dart';
import '../attendance/services/attendance_service.dart';
import '../chat/screens/chat_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../documents/screens/club_rules_screen.dart';
import '../documents/screens/document_detail_screen.dart';
import '../documents/screens/institutional_documents_hub_screen.dart';
import '../events/screens/event_detail_screen.dart';
import '../events/screens/events_screen.dart';
import '../finance/screens/finance_screen.dart';
import '../gamification/screens/games_screen.dart';
import '../gamification/screens/gamification_screen.dart';
import '../gamification/services/games_service.dart';
import '../help/screens/help_guide_screen.dart';
import '../help/screens/help_management_screen.dart';
import '../help/screens/help_screen.dart';
import '../impact/screens/impact_dashboard_screen.dart';
import '../impact/screens/impact_records_screen.dart';
import '../legal/screens/public_legal_screen.dart';
import '../legal/services/legal_gateway.dart';
import '../meetings/screens/meeting_detail_screen.dart';
import '../meetings/screens/meetings_screen.dart';
import '../members/screens/member_profile_screen.dart';
import '../members/screens/members_screen.dart';
import '../members/services/members_service.dart';
import '../notifications/screens/notifications_screen.dart';
import '../poles/screens/pole_detail_screen.dart';
import '../poles/screens/poles_screen.dart';
import '../poles/services/poles_service.dart';
import '../posts/screens/posts_screen.dart';
import '../profile/screens/my_profile_screen.dart';
import '../projects/screens/project_detail_screen.dart';
import '../projects/screens/projects_portfolio_screen.dart';
import '../projects/services/projects_service.dart';
import '../recruitment/screens/application_tracking_screen.dart';
import '../recruitment/screens/internal/internal_recruitment_screen.dart';
import '../recruitment/screens/public/public_application_flow_screen.dart';
import '../recruitment/screens/public/public_recruitment_campaigns_screen.dart';
import '../settings/screens/academic_profile_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../settings/screens/team_years_screen.dart';
import '../tasks/screens/task_detail_screen.dart';
import '../tasks/screens/tasks_screen.dart';
import '../veille/screens/veille_record_screen.dart';
import '../veille/screens/veille_screen.dart';
import 'demo_native_runtime.dart';
import 'demo_session.dart';

/// The production pages and shell, mounted under a visit-local router. It never
/// enters AppRouter's authenticated shell and never changes a browser's /demo URL.
class DemoNativeExperience extends StatefulWidget {
  const DemoNativeExperience({
    super.key,
    required this.profile,
    this.initialSection = 'home',
  });
  final DemoProfile profile;
  final String initialSection;
  @override
  State<DemoNativeExperience> createState() => _DemoNativeExperienceState();
}

class _DemoNativeExperienceState extends State<DemoNativeExperience> {
  late DemoNativeRuntime runtime;
  late GoRouter router;
  late _VisitRouteInformation routeInformation;

  String _initialPath() =>
      demoModuleRoutes.entries
          .where((e) => e.value == widget.initialSection)
          .map((e) => e.key)
          .firstOrNull ??
      '/dashboard';

  @override
  void initState() {
    super.initState();
    runtime = DemoNativeRuntime(widget.profile);
    router = GoRouter(
      initialLocation: _initialPath(),
      overridePlatformDefaultLocation: true,
      redirect: (_, state) {
        final path = state.uri.path;
        if (path == '/recruitment' && runtime.user.isAlumni) {
          return '/recruitment/apply';
        }
        if (path == '/login' ||
            path == '/about' ||
            path == '/help-guide' ||
            path.startsWith('/legal/') ||
            path == '/application-tracking' ||
            path == '/recruitment/apply' ||
            path.startsWith('/recruitment/apply/')) {
          return null;
        }
        return UserExperience.canAccessPath(runtime.user, path)
            ? null
            : '/dashboard';
      },
      errorBuilder: (_, _) =>
          _Unavailable(onBack: () => router.go('/dashboard')),
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(
            currentPath: state.uri.path,
            presentationMode: true,
            authService: runtime.auth,
            chatService: runtime.chatService,
            notificationsService: runtime.notificationsService,
            tasksService: runtime.tasksService,
            onExitPresentation: _exit,
            child: child,
          ),
          routes: _routes(),
        ),
      ],
    );
    routeInformation = _VisitRouteInformation(router.routeInformationProvider);
  }

  void _exit() => GoRouter.of(context).go('/demo');

  List<RouteBase> _routes() {
    final r = runtime;
    GoRoute route(String path, Widget Function(GoRouterState) build) =>
        GoRoute(path: path, builder: (_, state) => build(state));
    String param(GoRouterState s, String key) => s.pathParameters[key]!;
    return [
      route('/dashboard', (_) => DashboardScreen(gateway: r.dashboard)),
      route('/alumni', (_) => AlumniScreen(gateway: r.alumni)),
      route(
        '/alumni/:profileId',
        (s) => AlumniProfileDetailScreen(
          profileId: param(s, 'profileId'),
          gateway: r.alumni,
        ),
      ),
      route('/projects', (_) => ProjectsPortfolioScreen(gateway: r.projects)),
      route(
        '/projects/:projectId',
        (s) => ProjectDetailScreen(
          projectId: param(s, 'projectId'),
          gateway: r.projects,
        ),
      ),
      route('/poles', (_) => PolesScreen(gateway: r.poles)),
      route(
        '/poles/:poleId',
        (s) => PoleDetailScreen(poleId: param(s, 'poleId'), gateway: r.poles),
      ),
      route(
        '/members',
        (_) => MembersScreen(
          authService: r.auth,
          membersService: r.members,
          polesService: r.polesService,
          projectsService: r.projectsService,
        ),
      ),
      route(
        '/members/:memberId',
        (s) => MemberProfileScreen(
          memberId: param(s, 'memberId'),
          service: r.members,
          gamesService: r.games,
        ),
      ),
      route('/academy', (_) => AcademyHomeScreen(gateway: r.academy)),
      route(
        '/academy/paths/:pathId',
        (s) =>
            AcademyPathScreen(pathId: param(s, 'pathId'), gateway: r.academy),
      ),
      route(
        '/academy/courses/:courseId',
        (s) => AcademyCourseScreen(
          courseId: param(s, 'courseId'),
          gateway: r.academy,
          resume: s.uri.queryParameters['resume'] == 'true',
        ),
      ),
      route('/academy/admin', (_) => AcademyAdminScreen(gateway: r.academy)),
      route(
        '/chat',
        (s) => ChatScreen(
          gateway: r.chat,
          initialThreadId: s.uri.queryParameters['thread'],
        ),
      ),
      route('/posts', (_) => PostsScreen(gateway: r.posts)),
      route(
        '/notifications',
        (_) => NotificationsScreen(gateway: r.notifications),
      ),
      route('/events', (_) => EventsScreen(gateway: r.events)),
      route(
        '/events/:eventId',
        (s) =>
            EventDetailScreen(eventId: param(s, 'eventId'), gateway: r.events),
      ),
      route(
        '/meetings',
        (_) => MeetingsScreen(
          service: r.meetings,
          authService: r.auth,
          membersService: r.members,
          polesService: r.polesService,
          projectsService: r.projectsService,
        ),
      ),
      route(
        '/meetings/:meetingId',
        (s) => MeetingDetailScreen(
          meetingId: param(s, 'meetingId'),
          service: r.meetings,
          membersService: r.members,
        ),
      ),
      route(
        '/meetings/:meetingId/live',
        (_) => _Unavailable(
          onBack: () => router.go('/meetings'),
          message: 'Les appels réels restent désactivés pendant la visite.',
        ),
      ),
      route('/tasks', (_) => TasksScreen(gateway: r.tasks)),
      route(
        '/tasks/:taskId',
        (s) => TaskDetailScreen(taskId: param(s, 'taskId'), gateway: r.tasks),
      ),
      route(
        '/finance',
        (_) => FinanceScreen(
          authService: r.auth,
          financeService: r.finance,
          membersService: r.members,
        ),
      ),
      route(
        '/attendance',
        (_) => AttendanceScreen(
          authService: r.auth,
          attendanceService: r.attendance,
        ),
      ),
      for (final path in ['/attendance/scan', '/attendance/nfc'])
        route(
          path,
          (_) => _Unavailable(
            onBack: () => router.go('/attendance'),
            message:
                'La caméra et le NFC restent désactivés pendant la visite.',
          ),
        ),
      route(
        '/documents',
        (_) => InstitutionalDocumentsHubScreen(
          documentsGateway: r.documents,
          institutionalGateway: r.institutionalDocuments,
        ),
      ),
      route('/documents/reglement-interieur', (_) => const ClubRulesScreen()),
      route(
        '/documents/:documentId',
        (s) => DocumentDetailScreen(
          documentId: param(s, 'documentId'),
          gateway: r.documents,
        ),
      ),
      route(
        '/archives',
        (_) => ArchivesScreen(gateway: r.archives, initialHistoricalView: true),
      ),
      route(
        '/archives/minutes',
        (_) => ArchiveMinutesScreen(gateway: r.archives),
      ),
      route(
        '/archives/minutes/:minuteId',
        (s) => ArchiveMinutesScreen(
          minuteId: param(s, 'minuteId'),
          gateway: r.archives,
        ),
      ),
      route(
        '/archives/items/:archiveId',
        (s) => ArchiveItemDetailScreen(
          archiveId: param(s, 'archiveId'),
          gateway: r.archives,
        ),
      ),
      route(
        '/archives/projects/:projectId',
        (s) => HistoricalProjectDetailScreen(
          projectId: param(s, 'projectId'),
          gateway: r.archives,
        ),
      ),
      route(
        '/archives/awards/:recordId',
        (s) => ArchiveCollectionDetailScreen(
          recordId: param(s, 'recordId'),
          competition: false,
          gateway: r.archives,
        ),
      ),
      route(
        '/archives/competitions/:recordId',
        (s) => ArchiveCollectionDetailScreen(
          recordId: param(s, 'recordId'),
          competition: true,
          gateway: r.archives,
        ),
      ),
      route(
        '/archives/hall-of-fame/:entryId',
        (s) => HallOfFameDetailScreen(
          entryId: param(s, 'entryId'),
          gateway: r.archives,
        ),
      ),
      route('/impact', (_) => ImpactDashboardScreen(gateway: r.impact)),
      route('/impact/records', (_) => ImpactRecordsScreen(gateway: r.impact)),
      route(
        '/impact/records/:recordId',
        (s) => ImpactRecordDetailScreen(
          recordId: param(s, 'recordId'),
          gateway: r.impact,
        ),
      ),
      route('/veille', (_) => VeilleScreen(gateway: r.veille)),
      route(
        '/veille/records/:kind/:id',
        (s) => VeilleRecordScreen(
          kind: param(s, 'kind'),
          id: param(s, 'id'),
          gateway: r.veille,
        ),
      ),
      route(
        '/gamification',
        (_) => GamificationScreen(gateway: r.gamification),
      ),
      route('/gamification/games', (_) => GamesScreen(service: r.games)),
      route(
        '/gamification/games/:roomId',
        (s) => GameRoomScreen(roomId: param(s, 'roomId'), service: r.games),
      ),
      route(
        '/recruitment',
        (_) => InternalRecruitmentScreen(gateway: r.internalRecruitment),
      ),
      route(
        '/recruitment/apply',
        (_) => PublicRecruitmentCampaignsScreen(gateway: r.recruitment),
      ),
      route(
        '/recruitment/apply/:campaignId',
        (s) => PublicApplicationFlowScreen(
          campaignId: param(s, 'campaignId'),
          gateway: r.recruitment,
          demoMode: true,
        ),
      ),
      route(
        '/application-tracking',
        (_) => ApplicationTrackingScreen(gateway: r.recruitment),
      ),
      route(
        '/profile',
        (_) => MyProfileScreen(service: r.myProfile, gamesService: r.games),
      ),
      route(
        '/settings',
        (_) => SettingsScreen(controller: r.settings, authService: r.auth),
      ),
      route('/settings/years', (_) => TeamYearsScreen(gateway: r.years)),
      route(
        '/settings/academic',
        (_) => AcademicProfileScreen(service: r.academicProfile),
      ),
      route('/help', (_) => HelpScreen(gateway: r.help, user: r.user)),
      route('/welcome-help', (_) => HelpScreen(gateway: r.help, user: r.user)),
      route(
        '/help/manage',
        (_) => HelpManagementScreen(gateway: r.help, currentUserId: r.user.id),
      ),
      route('/help-guide', (_) => const HelpGuideScreen()),
      route('/about', (_) => AboutScreen()),
      for (final entry in const {
        'privacy': 'privacy_policy',
        'terms': 'terms_of_use',
      }.entries)
        route(
          '/legal/${entry.key}',
          (_) => PublicLegalScreen(
            documentType: entry.value,
            gateway: ApiLegalGateway(apiClient: r.api, authService: r.auth),
          ),
        ),
      route('/login', (_) => _LeaveVisit(onExit: _exit)),
    ];
  }

  @override
  void dispose() {
    routeInformation.dispose();
    router.dispose();
    runtime.settings.dispose();
    runtime.appearance.dispose();
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: runtime.appearance,
    builder: (context, _) {
      final mode = runtime.appearance.themeMode;
      final isDark =
          mode == ThemeMode.dark ||
          mode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
      return Theme(
        data: theme,
        child: Column(
          children: [
            Material(
              color: theme.colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'DÉMO · ${widget.profile.label}\nVrais écrans · Données fictives · Essais limités à cette visite',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Explorer les rubriques',
                        icon: const Icon(Icons.apps_rounded),
                        onSelected: router.go,
                        itemBuilder: (_) => [
                          for (final m in modulesFor(widget.profile))
                            PopupMenuItem(
                              value: demoModuleRoutes.entries
                                  .firstWhere((e) => e.value == m.id)
                                  .key,
                              child: Text(m.title),
                            ),
                          const PopupMenuItem(
                            value: '/recruitment/apply',
                            child: Text('Essayer une candidature'),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Changer de thème',
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        onPressed: () => runtime.appearance.select(
                          isDark ? AppAppearance.light : AppAppearance.dark,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Changer de profil ou quitter',
                        onPressed: _exit,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: theme,
                routeInformationProvider: routeInformation,
                routeInformationParser: router.routeInformationParser,
                routerDelegate: router.routerDelegate,
                builder: (context, child) => PreviewModeScope(
                  services: {
                    AttendanceService: runtime.attendance,
                    MembersService: runtime.members,
                    PolesService: runtime.polesService,
                    ProjectsService: runtime.projectsService,
                    GamesService: runtime.games,
                  },
                  child: child!,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _VisitRouteInformation extends RouteInformationProvider
    with ChangeNotifier {
  _VisitRouteInformation(this.source) {
    source.addListener(notifyListeners);
  }
  final RouteInformationProvider source;
  @override
  RouteInformation get value => source.value;
  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {}
  @override
  void dispose() {
    source.removeListener(notifyListeners);
    super.dispose();
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.onBack,
    this.message = 'Cet écran n’est pas disponible dans cette visite.',
  });
  final VoidCallback onBack;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('Revenir')),
        ],
      ),
    ),
  );
}

class _LeaveVisit extends StatefulWidget {
  const _LeaveVisit({required this.onExit});
  final VoidCallback onExit;
  @override
  State<_LeaveVisit> createState() => _LeaveVisitState();
}

class _LeaveVisitState extends State<_LeaveVisit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExit();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
