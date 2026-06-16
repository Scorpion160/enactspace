import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/user_experience.dart';
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
  UserExperience? _userExperience;
  Timer? _metricsTimer;
  bool _metricsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNavigationMetrics();
    _metricsTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _loadNavigationMetrics();
    });
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentPath != widget.currentPath) {
      _loadNavigationMetrics();
    }
  }

  Future<void> _loadNavigationMetrics() async {
    if (_metricsLoading) return;
    _metricsLoading = true;

    int? unreadNotifications;
    int? lateTasks;
    UserExperience? userExperience;

    try {
      try {
        final user = await _authService.getCurrentUser();
        userExperience = UserExperience.fromJson(user);
      } catch (_) {
        userExperience = null;
      }

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
        _userExperience = userExperience;
      });
    } finally {
      _metricsLoading = false;
    }
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
              userExperience: _userExperience,
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
      bottomNavigationBar: _MobileBottomNavigation(
        currentPath: widget.currentPath,
        userExperience: _userExperience,
        unreadNotifications: _unreadNotifications,
        lateTasks: _lateTasks,
      ),
      drawer: Drawer(
        child: _SideMenu(
          currentPath: widget.currentPath,
          userExperience: _userExperience,
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
  final UserExperience? userExperience;
  final int? unreadNotifications;
  final int? lateTasks;
  final VoidCallback onLogout;
  final bool compact;

  const _SideMenu({
    required this.currentPath,
    required this.userExperience,
    required this.unreadNotifications,
    required this.lateTasks,
    required this.onLogout,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final allowedRoutes = UserExperience.visibleRoutesFor(
      userExperience,
    ).toSet();
    final sections =
        [
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
                  _MenuItem(
                    label: 'Chat',
                    icon: Icons.chat_rounded,
                    path: '/chat',
                  ),
                  _MenuItem(
                    label: 'Gamification',
                    icon: Icons.workspace_premium_rounded,
                    path: '/gamification',
                  ),
                  _MenuItem(
                    label: 'Academy',
                    icon: Icons.school_rounded,
                    path: '/academy',
                  ),
                  _MenuItem(
                    label: 'Impact',
                    icon: Icons.insights_rounded,
                    path: '/impact',
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
                    label: 'Pôles',
                    icon: Icons.hub_rounded,
                    path: '/poles',
                  ),
                  _MenuItem(
                    label: 'Projets',
                    icon: Icons.rocket_launch_rounded,
                    path: '/projects',
                  ),
                  _MenuItem(
                    label: 'Événements',
                    icon: Icons.event_available_rounded,
                    path: '/events',
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
                    label: 'Archives',
                    icon: Icons.history_edu_rounded,
                    path: '/archives',
                  ),
                  _MenuItem(
                    label: 'Alumni',
                    icon: Icons.school_rounded,
                    path: '/alumni',
                  ),
                  _MenuItem(
                    label: 'Recrutement',
                    icon: Icons.how_to_reg_rounded,
                    path: '/recruitment',
                  ),
                ],
              ),
            ]
            .map((section) {
              return _MenuSection(
                title: section.title,
                items: section.items
                    .where((item) => allowedRoutes.contains(item.path))
                    .toList(),
              );
            })
            .where((section) => section.items.isNotEmpty)
            .toList();

    return Material(
      color: AppTheme.softBlack,
      child: SizedBox(
        width: compact ? null : 284,
        child: SafeArea(
          child: Column(
            children: [
              _BrandHeader(userExperience: userExperience),
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
  final UserExperience? userExperience;

  const _BrandHeader({required this.userExperience});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EnactSpace',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userExperience?.audienceLabel ?? 'Enactus ESP',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
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

class _MobileBottomNavigation extends StatelessWidget {
  final String currentPath;
  final UserExperience? userExperience;
  final int? unreadNotifications;
  final int? lateTasks;

  const _MobileBottomNavigation({
    required this.currentPath,
    required this.userExperience,
    required this.unreadNotifications,
    required this.lateTasks,
  });

  @override
  Widget build(BuildContext context) {
    final allowedRoutes = UserExperience.visibleRoutesFor(
      userExperience,
    ).toSet();
    final preferred = [
      _MobileDestination(
        label: 'Accueil',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        path: '/dashboard',
      ),
      _MobileDestination(
        label: 'Chat',
        icon: Icons.chat_outlined,
        selectedIcon: Icons.chat_rounded,
        path: '/chat',
      ),
      _MobileDestination(
        label: 'Tâches',
        icon: Icons.task_alt_outlined,
        selectedIcon: Icons.task_alt_rounded,
        path: '/tasks',
        badgeCount: lateTasks,
      ),
      _MobileDestination(
        label: 'Points',
        icon: Icons.workspace_premium_outlined,
        selectedIcon: Icons.workspace_premium_rounded,
        path: '/gamification',
      ),
      _MobileDestination(
        label: 'Alertes',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications_rounded,
        path: '/notifications',
        badgeCount: unreadNotifications,
      ),
      _MobileDestination(
        label: 'Com',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
        path: '/posts',
      ),
      _MobileDestination(
        label: 'Academy',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school_rounded,
        path: '/academy',
      ),
      _MobileDestination(
        label: 'Impact',
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        path: '/impact',
      ),
      _MobileDestination(
        label: 'Membres',
        icon: Icons.people_alt_outlined,
        selectedIcon: Icons.people_alt_rounded,
        path: '/members',
      ),
      _MobileDestination(
        label: 'Docs',
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder_rounded,
        path: '/documents',
      ),
      _MobileDestination(
        label: 'Archives',
        icon: Icons.history_edu_outlined,
        selectedIcon: Icons.history_edu_rounded,
        path: '/archives',
      ),
    ];
    final allowedDestinations = preferred
        .where((item) => allowedRoutes.contains(item.path))
        .toList();
    final destinations = allowedDestinations.take(5).toList();
    final currentDestination = _currentMobileDestination(
      allowedDestinations,
      currentPath,
    );

    if (currentDestination != null &&
        !destinations.any((item) => item.path == currentDestination.path)) {
      if (destinations.length >= 5) {
        destinations[destinations.length - 1] = currentDestination;
      } else {
        destinations.add(currentDestination);
      }
    }

    final selectedIndex = destinations.indexWhere(
      (item) => _isSelected(currentPath, item.path),
    );

    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return NavigationBar(
      height: 72,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => context.go(destinations[index].path),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: _BottomNavIcon(
              icon: destination.icon,
              badgeCount: destination.badgeCount,
            ),
            selectedIcon: _BottomNavIcon(
              icon: destination.selectedIcon,
              badgeCount: destination.badgeCount,
              selected: true,
            ),
            label: destination.label,
          ),
      ],
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final int? badgeCount;
  final bool selected;

  const _BottomNavIcon({
    required this.icon,
    required this.badgeCount,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = badgeCount ?? 0;

    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : count.toString()),
      backgroundColor: selected ? AppTheme.softBlack : Colors.red.shade700,
      textColor: Colors.white,
      child: Icon(icon),
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

class _MobileDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final int? badgeCount;

  const _MobileDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    this.badgeCount,
  });
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

_MobileDestination? _currentMobileDestination(
  List<_MobileDestination> destinations,
  String currentPath,
) {
  for (final destination in destinations) {
    if (_isSelected(currentPath, destination.path)) {
      return destination;
    }
  }
  return null;
}

String _navigationTitle(String currentPath) {
  final sections = <String, String>{
    '/dashboard': 'Tableau de bord Enactus ESP',
    '/members': 'Membres',
    '/poles': 'Pôles',
    '/projects': 'Projets',
    '/events': 'Événements',
    '/attendance': 'Présences',
    '/tasks': 'Tâches',
    '/finance': 'Finance',
    '/documents': 'Documents',
    '/archives': 'Archives & Mémoire collective',
    '/alumni': 'Alumni',
    '/recruitment': 'Recrutement',
    '/notifications': 'Notifications',
    '/posts': 'Communication',
    '/chat': 'Chat',
    '/gamification': 'Gamification',
    '/academy': 'EnactSpace Academy',
    '/impact': 'Impact & Performance',
  };

  return sections.entries
      .firstWhere(
        (entry) => _isSelected(currentPath, entry.key),
        orElse: () => const MapEntry('/dashboard', 'EnactSpace'),
      )
      .value;
}
