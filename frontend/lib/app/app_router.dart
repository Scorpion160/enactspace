import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/user_experience.dart';
import '../features/alumni/screens/alumni_screen.dart';
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
import '../features/tasks/screens/tasks_screen.dart';
import '../shared/layout/app_shell.dart';

class AppRouter {
  static final AuthService _authService = AuthService();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final loggedIn = await _authService.isLoggedIn();
      final goingToLogin = state.matchedLocation == '/login';

      if (!loggedIn && !goingToLogin) {
        return '/login';
      }

      if (loggedIn && goingToLogin) {
        return '/dashboard';
      }

      if (loggedIn) {
        try {
          final user = UserExperience.fromJson(
            await _authService.getCurrentUser(),
          );
          final visibleRoutes = UserExperience.visibleRoutesFor(user);
          final path = state.uri.path;
          final allowed = visibleRoutes.any(
            (route) => path == route || path.startsWith('$route/'),
          );

          if (!allowed) return '/dashboard';
        } catch (_) {
          return '/login';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
            builder: (context, state) => const ChatScreen(),
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
            path: '/impact',
            builder: (context, state) => const ImpactDashboardScreen(),
          ),
        ],
      ),
    ],
  );
}
