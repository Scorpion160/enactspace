import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/heritage_photo.dart';
import '../../../shared/ui/reading_blocks.dart';
import '../models/impact_models.dart';
import '../services/impact_gateway.dart';

class ImpactDashboardScreen extends StatefulWidget {
  final ImpactGateway? gateway;
  const ImpactDashboardScreen({super.key, this.gateway});

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  late final ImpactGateway _gateway;

  bool _loading = true;
  bool _exportingPdf = false;
  String? _error;
  ImpactDashboardData? _data;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiImpactGateway();
    _loadImpact();
  }

  Future<void> _loadImpact() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _gateway.loadDashboard();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadSummaryPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final bytes = await _gateway.downloadSummaryPdf();
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la synthèse Impact',
        fileName: 'enactspace-impact-summary.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (!mounted) return;
      final message = kIsWeb || result != null
          ? 'Synthèse Impact PDF enregistrée.'
          : 'Enregistrement du rapport annulé.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: const Key('impact-download-summary-pdf'),
                  onPressed: _exportingPdf ? null : _downloadSummaryPdf,
                  icon: _exportingPdf
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Télécharger la synthèse PDF'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      context.go('/impact/records', extra: _gateway),
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Gérer les fiches Impact'),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          if (_loading)
            Center(
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
    final wide =
        MediaQuery.sizeOf(context).width >= 1100 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;

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
                SizedBox(width: 18),
                Expanded(child: _HeaderCopy()),
                _MethodPill(label: 'People'),
                SizedBox(width: 8),
                _MethodPill(label: 'Planet'),
                SizedBox(width: 8),
                _MethodPill(label: 'Prosperity'),
              ],
            )
          : Column(
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
      child: Icon(Icons.insights_rounded, color: AppTheme.softBlack, size: 34),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'L’impact en action',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Des rencontres aux solutions durables : découvre ce que nos projets changent et suis les actions qui font avancer Enactus ESP.',
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
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
    final hasVerifiedImpact =
        data.historicalImpact != null ||
        organization.validatedEvidenceCount > 0 ||
        (organization.directImpactTotal ?? 0) > 0 ||
        (organization.indirectImpactTotal ?? 0) > 0 ||
        (organization.reachTotal ?? 0) > 0 ||
        (organization.livesImpactedTotal ?? 0) > 0 ||
        (organization.jobsCreatedTotal ?? 0) > 0 ||
        data.projects.any(
          (project) => project.claims.any((claim) => claim.isRealized),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasVerifiedImpact) ...[
          _ImpactGettingStartedCard(hasProjects: data.projects.isNotEmpty),
          const SizedBox(height: 16),
        ],

        if (data.historicalImpact != null) ...[
          _HistoricalImpactSection(impact: data.historicalImpact!),
          SizedBox(height: 22),
        ],
        _SectionTitle(
          title: 'Les résultats des projets suivis',
          subtitle:
              'Retrouve les mesures des actions enregistrées dans EnactSpace, avec leur période et leurs justificatifs dans chaque fiche.',
        ),
        const SizedBox(height: 12),
        _KpiGrid(
          items: [
            _KpiItem(
              label: 'Impact direct',
              value: impactNumber(organization.directImpactTotal),
              icon: Icons.volunteer_activism_rounded,
            ),
            _KpiItem(
              label: 'Impact indirect',
              value: impactNumber(organization.indirectImpactTotal),
              icon: Icons.groups_2_rounded,
            ),
            _KpiItem(
              label: 'Personnes touchées',
              value: impactNumber(organization.reachTotal),
              icon: Icons.public_rounded,
            ),
            _KpiItem(
              label: 'Vies touchées',
              value: impactNumber(organization.livesImpactedTotal),
              icon: Icons.favorite_rounded,
            ),
            _KpiItem(
              label: 'Emplois créés',
              value: impactNumber(organization.jobsCreatedTotal),
              icon: Icons.work_rounded,
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
              label: 'Arbres plantés',
              value: impactNumber(organization.treesPlantedTotal),
              icon: Icons.park_rounded,
            ),
            _KpiItem(
              label: 'Justificatifs examinés',
              value: organization.validatedEvidenceCount.toString(),
              icon: Icons.verified_rounded,
            ),
            _KpiItem(
              label: 'ODD concernés',
              value: impactNumber(organization.touchedSdgs),
              icon: Icons.hub_rounded,
            ),
            _KpiItem(
              label: 'Academy',
              value: organization.academyParticipation == null
                  ? 'Non renseigné'
                  : '${organization.academyParticipation!.toStringAsFixed(0)}%',
              icon: Icons.school_rounded,
            ),
          ],
        ),
        SizedBox(height: 22),
        _SectionTitle(
          title: 'Projets et données d’impact',
          subtitle:
              'Un besoin, une solution, des personnes concernées : entre dans chaque projet pour comprendre son cheminement et ses résultats.',
        ),
        SizedBox(height: 12),
        _ProjectImpactList(projects: data.projects),
        SizedBox(height: 22),
        _SectionTitle(
          title: 'Les prochaines actions',
          subtitle:
              'Complète les éléments utiles pour préparer un bilan clair et poursuivre le travail de terrain.',
        ),
        SizedBox(height: 12),
        _QualityAlerts(projects: alerts),
        SizedBox(height: 22),
        const SizedBox(height: 16),
        _OrganizationScoreCard(organization: organization),
        if (data.poles.isNotEmpty) ...[
          _SectionTitle(
            title: 'La vie des pôles',
            subtitle:
                'Les contributions et les activités qui font vivre nos équipes.',
          ),
          SizedBox(height: 12),
          _PoleHealthGrid(poles: data.poles),
        ],
        if (data.enacteurs.isNotEmpty) ...[
          SizedBox(height: 22),
          _SectionTitle(
            title: 'Engagement Enacteur',
            subtitle:
                'Retrouver les contributions pour mieux accompagner chaque membre.',
          ),
          SizedBox(height: 12),
          _EnacteurPerformanceList(enacteurs: data.enacteurs),
        ],
        SizedBox(height: 22),
        const _ScoreFrameworkCard(),
      ],
    );
  }
}

class _ImpactGettingStartedCard extends StatelessWidget {
  final bool hasProjects;

  const _ImpactGettingStartedCard({required this.hasProjects});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.enactusYellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: AppTheme.enactusYellow,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Écrivons la suite de notre impact',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasProjects
                        ? 'Tes projets sont déjà présents. Ajoute maintenant les résultats obtenus, la période concernée et les documents qui permettent de comprendre ce qui a changé.'
                        : 'Commence par une fiche projet : quel besoin l’équipe a-t-elle rencontré, quelle solution a-t-elle mise en place et quels changements observe-t-elle ?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => context.go('/impact/records'),
                    icon: const Icon(Icons.add_chart_rounded),
                    label: Text(
                      hasProjects
                          ? 'Renseigner les mesures d’impact'
                          : 'Créer une fiche Impact',
                    ),
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
              label: 'Santé opérationnelle',
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le club au quotidien',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Membres, projets et contributions : ces repères aident à organiser le travail de l’équipe.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 14),
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
                    if (organization.competitionReadiness != null)
                      Chip(
                        label: Text(
                          '${organization.competitionReadiness!.toStringAsFixed(0)}% préparation compétition',
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
                  SizedBox(width: 20),
                  Expanded(child: copy),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: scoreWidget),
                SizedBox(height: 16),
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
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  child: Icon(Icons.history_edu_rounded),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ce que nous avons construit ensemble',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Des premiers projets aux nouvelles générations d’enacteurs, chaque initiative prolonge une même ambition : créer des solutions utiles avec les communautés.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
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
                    value: impact.impactedLives == null
                        ? 'Non renseigné'
                        : '${impact.impactedLivesIsMinimum ? 'Plus de ' : ''}${_integer(impact.impactedLives)}',
                    subtitle:
                        '${impact.createdJobsIsMinimum ? 'Plus de ' : ''}${_integer(impact.createdJobs)} emplois • ${_integer(impact.peopleTrained)} personnes formées',
                    icon: Icons.groups_2_rounded,
                  ),
                  _HistoricalPillar(
                    title: 'Planet',
                    value: _integer(impact.plantedTrees),
                    subtitle:
                        'arbres plantés • ${_integer(impact.fieldKilometers)} km parcourus sur le terrain',
                    icon: Icons.park_rounded,
                  ),
                  _HistoricalPillar(
                    title: 'Prosperity',
                    value: '${_integer(impact.revenueUsd2021To2022)} USD',
                    subtitle:
                        'revenus 2021–2022 • +${_integer(impact.beneficiaryIncomeIncreasePct)} % de revenus bénéficiaires',
                    icon: Icons.trending_up_rounded,
                  ),
                  _HistoricalPillar(
                    title: 'Innovation',
                    value: _integer(impact.developedProducts),
                    subtitle:
                        'produits développés • ${_integer(impact.touchedSdgs)} ODD • ${_integer(impact.workHours)} h investies',
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
            const SizedBox(height: 20),
            _ImpactStories(impact: impact),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (impact.malnutritionBeforePct != null &&
                    impact.malnutritionAfterPct != null)
                  Chip(
                    avatar: const Icon(Icons.monitor_heart_rounded, size: 18),
                    label: Text(
                      'Malnutrition : ${_integer(impact.malnutritionBeforePct)} % → ${_integer(impact.malnutritionAfterPct)} %',
                    ),
                  ),
                if (impact.dimbaliRevenueUsd2021To2022 != null)
                  Chip(
                    avatar: const Icon(Icons.payments_rounded, size: 18),
                    label: Text(
                      'Dimbali 2021–2022 : ${_integer(impact.dimbaliRevenueUsd2021To2022)} USD',
                    ),
                  ),
                if (impact.menNanRevenueUsd2021To2022 != null)
                  Chip(
                    avatar: const Icon(Icons.payments_rounded, size: 18),
                    label: Text(
                      'Mën Nañ 2021–2022 : ${_integer(impact.menNanRevenueUsd2021To2022)} USD',
                    ),
                  ),
              ],
            ),
            if (impact.malnutritionBeforePct != null ||
                impact.dimbaliRevenueUsd2021To2022 != null ||
                impact.menNanRevenueUsd2021To2022 != null)
              SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final project in impact.emblematicProjects)
                  Chip(label: Text(project)),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final distinction in impact.distinctions)
                  Chip(
                    avatar: Icon(Icons.emoji_events_rounded, size: 18),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.25),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: Icon(icon),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(title, style: TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
  final double? score;
  final String label;

  const _RadialScore({required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = ((score ?? 0) / 100).clamp(0.0, 1.0);

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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
              color: AppTheme.enactusYellow,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.toStringAsFixed(0) ?? '—',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        final effectiveCount = MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 1
            : count;
        final width =
            (constraints.maxWidth - spacing * (effectiveCount - 1)) /
            effectiveCount;

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
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              child: Icon(item.icon),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
      ..sort((a, b) => a.projectName.compareTo(b.projectName));

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
              final score = _ProjectPortrait(project: project);
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.projectName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Chip(label: Text(project.status)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${project.poleName} • ${project.projectLead} / ${project.deputyLead}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    project.solution,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(height: 1.35),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          '${impactNumber(project.directImpact)} direct',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${impactNumber(project.indirectImpact)} indirect',
                        ),
                      ),
                      Chip(label: Text('${impactNumber(project.reach)} reach')),
                      if ((project.jobsCreated ?? 0) > 0)
                        Chip(label: Text('${project.jobsCreated} emplois')),
                      if ((project.livesImpacted ?? 0) > 0)
                        Chip(label: Text('${project.livesImpacted} vies')),
                      Chip(label: Text('${project.evidenceCount} preuves')),
                      for (final claim in project.claims)
                        Chip(
                          label: Text(
                            '${claim.claimTypeLabel} · ${claim.validationLabel}',
                          ),
                        ),
                      for (final sdg in project.sdgs) Chip(label: Text(sdg)),
                      if (project.sdgs.isEmpty)
                        const Chip(label: Text('ODD à définir')),
                    ],
                  ),
                  SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (project.progress / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    color: AppTheme.enactusYellow,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${project.progress.toStringAsFixed(0)}% avancement • ${project.completedTasks} tâches terminées • ${project.lateTasks} en retard',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  children: [
                    score,
                    SizedBox(width: 18),
                    Expanded(child: details),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: score),
                  SizedBox(height: 14),
                  details,
                  SizedBox(height: 8),
                  Align(
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '${project.poleName} • ${project.status} • ${project.projectLead} / ${project.deputyLead}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final score = _ProjectPortrait(project: project);
                    final metrics = _KpiGrid(
                      items: [
                        _KpiItem(
                          label: 'Impact direct',
                          value: impactNumber(project.directImpact),
                          icon: Icons.volunteer_activism_rounded,
                        ),
                        _KpiItem(
                          label: 'Impact indirect',
                          value: impactNumber(project.indirectImpact),
                          icon: Icons.groups_rounded,
                        ),
                        _KpiItem(
                          label: 'Reach',
                          value: impactNumber(project.reach),
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
                          value: impactNumber(project.jobsCreated),
                          icon: Icons.work_rounded,
                        ),
                        _KpiItem(
                          label: 'Vies touchées',
                          value: impactNumber(project.livesImpacted),
                          icon: Icons.favorite_rounded,
                        ),
                        _KpiItem(
                          label: 'Preuves vérifiées',
                          value: project.verifiedEvidenceCount.toString(),
                          icon: Icons.verified_rounded,
                        ),
                      ],
                    );

                    if (!wide) {
                      return Column(
                        children: [score, SizedBox(height: 16), metrics],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        score,
                        SizedBox(width: 20),
                        Expanded(child: metrics),
                      ],
                    );
                  },
                ),
                SizedBox(height: 18),
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
                SizedBox(height: 18),
                _ProjectDetailBlock(
                  title: 'Le besoin de départ',
                  text: project.problem,
                  icon: Icons.report_problem_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'La réponse de l’équipe',
                  text: project.solution,
                  icon: Icons.lightbulb_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Avec qui nous agissons',
                  text: project.targetBeneficiaries,
                  icon: Icons.diversity_3_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Les pièces du projet',
                  text:
                      '${project.evidenceCount} justificatif(s) et ${project.documentsCount} document(s) accompagnent ce projet. Ils permettent de retrouver les actions, de comprendre les résultats et de préparer la suite.',
                  icon: Icons.verified_rounded,
                ),
                if (project.hasEnvironmentalImpact)
                  _ProjectDetailBlock(
                    title: 'Impact environnemental',
                    text: [
                      if ((project.treesPlanted ?? 0) > 0)
                        '${project.treesPlanted} arbre(s) plantes',
                      if ((project.wasteReduced ?? 0) > 0)
                        '${project.wasteReduced!.toStringAsFixed(0)} kg de dechets reduits',
                      if ((project.waterSaved ?? 0) > 0)
                        '${project.waterSaved!.toStringAsFixed(0)} litres economises',
                      if ((project.co2Reduced ?? 0) > 0)
                        '${project.co2Reduced!.toStringAsFixed(0)} kg CO2 reduits',
                    ].join(' - '),
                    icon: Icons.eco_rounded,
                  ),
                _ProjectDetailBlock(
                  title: 'Comment nous suivons les résultats',
                  text: project.methodology ?? 'Non renseigné',
                  icon: Icons.fact_check_rounded,
                ),
                _ProjectDetailBlock(
                  title: 'Ce que nous préparons pour la suite',
                  text: project.assumptions ?? 'Non renseigné',
                  icon: Icons.rule_rounded,
                ),
                SizedBox(height: 8),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.25),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: Icon(icon),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                ReadingBlocks(text),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Chip(
            label: Text(
              'Budget opérationnel: ${project.budgetUsed.toStringAsFixed(0)}',
            ),
          ),
          if (project.claims.isEmpty)
            const Chip(label: Text('Aucune déclaration d’impact')),
          for (final claim in project.claims)
            Chip(
              label: Text(
                '${claim.title}: ${impactNumber(claim.value)} ${claim.unit} · '
                '${claim.claimTypeLabel} · ${claim.validationLabel}',
              ),
            ),
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
      return Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Aucun complément n’est demandé pour le moment.'),
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
                  child: Icon(Icons.warning_amber_rounded),
                ),
                title: Text(
                  project.projectName,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  project.impactRecordId == null
                      ? '/impact/records'
                      : '/impact/records/${project.impactRecordId}',
                ),
                subtitle: Text(
                  [
                    if (project.needsEvidence)
                      project.evidenceCount == 0
                          ? 'ajouter un justificatif'
                          : 'examiner les justificatifs',
                    if (project.needsSdg) 'préciser les ODD concernés',
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
        final effectiveCount = MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 1
            : count;
        final width =
            (constraints.maxWidth - spacing * (effectiveCount - 1)) /
            effectiveCount;

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
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: (pole.healthScore / 100).clamp(0.0, 1.0),
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
              color: AppTheme.enactusYellow,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            SizedBox(height: 10),
            Text(
              'Pole Health Score ${pole.healthScore.toStringAsFixed(0)}/100',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
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
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        child: Text(rank.toString()),
      ),
      title: Text(
        enacteur.memberName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${enacteur.completedTasks} tâches • ${enacteur.academyLessonsCompleted} leçons • ${enacteur.badges} badges',
      ),
      trailing: Text(
        enacteur.engagementScore.toStringAsFixed(0),
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ScoreFrameworkCard extends StatelessWidget {
  const _ScoreFrameworkCard();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'Mesuré + vérifié = réalisé',
      'Estimation ≠ réalisé',
      'Projection ≠ réalisé',
      'Historique déclaré ≠ mesuré',
      'Preuve jointe ≠ vérifié',
      'Non renseigné ≠ zéro',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprendre les indicateurs',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Une mesure décrit ce qui a été observé. Une estimation donne un ordre de grandeur, tandis qu’une projection prépare l’avenir. Chaque fiche conserve la période, la méthode et les limites utiles pour lire ses résultats.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final rule in rules) Chip(label: Text(rule))],
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
            SizedBox(height: 12),
            Text(
              'Impact indisponible',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

String _integer(num? value) {
  if (value == null) return 'Non renseigné';
  final raw = value is double && value % 1 != 0
      ? value.toStringAsFixed(1)
      : value.round().toString();
  final parts = raw.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return parts.length == 1
      ? buffer.toString()
      : '${buffer.toString()}.${parts[1]}';
}

String _money(double? amount) {
  if (amount == null) return 'Non renseigné';
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(0)}K';
  }
  return amount.toStringAsFixed(0);
}

class _ProjectPortrait extends StatelessWidget {
  final ProjectImpactMetricModel project;
  const _ProjectPortrait({required this.project});
  @override
  Widget build(BuildContext context) {
    final photo = heritagePhotoFor(project.projectName);
    if (photo != null) {
      return SizedBox(
        width: 240,
        child: HeritagePhoto(photo: photo, height: 170),
      );
    }
    return SizedBox(
      width: 180,
      child: Column(
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            project.projectName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${project.completedTasks} tâche(s) terminée(s)',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ImpactStory {
  final String title;
  final String subtitle;
  final HeritagePhotoData photo;
  final String content;
  const _ImpactStory(this.title, this.subtitle, this.photo, this.content);
}

class _ImpactStories extends StatelessWidget {
  final HistoricalImpactModel impact;
  const _ImpactStories({required this.impact});
  @override
  Widget build(BuildContext context) {
    final stories = [
      _ImpactStory(
        'People · des personnes au cœur du projet',
        'L’autonomie se construit avec les communautés.',
        const HeritagePhotoData(
          'dimbali-gie-favec',
          'Dimbali et les femmes du GIE FAVEC.',
        ),
        '### Agir avec les personnes\n\nUne solution prend tout son sens lorsque les personnes concernées peuvent se l’approprier. Avec Dimbali et Mën Nañ, l’entrepreneuriat rejoint des besoins du quotidien : développer une activité, accéder à des produits utiles et renforcer les savoir-faire. La rencontre, la formation et le suivi donnent au projet une place dans la vie des communautés.\n\n### Des parcours qui se prolongent\n\nLe bilan historique d’Enactus ESP réunit ${impact.impactedLivesIsMinimum ? "plus de " : ""}${_integer(impact.impactedLives)} vies touchées, ${impact.createdJobsIsMinimum ? "plus de " : ""}${_integer(impact.createdJobs)} emplois créés et ${_integer(impact.peopleTrained)} personnes formées. Derrière ces repères, l’enjeu reste concret : permettre aux personnes de faire, de choisir et de poursuivre une activité après le passage de l’équipe.\n\n### Ce que cela nous apprend\n\nLe nombre de personnes rencontrées ne raconte pas, à lui seul, le changement obtenu. Pour chaque nouvelle action, l’équipe précise avec qui elle travaille, sur quelle période et ce qui évolue réellement. Cette attention permet de transmettre une expérience utile à la génération suivante.',
      ),
      _ImpactStory(
        'Planet · prendre soin des ressources',
        'Le terrain nous apprend à concevoir autrement.',
        const HeritagePhotoData(
          'haffe-2025-parcelles',
          'Terrasen sur le terrain à Haffé.',
        ),
        '### Partir des usages réels\n\nLes projets environnementaux prennent forme dans un contexte précis : des ressources disponibles, des contraintes de production et des pratiques déjà en place. Terrasen et Aquatus invitent à relier innovation, agriculture et gestion des ressources. Avant de proposer un dispositif, les enacteurs prennent le temps de rencontrer les utilisateurs et de comprendre ce qu’ils peuvent entretenir eux-mêmes.\n\n### Une présence sur le terrain\n\nLe parcours du club comprend ${_integer(impact.plantedTrees)} arbres plantés et ${_integer(impact.fieldKilometers)} kilomètres parcourus sur le terrain. Les déplacements permettent de rencontrer les communautés, de tester les solutions et de revenir lorsque de nouvelles questions apparaissent. Les arbres plantés constituent une action ; leur suivi dans le temps aide à comprendre le résultat durable.\n\n### Préparer la continuité\n\nUne innovation environnementale doit rester utile après sa démonstration. Son coût, sa maintenance et son usage quotidien font donc partie du projet. Documenter les difficultés et prévoir un prochain suivi sont aussi essentiels que présenter une réussite.',
      ),
      _ImpactStory(
        'Prosperity · faire durer la valeur créée',
        'L’activité économique soutient la mission sociale.',
        const HeritagePhotoData(
          'niaguiss-2025-produits',
          'Mën Nañ : des produits développés avec les communautés.',
        ),
        '### Créer une activité qui tient dans le temps\n\nL’entrepreneuriat social cherche une réponse utile et une manière réaliste de la faire durer. Les produits, les ventes, les coûts et l’organisation locale sont liés : une activité doit pouvoir renouveler ses moyens et continuer à servir les personnes auxquelles elle s’adresse.\n\n### Un repère pour 2021–2022\n\nSur la période 2021–2022, les revenus réunis atteignent ${_integer(impact.revenueUsd2021To2022)} USD, dont ${_integer(impact.dimbaliRevenueUsd2021To2022)} USD pour Dimbali et ${_integer(impact.menNanRevenueUsd2021To2022)} USD pour Mën Nañ. Ces revenus décrivent cette période précise. Ils permettent de comprendre la place de l’activité économique dans les projets ; ils ne représentent ni un bénéfice net ni un montant ajouté aux résultats actuels d’EnactSpace.\n\n### Lire la valeur au-delà des ventes\n\nLe bilan historique indique également une hausse de ${_integer(impact.beneficiaryIncomeIncreasePct)} % des revenus des bénéficiaires. Pour poursuivre ce travail, une équipe suit les recettes et les dépenses, mais aussi ce que l’activité change pour les personnes. La pérennité se prépare avec elles : qui produit, qui décide, qui entretient et qui reprend le relais ?',
      ),
      _ImpactStory(
        'Innovation · apprendre, essayer, transmettre',
        'Chaque projet nourrit le suivant.',
        const HeritagePhotoData(
          'mobigel-prototypes',
          'Mobigel : construire un prototype et le mettre à l’épreuve du terrain.',
        ),
        '### Transformer une idée en expérience utile\n\nL’innovation commence souvent par une question simple posée sur le terrain. L’équipe imagine plusieurs réponses, fabrique un premier essai et regarde ce qui fonctionne réellement. Les projets Dimbali, Deconaane, Mën Nañ, SHERY, Terrasen ou Aquatus illustrent la diversité des pistes explorées par Enactus ESP.\n\n### Un effort collectif\n\nLe bilan du club rassemble ${_integer(impact.developedProducts)} produits développés, ${_integer(impact.workHours)} heures investies et une contribution à ${_integer(impact.touchedSdgs)} objectifs de développement durable. Le temps de recherche, de préparation, d’essai et de transmission accompagne les réalisations visibles.\n\n### Garder ce que l’on a appris\n\nLes compétitions sont des moments de rencontre et de présentation. La valeur d’un projet continue pourtant à se construire entre ces rendez-vous : revoir un prototype, répondre à un utilisateur et partager une difficulté. En conservant ces apprentissages, EnactSpace aide chaque nouvelle équipe à avancer avec les acquis de celles qui l’ont précédée.',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 700 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3
            ? 2
            : 1;
        final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final story in stories)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HeritagePhoto(photo: story.photo, height: 180),
                        const SizedBox(height: 16),
                        Text(
                          story.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          story.subtitle,
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          key: ValueKey('impact-story-${story.photo.asset}'),
                          icon: const Icon(Icons.auto_stories_outlined),
                          label: const Text('Découvrir cette histoire'),
                          onPressed: () => showDialog<void>(
                            context: context,
                            useSafeArea: false,
                            builder: (context) => Dialog.fullscreen(
                              child: Scaffold(
                                appBar: AppBar(
                                  title: Text(story.title, maxLines: 2),
                                ),
                                body: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 840,
                                    ),
                                    child: ListView(
                                      padding: const EdgeInsets.all(24),
                                      children: [
                                        HeritagePhoto(photo: story.photo),
                                        const SizedBox(height: 24),
                                        ReadingBlocks(story.content),
                                        const SizedBox(height: 32),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
