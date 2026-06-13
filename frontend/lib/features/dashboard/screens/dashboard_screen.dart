import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class DashboardStat {
  final String title;
  final String value;
  final IconData icon;

  const DashboardStat({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient = ApiClient();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _currentUser;

  int _usersCount = 0;
  int _polesCount = 0;
  int _projectsCount = 0;
  int _tasksCount = 0;
  int _notificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();

      if (token == null) {
        if (!mounted) return;
        context.go('/login');
        return;
      }

      final user = await _authService.getCurrentUser();

      final users = await _apiClient.get('/users/', token: token);
      final poles = await _apiClient.get('/poles/', token: token);
      final projects = await _apiClient.get('/projects/', token: token);
      final tasks = await _apiClient.get('/tasks/', token: token);
      final notifications = await _apiClient.get(
        '/notifications/unread-count',
        token: token,
      );

      setState(() {
        _currentUser = user;
        _usersCount = _countList(users);
        _polesCount = _countList(poles);
        _projectsCount = _countList(projects);
        _tasksCount = _countList(tasks);
        _notificationsCount = _extractUnreadCount(notifications);
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  int _countList(dynamic value) {
    if (value is List) return value.length;
    if (value is Map && value['data'] is List)
      return (value['data'] as List).length;
    if (value is Map && value['items'] is List)
      return (value['items'] as List).length;
    return 0;
  }

  int _extractUnreadCount(dynamic value) {
    if (value is Map) {
      if (value['count'] is int) return value['count'];
      if (value['unread_count'] is int) return value['unread_count'];
      if (value['total'] is int) return value['total'];
    }
    return 0;
  }

  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _currentUser?['full_name'] ??
        _currentUser?['name'] ??
        _currentUser?['email'] ??
        'Utilisateur';

    final stats = [
      DashboardStat(
        title: 'Membres',
        value: _usersCount.toString(),
        icon: Icons.people_alt_rounded,
      ),
      DashboardStat(
        title: 'Pôles',
        value: _polesCount.toString(),
        icon: Icons.account_tree_rounded,
      ),
      DashboardStat(
        title: 'Projets',
        value: _projectsCount.toString(),
        icon: Icons.rocket_launch_rounded,
      ),
      DashboardStat(
        title: 'Tâches',
        value: _tasksCount.toString(),
        icon: Icons.task_alt_rounded,
      ),
      DashboardStat(
        title: 'Notifications',
        value: _notificationsCount.toString(),
        icon: Icons.notifications_active_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('EnactSpace'),
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadDashboard)
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _HeaderCard(displayName: displayName.toString()),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 1100
                          ? 5
                          : width >= 800
                          ? 3
                          : width >= 520
                          ? 2
                          : 1;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: stats.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.55,
                        ),
                        itemBuilder: (context, index) {
                          return _StatCard(stat: stats[index]);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _ModulePreview(),
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String displayName;

  const _HeaderCard({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.enactusYellow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppTheme.softBlack,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bienvenue, $displayName",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Votre espace de pilotage Enactus ESP est connecté au backend.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final DashboardStat stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(stat.icon, size: 34, color: AppTheme.softBlack),
            const Spacer(),
            Text(
              stat.value,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            Text(
              stat.title,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulePreview extends StatelessWidget {
  const _ModulePreview();

  @override
  Widget build(BuildContext context) {
    final modules = [
      'Membres',
      'Présences',
      'Tâches',
      'Finance',
      'Recrutement',
      'Documents',
      'Notifications',
      'Gamification',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modules à intégrer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: modules
                  .map(
                    (module) => Chip(
                      label: Text(module),
                      avatar: const Icon(Icons.check_circle_outline, size: 18),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade600,
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'Erreur de chargement',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
