import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../attendance/services/attendance_service.dart';
import '../../documents/services/documents_service.dart';
import '../../finance/services/finance_service.dart';
import '../../members/services/members_service.dart';
import '../../notifications/services/notifications_service.dart';
import '../../recruitment/services/recruitment_service.dart';
import '../../tasks/services/tasks_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardStats {
  final int members;
  final int sessions;
  final int lateTasks;
  final int documents;
  final int applications;
  final int unreadNotifications;
  final double totalDue;
  final double totalPaid;
  final int pendingPayments;

  const _DashboardStats({
    required this.members,
    required this.sessions,
    required this.lateTasks,
    required this.documents,
    required this.applications,
    required this.unreadNotifications,
    required this.totalDue,
    required this.totalPaid,
    required this.pendingPayments,
  });

  int get alertCount {
    return [
      lateTasks,
      pendingPayments,
      unreadNotifications,
      totalDue > 0 ? 1 : 0,
    ].where((value) => value > 0).length;
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MembersService _membersService = MembersService();
  final AttendanceService _attendanceService = AttendanceService();
  final TasksService _tasksService = TasksService();
  final FinanceService _financeService = FinanceService();
  final DocumentsService _documentsService = DocumentsService();
  final RecruitmentService _recruitmentService = RecruitmentService();
  final NotificationsService _notificationsService = NotificationsService();

  bool _loading = true;
  String? _error;
  _DashboardStats? _stats;

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
      final members = await _membersService.getMembers();
      final sessions = await _attendanceService.getSessions();
      final lateTasks = await _tasksService.getLateTasks();
      final accounts = await _financeService.getAccounts();
      final payments = await _financeService.getPayments();
      final documents = await _documentsService.getDocuments();
      final applications = await _recruitmentService.getApplications();
      final unreadCount = await _notificationsService.getUnreadCount();

      final totalDue = accounts.fold<double>(
        0,
        (sum, account) => sum + account.balanceDue,
      );

      final totalPaid = accounts.fold<double>(
        0,
        (sum, account) => sum + account.totalPaid,
      );

      final pendingPayments = payments
          .where((payment) => payment.status == 'pending')
          .length;

      if (!mounted) return;

      setState(() {
        _stats = _DashboardStats(
          members: members.length,
          sessions: sessions.length,
          lateTasks: lateTasks.length,
          documents: documents.length,
          applications: applications.length,
          unreadNotifications: unreadCount,
          totalDue: totalDue,
          totalPaid: totalPaid,
          pendingPayments: pendingPayments,
        );
      });
    } catch (e) {
      if (!mounted) return;

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
                    children: [
                      _DashboardHeader(
                        stats: _stats,
                        loading: _loading,
                        onRefresh: _loadDashboard,
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const _DashboardLoading()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadDashboard)
                      else if (_stats != null)
                        _DashboardContent(stats: _stats!),
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

class _DashboardContent extends StatelessWidget {
  final _DashboardStats stats;

  const _DashboardContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1120;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _PriorityGrid(stats: stats),
                    const SizedBox(height: 22),
                    const _QuickAccessGrid(),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _QuickInsights(stats: stats),
                    const SizedBox(height: 22),
                    _MomentumCard(stats: stats),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _PriorityGrid(stats: stats),
            const SizedBox(height: 22),
            const _QuickAccessGrid(),
            const SizedBox(height: 22),
            _QuickInsights(stats: stats),
            const SizedBox(height: 22),
            _MomentumCard(stats: stats),
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final _DashboardStats? stats;
  final bool loading;
  final VoidCallback onRefresh;

  const _DashboardHeader({
    required this.stats,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;
    final alertCount = stats?.alertCount ?? 0;
    final statusText = loading
        ? 'Synchronisation des données...'
        : alertCount == 0
        ? 'Tout est calme pour le moment.'
        : '$alertCount point(s) à suivre aujourd’hui.';

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: isWide
          ? Row(
              children: [
                const _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(child: _HeaderText(statusText: statusText)),
                const SizedBox(width: 18),
                _HeaderActions(onRefresh: onRefresh),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderIcon(),
                const SizedBox(height: 18),
                _HeaderText(statusText: statusText),
                const SizedBox(height: 18),
                _HeaderActions(onRefresh: onRefresh),
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.dashboard_rounded,
        color: AppTheme.softBlack,
        size: 36,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String statusText;

  const _HeaderText({required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tableau de bord',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Le cockpit quotidien de Enactus ESP.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final VoidCallback onRefresh;

  const _HeaderActions({required this.onRefresh});

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
          onPressed: () => context.go('/posts'),
          icon: const Icon(Icons.forum_rounded),
          label: const Text('Communication'),
        ),
      ],
    );
  }
}

class _PriorityGrid extends StatelessWidget {
  final _DashboardStats stats;

  const _PriorityGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        title: 'Membres',
        value: stats.members.toString(),
        subtitle: 'Enacteurs enregistrés',
        icon: Icons.people_alt_rounded,
        route: '/members',
      ),
      _StatItem(
        title: 'Communication',
        value: stats.unreadNotifications.toString(),
        subtitle: 'notifications non lues',
        icon: Icons.notifications_active_rounded,
        route: '/notifications',
        danger: stats.unreadNotifications > 0,
      ),
      _StatItem(
        title: 'Tâches',
        value: stats.lateTasks.toString(),
        subtitle: 'tâches en retard',
        icon: Icons.warning_rounded,
        route: '/tasks',
        danger: stats.lateTasks > 0,
      ),
      _StatItem(
        title: 'Finance',
        value: _money(stats.totalDue),
        subtitle: 'reste à encaisser',
        icon: Icons.account_balance_wallet_rounded,
        route: '/finance',
        danger: stats.totalDue > 0,
      ),
      _StatItem(
        title: 'Présences',
        value: stats.sessions.toString(),
        subtitle: 'sessions suivies',
        icon: Icons.event_available_rounded,
        route: '/attendance',
      ),
      _StatItem(
        title: 'Documents',
        value: stats.documents.toString(),
        subtitle: 'ressources partagées',
        icon: Icons.folder_copy_rounded,
        route: '/documents',
      ),
      _StatItem(
        title: 'Paiements',
        value: stats.pendingPayments.toString(),
        subtitle: 'paiements à valider',
        icon: Icons.pending_actions_rounded,
        route: '/finance',
        danger: stats.pendingPayments > 0,
      ),
      _StatItem(
        title: 'Recrutement',
        value: stats.applications.toString(),
        subtitle: 'candidatures',
        icon: Icons.how_to_reg_rounded,
        route: '/recruitment',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count == 1 ? 3.3 : 1.55,
          ),
          itemBuilder: (context, index) {
            return _StatCard(item: items[index]);
          },
        );
      },
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool danger;

  const _StatItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.danger = false,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? Colors.red.shade700 : AppTheme.softBlack;
    final background = item.danger
        ? Colors.red.shade50
        : AppTheme.enactusYellow.withValues(alpha: 0.18);

    return Card(
      child: InkWell(
        onTap: () => context.go(item.route),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: background,
                    foregroundColor: color,
                    child: Icon(item.icon),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.black.withValues(alpha: 0.36),
                    size: 20,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    item.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      const _QuickAccessItem(
        title: 'Membres',
        subtitle: 'Profils, rôles, statuts',
        icon: Icons.people_alt_rounded,
        route: '/members',
      ),
      const _QuickAccessItem(
        title: 'Pôles',
        subtitle: 'Équipes et objectifs',
        icon: Icons.hub_rounded,
        route: '/poles',
      ),
      const _QuickAccessItem(
        title: 'Communication',
        subtitle: 'Posts et annonces',
        icon: Icons.forum_rounded,
        route: '/posts',
      ),
      const _QuickAccessItem(
        title: 'Présences',
        subtitle: 'Absences et retards',
        icon: Icons.fact_check_rounded,
        route: '/attendance',
      ),
      const _QuickAccessItem(
        title: 'Tâches',
        subtitle: 'Kanban et suivi',
        icon: Icons.task_alt_rounded,
        route: '/tasks',
      ),
      const _QuickAccessItem(
        title: 'Finance',
        subtitle: 'Paiements, dettes',
        icon: Icons.account_balance_wallet_rounded,
        route: '/finance',
      ),
      const _QuickAccessItem(
        title: 'Documents',
        subtitle: 'PV, rapports, fichiers',
        icon: Icons.folder_copy_rounded,
        route: '/documents',
      ),
      const _QuickAccessItem(
        title: 'Recrutement',
        subtitle: 'Candidatures',
        icon: Icons.how_to_reg_rounded,
        route: '/recruitment',
      ),
      const _QuickAccessItem(
        title: 'Notifications',
        subtitle: 'Alertes et rappels',
        icon: Icons.notifications_rounded,
        route: '/notifications',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const _SectionTitle(
              icon: Icons.grid_view_rounded,
              title: 'Accès rapides',
            ),
            const Divider(height: 26),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 860
                    ? 4
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: count == 1 ? 3.8 : 2.2,
                  ),
                  itemBuilder: (context, index) {
                    return _QuickAccessCard(item: items[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _QuickAccessItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

class _QuickAccessCard extends StatelessWidget {
  final _QuickAccessItem item;

  const _QuickAccessCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(item.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.enactusYellow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.enactusYellow.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    item.subtitle,
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

class _QuickInsights extends StatelessWidget {
  final _DashboardStats stats;

  const _QuickInsights({required this.stats});

  @override
  Widget build(BuildContext context) {
    final alerts = <_InsightItem>[];

    if (stats.lateTasks > 0) {
      alerts.add(
        _InsightItem(
          icon: Icons.warning_rounded,
          title: 'Tâches en retard',
          message: '${stats.lateTasks} tâche(s) doivent être suivies.',
          route: '/tasks',
          danger: true,
        ),
      );
    }

    if (stats.pendingPayments > 0) {
      alerts.add(
        _InsightItem(
          icon: Icons.pending_actions_rounded,
          title: 'Paiements à valider',
          message: '${stats.pendingPayments} paiement(s) attendent validation.',
          route: '/finance',
          danger: true,
        ),
      );
    }

    if (stats.totalDue > 0) {
      alerts.add(
        _InsightItem(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Dette totale',
          message: '${_money(stats.totalDue)} restent à encaisser.',
          route: '/finance',
          danger: true,
        ),
      );
    }

    if (stats.unreadNotifications > 0) {
      alerts.add(
        _InsightItem(
          icon: Icons.notifications_active_rounded,
          title: 'Notifications',
          message: '${stats.unreadNotifications} notification(s) non lue(s).',
          route: '/notifications',
        ),
      );
    }

    if (alerts.isEmpty) {
      alerts.add(
        const _InsightItem(
          icon: Icons.check_circle_rounded,
          title: 'Tout est sous contrôle',
          message: 'Aucune alerte critique pour le moment.',
          route: '/dashboard',
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const _SectionTitle(
              icon: Icons.insights_rounded,
              title: 'Points d’attention',
            ),
            const Divider(height: 26),
            ...alerts.map((alert) => _InsightTile(item: alert)),
          ],
        ),
      ),
    );
  }
}

class _MomentumCard extends StatelessWidget {
  final _DashboardStats stats;

  const _MomentumCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalFinancial = stats.totalPaid + stats.totalDue;
    final paidRatio = totalFinancial <= 0
        ? 0.0
        : stats.totalPaid / totalFinancial;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.auto_graph_rounded,
              title: 'Dynamique du club',
            ),
            const Divider(height: 26),
            _ProgressLine(
              label: 'Encaissement',
              value: paidRatio,
              trailing: '${(paidRatio * 100).round()}%',
            ),
            const SizedBox(height: 16),
            _SoftMetric(
              icon: Icons.verified_rounded,
              label: 'Total payé',
              value: _money(stats.totalPaid),
            ),
            const SizedBox(height: 10),
            _SoftMetric(
              icon: Icons.description_rounded,
              label: 'Documents',
              value: '${stats.documents} ressource(s)',
            ),
            const SizedBox(height: 10),
            _SoftMetric(
              icon: Icons.how_to_reg_rounded,
              label: 'Recrutement',
              value: '${stats.applications} candidature(s)',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final double value;
  final String trailing;

  const _ProgressLine({
    required this.label,
    required this.value,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.18),
            valueColor: const AlwaysStoppedAnimation(AppTheme.enactusYellow),
          ),
        ),
      ],
    );
  }
}

class _SoftMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SoftMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.softBlack),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _InsightItem {
  final IconData icon;
  final String title;
  final String message;
  final String route;
  final bool danger;

  const _InsightItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.route,
    this.danger = false,
  });
}

class _InsightTile extends StatelessWidget {
  final _InsightItem item;

  const _InsightTile({required this.item});

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
                : AppTheme.enactusYellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.message,
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement du dashboard',
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
    );
  }
}

String _money(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < rounded.length; i++) {
    final reverseIndex = rounded.length - i;
    buffer.write(rounded[i]);

    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} FCFA';
}
