import 'package:flutter/material.dart';

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
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _DashboardHeader(onRefresh: _loadDashboard),
          const SizedBox(height: 22),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadDashboard)
          else if (_stats != null) ...[
            _StatsGrid(stats: _stats!),
            const SizedBox(height: 22),
            _QuickInsights(stats: _stats!),
          ],
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const _DashboardHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                _HeaderIcon(),
                const SizedBox(width: 18),
                const Expanded(child: _HeaderText()),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualiser'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderIcon(),
                    const SizedBox(width: 18),
                    const Expanded(child: _HeaderText()),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualiser'),
                ),
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
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

class _HeaderText extends StatelessWidget {
  const _HeaderText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tableau de bord',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Vue globale de la vie du club Enactus ESP.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final _DashboardStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        title: 'Membres',
        value: stats.members.toString(),
        subtitle: 'membres enregistrés',
        icon: Icons.people_alt_rounded,
      ),
      _StatItem(
        title: 'Réunions',
        value: stats.sessions.toString(),
        subtitle: 'sessions de présence',
        icon: Icons.event_available_rounded,
      ),
      _StatItem(
        title: 'Tâches en retard',
        value: stats.lateTasks.toString(),
        subtitle: 'à surveiller',
        icon: Icons.warning_rounded,
        danger: stats.lateTasks > 0,
      ),
      _StatItem(
        title: 'Dette totale',
        value: _money(stats.totalDue),
        subtitle: 'reste à payer',
        icon: Icons.account_balance_wallet_rounded,
        danger: stats.totalDue > 0,
      ),
      _StatItem(
        title: 'Total payé',
        value: _money(stats.totalPaid),
        subtitle: 'paiements validés',
        icon: Icons.verified_rounded,
      ),
      _StatItem(
        title: 'Paiements attente',
        value: stats.pendingPayments.toString(),
        subtitle: 'à valider',
        icon: Icons.pending_actions_rounded,
        danger: stats.pendingPayments > 0,
      ),
      _StatItem(
        title: 'Documents',
        value: stats.documents.toString(),
        subtitle: 'documents partagés',
        icon: Icons.folder_copy_rounded,
      ),
      _StatItem(
        title: 'Candidatures',
        value: stats.applications.toString(),
        subtitle: 'recrutement',
        icon: Icons.how_to_reg_rounded,
      ),
      _StatItem(
        title: 'Notifications',
        value: stats.unreadNotifications.toString(),
        subtitle: 'non lues',
        icon: Icons.notifications_active_rounded,
        danger: stats.unreadNotifications > 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1200
            ? 3
            : constraints.maxWidth >= 760
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
            childAspectRatio: 2.6,
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
  final bool danger;

  const _StatItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.danger = false,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? Colors.red.shade700 : AppTheme.softBlack;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: item.danger
                  ? Colors.red.shade50
                  : AppTheme.enactusYellow,
              foregroundColor: color,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    item.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
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
    final alerts = <String>[];

    if (stats.lateTasks > 0) {
      alerts.add('${stats.lateTasks} tâche(s) en retard doivent être suivies.');
    }

    if (stats.pendingPayments > 0) {
      alerts.add('${stats.pendingPayments} paiement(s) attendent validation.');
    }

    if (stats.totalDue > 0) {
      alerts.add('La dette totale actuelle est de ${_money(stats.totalDue)}.');
    }

    if (stats.unreadNotifications > 0) {
      alerts.add('${stats.unreadNotifications} notification(s) non lue(s).');
    }

    if (alerts.isEmpty) {
      alerts.add('Aucune alerte critique pour le moment.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.insights_rounded),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Points d’attention',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            ...alerts.map(
              (alert) => ListTile(
                leading: const Icon(Icons.chevron_right_rounded),
                title: Text(alert),
              ),
            ),
          ],
        ),
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
