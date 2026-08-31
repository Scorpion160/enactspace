import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/app_components.dart';
import '../models/dashboard_summary_model.dart';
import '../services/dashboard_gateway.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardGateway? gateway;

  const DashboardScreen({super.key, this.gateway});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardGateway _gateway;

  bool _loading = true;
  String? _error;
  DashboardSummaryModel? _summary;
  UserExperience? _userExperience;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiDashboardGateway();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await _gateway.loadSummary();

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _userExperience = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 560
              ? 14.0
              : constraints.maxWidth >= 1440
              ? 36.0
              : 24.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              28,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardHero(
                        summary: _summary,
                        userExperience: _userExperience,
                        loading: _loading,
                        onRefresh: _loadDashboard,
                      ),
                      const SizedBox(height: 20),
                      if (_loading)
                        const _DashboardLoading()
                      else if (_error != null)
                        _DashboardError(
                          message: _error!,
                          onRetry: _loadDashboard,
                        )
                      else if (_summary != null)
                        _DashboardBody(
                          summary: _summary!,
                          userExperience: _userExperience,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardSummaryModel summary;
  final UserExperience? userExperience;

  const _DashboardBody({required this.summary, required this.userExperience});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1060;
        final isAdmin = summary.profile.canViewGlobal;
        final main = Column(
          children: [
            if (isAdmin) ...[
              _AttentionPanel(items: _attentionItems(summary)),
              const SizedBox(height: 18),
            ],
            _SummaryGrid(cards: _metricCards(summary), compactMobile: !isAdmin),
            const SizedBox(height: 18),
            _RoleCardsGrid(cards: _roleCards(summary, userExperience)),
            const SizedBox(height: 18),
            _QuickActionsPanel(
              userExperience: userExperience,
              summary: summary,
            ),
          ],
        );
        final side = Column(
          children: [
            if (!isAdmin) ...[
              _AttentionPanel(items: _attentionItems(summary)),
              const SizedBox(height: 18),
            ],
            _RoleFocusPanel(summary: summary, userExperience: userExperience),
            const SizedBox(height: 18),
            _ActivityPanel(items: summary.recentActivity),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 8, child: main),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: side),
            ],
          );
        }

        return Column(children: [main, const SizedBox(height: 18), side]);
      },
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final DashboardSummaryModel? summary;
  final UserExperience? userExperience;
  final bool loading;
  final VoidCallback onRefresh;

  const _DashboardHero({
    required this.summary,
    required this.userExperience,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final profile = summary?.profile;
    final displayName =
        profile?.displayName ?? userExperience?.displayName ?? 'Enacteur';
    final subtitle =
        userExperience?.dashboardSubtitle ?? _subtitleForProfile(profile);
    final unread = summary?.counts.integer('notifications_unread') ?? 0;
    final lateTasks = summary?.counts.integer('tasks_late') ?? 0;
    final statusText = loading
        ? 'Synchronisation des données...'
        : unread + lateTasks == 0
        ? 'Aucune alerte urgente pour le moment.'
        : '${unread + lateTasks} point(s) à suivre aujourd’hui.';
    final isAdmin = profile?.canViewGlobal == true;
    return AppDataCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppPrimaryButton(
                label: isAdmin ? 'Voir les alertes' : 'Mes taches',
                icon: isAdmin
                    ? Icons.priority_high_rounded
                    : Icons.task_alt_rounded,
                onPressed: () =>
                    context.go(isAdmin ? '/notifications' : '/tasks'),
              ),
              AppSecondaryButton(
                label: 'Actualiser',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              ),
            ],
          );
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppStatusBadge(
                label: userExperience?.audienceLabel ?? 'Enactus ESP',
                tone: AppStatusTone.info,
              ),
              const SizedBox(height: 8),
              Container(width: 34, height: 3, color: AppTheme.enactusYellow),
              const SizedBox(height: 10),
              Text(
                'Bonjour, $displayName',
                style: TextStyle(
                  fontSize: compact ? 25 : 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.secondaryText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: unread + lateTasks > 0
                      ? AppTheme.warning
                      : AppTheme.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 16), actions],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 24),
                    actions,
                  ],
                );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<_MetricCardData> cards;
  final bool compactMobile;

  const _SummaryGrid({required this.cards, required this.compactMobile});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 480 || compactMobile
            ? 2
            : 1;
        final compact = compactMobile && constraints.maxWidth < 480;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _MetricCard(data: card, compact: compact),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool danger;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.danger = false,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;
  final bool compact;

  const _MetricCard({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 180 : 166,
      child: AppMetric(
        label: data.title,
        value: data.value,
        detail: data.subtitle,
        icon: data.icon,
        tone: data.danger ? AppStatusTone.warning : AppStatusTone.neutral,
        onTap: () => context.go(data.route),
      ),
    );
  }
}

class _RoleCardsGrid extends StatelessWidget {
  final List<_RoleCardData> cards;

  const _RoleCardsGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return _DashboardSection(
      icon: Icons.dashboard_customize_rounded,
      title: 'Cartes adaptées à ton rôle',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 820
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          const spacing = 12.0;
          final width = (constraints.maxWidth - spacing * (count - 1)) / count;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final card in cards)
                SizedBox(
                  width: width,
                  child: _RoleCard(data: card),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color? color;

  const _RoleCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.color,
  });
}

class _RoleCard extends StatelessWidget {
  final _RoleCardData data;

  const _RoleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.color ?? AppTheme.softBlack;

    return InkWell(
      onTap: () => context.go(data.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: color,
                  child: Icon(data.icon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final UserExperience? userExperience;
  final DashboardSummaryModel summary;

  const _QuickActionsPanel({
    required this.userExperience,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final allowedRoutes = UserExperience.visibleRoutesFor(
      userExperience,
    ).toSet();
    final actions = _quickActions(
      summary,
    ).where((action) => allowedRoutes.contains(action.route)).toList();

    return _DashboardSection(
      icon: Icons.flash_on_rounded,
      title: 'Actions rapides',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 820
              ? 4
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 84,
            ),
            itemBuilder: (context, index) {
              return _QuickActionTile(action: actions[index]);
            },
          );
        },
      ),
    );
  }
}

class _QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool primary;

  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.primary = false,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickActionData action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final background = action.primary
        ? AppTheme.enactusYellow.withValues(alpha: 0.24)
        : AppTheme.enactusYellow.withValues(alpha: 0.12);
    final border = action.primary
        ? AppTheme.enactusYellow.withValues(alpha: 0.58)
        : AppTheme.enactusYellow.withValues(alpha: 0.30);

    return InkWell(
      onTap: () => context.go(action.route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: action.primary
                  ? AppTheme.softBlack
                  : AppTheme.enactusYellow,
              foregroundColor: action.primary
                  ? Colors.white
                  : AppTheme.softBlack,
              child: Icon(action.icon, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  final List<_AttentionItem> items;

  const _AttentionPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      icon: Icons.notifications_active_rounded,
      title: 'À suivre aujourd’hui',
      child: Column(
        children: [
          if (items.isEmpty)
            const _EmptyState(
              icon: Icons.check_circle_rounded,
              title: 'Rien de critique',
              message: 'Les alertes importantes apparaîtront ici.',
            )
          else
            for (final item in items) _AttentionTile(item: item),
        ],
      ),
    );
  }
}

class _AttentionItem {
  final String title;
  final String message;
  final IconData icon;
  final String route;
  final bool danger;

  const _AttentionItem({
    required this.title,
    required this.message,
    required this.icon,
    required this.route,
    this.danger = false,
  });
}

class _AttentionTile extends StatelessWidget {
  final _AttentionItem item;

  const _AttentionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? Colors.red.shade700 : AppTheme.softBlack;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.danger
                ? Colors.red.shade50
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final List<DashboardActivityModel> items;

  const _ActivityPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      icon: Icons.history_rounded,
      title: 'Activité récente',
      child: Column(
        children: [
          if (items.isEmpty)
            const _EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'Aucune activité récente',
              message:
                  'Les notifications, posts et affectations apparaîtront ici.',
            )
          else
            for (final item in items) _ActivityTile(item: item),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final DashboardActivityModel item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.enactusYellow,
        foregroundColor: AppTheme.softBlack,
        child: Icon(_activityIcon(item.type), size: 20),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(_relativeTime(item.createdAt)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(item.route),
    );
  }
}

class _RoleFocusPanel extends StatelessWidget {
  final DashboardSummaryModel summary;
  final UserExperience? userExperience;

  const _RoleFocusPanel({required this.summary, required this.userExperience});

  @override
  Widget build(BuildContext context) {
    final profile = summary.profile;
    final counts = summary.counts;
    final items = _focusItems(profile, counts, userExperience);

    return _DashboardSection(
      icon: Icons.center_focus_strong_rounded,
      title: 'Priorité du moment',
      child: Column(
        children: [
          for (final item in items)
            _SoftMetric(label: item.$1, value: item.$2, icon: item.$3),
        ],
      ),
    );
  }
}

class _SoftMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SoftMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DashboardSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.black38),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(42),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade700,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement du dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
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
    );
  }
}

List<_MetricCardData> _metricCards(DashboardSummaryModel summary) {
  final counts = summary.counts;
  final profile = summary.profile;
  final cards = <_MetricCardData>[
    _MetricCardData(
      title: 'Notifications',
      value: counts.integerLabel('notifications_unread'),
      subtitle: 'non lues',
      icon: Icons.notifications_active_rounded,
      route: '/notifications',
      danger: counts.integer('notifications_unread') > 0,
    ),
    _MetricCardData(
      title: 'Mes tâches',
      value: counts.integerLabel('tasks_assigned'),
      subtitle: counts.hasValue('tasks_late')
          ? '${counts.integer('tasks_late')} en retard'
          : 'retard indisponible',
      icon: Icons.task_alt_rounded,
      route: '/tasks?view=my',
      danger: counts.integer('tasks_late') > 0,
    ),
    _MetricCardData(
      title: 'Messages',
      value: counts.integerLabel('messages_unread'),
      subtitle: 'messages non lus',
      icon: Icons.chat_rounded,
      route: '/chat',
      danger: counts.integer('messages_unread') > 0,
    ),
    _MetricCardData(
      title: 'Événements',
      value: counts.integerLabel('events_upcoming'),
      subtitle: 'à venir',
      icon: Icons.event_available_rounded,
      route: '/events',
    ),
    _MetricCardData(
      title: 'Documents',
      value: counts.integerLabel('documents_accessible'),
      subtitle: 'accessibles',
      icon: Icons.folder_copy_rounded,
      route: '/documents',
    ),
    _MetricCardData(
      title: 'Engagement',
      value: counts.integerLabel('badges_points'),
      subtitle: counts.hasValue('badges_count')
          ? '${counts.integer('badges_count')} badge(s)'
          : 'badges indisponibles',
      icon: Icons.workspace_premium_rounded,
      route: '/gamification',
    ),
  ];

  if (counts.hasValue('members_active')) {
    cards.add(
      _MetricCardData(
        title: 'Membres actifs',
        value: counts.integerLabel('members_active'),
        subtitle: counts.hasValue('members_inactive')
            ? '${counts.integer('members_inactive')} inactif(s)'
            : 'donnée partielle',
        icon: Icons.people_alt_rounded,
        route: '/members',
      ),
    );
  }

  if (counts.hasValue('projects_active')) {
    cards.add(
      _MetricCardData(
        title: 'Projets actifs',
        value: counts.integerLabel('projects_active'),
        subtitle: counts.hasValue('poles')
            ? '${counts.integer('poles')} pôle(s)'
            : 'donnée partielle',
        icon: Icons.rocket_launch_rounded,
        route: '/projects',
      ),
    );
  }

  if (profile.canManageDocuments &&
      counts.hasValue('documents_pending_validation')) {
    cards.add(
      _MetricCardData(
        title: 'Documents à valider',
        value: counts.integerLabel('documents_pending_validation'),
        subtitle: 'en attente',
        icon: Icons.verified_rounded,
        route: '/documents',
        danger: counts.integer('documents_pending_validation') > 0,
      ),
    );
  }

  if (profile.canViewFinance) {
    cards.addAll([
      if (counts.hasValue('payments_pending'))
        _MetricCardData(
          title: 'Paiements',
          value: counts.integerLabel('payments_pending'),
          subtitle: 'à valider',
          icon: Icons.pending_actions_rounded,
          route: '/finance',
          danger: counts.integer('payments_pending') > 0,
        ),
      if (counts.hasValue('finance_due'))
        _MetricCardData(
          title: 'À encaisser',
          value: _money(counts.decimal('finance_due')),
          subtitle: 'solde global',
          icon: Icons.account_balance_wallet_rounded,
          route: '/finance',
          danger: counts.decimal('finance_due') > 0,
        ),
    ]);
  }

  if (profile.canViewRecruitment && counts.hasValue('applications_pending')) {
    cards.add(
      _MetricCardData(
        title: 'Candidatures',
        value: counts.integerLabel('applications_pending'),
        subtitle: 'à suivre',
        icon: Icons.how_to_reg_rounded,
        route: '/recruitment',
        danger: counts.integer('applications_pending') > 0,
      ),
    );
  }

  return cards;
}

List<_RoleCardData> _roleCards(
  DashboardSummaryModel summary,
  UserExperience? user,
) {
  final profile = summary.profile;
  final counts = summary.counts;
  final cards = <_RoleCardData>[];

  void add({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    Color? color,
  }) {
    if (!counts.hasValue(key)) return;
    cards.add(
      _RoleCardData(
        title: title,
        value: counts.integerLabel(key),
        subtitle: subtitle,
        icon: icon,
        route: route,
        color: color,
      ),
    );
  }

  if (profile.canViewGlobal) {
    add(
      key: 'members_active',
      title: 'Vue club',
      subtitle: 'membres actifs actuellement',
      icon: Icons.groups_rounded,
      route: '/members',
    );
    add(
      key: 'projects_active',
      title: 'Projets en mouvement',
      subtitle: 'projets actifs',
      icon: Icons.rocket_launch_rounded,
      route: '/projects',
    );
    add(
      key: 'documents_pending_validation',
      title: 'Organisation',
      subtitle: 'document(s) à valider',
      icon: Icons.fact_check_rounded,
      route: '/documents',
    );
    return cards;
  }

  if (profile.canViewFinance) {
    add(
      key: 'payments_pending',
      title: 'Paiements récents',
      subtitle: 'paiement(s) à valider',
      icon: Icons.pending_actions_rounded,
      route: '/finance',
      color: Colors.green.shade800,
    );
    if (counts.hasValue('finance_due')) {
      cards.add(
        _RoleCardData(
          title: 'Cotisations',
          value: _money(counts.decimal('finance_due')),
          subtitle: 'reste à encaisser',
          icon: Icons.account_balance_wallet_rounded,
          route: '/finance',
          color: Colors.green.shade800,
        ),
      );
    }
    return cards;
  }

  if (profile.canViewGlobalMembers || profile.canManageDocuments) {
    add(
      key: 'absences_recent',
      title: 'Présences',
      subtitle: 'absences récentes',
      icon: Icons.event_busy_rounded,
      route: '/attendance',
    );
    add(
      key: 'documents_pending_validation',
      title: 'Documents',
      subtitle: 'validation et classement',
      icon: Icons.description_rounded,
      route: '/documents',
    );
    add(
      key: 'applications_pending',
      title: 'Candidatures',
      subtitle: 'profils à suivre',
      icon: Icons.how_to_reg_rounded,
      route: '/recruitment',
    );
    return cards;
  }

  if (profile.isEnacchef) {
    add(
      key: 'tasks_assigned',
      title: 'Mon périmètre',
      subtitle: 'tâche(s) où je suis impliqué',
      icon: Icons.task_alt_rounded,
      route: '/tasks?view=my',
    );
    add(
      key: 'projects_active',
      title: 'Projets',
      subtitle: 'projets actifs à coordonner',
      icon: Icons.rocket_launch_rounded,
      route: '/projects',
    );
    add(
      key: 'posts_recent',
      title: 'Communication',
      subtitle: 'posts récents visibles',
      icon: Icons.campaign_rounded,
      route: '/posts',
    );
    return cards;
  }

  if (profile.isAlumni || user?.isAlumni == true) {
    add(
      key: 'posts_recent',
      title: 'Annonces',
      subtitle: 'publications accessibles',
      icon: Icons.campaign_rounded,
      route: '/posts',
    );
    add(
      key: 'events_upcoming',
      title: 'Événements',
      subtitle: 'moments ouverts au réseau',
      icon: Icons.event_available_rounded,
      route: '/events',
    );
    return cards;
  }

  add(
    key: 'tasks_assigned',
    title: 'Mes tâches',
    subtitle: 'suivi opérationnel',
    icon: Icons.task_alt_rounded,
    route: '/tasks?view=my',
  );
  add(
    key: 'messages_unread',
    title: 'Mes échanges',
    subtitle: 'message(s) à lire',
    icon: Icons.chat_rounded,
    route: '/chat',
  );
  add(
    key: 'badges_points',
    title: 'Mon engagement',
    subtitle: 'points obtenus',
    icon: Icons.workspace_premium_rounded,
    route: '/gamification',
  );
  return cards;
}

List<_AttentionItem> _attentionItems(DashboardSummaryModel summary) {
  final counts = summary.counts;
  final items = <_AttentionItem>[];

  if ((counts.nullableInteger('tasks_late') ?? 0) > 0) {
    items.add(
      _AttentionItem(
        title: 'Tâches en retard',
        message:
            '${counts.integer('tasks_late')} tâche(s) doivent être suivies.',
        icon: Icons.warning_rounded,
        route: '/tasks?view=late',
        danger: true,
      ),
    );
  }
  if ((counts.nullableInteger('notifications_unread') ?? 0) > 0) {
    items.add(
      _AttentionItem(
        title: 'Notifications',
        message:
            '${counts.integer('notifications_unread')} notification(s) non lue(s).',
        icon: Icons.notifications_rounded,
        route: '/notifications',
      ),
    );
  }
  if ((counts.nullableInteger('messages_unread') ?? 0) > 0) {
    items.add(
      _AttentionItem(
        title: 'Messages',
        message: '${counts.integer('messages_unread')} message(s) non lu(s).',
        icon: Icons.chat_rounded,
        route: '/chat',
      ),
    );
  }
  if ((counts.nullableInteger('events_upcoming') ?? 0) > 0) {
    items.add(
      _AttentionItem(
        title: 'Prochains événements',
        message: '${counts.integer('events_upcoming')} événement(s) à venir.',
        icon: Icons.event_available_rounded,
        route: '/events',
      ),
    );
  }

  return items;
}

List<_QuickActionData> _quickActions(DashboardSummaryModel summary) {
  final profile = summary.profile;
  return [
    if (profile.isEnacchef)
      const _QuickActionData(
        title: 'Créer une tâche',
        subtitle: 'Brief et suivi',
        icon: Icons.add_task_rounded,
        route: '/tasks',
        primary: true,
      ),
    if (profile.canManageDocuments)
      const _QuickActionData(
        title: 'Valider documents',
        subtitle: 'PV, rapports, fichiers',
        icon: Icons.verified_rounded,
        route: '/documents',
        primary: true,
      ),
    if (profile.canViewFinance)
      const _QuickActionData(
        title: 'Ouvrir finance',
        subtitle: 'Paiements et cotisations',
        icon: Icons.account_balance_wallet_rounded,
        route: '/finance',
        primary: true,
      ),
    if (profile.canViewRecruitment)
      const _QuickActionData(
        title: 'Voir candidatures',
        subtitle: 'Tri et suivi',
        icon: Icons.how_to_reg_rounded,
        route: '/recruitment',
        primary: true,
      ),
    const _QuickActionData(
      title: 'Chat',
      subtitle: 'Discussions',
      icon: Icons.chat_rounded,
      route: '/chat',
    ),
    const _QuickActionData(
      title: 'Notifications',
      subtitle: 'Alertes et suivi',
      icon: Icons.notifications_rounded,
      route: '/notifications',
    ),
    const _QuickActionData(
      title: 'Créer un post',
      subtitle: 'Communication',
      icon: Icons.campaign_rounded,
      route: '/posts',
    ),
    const _QuickActionData(
      title: 'Mes tâches',
      subtitle: 'Suivi opérationnel',
      icon: Icons.task_alt_rounded,
      route: '/tasks',
    ),
    const _QuickActionData(
      title: 'Ajouter document',
      subtitle: 'PV ou ressource',
      icon: Icons.upload_file_rounded,
      route: '/documents',
    ),
    if (profile.canViewGlobalMembers || profile.isEnacchef)
      const _QuickActionData(
        title: 'Membres',
        subtitle: 'Profils, rôles, affectations',
        icon: Icons.people_alt_rounded,
        route: '/members',
      ),
    if (profile.isEnacchef)
      const _QuickActionData(
        title: 'Pôles',
        subtitle: 'Équipes',
        icon: Icons.hub_rounded,
        route: '/poles',
      ),
    if (profile.isEnacchef)
      const _QuickActionData(
        title: 'Projets',
        subtitle: 'Impact',
        icon: Icons.rocket_launch_rounded,
        route: '/projects',
      ),
    if (profile.canViewAttendance)
      const _QuickActionData(
        title: 'Présences',
        subtitle: 'Sessions et retards',
        icon: Icons.fact_check_rounded,
        route: '/attendance',
      ),
    const _QuickActionData(
      title: 'Événements',
      subtitle: 'Planning',
      icon: Icons.event_available_rounded,
      route: '/events',
    ),
  ];
}

List<(String, String, IconData)> _focusItems(
  DashboardProfileModel profile,
  DashboardCountsModel counts,
  UserExperience? user,
) {
  final items = <(String, String, IconData)>[];

  void add(String key, String label, IconData icon) {
    if (counts.hasValue(key)) {
      items.add((label, counts.integerLabel(key), icon));
    }
  }

  void addMoney(String key, String label, IconData icon) {
    if (counts.hasValue(key)) {
      items.add((label, _money(counts.decimal(key)), icon));
    }
  }

  if (profile.canViewFinance) {
    add(
      'payments_pending',
      'Paiements à valider',
      Icons.pending_actions_rounded,
    );
    addMoney('finance_due', 'Montant à encaisser', Icons.payments_rounded);
    addMoney('finance_paid', 'Montant encaissé', Icons.verified_rounded);
    return items;
  }
  if (profile.canViewRecruitment) {
    add(
      'applications_pending',
      'Candidatures à suivre',
      Icons.how_to_reg_rounded,
    );
    add(
      'documents_pending_validation',
      'Documents à valider',
      Icons.description_rounded,
    );
    add('events_upcoming', 'Événements à venir', Icons.event_rounded);
    return items;
  }
  if (profile.isEnacchef) {
    add('projects_active', 'Projets actifs', Icons.rocket_launch_rounded);
    add('poles', 'Pôles suivis', Icons.hub_rounded);
    add('tasks_late', 'Tâches en retard', Icons.warning_rounded);
    return items;
  }
  if (profile.isAlumni || user?.isAlumni == true) {
    add('posts_recent', 'Annonces récentes', Icons.campaign_rounded);
    add('events_upcoming', 'Événements ouverts', Icons.event_available_rounded);
    add('messages_unread', 'Messages non lus', Icons.chat_rounded);
    return items;
  }
  add('tasks_assigned', 'Mes tâches', Icons.task_alt_rounded);
  add('badges_points', 'Mes points', Icons.workspace_premium_rounded);
  add('messages_unread', 'Mes messages', Icons.chat_rounded);
  return items;
}

IconData _activityIcon(String type) {
  switch (type) {
    case 'post':
      return Icons.campaign_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'document':
      return Icons.description_rounded;
    case 'recruitment':
      return Icons.how_to_reg_rounded;
    case 'assignment':
      return Icons.hub_rounded;
    case 'notification':
      return Icons.notifications_rounded;
    default:
      return Icons.history_rounded;
  }
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'À l’instant';
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _money(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < rounded.length; index++) {
    final reverseIndex = rounded.length - index;
    buffer.write(rounded[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} FCFA';
}

String _subtitleForProfile(DashboardProfileModel? profile) {
  if (profile?.isAlumni == true) {
    return 'Annonces, échanges, événements et réseau alumni.';
  }
  if (profile?.canViewGlobal == true) {
    return 'Vue club, membres, projets, documents, finance et alertes.';
  }
  if (profile?.canViewFinance == true) {
    return 'Cotisations, paiements et signaux financiers utiles.';
  }
  if (profile?.isEnacchef == true) {
    return 'Tes équipes, tâches, documents, projets et points à suivre.';
  }
  return 'Tes tâches, messages, documents et prochains rendez-vous.';
}
