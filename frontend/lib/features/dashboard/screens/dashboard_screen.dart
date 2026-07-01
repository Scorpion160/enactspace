import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../models/dashboard_summary_model.dart';
import '../services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final AuthService _authService = AuthService();

  bool _loading = true;
  String? _error;
  DashboardSummaryModel? _summary;
  UserExperience? _userExperience;

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
      final summary = await _dashboardService.getSummary();
      UserExperience? user;

      try {
        user = UserExperience.fromJson(await _authService.getCurrentUser());
      } catch (_) {
        user = null;
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _userExperience = user;
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
          final horizontalPadding = constraints.maxWidth < 560 ? 14.0 : 24.0;

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
                  constraints: const BoxConstraints(maxWidth: 1280),
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
        final main = Column(
          children: [
            _SummaryGrid(cards: _metricCards(summary)),
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
            _AttentionPanel(items: _attentionItems(summary)),
            const SizedBox(height: 18),
            _ActivityPanel(items: summary.recentActivity),
            const SizedBox(height: 18),
            _RoleFocusPanel(summary: summary, userExperience: userExperience),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: side),
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
    final title = userExperience?.dashboardTitle ?? _titleForProfile(profile);
    final subtitle =
        userExperience?.dashboardSubtitle ?? _subtitleForProfile(profile);
    final unread = summary?.counts.integer('notifications_unread') ?? 0;
    final lateTasks = summary?.counts.integer('tasks_late') ?? 0;
    final statusText = loading
        ? 'Synchronisation des données...'
        : unread + lateTasks == 0
        ? 'Aucune alerte urgente pour le moment.'
        : '${unread + lateTasks} point(s) à suivre aujourd’hui.';
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                const _HeroMark(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeroText(
                    title: title,
                    displayName: displayName,
                    subtitle: subtitle,
                    statusText: statusText,
                  ),
                ),
                const SizedBox(width: 18),
                _HeroActions(onRefresh: onRefresh),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroMark(),
                const SizedBox(height: 16),
                _HeroText(
                  title: title,
                  displayName: displayName,
                  subtitle: subtitle,
                  statusText: statusText,
                ),
                const SizedBox(height: 16),
                _HeroActions(onRefresh: onRefresh),
              ],
            ),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.dashboard_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final String title;
  final String displayName;
  final String subtitle;
  final String statusText;

  const _HeroText({
    required this.title,
    required this.displayName,
    required this.subtitle,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.enactusYellow,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroChip(label: statusText),
            const _HeroChip(label: 'Enactus ESP'),
          ],
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}

class _HeroActions extends StatelessWidget {
  final VoidCallback onRefresh;

  const _HeroActions({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/chat'),
          icon: const Icon(Icons.chat_rounded),
          label: const Text('Chat'),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<_MetricCardData> cards;

  const _SummaryGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 480
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
                child: _MetricCard(data: card),
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

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.danger ? Colors.red.shade700 : AppTheme.softBlack;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go(data.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: data.danger
                        ? Colors.red.shade50
                        : AppTheme.enactusYellow,
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
              const SizedBox(height: 14),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
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
      title: 'À suivre',
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
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
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
      value: counts.integer('notifications_unread').toString(),
      subtitle: 'non lues',
      icon: Icons.notifications_active_rounded,
      route: '/notifications',
      danger: counts.integer('notifications_unread') > 0,
    ),
    _MetricCardData(
      title: 'Mes tâches',
      value: counts.integer('tasks_assigned').toString(),
      subtitle: '${counts.integer('tasks_late')} en retard',
      icon: Icons.task_alt_rounded,
      route: '/tasks',
      danger: counts.integer('tasks_late') > 0,
    ),
    _MetricCardData(
      title: 'Messages',
      value: counts.integer('messages_unread').toString(),
      subtitle: 'messages non lus',
      icon: Icons.chat_rounded,
      route: '/chat',
      danger: counts.integer('messages_unread') > 0,
    ),
    _MetricCardData(
      title: 'Événements',
      value: counts.integer('events_upcoming').toString(),
      subtitle: 'à venir',
      icon: Icons.event_available_rounded,
      route: '/events',
    ),
    _MetricCardData(
      title: 'Documents',
      value: counts.integer('documents_accessible').toString(),
      subtitle: 'accessibles',
      icon: Icons.folder_copy_rounded,
      route: '/documents',
    ),
    _MetricCardData(
      title: 'Engagement',
      value: counts.integer('badges_points').toString(),
      subtitle: '${counts.integer('badges_count')} badge(s)',
      icon: Icons.workspace_premium_rounded,
      route: '/gamification',
    ),
  ];

  if (counts.hasValue('members_active')) {
    cards.add(
      _MetricCardData(
        title: 'Membres actifs',
        value: counts.integer('members_active').toString(),
        subtitle: '${counts.integer('members_inactive')} inactif(s)',
        icon: Icons.people_alt_rounded,
        route: '/members',
      ),
    );
  }

  if (counts.hasValue('projects_active')) {
    cards.add(
      _MetricCardData(
        title: 'Projets actifs',
        value: counts.integer('projects_active').toString(),
        subtitle: '${counts.integer('poles')} pôle(s)',
        icon: Icons.rocket_launch_rounded,
        route: '/projects',
      ),
    );
  }

  if (profile.canManageDocuments) {
    cards.add(
      _MetricCardData(
        title: 'Documents à valider',
        value: counts.integer('documents_pending_validation').toString(),
        subtitle: 'en attente',
        icon: Icons.verified_rounded,
        route: '/documents',
        danger: counts.integer('documents_pending_validation') > 0,
      ),
    );
  }

  if (profile.canViewFinance) {
    cards.addAll([
      _MetricCardData(
        title: 'Paiements',
        value: counts.integer('payments_pending').toString(),
        subtitle: 'à valider',
        icon: Icons.pending_actions_rounded,
        route: '/finance',
        danger: counts.integer('payments_pending') > 0,
      ),
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

  if (profile.canViewRecruitment) {
    cards.add(
      _MetricCardData(
        title: 'Candidatures',
        value: counts.integer('applications_pending').toString(),
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

  if (profile.canViewGlobal) {
    return [
      _RoleCardData(
        title: 'Vue club',
        value: counts.integer('members_active').toString(),
        subtitle: 'membres actifs actuellement',
        icon: Icons.groups_rounded,
        route: '/members',
      ),
      _RoleCardData(
        title: 'Projets en mouvement',
        value: counts.integer('projects_active').toString(),
        subtitle: '${counts.integer('poles')} pôle(s) structurés',
        icon: Icons.rocket_launch_rounded,
        route: '/projects',
      ),
      _RoleCardData(
        title: 'Organisation',
        value: counts.integer('documents_pending_validation').toString(),
        subtitle: 'document(s) à valider',
        icon: Icons.fact_check_rounded,
        route: '/documents',
      ),
    ];
  }

  if (profile.canViewFinance) {
    return [
      _RoleCardData(
        title: 'Paiements récents',
        value: counts.integer('payments_pending').toString(),
        subtitle: 'paiement(s) à valider',
        icon: Icons.pending_actions_rounded,
        route: '/finance',
        color: Colors.green.shade800,
      ),
      _RoleCardData(
        title: 'Cotisations',
        value: _money(counts.decimal('finance_due')),
        subtitle: 'reste à encaisser',
        icon: Icons.account_balance_wallet_rounded,
        route: '/finance',
        color: Colors.green.shade800,
      ),
      _RoleCardData(
        title: 'Encaissements',
        value: _money(counts.decimal('finance_paid')),
        subtitle: 'total payé enregistré',
        icon: Icons.verified_rounded,
        route: '/finance',
        color: Colors.green.shade800,
      ),
    ];
  }

  if (profile.canViewGlobalMembers || profile.canManageDocuments) {
    return [
      _RoleCardData(
        title: 'Présences',
        value: counts.integer('absences_recent').toString(),
        subtitle:
            '${counts.integer('late_attendance_recent')} retard(s) suivis',
        icon: Icons.event_busy_rounded,
        route: '/attendance',
      ),
      _RoleCardData(
        title: 'Documents',
        value: counts.integer('documents_pending_validation').toString(),
        subtitle: 'validation et classement',
        icon: Icons.description_rounded,
        route: '/documents',
      ),
      _RoleCardData(
        title: 'Candidatures',
        value: counts.integer('applications_pending').toString(),
        subtitle: 'profils à suivre',
        icon: Icons.how_to_reg_rounded,
        route: '/recruitment',
      ),
    ];
  }

  if (profile.isEnacchef) {
    return [
      _RoleCardData(
        title: 'Mon périmètre',
        value: counts.integer('tasks_assigned').toString(),
        subtitle: 'tâche(s) où je suis impliqué',
        icon: Icons.task_alt_rounded,
        route: '/tasks',
      ),
      _RoleCardData(
        title: 'Projets',
        value: counts.integer('projects_active').toString(),
        subtitle: 'projets actifs à coordonner',
        icon: Icons.rocket_launch_rounded,
        route: '/projects',
      ),
      _RoleCardData(
        title: 'Communication',
        value: counts.integer('posts_recent').toString(),
        subtitle: 'posts récents visibles',
        icon: Icons.campaign_rounded,
        route: '/posts',
      ),
    ];
  }

  if (profile.isAlumni || user?.isAlumni == true) {
    return [
      _RoleCardData(
        title: 'Annonces',
        value: counts.integer('posts_recent').toString(),
        subtitle: 'publications accessibles',
        icon: Icons.campaign_rounded,
        route: '/posts',
      ),
      _RoleCardData(
        title: 'Événements',
        value: counts.integer('events_upcoming').toString(),
        subtitle: 'moments ouverts au réseau',
        icon: Icons.event_available_rounded,
        route: '/events',
      ),
      _RoleCardData(
        title: 'Réseau',
        value: counts.integer('messages_unread').toString(),
        subtitle: 'message(s) non lus',
        icon: Icons.chat_rounded,
        route: '/chat',
      ),
    ];
  }

  return [
    _RoleCardData(
      title: 'Mes tâches',
      value: counts.integer('tasks_assigned').toString(),
      subtitle: '${counts.integer('tasks_done')} terminée(s)',
      icon: Icons.task_alt_rounded,
      route: '/tasks',
    ),
    _RoleCardData(
      title: 'Mes échanges',
      value: counts.integer('messages_unread').toString(),
      subtitle: 'message(s) à lire',
      icon: Icons.chat_rounded,
      route: '/chat',
    ),
    _RoleCardData(
      title: 'Mon engagement',
      value: counts.integer('badges_points').toString(),
      subtitle: '${counts.integer('badges_count')} badge(s)',
      icon: Icons.workspace_premium_rounded,
      route: '/gamification',
    ),
  ];
}

List<_AttentionItem> _attentionItems(DashboardSummaryModel summary) {
  final counts = summary.counts;
  final items = <_AttentionItem>[];

  if (counts.integer('tasks_late') > 0) {
    items.add(
      _AttentionItem(
        title: 'Tâches en retard',
        message:
            '${counts.integer('tasks_late')} tâche(s) doivent être suivies.',
        icon: Icons.warning_rounded,
        route: '/tasks',
        danger: true,
      ),
    );
  }
  if (counts.integer('notifications_unread') > 0) {
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
  if (summary.profile.canViewFinance &&
      counts.integer('payments_pending') > 0) {
    items.add(
      _AttentionItem(
        title: 'Paiements à valider',
        message:
            '${counts.integer('payments_pending')} paiement(s) en attente.',
        icon: Icons.payments_rounded,
        route: '/finance',
        danger: true,
      ),
    );
  }
  if (summary.profile.canManageDocuments &&
      counts.integer('documents_pending_validation') > 0) {
    items.add(
      _AttentionItem(
        title: 'Documents à valider',
        message:
            '${counts.integer('documents_pending_validation')} document(s) attendent.',
        icon: Icons.description_rounded,
        route: '/documents',
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
  if (profile.canViewFinance) {
    return [
      (
        'Paiements à valider',
        counts.integer('payments_pending').toString(),
        Icons.pending_actions_rounded,
      ),
      (
        'Montant à encaisser',
        _money(counts.decimal('finance_due')),
        Icons.payments_rounded,
      ),
      (
        'Montant encaissé',
        _money(counts.decimal('finance_paid')),
        Icons.verified_rounded,
      ),
    ];
  }
  if (profile.canViewRecruitment) {
    return [
      (
        'Candidatures à suivre',
        counts.integer('applications_pending').toString(),
        Icons.how_to_reg_rounded,
      ),
      (
        'Documents à valider',
        counts.integer('documents_pending_validation').toString(),
        Icons.description_rounded,
      ),
      (
        'Événements à venir',
        counts.integer('events_upcoming').toString(),
        Icons.event_rounded,
      ),
    ];
  }
  if (profile.isEnacchef) {
    return [
      (
        'Projets actifs',
        counts.integer('projects_active').toString(),
        Icons.rocket_launch_rounded,
      ),
      ('Pôles suivis', counts.integer('poles').toString(), Icons.hub_rounded),
      (
        'Tâches en retard',
        counts.integer('tasks_late').toString(),
        Icons.warning_rounded,
      ),
    ];
  }
  if (profile.isAlumni || user?.isAlumni == true) {
    return [
      (
        'Annonces récentes',
        counts.integer('posts_recent').toString(),
        Icons.campaign_rounded,
      ),
      (
        'Événements ouverts',
        counts.integer('events_upcoming').toString(),
        Icons.event_available_rounded,
      ),
      (
        'Messages non lus',
        counts.integer('messages_unread').toString(),
        Icons.chat_rounded,
      ),
    ];
  }
  return [
    (
      'Mes tâches',
      counts.integer('tasks_assigned').toString(),
      Icons.task_alt_rounded,
    ),
    (
      'Mes points',
      counts.integer('badges_points').toString(),
      Icons.workspace_premium_rounded,
    ),
    (
      'Mes messages',
      counts.integer('messages_unread').toString(),
      Icons.chat_rounded,
    ),
  ];
}

IconData _activityIcon(String type) {
  switch (type) {
    case 'post':
      return Icons.campaign_rounded;
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

String _titleForProfile(DashboardProfileModel? profile) {
  if (profile?.isAlumni == true) return 'Espace alumni';
  if (profile?.canViewGlobal == true) return 'Tableau de bord global';
  if (profile?.canViewFinance == true) return 'Tableau finance';
  if (profile?.isEnacchef == true) return 'Pilotage Enacchef';
  return 'Mon espace Enactus';
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
