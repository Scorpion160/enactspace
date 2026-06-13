import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const AppShell({super.key, required this.child, required this.currentPath});

  static final AuthService _authService = AuthService();

  Future<void> _logout(BuildContext context) async {
    await _authService.logout();

    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideMenu(
              currentPath: currentPath,
              onLogout: () => _logout(context),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(onLogout: () => _logout(context)),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EnactSpace'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: _SideMenu(
          currentPath: currentPath,
          onLogout: () => _logout(context),
          compact: true,
        ),
      ),
      body: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onLogout;

  const _TopBar({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: Row(
        children: [
          const Text(
            'Tableau de bord Enactus ESP',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              GoRouter.of(context).refresh();
            },
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: onLogout,
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  final String currentPath;
  final VoidCallback onLogout;
  final bool compact;

  const _SideMenu({
    required this.currentPath,
    required this.onLogout,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItem(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        path: '/dashboard',
      ),
      _MenuItem(
        label: 'Membres',
        icon: Icons.people_alt_rounded,
        path: '/members',
      ),
      _MenuItem(
        label: 'Présences',
        icon: Icons.fact_check_rounded,
        path: '/attendance',
      ),
      _MenuItem(label: 'Tâches', icon: Icons.task_alt_rounded, path: '/tasks'),
      _MenuItem(
        label: 'Finance',
        icon: Icons.payments_rounded,
        path: '/finance',
      ),
      _MenuItem(
        label: 'Recrutement',
        icon: Icons.how_to_reg_rounded,
        path: '/recruitment',
      ),
      _MenuItem(
        label: 'Documents',
        icon: Icons.folder_rounded,
        path: '/documents',
      ),
      _MenuItem(
        label: 'Notifications',
        icon: Icons.notifications_rounded,
        path: '/notifications',
      ),
    ];

    return Material(
      color: AppTheme.softBlack,
      child: SizedBox(
        width: compact ? null : 280,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.enactusYellow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.groups_2_rounded,
                        color: AppTheme.softBlack,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'EnactSpace',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: items.map((item) {
                    final selected = currentPath == item.path;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: selected
                            ? AppTheme.enactusYellow
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Icon(
                            item.icon,
                            color: selected
                                ? AppTheme.softBlack
                                : Colors.white70,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.softBlack
                                  : Colors.white,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            if (compact) Navigator.of(context).pop();
                            context.go(item.path);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white12),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Déconnexion',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: onLogout,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final String path;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}
