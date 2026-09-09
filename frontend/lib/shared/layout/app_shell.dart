import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/user_experience.dart';
import '../../core/brand/brand_assets.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/push/push_lifecycle_controller.dart';
import '../../core/push/push_navigation_resolver.dart';
import '../../core/push/push_platform.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/notifications/services/notifications_service.dart';
import '../../features/tasks/services/tasks_service.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AppShell({super.key, required this.child, required this.currentPath});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final NotificationsService _notificationsService = NotificationsService();
  final TasksService _tasksService = TasksService();
  final RealtimeService _realtimeService = RealtimeService();

  int? _unreadNotifications;
  int? _unreadChatMessages;
  int? _lateTasks;
  UserExperience? _userExperience;
  bool _hasSession = false;
  Timer? _metricsTimer;
  Timer? _notificationTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  StreamSubscription<PushIncomingMessage>? _foregroundPushSubscription;
  StreamSubscription<PushIncomingMessage>? _openedPushSubscription;
  bool _metricsLoading = false;
  bool _notificationLoading = false;
  bool _chatMetricLoading = false;
  String? _lastPresentedNotificationId;
  final PushOpenReadinessGate _pushOpenGate = PushOpenReadinessGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeSubscription = _realtimeService.events.listen((event) {
      if (event['type'] == 'connected' && event['unread_count'] != null) {
        final unreadCount = int.tryParse(event['unread_count'].toString());
        if (unreadCount != null && mounted) {
          setState(() => _unreadNotifications = unreadCount);
        }
      }
      if (event['type'] == 'notification') {
        final unreadCount = int.tryParse(
          event['unread_count']?.toString() ?? '',
        );
        if (unreadCount != null && mounted) {
          setState(() => _unreadNotifications = unreadCount);
        }
        _loadNotificationMetric();
      }
      if (event['type'] == 'chat' || event['type'] == 'read') {
        _loadChatMetric();
      }
    });
    unawaited(_realtimeService.start());
    unawaited(_startPushLifecycle());
    _metricsTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _loadNavigationMetrics();
    });
    _notificationTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadNotificationMetric();
      _loadChatMetric();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushOpenGate.discard();
    _metricsTimer?.cancel();
    _notificationTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_foregroundPushSubscription?.cancel());
    unawaited(_openedPushSubscription?.cancel());
    unawaited(_realtimeService.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNavigationMetrics();
      unawaited(PushLifecycleController.instance.reconcileOnResume());
    }
  }

  Future<void> _startPushLifecycle() async {
    final push = PushLifecycleController.instance;
    _foregroundPushSubscription = push.foregroundMessages.listen(
      _presentForegroundPush,
    );
    _openedPushSubscription = push.openedMessages.listen(_receivePushOpen);
    final initial = await push.platform.initialMessage();
    if (initial != null) _receivePushOpen(initial);
    await push.activateForAuthenticatedUser();

    bool? authenticated;
    try {
      await _authService.getCurrentUser();
      authenticated = true;
    } on ApiException catch (exception) {
      if (exception.statusCode == 401 || exception.statusCode == 403) {
        authenticated = false;
      }
    } catch (_) {
      authenticated = false;
    }
    if (!mounted) return;
    if (authenticated != null) _resolvePushSession(authenticated);
    _loadNavigationMetrics();
  }

  void _resolvePushSession(bool authenticated) {
    if (!mounted) return;
    setState(() => _hasSession = authenticated);
    final pending = _pushOpenGate.resolve(authenticated: authenticated);
    if (pending != null) unawaited(_openAuthenticatedPush(pending));
  }

  void _receivePushOpen(PushIncomingMessage message) {
    final ready = _pushOpenGate.receive(message);
    if (ready != null) unawaited(_openAuthenticatedPush(ready));
  }

  void _presentForegroundPush(PushIncomingMessage message) {
    if (!mounted || !_hasSession) return;
    final title = message.title?.trim();
    final body = message.body?.trim();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Text(
            [
              if (title?.isNotEmpty == true) title!,
              if (body?.isNotEmpty == true) body!,
            ].join('\n'),
          ),
          action: SnackBarAction(
            label: 'Ouvrir',
            onPressed: () => _openAuthenticatedPush(message),
          ),
        ),
      );
    _loadNotificationMetric();
  }

  Future<void> _openAuthenticatedPush(PushIncomingMessage message) async {
    if (!mounted || !_hasSession) return;
    await PushLifecycleController.instance.markReadBestEffort(
      message.data['notification_id'],
    );
    if (!mounted) return;
    context.go(PushNavigationResolver.fromData(message.data));
    _loadNotificationMetric();
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

    int? lateTasks;
    UserExperience? userExperience;

    try {
      try {
        final token = await _authService.getToken();
        if (mounted) {
          setState(() => _hasSession = token != null && token.isNotEmpty);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _hasSession = false);
        }
      }

      try {
        final cachedUser = await _authService.getCachedCurrentUser();
        if (cachedUser != null) {
          userExperience = UserExperience.fromJson(cachedUser);
          if (mounted) {
            setState(() => _userExperience = userExperience);
          }
        }
      } catch (_) {
        userExperience = null;
      }

      await _loadNotificationMetric();
      await _loadChatMetric();

      try {
        final user = await _authService.getCurrentUser();
        userExperience = UserExperience.fromJson(user);
        _resolvePushSession(true);
      } on ApiException catch (exception) {
        if (exception.statusCode == 401 || exception.statusCode == 403) {
          _resolvePushSession(false);
        }
        userExperience = null;
      } catch (_) {
        userExperience = null;
      }

      try {
        lateTasks = (await _tasksService.getLateTasks()).length;
      } catch (_) {
        lateTasks = null;
      }

      if (!mounted) return;

      setState(() {
        _lateTasks = lateTasks;
        _userExperience = userExperience;
      });
    } finally {
      _metricsLoading = false;
    }
  }

  Future<void> _loadNotificationMetric() async {
    if (_notificationLoading) return;
    _notificationLoading = true;

    try {
      final unreadNotifications = await _notificationsService.getUnreadCount();
      final previousUnread = _unreadNotifications;
      NotificationModel? latestNotification;

      if (previousUnread != null &&
          unreadNotifications > previousUnread &&
          widget.currentPath != '/notifications') {
        final unreadItems = await _notificationsService.getNotifications(
          unreadOnly: true,
        );
        if (unreadItems.isNotEmpty) {
          latestNotification = unreadItems.first;
        }
      }

      if (!mounted) return;
      setState(() => _unreadNotifications = unreadNotifications);

      if (latestNotification != null) {
        _presentNotification(latestNotification);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unreadNotifications = null);
      }
    } finally {
      _notificationLoading = false;
    }
  }

  Future<void> _loadChatMetric() async {
    if (_chatMetricLoading) return;
    _chatMetricLoading = true;

    try {
      final unreadChatMessages = await _chatService.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadChatMessages = unreadChatMessages);
    } catch (_) {
      if (mounted) {
        setState(() => _unreadChatMessages = null);
      }
    } finally {
      _chatMetricLoading = false;
    }
  }

  void _presentNotification(NotificationModel notification) {
    if (_lastPresentedNotificationId == notification.id || !mounted) return;
    _lastPresentedNotificationId = notification.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            content: Text(
              notification.message?.trim().isNotEmpty == true
                  ? '${notification.title}\n${notification.message}'
                  : notification.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            action: SnackBarAction(
              label: 'Ouvrir',
              onPressed: () {
                context.go(notification.routePath ?? '/notifications');
              },
            ),
          ),
        );
    });
  }

  Future<void> _logout(BuildContext context) async {
    final all = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Déconnecter cet appareil ou tous vos appareils ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cet appareil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tous les appareils'),
          ),
        ],
      ),
    );
    if (all == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runLogoutWithPushCleanup(
        cleanup: () =>
            PushLifecycleController.instance.cleanupForLogout(allDevices: all),
        logout: all ? _authService.logoutAll : _authService.logout,
      );
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Déconnexion serveur non confirmée. Vérifiez votre connexion avant de réessayer.',
            ),
          ),
        );
      }
    }

    _pushOpenGate.discard();

    if (!context.mounted) return;
    context.go('/login');
  }

  void _refresh(BuildContext context) {
    _loadNavigationMetrics();
    GoRouter.of(context).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final title = _navigationTitle(widget.currentPath);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideMenu(
              currentPath: widget.currentPath,
              userExperience: _userExperience,
              hasSession: _hasSession,
              unreadNotifications: _unreadNotifications,
              unreadChatMessages: _unreadChatMessages,
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
        titleSpacing: 8,
        title: Text(_mobileNavigationTitle(widget.currentPath)),
        actions: [
          _NotificationIconButton(
            unreadNotifications: _unreadNotifications,
            onPressed: () => context.go('/notifications'),
          ),
          IconButton(
            onPressed: () => context.go('/settings'),
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton(
            onPressed: () => _logout(context),
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      bottomNavigationBar: MobileBottomNavigation(
        currentPath: widget.currentPath,
        userExperience: _userExperience,
        unreadNotifications: _unreadNotifications,
        unreadChatMessages: _unreadChatMessages,
        lateTasks: _lateTasks,
      ),
      drawer: Drawer(
        child: _SideMenu(
          currentPath: widget.currentPath,
          userExperience: _userExperience,
          hasSession: _hasSession,
          unreadNotifications: _unreadNotifications,
          unreadChatMessages: _unreadChatMessages,
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
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
            onPressed: () => context.go('/settings'),
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_rounded),
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
  final bool hasSession;
  final int? unreadNotifications;
  final int? unreadChatMessages;
  final int? lateTasks;
  final VoidCallback onLogout;
  final bool compact;

  const _SideMenu({
    required this.currentPath,
    required this.userExperience,
    required this.hasSession,
    required this.unreadNotifications,
    required this.unreadChatMessages,
    required this.lateTasks,
    required this.onLogout,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final allowedRoutes = _visibleShellRoutes(userExperience, hasSession);
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
                    badgeCount: unreadChatMessages,
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
        width: compact ? null : 232,
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
                child: Column(
                  children: [
                    _NavigationTile(
                      item: const _MenuItem(
                        label: 'Réglages',
                        icon: Icons.settings_rounded,
                        path: '/settings',
                      ),
                      selected: _isSelected(currentPath, '/settings'),
                      compact: compact,
                    ),
                    _LogoutTile(onLogout: onLogout),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Set<String> _visibleShellRoutes(UserExperience? user, bool hasSession) {
  if (user != null) {
    return UserExperience.visibleRoutesFor(user).toSet();
  }

  if (!hasSession) {
    return UserExperience.visibleRoutesFor(null).toSet();
  }

  return const {
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
}

class _BrandHeader extends StatelessWidget {
  final UserExperience? userExperience;

  const _BrandHeader({required this.userExperience});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Image.asset(BrandAssets.icon, fit: BoxFit.contain),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppTheme.enactusYellow : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (compact) Navigator.of(context).pop();
            context.go(item.path);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? const Border(
                      left: BorderSide(color: Colors.white, width: 3),
                    )
                  : null,
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

class MobileBottomNavigation extends StatelessWidget {
  final String currentPath;
  final UserExperience? userExperience;
  final int? unreadNotifications;
  final int? unreadChatMessages;
  final int? lateTasks;

  const MobileBottomNavigation({
    super.key,
    required this.currentPath,
    required this.userExperience,
    required this.unreadNotifications,
    required this.unreadChatMessages,
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
        badgeCount: unreadChatMessages,
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
      _MobileDestination(
        label: 'Présences',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check_rounded,
        path: '/attendance',
      ),
      _MobileDestination(
        label: 'Pôles',
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub_rounded,
        path: '/poles',
      ),
      _MobileDestination(
        label: 'Projets',
        icon: Icons.rocket_launch_outlined,
        selectedIcon: Icons.rocket_launch_rounded,
        path: '/projects',
      ),
      _MobileDestination(
        label: 'Événements',
        icon: Icons.event_outlined,
        selectedIcon: Icons.event_rounded,
        path: '/events',
      ),
      _MobileDestination(
        label: 'Finance',
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments_rounded,
        path: '/finance',
      ),
      _MobileDestination(
        label: 'Alumni',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school_rounded,
        path: '/alumni',
      ),
      _MobileDestination(
        label: 'Recrutement',
        icon: Icons.how_to_reg_outlined,
        selectedIcon: Icons.how_to_reg_rounded,
        path: '/recruitment',
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

    final compactLabels = MediaQuery.sizeOf(context).width < 380;

    return NavigationBar(
      height: 72,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => context.go(destinations[index].path),
      labelBehavior: compactLabels
          ? NavigationDestinationLabelBehavior.onlyShowSelected
          : NavigationDestinationLabelBehavior.alwaysShow,
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
    '/settings': 'Réglages',
    '/help': 'Centre d’aide',
  };

  return sections.entries
      .firstWhere(
        (entry) => _isSelected(currentPath, entry.key),
        orElse: () => const MapEntry('/dashboard', 'EnactSpace'),
      )
      .value;
}

String _mobileNavigationTitle(String currentPath) {
  if (_isSelected(currentPath, '/dashboard')) return 'Accueil';
  return _navigationTitle(currentPath);
}
