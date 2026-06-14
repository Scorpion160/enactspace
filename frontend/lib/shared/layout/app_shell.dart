import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/notifications/services/notifications_service.dart';
import '../../features/tasks/services/tasks_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AppShell({super.key, required this.child, required this.currentPath});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AuthService _authService = AuthService();
  final NotificationsService _notificationsService = NotificationsService();
  final TasksService _tasksService = TasksService();

  int? _unreadNotifications;
  int? _lateTasks;

  @override
  void initState() {
    super.initState();
    _loadNavigationMetrics();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentPath != widget.currentPath) {
      _loadNavigationMetrics();
    }
  }

  Future<void> _loadNavigationMetrics() async {
    int? unreadNotifications;
    int? lateTasks;

    try {
      unreadNotifications = await _notificationsService.getUnreadCount();
    } catch (_) {
      unreadNotifications = null;
    }

    try {
      lateTasks = (await _tasksService.getLateTasks()).length;
    } catch (_) {
      lateTasks = null;
    }

    if (!mounted) return;

    setState(() {
      _unreadNotifications = unreadNotifications;
      _lateTasks = lateTasks;
    });
  }

  Future<void> _logout(BuildContext context) async {
    await _authService.logout();

    if (!context.mounted) return;
    context.go('/login');
  }

  void _refresh(BuildContext context) {
    _loadNavigationMetrics();
    GoRouter.of(context).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final title = _navigationTitle(widget.currentPath);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideMenu(
              currentPath: widget.currentPath,
              unreadNotifications: _unreadNotifications,
              lateTasks: _lateTasks,
              onLogout: () => _logout(context),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: title,
                    unreadNotifications: _unreadNotifications,
                    onRefresh: () => _refresh(context),
                    onLogout: () => _logout(context),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          _NotificationIconButton(
            unreadNotifications: _unreadNotifications,
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            onPressed: () => _logout(context),
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: _SideMenu(
          currentPath: widget.currentPath,
          unreadNotifications: _unreadNotifications,
          lateTasks: _lateTasks,
          onLogout: () => _logout(context),
          compact: true,
        ),
      ),
      body: widget.child,
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final int? unreadNotifications;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const _TopBar({
    required this.title,
    required this.unreadNotifications,
    required this.onRefresh,
    required this.onLogout,
  });

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
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
          ),
          _NotificationIconButton(
            unreadNotifications: unreadNotifications,
            onPressed: () => context.go('/notifications'),
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
  final int? unreadNotifications;
  final int? lateTasks;
  final VoidCallback onLogout;
  final bool compact;

  const _SideMenu({
    required this.currentPath,
    required this.unreadNotifications,
    required this.lateTasks,
    required this.onLogout,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final sections = [
      _MenuSection(
        title: 'Pilotage',
        items: [
          _MenuItem(
            label: 'Dashboard',
            icon: Icons.dashboard_rounded,
            path: '/dashboard',
          ),
          _MenuItem(
            label: 'Notifications',
            icon: Icons.notifications_rounded,
            path: '/notifications',
            badgeCount: unreadNotifications,
          ),
          _MenuItem(
            label: 'Communication',
            icon: Icons.forum_rounded,
            path: '/posts',
          ),
        ],
      ),
      _MenuSection(
        title: 'Opérations',
        items: [
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
          _MenuItem(
            label: 'Tâches',
            icon: Icons.task_alt_rounded,
            path: '/tasks',
            badgeCount: lateTasks,
            badgeColor: Colors.red.shade700,
          ),
        ],
      ),
      _MenuSection(
        title: 'Ressources',
        items: [
          _MenuItem(
            label: 'Finance',
            icon: Icons.payments_rounded,
            path: '/finance',
          ),
          _MenuItem(
            label: 'Documents',
            icon: Icons.folder_rounded,
            path: '/documents',
          ),
          _MenuItem(
            label: 'Recrutement',
            icon: Icons.how_to_reg_rounded,
            path: '/recruitment',
          ),
        ],
      ),
    ];

    return Material(
      color: AppTheme.softBlack,
      child: SizedBox(
        width: compact ? null : 284,
        child: SafeArea(
          child: Column(
            children: [
              const _BrandHeader(),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  children: [
                    for (final section in sections) ...[
                      _SectionLabel(section.title),
                      const SizedBox(height: 8),
                      for (final item in section.items)
                        _NavigationTile(
                          item: item,
                          selected: _isSelected(currentPath, item.path),
                          compact: compact,
                        ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _LogoutTile(onLogout: onLogout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EnactSpace',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Enactus ESP',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label.toUpperCase(),
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final _MenuItem item;
  final bool selected;
  final bool compact;

  const _NavigationTile({
    required this.item,
    required this.selected,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.softBlack : Colors.white;
    final mutedForeground = selected ? AppTheme.softBlack : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? AppTheme.enactusYellow
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (compact) Navigator.of(context).pop();
            context.go(item.path);
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.enactusYellow
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: mutedForeground, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
                if (item.badgeCount != null && item.badgeCount! > 0) ...[
                  const SizedBox(width: 8),
                  _CountBadge(
                    count: item.badgeCount!,
                    color: selected
                        ? AppTheme.softBlack
                        : item.badgeColor ?? AppTheme.enactusYellow,
                    foreground: selected
                        ? Colors.white
                        : item.badgeColor == null
                        ? AppTheme.softBlack
                        : Colors.white,
                  ),
                ],
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: foreground,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final Color foreground;

  const _CountBadge({
    required this.count,
    required this.color,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();

    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NotificationIconButton extends StatelessWidget {
  final int? unreadNotifications;
  final VoidCallback onPressed;

  const _NotificationIconButton({
    required this.unreadNotifications,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final count = unreadNotifications ?? 0;

    return IconButton(
      onPressed: onPressed,
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : count.toString()),
        backgroundColor: AppTheme.enactusYellow,
        textColor: AppTheme.softBlack,
        child: const Icon(Icons.notifications_rounded),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onLogout;

  const _LogoutTile({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onLogout,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Déconnexion',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

class _MenuSection {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});
}

class _MenuItem {
  final String label;
  final IconData icon;
  final String path;
  final int? badgeCount;
  final Color? badgeColor;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.path,
    this.badgeCount,
    this.badgeColor,
  });
}

bool _isSelected(String currentPath, String itemPath) {
  return currentPath == itemPath || currentPath.startsWith('$itemPath/');
}

String _navigationTitle(String currentPath) {
  final sections = <String, String>{
    '/dashboard': 'Tableau de bord Enactus ESP',
    '/members': 'Membres',
    '/attendance': 'Présences',
    '/tasks': 'Tâches',
    '/finance': 'Finance',
    '/documents': 'Documents',
    '/recruitment': 'Recrutement',
    '/notifications': 'Notifications',
    '/posts': 'Communication',
  };

  return sections.entries
      .firstWhere(
        (entry) => _isSelected(currentPath, entry.key),
        orElse: () => const MapEntry('/dashboard', 'EnactSpace'),
      )
      .value;
}
