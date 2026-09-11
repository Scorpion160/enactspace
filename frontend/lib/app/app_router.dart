import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/auth_storage.dart';
import '../core/auth/user_experience.dart';
import '../features/academy/screens/academy_home_screen.dart';
import '../features/academy/screens/academy_course_screen.dart';
import '../features/academy/services/academy_gateway.dart';
import '../features/about/screens/about_screen.dart';
import '../features/alumni/screens/alumni_screen.dart';
import '../features/alumni/screens/alumni_profile_detail_screen.dart';
import '../features/alumni/services/alumni_gateway.dart';
import '../features/archives/screens/archive_detail_screens.dart';
import '../features/archives/screens/archives_center_screen.dart';
import '../features/archives/models/memory_timeline_models.dart';
import '../features/archives/services/archives_gateway.dart';
import '../features/attendance/screens/attendance_nfc_enrollment_screen.dart';
import '../features/attendance/screens/attendance_qr_scanner_screen.dart';
import '../features/attendance/screens/attendance_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/documents/screens/documents_screen.dart';
import '../features/documents/screens/document_detail_screen.dart';
import '../features/documents/services/documents_gateway.dart';
import '../features/events/screens/events_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/services/events_gateway.dart';
import '../features/finance/screens/finance_screen.dart';
import '../features/gamification/screens/gamification_screen.dart';
import '../features/help/screens/help_screen.dart';
import '../features/impact/screens/impact_dashboard_screen.dart';
import '../features/impact/screens/impact_records_screen.dart';
import '../features/impact/services/impact_gateway.dart';
import '../features/legal/screens/public_legal_screen.dart';
import '../features/legal/widgets/legal_acceptance_gate.dart';
import '../features/members/screens/members_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/poles/screens/pole_detail_screen.dart';
import '../features/poles/screens/poles_screen.dart';
import '../features/product_readiness/product_readiness_gate.dart';
import '../features/posts/screens/posts_screen.dart';
import '../features/projects/screens/project_detail_screen.dart';
import '../features/projects/screens/projects_portfolio_screen.dart';
import '../features/recruitment/screens/internal/internal_recruitment_screen.dart';
import '../features/recruitment/screens/application_tracking_screen.dart';
import '../features/recruitment/screens/public/public_application_flow_screen.dart';
import '../features/recruitment/screens/public/public_recruitment_campaigns_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/tasks/models/task_center_models.dart';
import '../features/tasks/services/tasks_gateway.dart';
import '../shared/layout/app_shell.dart';

class AppRouter {
  static final AuthService _authService = AuthService();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: AuthStorage.instance.sessionChanges,
    errorBuilder: (context, state) => const _RouteNotFoundScreen(),
    redirect: (context, state) async {
      final loggedIn = await _authService.isLoggedIn();
      final publicPath = isPublicPath(state.matchedLocation);
      final goingToLogin = state.matchedLocation == '/login';

      if (state.matchedLocation == '/splash') {
        return null;
      }

      if (!loggedIn && !publicPath) {
        return '/login';
      }

      if (loggedIn && goingToLogin) {
        return '/dashboard';
      }

      if (publicPath) return null;

      if (loggedIn) {
        var userData = await _authService.getCachedCurrentUser();
        if (userData == null) {
          try {
            userData = await _authService.getCurrentUser();
          } catch (_) {
            userData = null;
          }
        }

        if (userData != null) {
          final user = UserExperience.fromJson(userData);
          final path = state.uri.path;

          if (!UserExperience.canAccessPath(user, path)) {
            if (path == '/attendance/nfc' &&
                UserExperience.canAccessPath(user, '/attendance')) {
              return '/attendance';
            }
            return '/dashboard';
          }
        } else if (!_authenticatedFallbackAllows(state.uri.path)) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) =>
            const PublicLegalScreen(documentType: 'privacy_policy'),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const PublicLegalScreen(documentType: 'terms_of_use'),
      ),
      ShellRoute(
        builder: (context, state, child) => ProductReadinessGate(child: child),
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(path: '/about', builder: (context, state) => AboutScreen()),
          GoRoute(
            path: '/application-tracking',
            builder: (context, state) => const ApplicationTrackingScreen(),
          ),
          GoRoute(
            path: '/recruitment/apply',
            builder: (context, state) =>
                const PublicRecruitmentCampaignsScreen(),
            routes: [
              GoRoute(
                path: ':campaignId',
                builder: (context, state) => PublicApplicationFlowScreen(
                  campaignId: state.pathParameters['campaignId']!,
                ),
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) {
              return LegalAcceptanceGate(
                child: AppShell(currentPath: state.uri.path, child: child),
              );
            },
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: '/help',
                builder: (context, state) => const HelpScreen(),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/members',
                builder: (context, state) => const MembersScreen(),
              ),
              GoRoute(
                path: '/attendance',
                builder: (context, state) => const AttendanceScreen(),
              ),
              GoRoute(
                path: '/attendance/scan',
                builder: (context, state) => const AttendanceQrScannerScreen(),
              ),
              GoRoute(
                path: '/attendance/nfc',
                builder: (context, state) =>
                    const AttendanceNfcEnrollmentScreen(),
              ),
              GoRoute(
                path: '/tasks',
                builder: (context, state) => TasksScreen(
                  initialView: TaskCenterViewPresentation.fromQuery(
                    state.uri.queryParameters['view'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':taskId',
                    builder: (context, state) => TaskDetailScreen(
                      taskId: state.pathParameters['taskId']!,
                      gateway: state.extra is TasksGateway
                          ? state.extra! as TasksGateway
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceScreen(),
              ),
              GoRoute(
                path: '/recruitment',
                builder: (context, state) => const InternalRecruitmentScreen(),
              ),
              GoRoute(
                path: '/documents',
                builder: (context, state) => const DocumentsScreen(),
                routes: [
                  GoRoute(
                    path: ':documentId',
                    builder: (context, state) => DocumentDetailScreen(
                      documentId: state.pathParameters['documentId']!,
                      gateway: state.extra is DocumentsGateway
                          ? state.extra! as DocumentsGateway
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/posts',
                builder: (context, state) => const PostsScreen(),
              ),
              GoRoute(
                path: '/chat',
                builder: (context, state) => ChatScreen(
                  initialThreadId: state.uri.queryParameters['thread'],
                ),
              ),
              GoRoute(
                path: '/poles',
                builder: (context, state) => const PolesScreen(),
                routes: [
                  GoRoute(
                    path: ':poleId',
                    builder: (context, state) {
                      final extra = state.extra;
                      return PoleDetailScreen(
                        poleId: state.pathParameters['poleId']!,
                        gateway: extra is PoleDetailRouteData
                            ? extra.gateway
                            : null,
                        initialItem: extra is PoleDetailRouteData
                            ? extra.initialItem
                            : null,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/projects',
                builder: (context, state) => const ProjectsPortfolioScreen(),
                routes: [
                  GoRoute(
                    path: ':projectId',
                    builder: (context, state) {
                      final extra = state.extra;
                      return ProjectDetailScreen(
                        projectId: state.pathParameters['projectId']!,
                        gateway: extra is ProjectDetailRouteData
                            ? extra.gateway
                            : null,
                        initialItem: extra is ProjectDetailRouteData
                            ? extra.initialItem
                            : null,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/events',
                builder: (context, state) => const EventsScreen(),
                routes: [
                  GoRoute(
                    path: ':eventId',
                    builder: (context, state) => EventDetailScreen(
                      eventId: state.pathParameters['eventId']!,
                      gateway: state.extra is EventsGateway
                          ? state.extra! as EventsGateway
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/alumni',
                builder: (context, state) => const AlumniScreen(),
                routes: [
                  GoRoute(
                    path: ':profileId',
                    builder: (context, state) => AlumniProfileDetailScreen(
                      profileId: state.pathParameters['profileId']!,
                      gateway: state.extra is AlumniGateway
                          ? state.extra! as AlumniGateway
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/gamification',
                builder: (context, state) => const GamificationScreen(),
              ),
              GoRoute(
                path: '/academy',
                builder: (context, state) => const AcademyHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'courses/:courseId',
                    builder: (context, state) => AcademyCourseScreen(
                      courseId: state.pathParameters['courseId']!,
                      gateway: state.extra is AcademyGateway
                          ? state.extra! as AcademyGateway
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'admin',
                    builder: (context, state) => AcademyAdminScreen(
                      gateway: state.extra is AcademyGateway
                          ? state.extra! as AcademyGateway
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/archives',
                builder: (context, state) => ArchivesScreen(
                  gateway: state.extra is ArchivesGateway
                      ? state.extra! as ArchivesGateway
                      : null,
                  initialFilters: MemoryTimelineFilters(
                    startYear: int.tryParse(
                      state.uri.queryParameters['start_year'] ?? '',
                    ),
                    endYear: int.tryParse(
                      state.uri.queryParameters['end_year'] ?? '',
                    ),
                    resourceType: state.uri.queryParameters['type'],
                    projectId: state.uri.queryParameters['project_id'],
                    poleId: state.uri.queryParameters['pole_id'],
                    memberId: state.uri.queryParameters['member_id'],
                    eventId: state.uri.queryParameters['event_id'],
                    search: state.uri.queryParameters['search'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'items/:archiveId',
                    builder: (context, state) => ArchiveItemDetailScreen(
                      archiveId: state.pathParameters['archiveId']!,
                      gateway: state.extra is ArchivesGateway
                          ? state.extra! as ArchivesGateway
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'projects/:projectId',
                    builder: (context, state) => HistoricalProjectDetailScreen(
                      projectId: state.pathParameters['projectId']!,
                      gateway: state.extra is ArchivesGateway
                          ? state.extra! as ArchivesGateway
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'hall-of-fame/:entryId',
                    builder: (context, state) => HallOfFameDetailScreen(
                      entryId: state.pathParameters['entryId']!,
                      gateway: state.extra is ArchivesGateway
                          ? state.extra! as ArchivesGateway
                          : null,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/impact',
                builder: (context, state) => const ImpactDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'records',
                    builder: (context, state) => ImpactRecordsScreen(
                      gateway: state.extra is ImpactGateway
                          ? state.extra! as ImpactGateway
                          : null,
                    ),
                    routes: [
                      GoRoute(
                        path: ':impactRecordId',
                        builder: (context, state) => ImpactRecordDetailScreen(
                          recordId: state.pathParameters['impactRecordId']!,
                          gateway: state.extra is ImpactGateway
                              ? state.extra! as ImpactGateway
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static bool isPublicPath(String path) {
    return path == '/splash' ||
        path == '/login' ||
        path == '/legal/privacy' ||
        path == '/legal/terms' ||
        path == '/about' ||
        path == '/application-tracking' ||
        path == '/recruitment/apply' ||
        path.startsWith('/recruitment/apply/');
  }

  static bool isProductReadinessExemptPath(String path) {
    return path == '/legal/privacy' || path == '/legal/terms';
  }

  static bool _authenticatedFallbackAllows(String path) {
    if (path == '/finance' ||
        path.startsWith('/finance/') ||
        path == '/attendance/nfc' ||
        path.startsWith('/attendance/nfc/')) {
      return false;
    }

    const fallbackRoutes = {
      '/dashboard',
      '/notifications',
      '/posts',
      '/chat',
      '/tasks',
      '/documents',
      '/gamification',
      '/academy',
      '/archives',
      '/members',
      '/finance',
      '/attendance',
      '/poles',
      '/projects',
      '/events',
      '/recruitment',
      '/impact',
      '/alumni',
      '/settings',
      '/help',
    };

    return fallbackRoutes.any(
      (route) => path == route || path.startsWith('$route/'),
    );
  }
}

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_off_rounded, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Cette page n’existe pas ou n’est pas disponible pour ce compte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Retourne à l’accueil EnactSpace pour continuer.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Accueil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
