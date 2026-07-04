import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/user_experience.dart';
import '../features/academy/screens/academy_home_screen.dart';
import '../features/alumni/screens/alumni_screen.dart';
import '../features/archives/screens/archives_screen.dart';
import '../features/attendance/screens/attendance_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/documents/screens/documents_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/finance/screens/finance_screen.dart';
import '../features/gamification/screens/gamification_screen.dart';
import '../features/impact/screens/impact_dashboard_screen.dart';
import '../features/members/screens/members_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/poles/screens/poles_screen.dart';
import '../features/posts/screens/posts_screen.dart';
import '../features/projects/screens/projects_screen.dart';
import '../features/recruitment/screens/recruitment_screen.dart';
import '../features/recruitment/screens/application_tracking_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../shared/layout/app_shell.dart';

class AppRouter {
  static final AuthService _authService = AuthService();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    errorBuilder: (context, state) => const _RouteNotFoundScreen(),
    redirect: (context, state) async {
      final loggedIn = await _authService.isLoggedIn();
      final publicPath =
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/application-tracking';
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
          final visibleRoutes = UserExperience.visibleRoutesFor(user);
          final path = state.uri.path;
          final allowed = visibleRoutes.any(
            (route) => path == route || path.startsWith('$route/'),
          );

          if (!allowed) return '/dashboard';
        } else if (!_authenticatedFallbackAllows(state.uri.path)) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/application-tracking',
        builder: (context, state) => const ApplicationTrackingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(currentPath: state.uri.path, child: child);
        },
        routes: [
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
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceScreen(),
          ),
          GoRoute(
            path: '/recruitment',
            builder: (context, state) => const RecruitmentScreen(),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentsScreen(),
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
          ),
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (context, state) => const EventsScreen(),
          ),
          GoRoute(
            path: '/alumni',
            builder: (context, state) => const AlumniScreen(),
          ),
          GoRoute(
            path: '/gamification',
            builder: (context, state) => const GamificationScreen(),
          ),
          GoRoute(
            path: '/academy',
            builder: (context, state) => const AcademyHomeScreen(),
          ),
          GoRoute(
            path: '/archives',
            builder: (context, state) => const ArchivesScreen(),
          ),
          GoRoute(
            path: '/impact',
            builder: (context, state) => const ImpactDashboardScreen(),
          ),
        ],
      ),
    ],
  );

  static bool _authenticatedFallbackAllows(String path) {
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
