import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/archive_models.dart';
import '../services/archives_service.dart';

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key});

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  final ArchivesService _service = ArchivesService();

  bool _loading = true;
  String? _error;
  ArchivesHomeData? _data;

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getArchives();
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
      onRefresh: _loadArchives,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _ArchivesHeader(),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ArchivesErrorCard(message: _error!, onRetry: _loadArchives)
          else
            _ArchivesContent(data: _data!),
        ],
      ),
    );
  }
}

class _ArchivesHeader extends StatelessWidget {
  const _ArchivesHeader();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: wide
          ? const Row(
              children: [
                _HeaderIcon(),
                SizedBox(width: 18),
                Expanded(child: _HeaderCopy()),
              ],
            )
          : const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_HeaderIcon(), SizedBox(height: 18), _HeaderCopy()],
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
        Icons.history_edu_rounded,
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
          'Archives & Mémoire collective',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Anciens projets, impacts historiques, livrables, leçons apprises et possibilités d’expansion.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _ArchivesContent extends StatelessWidget {
  final ArchivesHomeData data;

  const _ArchivesContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArchiveSummaryGrid(summary: data.summary),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Projets historiques',
          subtitle:
              'Une base vivante pour apprendre, transmettre et relancer les meilleures initiatives.',
        ),
        const SizedBox(height: 12),
        _ArchiveProjectsGrid(projects: data.projects),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Palmarès Enactus ESP',
          subtitle:
              'Prix, titres, compétition internationale et visibilité médiatique du club.',
        ),
        const SizedBox(height: 12),
        _HallOfFameSection(items: data.hallOfFame),
      ],
    );
  }
}

class _ArchiveSummaryGrid extends StatelessWidget {
  final ArchiveImpactSummaryModel summary;

  const _ArchiveSummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ArchiveMetric(
        'Projets créés',
        summary.createdProjects.toString(),
        Icons.rocket_launch_rounded,
      ),
      _ArchiveMetric(
        'Produits',
        summary.developedProducts.toString(),
        Icons.inventory_2_rounded,
      ),
      _ArchiveMetric(
        'ODD touchés',
        summary.touchedSdgs.toString(),
        Icons.public_rounded,
      ),
      _ArchiveMetric(
        'Emplois créés',
        summary.createdJobs.toString(),
        Icons.work_rounded,
      ),
      _ArchiveMetric(
        'Vies sauvées',
        summary.savedLives.toString(),
        Icons.health_and_safety_rounded,
      ),
      _ArchiveMetric(
        'Arbres plantés',
        summary.plantedTrees.toString(),
        Icons.park_rounded,
      ),
      _ArchiveMetric(
        'Vies impactées',
        '+${summary.impactedLives}',
        Icons.groups_2_rounded,
      ),
      _ArchiveMetric(
        'Gains cumulés',
        '${(summary.cumulativeFcfaGains / 1000000).toStringAsFixed(1)}M FCFA',
        Icons.savings_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1050
            ? 4
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
                child: _ArchiveMetricCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _ArchiveMetric {
  final String label;
  final String value;
  final IconData icon;

  const _ArchiveMetric(this.label, this.value, this.icon);
}

class _ArchiveMetricCard extends StatelessWidget {
  final _ArchiveMetric item;

  const _ArchiveMetricCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.22),
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

class _ArchiveProjectsGrid extends StatelessWidget {
  final List<ArchiveProjectModel> projects;

  const _ArchiveProjectsGrid({required this.projects});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        const spacing = 14.0;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final project in projects)
              SizedBox(
                width: width,
                child: _ArchiveProjectCard(project: project),
              ),
          ],
        );
      },
    );
  }
}

class _ArchiveProjectCard extends StatelessWidget {
  final ArchiveProjectModel project;

  const _ArchiveProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _showProjectDetails(context, project),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ArchiveProjectLogo(project: project, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Chip(label: Text(project.status)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                project.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(project.periodLabel)),
                  Chip(label: Text(project.locality)),
                  if (project.expansionReady)
                    const Chip(label: Text('Expansion possible')),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${project.impactedLives} vies')),
                  Chip(label: Text('${project.jobs} emplois')),
                  Chip(label: Text('${project.products.length} produit(s)')),
                  for (final sdg in project.sdgs.take(2))
                    Chip(label: Text(sdg)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectDetails(BuildContext context, ArchiveProjectModel project) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ArchiveProjectDetails(project: project),
    );
  }
}

class _ArchiveProjectDetails extends StatelessWidget {
  final ArchiveProjectModel project;

  const _ArchiveProjectDetails({required this.project});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _ArchiveProjectLogo(project: project, size: 68),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.summary,
                    style: const TextStyle(color: Colors.black54, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: 'Problème',
                    body: project.problem,
                    icon: Icons.report_problem_rounded,
                  ),
                  _DetailSection(
                    title: 'Solution',
                    body: project.solution,
                    icon: Icons.lightbulb_rounded,
                  ),
                  _DetailChips(
                    title: 'Impacts et indicateurs',
                    chips: [
                      '${project.impactedLives} vies impactées',
                      '${project.savedLives} vies sauvées',
                      '${project.jobs} emplois',
                      '${project.plantedTrees} arbres',
                      '${_money(project.revenue)} revenus',
                      '${_money(project.profit)} bénéfices',
                    ],
                  ),
                  _DetailChips(title: 'ODD', chips: project.sdgs),
                  _DetailChips(title: 'Produits', chips: project.products),
                  _DetailChips(title: 'Actes posés', chips: project.actions),
                  _DetailChips(title: 'Partenaires', chips: project.partners),
                  _DetailChips(title: 'Prix', chips: project.awards),
                  _DetailChips(title: 'Documents', chips: project.documents),
                  _DetailChips(
                    title: 'Membres / Alumni',
                    chips: project.members,
                  ),
                  _DetailChips(
                    title: 'Leçons apprises',
                    chips: project.lessons,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Fermer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: project.expansionReady ? () {} : null,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Créer expansion'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArchiveProjectLogo extends StatelessWidget {
  final ArchiveProjectModel project;
  final double size;

  const _ArchiveProjectLogo({required this.project, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = project.logoAsset;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.enactusYellow.withValues(alpha: 0.24),
        child: asset == null
            ? Center(
                child: Text(
                  project.name.characters.first,
                  style: TextStyle(
                    color: AppTheme.softBlack,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      project.name.characters.first,
                      style: TextStyle(
                        color: AppTheme.softBlack,
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _DetailSection({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.22),
          foregroundColor: AppTheme.softBlack,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(body),
      ),
    );
  }
}

class _DetailChips extends StatelessWidget {
  final String title;
  final List<String> chips;

  const _DetailChips({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final chip in chips) Chip(label: Text(chip))],
          ),
        ],
      ),
    );
  }
}

class HallOfFamePreview extends StatelessWidget {
  final List<HallOfFameItemModel> items;

  const HallOfFamePreview({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final item in items.take(4))
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.22),
                foregroundColor: AppTheme.softBlack,
                child: const Icon(Icons.emoji_events_rounded),
              ),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('${item.period} • ${item.type}'),
            ),
        ],
      ),
    );
  }
}

class _HallOfFameSection extends StatelessWidget {
  final List<HallOfFameItemModel> items;

  const _HallOfFameSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final titles = items.where((item) => item.type == 'Titre').length;
    final competitions = items
        .where(
          (item) => item.type == 'Compétition' || item.type == 'International',
        )
        .length;
    final media = items.where((item) => item.type == 'Média').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final cards = [
              _HallMetric(
                label: 'Titres nationaux',
                value: titles.toString(),
                icon: Icons.workspace_premium_rounded,
              ),
              _HallMetric(
                label: 'Compétitions',
                value: competitions.toString(),
                icon: Icons.emoji_events_rounded,
              ),
              _HallMetric(
                label: 'Médias',
                value: media.toString(),
                icon: Icons.campaign_rounded,
              ),
            ];

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 24) / 3,
                    child: _HallMetricCard(metric: card),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++)
                _HallOfFameTile(
                  item: items[index],
                  first: index == 0,
                  last: index == items.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.enactusYellow.withValues(
                    alpha: 0.24,
                  ),
                  foregroundColor: AppTheme.softBlack,
                  child: const Icon(Icons.menu_book_rounded),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Source mémoire',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Informations structurées depuis la présentation historique Enactus ESP et prêtes à être reliées aux documents officiels.',
                        style: TextStyle(color: Colors.black54, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HallMetric {
  final String label;
  final String value;
  final IconData icon;

  const _HallMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _HallMetricCard extends StatelessWidget {
  final _HallMetric metric;

  const _HallMetricCard({required this.metric});

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
              child: Icon(metric.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    metric.label,
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

class _HallOfFameTile extends StatelessWidget {
  final HallOfFameItemModel item;
  final bool first;
  final bool last;

  const _HallOfFameTile({
    required this.item,
    required this.first,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: first
                        ? Colors.transparent
                        : AppTheme.enactusYellow.withValues(alpha: 0.55),
                  ),
                ),
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Icon(_hallIcon(item.type), size: 19),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last
                        ? Colors.transparent
                        : AppTheme.enactusYellow.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(item.period)),
                      Chip(label: Text(item.type)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.description,
                    style: const TextStyle(color: Colors.black54, height: 1.35),
                  ),
                  if (item.imageAsset != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        item.imageAsset!,
                        width: double.infinity,
                        height: 156,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 96,
                            alignment: Alignment.center,
                            color: AppTheme.enactusYellow.withValues(
                              alpha: 0.16,
                            ),
                            child: const Icon(
                              Icons.image_not_supported_rounded,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _hallIcon(String type) {
  switch (type) {
    case 'Titre':
      return Icons.workspace_premium_rounded;
    case 'International':
      return Icons.public_rounded;
    case 'Média':
      return Icons.campaign_rounded;
    case 'Prix':
      return Icons.star_rounded;
    default:
      return Icons.emoji_events_rounded;
  }
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

class _ArchivesErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ArchivesErrorCard({required this.message, required this.onRetry});

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
              'Archives indisponibles',
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
    return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
  }
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K FCFA';
  return '${amount.toStringAsFixed(0)} FCFA';
}
