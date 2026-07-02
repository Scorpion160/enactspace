import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/impact_models.dart';
import '../services/impact_service.dart';

class ImpactDashboardScreen extends StatefulWidget {
  const ImpactDashboardScreen({super.key});

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  final ImpactService _service = ImpactService();

  bool _loading = true;
  String? _error;
  ImpactDashboardData? _data;

  @override
  void initState() {
    super.initState();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getDashboard();
      if (!mounted) return;
      setState(() => _data = data);
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
      onRefresh: _loadImpact,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _ImpactHeader(),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ImpactErrorCard(message: _error!, onRetry: _loadImpact)
          else
            _ImpactContent(data: _data!),
        ],
      ),
    );
  }
}

class _ImpactHeader extends StatelessWidget {
  const _ImpactHeader();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 780;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: wide
          ? Row(
              children: [
                const _HeaderIcon(),
                const SizedBox(width: 18),
                const Expanded(child: _HeaderCopy()),
                _MethodPill(label: 'People'),
                const SizedBox(width: 8),
                _MethodPill(label: 'Planet'),
                const SizedBox(width: 8),
                _MethodPill(label: 'Prosperity'),
              ],
            )
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderIcon(),
                    SizedBox(width: 18),
                    Expanded(child: _HeaderCopy()),
                  ],
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MethodPill(label: 'People'),
                    _MethodPill(label: 'Planet'),
                    _MethodPill(label: 'Prosperity'),
                  ],
                ),
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
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.insights_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Impact & Performance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Pilotage Enactus: impact, preuves, ODD, performance projets et préparation compétition.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _MethodPill extends StatelessWidget {
  final String label;

  const _MethodPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ImpactContent extends StatelessWidget {
  final ImpactDashboardData data;

  const _ImpactContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final organization = data.organization;
    final alerts = data.projects
        .where((project) => project.needsEvidence || project.needsSdg)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.usesDemoData) ...[
          const _DemoDataNotice(),
          const SizedBox(height: 16),
        ],
        _OrganizationScoreCard(organization: organization),
        const SizedBox(height: 16),
        _HistoricalImpactSection(impact: data.historicalImpact),
        const SizedBox(height: 22),
        _KpiGrid(
          items: [
            _KpiItem(
              label: 'Impact direct',
              value: organization.directImpactTotal.toString(),
              icon: Icons.volunteer_activism_rounded,
            ),
            _KpiItem(
              label: 'Impact indirect',
              value: organization.indirectImpactTotal.toString(),
              icon: Icons.groups_2_rounded,
            ),
            _KpiItem(
              label: 'Reach total',
              value: organization.reachTotal.toString(),
              icon: Icons.public_rounded,
            ),
            _KpiItem(
              label: 'Revenus projets',
              value: _money(organization.revenueTotal),
              icon: Icons.trending_up_rounded,
            ),
            _KpiItem(
              label: 'Surplus',
              value: _money(organization.surplusTotal),
              icon: Icons.savings_rounded,
            ),
            _KpiItem(
              label: 'Academy',
              value: '${organization.academyParticipation.toStringAsFixed(0)}%',
              icon: Icons.school_rounded,
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Top projets par impact',
          subtitle:
              'Score indicatif /100 basé sur impact, preuves, ODD, innovation et viabilité.',
        ),
        const SizedBox(height: 12),
        _ProjectImpactList(projects: data.projects),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Alertes de qualité',
          subtitle:
              'Points à corriger avant reporting, annual report ou compétition.',
        ),
        const SizedBox(height: 12),
        _QualityAlerts(projects: alerts),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Santé des pôles',
          subtitle:
              'Lecture positive: contribution, production, présence et progression Academy.',
        ),
        const SizedBox(height: 12),
        _PoleHealthGrid(poles: data.poles),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Engagement Enacteur',
          subtitle:
              'Score privé à utiliser pour accompagner, jamais pour humilier.',
        ),
        const SizedBox(height: 12),
        _EnacteurPerformanceList(enacteurs: data.enacteurs),
        const SizedBox(height: 22),
        const _ScoreFrameworkCard(),
      ],
    );
  }
}

class _DemoDataNotice extends StatelessWidget {
  const _DemoDataNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.42),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.softBlack),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Données de démonstration affichées. Le module basculera automatiquement sur les données backend dès qu’elles seront disponibles.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationScoreCard extends StatelessWidget {
  final OrganizationPerformanceModel organization;

  const _OrganizationScoreCard({required this.organization});

  @override
  Widget build(BuildContext context) {
    final score = organization.organizationHealthScore;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final scoreWidget = _RadialScore(
              score: score,
              label: 'Organization Health',
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Santé globale Enactus ESP',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Un score de pilotage qui combine présence, rétention, avancement, impact, preuves, Academy, communication et finance.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        '${organization.activeMembers} membres actifs',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${organization.activeProjects} projets actifs',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${organization.competitionReadiness.toStringAsFixed(0)}% compétition',
                      ),
                    ),
                  ],
                ),
              ],
            );

            if (wide) {
              return Row(
                children: [
                  scoreWidget,
                  const SizedBox(width: 20),
                  Expanded(child: copy),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: scoreWidget),
                const SizedBox(height: 16),
                copy,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoricalImpactSection extends StatelessWidget {
  final HistoricalImpactModel impact;

  const _HistoricalImpactSection({required this.impact});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  child: const Icon(Icons.history_edu_rounded),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impact historique Enactus ESP',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Mémoire des réalisations et base de préparation compétition.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 650
                    ? 2
                    : 1;
                const spacing = 12.0;
                final width =
                    (constraints.maxWidth - spacing * (count - 1)) / count;
                final cards = [
                  _HistoricalPillar(
                    title: 'People',
                    value: '+${impact.impactedLives}',
                    subtitle:
                        '${impact.createdJobs} emplois • ${impact.savedLives} vies sauvées',
                    icon: Icons.groups_2_rounded,
                  ),
                  _HistoricalPillar(
                    title: 'Planet',
                    value: impact.plantedTrees.toString(),
                    subtitle: 'arbres plantés et ressources valorisées',
                    icon: Icons.park_rounded,
                  ),
                  _HistoricalPillar(
                    title: 'Prosperity',
                    value: _money(impact.cumulativeFcfaGains),
                    subtitle:
                        '${impact.cumulativeUsdGains.toStringAsFixed(1)} USD de gains cumulés',
                    icon: Icons.trending_up_rounded,
                  ),
                  _HistoricalPillar(
                    title: 'Innovation',
                    value: impact.developedProducts.toString(),
                    subtitle:
                        '${impact.createdProjects} projets créés • ${impact.touchedSdgs} ODD',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final card in cards)
                      SizedBox(width: width, child: card),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final project in impact.emblematicProjects)
                  Chip(label: Text(project)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final distinction in impact.distinctions)
                  Chip(
                    avatar: const Icon(Icons.emoji_events_rounded, size: 18),
                    label: Text(distinction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalPillar extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _HistoricalPillar({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.25),
            foregroundColor: AppTheme.softBlack,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialScore extends StatelessWidget {
  final double score;
  final String label;

  const _RadialScore({required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = (score / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 136,
            height: 136,
            child: CircularProgressIndicator(
              value: normalized,
              strokeWidth: 13,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              color: AppTheme.enactusYellow,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiItem> items;

  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _KpiCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;

  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.24),
              foregroundColor: AppTheme.softBlack,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.label,
                    maxLines: 1,
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

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _ProjectImpactList extends StatelessWidget {
  final List<ProjectImpactMetricModel> projects;

  const _ProjectImpactList({required this.projects});

  @override
  Widget build(BuildContext context) {
    final sorted = [...projects]
      ..sort((a, b) => b.projectImpactScore.compareTo(a.projectImpactScore));

    return Column(
      children: [
        for (final project in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProjectImpactCard(project: project),
          ),
      ],
    );
  }
}

class _ProjectImpactCard extends StatelessWidget {
  final ProjectImpactMetricModel project;

  const _ProjectImpactCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showProjectImpactDetails(context, project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final score = _RadialScore(
                score: project.projectImpactScore,
                label: 'Project Impact',
              );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.projectName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Chip(label: Text(project.status)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${project.poleName} • ${project.projectLead} / ${project.deputyLead}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    project.solution,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('${project.directImpact} direct')),
                      Chip(label: Text('${project.indirectImpact} indirect')),
                      Chip(label: Text('${project.reach} reach')),
                      if (project.jobsCreated > 0)
                        Chip(label: Text('${project.jobsCreated} emplois')),
                      if (project.livesImpacted > 0)
                        Chip(label: Text('${project.livesImpacted} vies')),
                      Chip(label: Text('${project.evidenceCount} preuves')),
                      for (final sdg in project.sdgs) Chip(label: Text(sdg)),
                      if (project.sdgs.isEmpty)
                        const Chip(label: Text('ODD à définir')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (project.progress / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: Colors.black.withValues(alpha: 0.08),
                    color: AppTheme.enactusYellow,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${project.progress.toStringAsFixed(0)}% avancement • ${project.completedTasks} tâches terminées • ${project.lateTasks} en retard',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  children: [
                    score,
                    const SizedBox(width: 18),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: score),
                  const SizedBox(height: 14),
                  details,
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.expand_more_rounded),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void _showProjectImpactDetails(
  BuildContext context,
  ProjectImpactMetricModel project,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ProjectImpactDetailSheet(project: project),
  );
}

class _ProjectImpactDetailSheet extends StatelessWidget {
  final ProjectImpactMetricModel project;

  const _ProjectImpactDetailSheet({required this.project});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: height * 0.92,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.projectName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${project.poleName} • ${project.status} • ${project.projectLead} / ${project.deputyLead}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final score = _RadialScore(
                      score: project.projectImpactScore,
                      label: 'Impact',
                    );
                    final metrics = _KpiGrid(
                      items: [
                        _KpiItem(
                          label: 'Impact direct',
                          value: project.directImpact.toString(),
                          icon: Icons.volunteer_activism_rounded,
                        ),
                        _KpiItem(
                          label: 'Impact indirect',
                          value: project.indirectImpact.toString(),
                          icon: Icons.groups_rounded,
                        ),
                        _KpiItem(
                          label: 'Reach',
                          value: project.reach.toString(),
                          icon: Icons.public_rounded,
                        ),
                        _KpiItem(
                          label: 'Revenus',
                          value: _money(project.revenue),
                          icon: Icons.trending_up_rounded,
                        ),
                        _KpiItem(
                          label: 'Surplus',
                          value: _money(project.surplus),
                          icon: Icons.savings_rounded,
                        ),
                        _KpiItem(
                          label: 'Emplois',
                          value: project.jobsCreated.toString(),
                          icon: Icons.work_rounded,
                        ),
                        _KpiItem(
                          label: 'Vies impactees',
                          value: project.livesImpacted.toString(),
                          icon: Icons.favorite_rounded,
                        ),
                        _KpiItem(
                          label: 'Preuves',
                          value: project.evidenceCount.toString(),
                          icon: Icons.verified_rounded,
                        ),
                      ],
                    );

                    if (!wide) {
                      return Column(
                        children: [score, const SizedBox(height: 16), metrics],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        score,
                        const SizedBox(width: 20),
                        Expanded(child: metrics),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sdg in project.sdgs) Chip(label: Text(sdg)),
                    if (project.sdgs.isEmpty)
                      const Chip(label: Text('ODD a definir')),
                    Chip(
                      label: Text('${project.documentsCount} document(s) lies'),
                    ),
                    Chip(
                      label: Text(
                        '${project.progress.toStringAsFixed(0)}% avancement',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ProjectDetailBlock(
                  title: 'Probleme',
                  text: project.problem,
                  icon: Icons.report_problem_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Solution',
                  text: project.solution,
                  icon: Icons.lightbulb_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Beneficiaires',
                  text: project.targetBeneficiaries,
                  icon: Icons.diversity_3_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Preuves disponibles',
                  text:
                      '${project.evidenceCount} preuve(s) rattachee(s), ${project.documentsCount} document(s) projet. Les fichiers sont consultables via Documents, sans afficher les liens techniques ici.',
                  icon: Icons.verified_rounded,
                ),
                if (project.hasEnvironmentalImpact)
                  _ProjectDetailBlock(
                    title: 'Impact environnemental',
                    text: [
                      if (project.treesPlanted > 0)
                        '${project.treesPlanted} arbre(s) plantes',
                      if (project.wasteReduced > 0)
                        '${project.wasteReduced.toStringAsFixed(0)} kg de dechets reduits',
                      if (project.waterSaved > 0)
                        '${project.waterSaved.toStringAsFixed(0)} litres economises',
                      if (project.co2Reduced > 0)
                        '${project.co2Reduced.toStringAsFixed(0)} kg CO2 reduits',
                    ].join(' - '),
                    icon: Icons.eco_rounded,
                  ),
                _ProjectDetailBlock(
                  title: 'Methode de mesure',
                  text: project.methodology,
                  icon: Icons.fact_check_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Projection et hypotheses',
                  text: project.assumptions,
                  icon: Icons.rule_rounded,
                ),
                const SizedBox(height: 8),
                _ProjectScoreBreakdown(project: project),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectDetailBlock extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _ProjectDetailBlock({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.25),
            foregroundColor: AppTheme.softBlack,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectScoreBreakdown extends StatelessWidget {
  final ProjectImpactMetricModel project;

  const _ProjectScoreBreakdown({required this.project});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Innovation', project.innovationScore),
      ('Viabilite', project.businessViabilityScore),
      ('Scalabilite', project.scalabilityScore),
      ('Competition', project.competitionReadinessScore),
      ('Planete', project.planetImpact),
      ('Emplois', project.jobsCreated.toDouble()),
      ('Vies', project.livesImpacted.toDouble()),
      ('Arbres', project.treesPlanted.toDouble()),
      ('Budget utilise', project.budgetUsed),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            Chip(label: Text('${item.$1}: ${item.$2.toStringAsFixed(0)}')),
        ],
      ),
    );
  }
}

class _QualityAlerts extends StatelessWidget {
  final List<ProjectImpactMetricModel> projects;

  const _QualityAlerts({required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Tous les projets ont des preuves et des ODD renseignés.',
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final project in projects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade900,
                  child: const Icon(Icons.warning_amber_rounded),
                ),
                title: Text(
                  project.projectName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [
                    if (project.needsEvidence) 'preuves insuffisantes',
                    if (project.needsSdg) 'ODD manquants',
                  ].join(' • '),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PoleHealthGrid extends StatelessWidget {
  final List<PolePerformanceModel> poles;

  const _PoleHealthGrid({required this.poles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 660
            ? 2
            : 1;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final pole in poles)
              SizedBox(
                width: width,
                child: _PoleHealthCard(pole: pole),
              ),
          ],
        );
      },
    );
  }
}

class _PoleHealthCard extends StatelessWidget {
  final PolePerformanceModel pole;

  const _PoleHealthCard({required this.pole});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pole.poleName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (pole.healthScore / 100).clamp(0.0, 1.0),
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
              color: AppTheme.enactusYellow,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 10),
            Text(
              'Pole Health Score ${pole.healthScore.toStringAsFixed(0)}/100',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${pole.activeMembers} membres')),
                Chip(label: Text('${pole.completedTasks} tâches')),
                Chip(
                  label: Text(
                    '${pole.academyProgress.toStringAsFixed(0)}% academy',
                  ),
                ),
                if (pole.alerts > 0)
                  Chip(label: Text('${pole.alerts} alerte(s)')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnacteurPerformanceList extends StatelessWidget {
  final List<EnacteurPerformanceModel> enacteurs;

  const _EnacteurPerformanceList({required this.enacteurs});

  @override
  Widget build(BuildContext context) {
    final sorted = [...enacteurs]
      ..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));

    return Card(
      child: Column(
        children: [
          for (var index = 0; index < sorted.length; index++)
            _EnacteurRow(enacteur: sorted[index], rank: index + 1),
        ],
      ),
    );
  }
}

class _EnacteurRow extends StatelessWidget {
  final EnacteurPerformanceModel enacteur;
  final int rank;

  const _EnacteurRow({required this.enacteur, required this.rank});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rank == 1
            ? AppTheme.enactusYellow
            : Colors.black.withValues(alpha: 0.08),
        foregroundColor: AppTheme.softBlack,
        child: Text(rank.toString()),
      ),
      title: Text(
        enacteur.memberName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${enacteur.completedTasks} tâches • ${enacteur.academyLessonsCompleted} leçons • ${enacteur.badges} badges',
      ),
      trailing: Text(
        enacteur.engagementScore.toStringAsFixed(0),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ScoreFrameworkCard extends StatelessWidget {
  const _ScoreFrameworkCard();

  @override
  Widget build(BuildContext context) {
    const weights = [
      ('Impact direct', '25%'),
      ('Viabilité économique', '15%'),
      ('Innovation', '15%'),
      ('Preuves / méthodologie', '15%'),
      ('Avancement opérationnel', '10%'),
      ('Alignement ODD', '10%'),
      ('Scalabilité', '10%'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grille Project Impact Score',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Score indicatif et configurable. Il sert à guider la préparation, pas à masquer le jugement humain.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final weight in weights)
                  Chip(label: Text('${weight.$1} • ${weight.$2}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ImpactErrorCard({required this.message, required this.onRetry});

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
              'Impact indisponible',
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

String _money(double amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}K';
  }
  return amount.toStringAsFixed(0);
}
