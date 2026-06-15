import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../academy/models/academy_models.dart';
import '../../academy/services/academy_service.dart';
import '../../attendance/services/attendance_service.dart';
import '../../documents/services/documents_service.dart';
import '../../finance/services/finance_service.dart';
import '../../impact/models/impact_models.dart';
import '../../impact/services/impact_service.dart';
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
  final AuthService _authService = AuthService();
  final MembersService _membersService = MembersService();
  final AttendanceService _attendanceService = AttendanceService();
  final TasksService _tasksService = TasksService();
  final FinanceService _financeService = FinanceService();
  final DocumentsService _documentsService = DocumentsService();
  final RecruitmentService _recruitmentService = RecruitmentService();
  final NotificationsService _notificationsService = NotificationsService();
  final AcademyService _academyService = AcademyService();
  final ImpactService _impactService = ImpactService();

  bool _loading = true;
  String? _error;
  _DashboardStats? _stats;
  UserExperience? _userExperience;
  AcademyHomeData? _academyData;
  ImpactDashboardData? _impactData;

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
      final user = UserExperience.fromJson(await _authService.getCurrentUser());

      final members = user.canManageMembers
          ? await _safeList(() => _membersService.getMembers())
          : const [];
      final sessions = user.isAlumni
          ? const []
          : await _safeList(() => _attendanceService.getSessions());
      final lateTasks = await _safeList(() => _tasksService.getLateTasks());
      final accounts = user.canViewFinance
          ? await _safeList(() => _financeService.getAccounts())
          : const [];
      final payments = user.canViewFinance
          ? await _safeList(() => _financeService.getPayments())
          : const [];
      final documents = await _safeList(() => _documentsService.getDocuments());
      final applications = user.canViewRecruitment
          ? await _safeList(() => _recruitmentService.getApplications())
          : const [];
      final unreadCount = await _safeValue(
        () => _notificationsService.getUnreadCount(),
        0,
      );
      AcademyHomeData? academyData;
      ImpactDashboardData? impactData;

      try {
        academyData = await _academyService.getHome();
      } catch (_) {
        academyData = null;
      }

      if (user.canViewImpact) {
        try {
          impactData = await _impactService.getDashboard();
        } catch (_) {
          impactData = null;
        }
      }

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
        _userExperience = user;
        _academyData = academyData;
        _impactData = impactData;
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

  Future<List<T>> _safeList<T>(Future<List<T>> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return [];
    }
  }

  Future<T> _safeValue<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
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
                        userExperience: _userExperience,
                        loading: _loading,
                        onRefresh: _loadDashboard,
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const _DashboardLoading()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadDashboard)
                      else if (_stats != null)
                        _DashboardContent(
                          stats: _stats!,
                          userExperience: _userExperience,
                          academyData: _academyData,
                          impactData: _impactData,
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

class _DashboardContent extends StatelessWidget {
  final _DashboardStats stats;
  final UserExperience? userExperience;
  final AcademyHomeData? academyData;
  final ImpactDashboardData? impactData;

  const _DashboardContent({
    required this.stats,
    required this.userExperience,
    required this.academyData,
    required this.impactData,
  });

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
                    _PriorityGrid(stats: stats, userExperience: userExperience),
                    const SizedBox(height: 22),
                    if (impactData != null) ...[
                      _DashboardImpactPanel(data: impactData!),
                      const SizedBox(height: 22),
                    ],
                    _QuickAccessGrid(userExperience: userExperience),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _QuickInsights(
                      stats: stats,
                      userExperience: userExperience,
                    ),
                    const SizedBox(height: 22),
                    if (academyData != null) ...[
                      _DashboardAcademyCard(data: academyData!),
                      const SizedBox(height: 22),
                    ],
                    _MomentumCard(stats: stats, userExperience: userExperience),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _PriorityGrid(stats: stats, userExperience: userExperience),
            const SizedBox(height: 22),
            if (impactData != null) ...[
              _DashboardImpactPanel(data: impactData!),
              const SizedBox(height: 22),
            ],
            if (academyData != null) ...[
              _DashboardAcademyCard(data: academyData!),
              const SizedBox(height: 22),
            ],
            _QuickAccessGrid(userExperience: userExperience),
            const SizedBox(height: 22),
            _QuickInsights(stats: stats, userExperience: userExperience),
            const SizedBox(height: 22),
            _MomentumCard(stats: stats, userExperience: userExperience),
          ],
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final _DashboardStats? stats;
  final UserExperience? userExperience;
  final bool loading;
  final VoidCallback onRefresh;

  const _DashboardHeader({
    required this.stats,
    required this.userExperience,
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
                Expanded(
                  child: _HeaderText(
                    userExperience: userExperience,
                    statusText: statusText,
                  ),
                ),
                const SizedBox(width: 18),
                _HeaderActions(onRefresh: onRefresh),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderIcon(),
                const SizedBox(height: 18),
                _HeaderText(
                  userExperience: userExperience,
                  statusText: statusText,
                ),
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
  final UserExperience? userExperience;
  final String statusText;

  const _HeaderText({required this.userExperience, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userExperience?.dashboardTitle ?? 'Tableau de bord',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          userExperience?.dashboardSubtitle ??
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
  final UserExperience? userExperience;

  const _PriorityGrid({required this.stats, required this.userExperience});

  @override
  Widget build(BuildContext context) {
    final user = userExperience;
    final items = [
      if (user?.canManageMembers == true)
        _StatItem(
          title: 'Membres',
          value: stats.members.toString(),
          subtitle: 'Enacteurs enregistrés',
          icon: Icons.people_alt_rounded,
          route: '/members',
        ),
      _StatItem(
        title: 'Notifications',
        value: stats.unreadNotifications.toString(),
        subtitle: 'notifications non lues',
        icon: Icons.notifications_active_rounded,
        route: '/notifications',
        danger: stats.unreadNotifications > 0,
      ),
      _StatItem(
        title: user?.isMemberExperience == true ? 'Mes tâches' : 'Tâches',
        value: stats.lateTasks.toString(),
        subtitle: 'tâches en retard',
        icon: Icons.warning_rounded,
        route: '/tasks',
        danger: stats.lateTasks > 0,
      ),
      if (user?.canViewFinance == true)
        _StatItem(
          title: 'Finance',
          value: _money(stats.totalDue),
          subtitle: 'reste à encaisser',
          icon: Icons.account_balance_wallet_rounded,
          route: '/finance',
          danger: stats.totalDue > 0,
        ),
      if (user?.isAlumni != true)
        _StatItem(
          title: 'Présences',
          value: stats.sessions.toString(),
          subtitle: user?.isMemberExperience == true
              ? 'sessions du club'
              : 'sessions suivies',
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
        title: 'Engagement',
        value: user?.isAlumni == true ? 'Alumni' : 'Points',
        subtitle: 'badges et contributions',
        icon: Icons.workspace_premium_rounded,
        route: '/gamification',
      ),
      const _StatItem(
        title: 'Academy',
        value: 'Cours',
        subtitle: 'leçons, quiz et badges',
        icon: Icons.school_rounded,
        route: '/academy',
      ),
      if (user?.canViewImpact == true)
        const _StatItem(
          title: 'Impact',
          value: 'Score',
          subtitle: 'performance projets',
          icon: Icons.insights_rounded,
          route: '/impact',
        ),
      const _StatItem(
        title: 'Communication',
        value: 'Fil',
        subtitle: 'posts et annonces',
        icon: Icons.forum_rounded,
        route: '/posts',
      ),
      if (user?.canViewFinance == true)
        _StatItem(
          title: 'Paiements',
          value: stats.pendingPayments.toString(),
          subtitle: 'paiements à valider',
          icon: Icons.pending_actions_rounded,
          route: '/finance',
          danger: stats.pendingPayments > 0,
        ),
      if (user?.canViewRecruitment == true)
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
            mainAxisExtent: count == 1 ? 132 : 174,
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

class _DashboardImpactPanel extends StatelessWidget {
  final ImpactDashboardData data;

  const _DashboardImpactPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final organization = data.organization;
    final topProject = [...data.projects]
      ..sort((a, b) => b.projectImpactScore.compareTo(a.projectImpactScore));
    final alerts = data.projects
        .where((project) => project.needsEvidence || project.needsSdg)
        .length;

    return Card(
      child: InkWell(
        onTap: () => context.go('/impact'),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow.withValues(
                      alpha: 0.24,
                    ),
                    foregroundColor: AppTheme.softBlack,
                    child: const Icon(Icons.insights_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Impact & Performance',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final items = [
                    _MiniMetric(
                      label: 'Health score',
                      value:
                          '${organization.organizationHealthScore.toStringAsFixed(0)}/100',
                    ),
                    _MiniMetric(
                      label: 'Impact direct',
                      value: organization.directImpactTotal.toString(),
                    ),
                    _MiniMetric(
                      label: 'Reach',
                      value: organization.reachTotal.toString(),
                    ),
                    _MiniMetric(
                      label: 'Surplus',
                      value: _money(organization.surplusTotal),
                    ),
                  ];

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final item in items)
                        SizedBox(
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 10) / 2,
                          child: _MiniMetricTile(item: item),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (topProject.isNotEmpty)
                    Chip(label: Text('Top: ${topProject.first.projectName}')),
                  Chip(label: Text('$alerts alerte(s) preuve/ODD')),
                  Chip(
                    label: Text(
                      '${organization.competitionReadiness.toStringAsFixed(0)}% compétition',
                    ),
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

class _DashboardAcademyCard extends StatelessWidget {
  final AcademyHomeData data;

  const _DashboardAcademyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data.progress;

    return Card(
      child: InkWell(
        onTap: () => context.go('/academy'),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow.withValues(
                      alpha: 0.24,
                    ),
                    foregroundColor: AppTheme.softBlack,
                    child: const Icon(Icons.school_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Academy Progress',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
              const SizedBox(height: 14),
              _DashboardProgressLine(
                label: 'Leçons',
                value: progress.lessonsProgress,
                detail: '${progress.completedLessons}/${progress.totalLessons}',
              ),
              const SizedBox(height: 12),
              _DashboardProgressLine(
                label: 'Quiz',
                value: progress.quizProgress,
                detail: '${progress.passedQuizzes}/${progress.totalQuizzes}',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${progress.points} points')),
                  Chip(
                    label: Text(
                      '${data.badges.where((b) => b.unlocked).length} badge(s)',
                    ),
                  ),
                  Chip(label: Text('Rang #${progress.rank}')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardProgressLine extends StatelessWidget {
  final String label;
  final double value;
  final String detail;

  const _DashboardProgressLine({
    required this.label,
    required this.value,
    required this.detail,
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
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(detail, style: const TextStyle(color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
          color: AppTheme.enactusYellow,
          backgroundColor: Colors.black.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class _MiniMetric {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});
}

class _MiniMetricTile extends StatelessWidget {
  final _MiniMetric item;

  const _MiniMetricTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final UserExperience? userExperience;

  const _QuickAccessGrid({required this.userExperience});

  @override
  Widget build(BuildContext context) {
    final allowedRoutes = UserExperience.visibleRoutesFor(
      userExperience,
    ).toSet();
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
        title: 'Projets',
        subtitle: 'Impact et avancement',
        icon: Icons.rocket_launch_rounded,
        route: '/projects',
      ),
      const _QuickAccessItem(
        title: 'Événements',
        subtitle: 'Calendrier et pointage',
        icon: Icons.event_available_rounded,
        route: '/events',
      ),
      const _QuickAccessItem(
        title: 'Communication',
        subtitle: 'Posts et annonces',
        icon: Icons.forum_rounded,
        route: '/posts',
      ),
      const _QuickAccessItem(
        title: 'Chat',
        subtitle: 'Messages et groupes',
        icon: Icons.chat_rounded,
        route: '/chat',
      ),
      const _QuickAccessItem(
        title: 'Gamification',
        subtitle: 'Points et badges',
        icon: Icons.workspace_premium_rounded,
        route: '/gamification',
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
        title: 'Alumni',
        subtitle: 'Mentorat et réseau',
        icon: Icons.school_rounded,
        route: '/alumni',
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
    ].where((item) => allowedRoutes.contains(item.route)).toList();

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
                    mainAxisExtent: 92,
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
  final UserExperience? userExperience;

  const _QuickInsights({required this.stats, required this.userExperience});

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

    if (userExperience?.canViewFinance == true && stats.pendingPayments > 0) {
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

    if (userExperience?.canViewFinance == true && stats.totalDue > 0) {
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
  final UserExperience? userExperience;

  const _MomentumCard({required this.stats, required this.userExperience});

  @override
  Widget build(BuildContext context) {
    final showFinance = userExperience?.canViewFinance == true;
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
              title: 'Dynamique utile',
            ),
            const Divider(height: 26),
            if (showFinance) ...[
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
            ],
            _SoftMetric(
              icon: Icons.description_rounded,
              label: 'Documents',
              value: '${stats.documents} ressource(s)',
            ),
            const SizedBox(height: 10),
            _SoftMetric(
              icon: userExperience?.isAlumni == true
                  ? Icons.school_rounded
                  : Icons.workspace_premium_rounded,
              label: userExperience?.canViewRecruitment == true
                  ? 'Recrutement'
                  : 'Espace',
              value: userExperience?.canViewRecruitment == true
                  ? '${stats.applications} candidature(s)'
                  : userExperience?.audienceLabel ?? 'EnactSpace',
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
