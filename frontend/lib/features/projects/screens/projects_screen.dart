import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/project_model.dart';
import '../services/projects_service.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectsService _service = ProjectsService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _status = 'all';
  List<ProjectModel> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projects = await _service.getProjects();

      if (!mounted) return;
      setState(() {
        _projects = projects;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<ProjectModel> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();

    return _projects.where((project) {
      final matchesStatus = _status == 'all' || project.status == _status;
      final matchesSearch =
          query.isEmpty ||
          project.name.toLowerCase().contains(query) ||
          (project.description ?? '').toLowerCase().contains(query) ||
          (project.problemStatement ?? '').toLowerCase().contains(query) ||
          (project.solution ?? '').toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CreateProjectSheet(service: _service);
      },
    );

    if (created == true) {
      await _loadProjects();
    }
  }

  void _replaceProject(ProjectModel updated) {
    setState(() {
      _projects = [
        for (final project in _projects)
          project.id == updated.id ? updated : project,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProjects,
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
                      _ProjectsHeader(
                        total: _projects.length,
                        active: _projects
                            .where(
                              (project) =>
                                  project.status != 'termine' &&
                                  project.status != 'suspendu',
                            )
                            .length,
                        onCreate: _openCreateSheet,
                        onRefresh: _loadProjects,
                      ),
                      const SizedBox(height: 18),
                      _ProjectsToolbar(
                        searchController: _searchController,
                        status: _status,
                        onSearchChanged: (_) => setState(() {}),
                        onStatusChanged: (value) {
                          setState(() => _status = value);
                        },
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const _LoadingCard()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadProjects)
                      else if (_filteredProjects.isEmpty)
                        const _EmptyProjectsCard()
                      else
                        _ProjectsGrid(
                          projects: _filteredProjects,
                          service: _service,
                          onProjectChanged: _replaceProject,
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

class _ProjectsHeader extends StatelessWidget {
  final int total;
  final int active;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _ProjectsHeader({
    required this.total,
    required this.active,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;

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
                  child: _HeaderText(total: total, active: active),
                ),
                const SizedBox(width: 18),
                _HeaderActions(onCreate: onCreate, onRefresh: onRefresh),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderIcon(),
                const SizedBox(height: 18),
                _HeaderText(total: total, active: active),
                const SizedBox(height: 18),
                _HeaderActions(onCreate: onCreate, onRefresh: onRefresh),
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
        Icons.rocket_launch_rounded,
        color: AppTheme.softBlack,
        size: 36,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int active;

  const _HeaderText({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Projets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Idées, prototypes, impact et déploiement sur un seul tableau.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderChip(label: '$total projet(s)'),
            _HeaderChip(label: '$active actif(s)'),
          ],
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _HeaderActions({required this.onCreate, required this.onRefresh});

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
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer un projet'),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;

  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}

class _ProjectsToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  const _ProjectsToolbar({
    required this.searchController,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchWidth = constraints.maxWidth >= 760
                ? 360.0
                : constraints.maxWidth;
            final statusWidth = constraints.maxWidth >= 520
                ? 240.0
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un projet',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: statusWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: _statusItems(includeAll: true),
                    onChanged: (value) {
                      if (value != null) onStatusChanged(value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectsGrid extends StatelessWidget {
  final List<ProjectModel> projects;
  final ProjectsService service;
  final ValueChanged<ProjectModel> onProjectChanged;

  const _ProjectsGrid({
    required this.projects,
    required this.service,
    required this.onProjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        const spacing = 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final project in projects)
              SizedBox(
                width: itemWidth,
                child: _ProjectCard(
                  project: project,
                  service: service,
                  onProjectChanged: onProjectChanged,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final ProjectsService service;
  final ValueChanged<ProjectModel> onProjectChanged;

  const _ProjectCard({
    required this.project,
    required this.service,
    required this.onProjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('dd/MM/yyyy').format(project.createdAt);
    final statusColor = _statusColor(project.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.enactusYellow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: AppTheme.softBlack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Créé le $createdAt',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProjectChip(
                  icon: Icons.timeline_rounded,
                  label: project.statusLabel,
                  color: statusColor,
                ),
                _ProjectChip(
                  icon: Icons.payments_rounded,
                  label: _money(project.budgetEstimated),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _safeText(
                project.description,
                fallback: 'Aucune description renseignée pour ce projet.',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            _ProgressLine(progress: project.progress, color: statusColor),
            const SizedBox(height: 16),
            _ProjectInfoBlock(
              icon: Icons.report_problem_rounded,
              title: 'Problème',
              value: _safeText(
                project.problemStatement,
                fallback: 'Problématique à préciser',
              ),
            ),
            const SizedBox(height: 10),
            _ProjectInfoBlock(
              icon: Icons.lightbulb_rounded,
              title: 'Solution',
              value: _safeText(
                project.solution,
                fallback: 'Solution à préciser',
              ),
            ),
            const SizedBox(height: 16),
            _ProjectReadinessBar(project: project),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _safeText(
                      project.expectedImpact,
                      fallback: 'Impact attendu à préciser',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showProjectDetails(
                  context,
                  project,
                  service,
                  onProjectChanged,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Détail projet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final int progress;
  final Color color;

  const _ProgressLine({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Avancement estimé',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$progress%',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progress / 100,
            backgroundColor: color.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ProjectReadinessBar extends StatelessWidget {
  final ProjectModel project;

  const _ProjectReadinessBar({required this.project});

  @override
  Widget build(BuildContext context) {
    final score = _projectReadinessScore(project);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Préparation compétition',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$score/100',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppTheme.enactusYellow,
            ),
          ),
        ],
      ),
    );
  }
}

void _showProjectDetails(
  BuildContext context,
  ProjectModel project,
  ProjectsService service,
  ValueChanged<ProjectModel> onProjectChanged,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _ProjectDetailsSheet(
      project: project,
      service: service,
      onProjectChanged: onProjectChanged,
    ),
  );
}

class _ProjectDetailsSheet extends StatefulWidget {
  final ProjectModel project;
  final ProjectsService service;
  final ValueChanged<ProjectModel> onProjectChanged;

  const _ProjectDetailsSheet({
    required this.project,
    required this.service,
    required this.onProjectChanged,
  });

  @override
  State<_ProjectDetailsSheet> createState() => _ProjectDetailsSheetState();
}

class _ProjectDetailsSheetState extends State<_ProjectDetailsSheet> {
  late ProjectModel _project;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updatingStatus = true);

    try {
      final updated = await widget.service.updateProject(
        projectId: _project.id,
        status: status,
        endedAt: status == 'termine' ? DateTime.now() : null,
        clearEndedAt: status != 'termine' && _project.endedAt != null,
      );

      widget.onProjectChanged(updated);

      if (!mounted) return;
      setState(() => _project = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Projet passé en ${updated.statusLabel}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final statusColor = _statusColor(project.status);
    final readiness = _projectReadinessScore(project);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.enactusYellow,
                        foregroundColor: AppTheme.softBlack,
                        child: const Icon(Icons.rocket_launch_rounded),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${project.statusLabel} · ${_money(project.budgetEstimated)} · préparation $readiness/100',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ProgressLine(progress: project.progress, color: statusColor),
                  const SizedBox(height: 12),
                  _ProjectStatusPanel(
                    project: project,
                    updating: _updatingStatus,
                    onStatusChanged: _updateStatus,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ProjectDetailBlock(
                        icon: Icons.report_problem_rounded,
                        title: 'Problème',
                        body: _safeText(
                          project.problemStatement,
                          fallback: 'Problématique à préciser.',
                        ),
                      ),
                      _ProjectDetailBlock(
                        icon: Icons.lightbulb_rounded,
                        title: 'Solution',
                        body: _safeText(
                          project.solution,
                          fallback: 'Solution à préciser.',
                        ),
                      ),
                      _ProjectDetailBlock(
                        icon: Icons.flag_rounded,
                        title: 'Objectifs',
                        body: _safeText(
                          project.objectives,
                          fallback: 'Objectifs à préciser.',
                        ),
                      ),
                      _ProjectDetailBlock(
                        icon: Icons.public_rounded,
                        title: 'Impact / livrables',
                        body: _safeText(
                          project.expectedImpact,
                          fallback: 'Impact attendu et livrables à préciser.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isTerrasenProject(project)) ...[
                    const _TerrasenReferenceCard(),
                    const SizedBox(height: 16),
                  ],
                  const _ProjectActionPanel(),
                  const SizedBox(height: 16),
                  _ProjectLogPreview(project: project),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProjectStatusPanel extends StatelessWidget {
  final ProjectModel project;
  final bool updating;
  final ValueChanged<String> onStatusChanged;

  const _ProjectStatusPanel({
    required this.project,
    required this.updating,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final started = project.startedAt == null
        ? 'Début à préciser'
        : 'Début ${DateFormat('dd/MM/yyyy').format(project.startedAt!)}';
    final ended = project.endedAt == null
        ? 'Fin non définie'
        : 'Fin ${DateFormat('dd/MM/yyyy').format(project.endedAt!)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.34),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 620;
          final statusPicker = DropdownButtonFormField<String>(
            key: ValueKey(project.status),
            initialValue: project.status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Changer le statut',
              prefixIcon: Icon(Icons.timeline_rounded),
            ),
            items: _statusItems(includeAll: false),
            onChanged: updating
                ? null
                : (value) {
                    if (value != null && value != project.status) {
                      onStatusChanged(value);
                    }
                  },
          );

          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilotage projet',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${project.statusLabel} · ${project.progress}% · $started · $ended',
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
              if (updating) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 4),
              ],
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 14),
                SizedBox(width: 260, child: statusPicker),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [summary, const SizedBox(height: 12), statusPicker],
          );
        },
      ),
    );
  }
}

class _TerrasenReferenceCard extends StatelessWidget {
  const _TerrasenReferenceCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.agriculture_rounded,
        'Volets',
        'Production, transformation, conservation et distribution.',
      ),
      (
        Icons.groups_2_rounded,
        'Cibles',
        'Yeumbeul, Passy, Khaffe, Ngayenne Sabakh, vendeuses de legumes, COUD et UCAD.',
      ),
      (
        Icons.memory_rounded,
        'Innovation',
        'Arrosage automatise ESP32, capteur humidite, relais, pompe et controle Wi-Fi.',
      ),
      (
        Icons.verified_rounded,
        'Preuves',
        'Transferts 2024, immersions terrain, recettes produits et budget documente.',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: AppTheme.enactusYellow),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Repères document TERRASEN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: _TerrasenReferenceItem(
                        icon: item.$1,
                        title: item.$2,
                        body: item.$3,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TerrasenReferenceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TerrasenReferenceItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppTheme.enactusYellow,
          foregroundColor: AppTheme.softBlack,
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectDetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ProjectDetailBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 72).clamp(280.0, 360.0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.enactusYellow.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.enactusYellow.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectActionPanel extends StatelessWidget {
  const _ProjectActionPanel();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _ProjectActionChip(icon: Icons.groups_rounded, label: 'Équipe'),
        _ProjectActionChip(icon: Icons.task_alt_rounded, label: 'Tâches'),
        _ProjectActionChip(icon: Icons.description_rounded, label: 'Documents'),
        _ProjectActionChip(icon: Icons.payments_rounded, label: 'Budget'),
        _ProjectActionChip(icon: Icons.photo_library_rounded, label: 'Photos'),
        _ProjectActionChip(icon: Icons.handshake_rounded, label: 'Partenaires'),
      ],
    );
  }
}

class _ProjectActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProjectActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _ProjectLogPreview extends StatelessWidget {
  final ProjectModel project;

  const _ProjectLogPreview({required this.project});

  @override
  Widget build(BuildContext context) {
    final items = [
      'Création du projet le ${DateFormat('dd/MM/yyyy').format(project.createdAt)}',
      if (project.startedAt != null)
        'Démarrage terrain le ${DateFormat('dd/MM/yyyy').format(project.startedAt!)}',
      if (project.endedAt != null)
        'Clôture prévue le ${DateFormat('dd/MM/yyyy').format(project.endedAt!)}',
      'Prochaine mise à jour: rapport impact, livrables et budget réel.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journal de bord',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.enactusYellow,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: Colors.white70),
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

class _ProjectInfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProjectInfoBlock({
    required this.icon,
    required this.title,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.softBlack),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  value,
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

class _ProjectChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ProjectChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppTheme.softBlack;

    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(label),
      backgroundColor: foreground.withValues(alpha: 0.12),
      side: BorderSide(color: foreground.withValues(alpha: 0.24)),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w800),
    );
  }
}

class _CreateProjectSheet extends StatefulWidget {
  final ProjectsService service;

  const _CreateProjectSheet({required this.service});

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _problemController = TextEditingController();
  final _solutionController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _impactController = TextEditingController();
  final _budgetController = TextEditingController(text: '0');

  String _status = 'idee';
  DateTime? _startedAt;
  DateTime? _endedAt;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _problemController.dispose();
    _solutionController.dispose();
    _objectivesController.dispose();
    _impactController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _startedAt : _endedAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _startedAt = picked;
      } else {
        _endedAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.service.createProject(
        name: _nameController.text,
        description: _descriptionController.text,
        problemStatement: _problemController.text,
        solution: _solutionController.text,
        objectives: _objectivesController.text,
        expectedImpact: _impactController.text,
        budgetEstimated:
            double.tryParse(
              _budgetController.text.trim().replaceAll(' ', ''),
            ) ??
            0,
        status: _status,
        startedAt: _startedAt,
        endedAt: _endedAt,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _prefillTerrasenFromDocument() {
    setState(() {
      _nameController.text = 'TERRASEN';
      _status = 'deploiement';
      _descriptionController.text =
          'Projet integre agriculture et elevage concu par Enactus ESP pour renforcer l’autonomie alimentaire des menages vulnerables au Senegal. Il articule micro-jardinage sur table, irrigation, transformation agroalimentaire, conservation et distribution.';
      _problemController.text =
          'L’insecurite alimentaire, la dependance aux importations, la rarete des terres cultivables, les variations climatiques et le cout eleve des intrants fragilisent les menages ruraux et periurbains ainsi que les petits producteurs.';
      _solutionController.text =
          'Deployement de micro-jardins sur table, systeme goutte-a-goutte, arrosage automatise ESP32, transformation de produits locaux (sirop de menthe, jus betterave-carotte, the de bissap, confiture, sauce verte, conserves), conservation par sechage solaire/sacs thermiques et distribution ciblee.';
      _objectivesController.text =
          'Former les beneficiaires, transferer des technologies simples, produire localement, reduire les pertes post-recolte, creer de la valeur economique et structurer une chaine production-transformation-conservation-distribution reproductible.';
      _impactController.text =
          'Cibles documentees: GIE Anddeu takku ligueye a Yeumbeul (10 a 15 personnes), GIE Waar wi a Passy (35 personnes dont 20 femmes), Khaffe, Ngayenne Sabakh, Passy, vendeuses de legumes, personnels du COUD et etudiants UCAD. ODD: 8, 11, 12, 13 et 15.';
      _budgetController.text = '1406820';
      _startedAt = DateTime(2024, 8);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fiche TERRASEN pre-remplie depuis le document projet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Créer un projet',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _prefillTerrasenFromDocument,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Préremplir TERRASEN'),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du projet',
                      prefixIcon: Icon(Icons.rocket_launch_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      prefixIcon: Icon(Icons.timeline_rounded),
                    ),
                    items: _statusItems(includeAll: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _problemController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Problématique',
                      prefixIcon: Icon(Icons.report_problem_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _solutionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Solution',
                      prefixIcon: Icon(Icons.lightbulb_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _objectivesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Objectifs',
                      prefixIcon: Icon(Icons.flag_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _impactController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Impact attendu',
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget estimé',
                      prefixIcon: Icon(Icons.payments_rounded),
                      suffixText: 'FCFA',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(start: true),
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          _startedAt == null
                              ? 'Début'
                              : DateFormat('dd/MM/yyyy').format(_startedAt!),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(start: false),
                        icon: const Icon(Icons.event_available_rounded),
                        label: Text(
                          _endedAt == null
                              ? 'Fin'
                              : DateFormat('dd/MM/yyyy').format(_endedAt!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Créer le projet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement des projets',
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

class _EmptyProjectsCard extends StatelessWidget {
  const _EmptyProjectsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Text(
            'Aucun projet ne correspond aux filtres actuels.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> _statusItems({required bool includeAll}) {
  return [
    if (includeAll) const DropdownMenuItem(value: 'all', child: Text('Tous')),
    const DropdownMenuItem(value: 'idee', child: Text('Idée')),
    const DropdownMenuItem(value: 'etude', child: Text('Étude')),
    const DropdownMenuItem(value: 'prototype', child: Text('Prototype')),
    const DropdownMenuItem(value: 'test', child: Text('Test')),
    const DropdownMenuItem(value: 'deploiement', child: Text('Déploiement')),
    const DropdownMenuItem(value: 'termine', child: Text('Terminé')),
    const DropdownMenuItem(value: 'suspendu', child: Text('Suspendu')),
  ];
}

Color _statusColor(String status) {
  switch (status) {
    case 'termine':
      return Colors.green.shade700;
    case 'suspendu':
      return Colors.red.shade700;
    case 'deploiement':
      return Colors.blue.shade700;
    case 'test':
      return Colors.deepPurple.shade600;
    case 'prototype':
      return Colors.orange.shade800;
    default:
      return AppTheme.softBlack;
  }
}

String _safeText(String? value, {required String fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return value.trim();
}

int _projectReadinessScore(ProjectModel project) {
  var score = project.progress;

  if ((project.problemStatement ?? '').trim().length >= 40) score += 10;
  if ((project.solution ?? '').trim().length >= 40) score += 10;
  if ((project.objectives ?? '').trim().length >= 40) score += 10;
  if ((project.expectedImpact ?? '').trim().length >= 40) score += 10;
  if (project.budgetEstimated > 0) score += 10;
  if (project.startedAt != null) score += 5;
  if (project.endedAt != null) score += 5;

  return score.clamp(0, 100);
}

bool _isTerrasenProject(ProjectModel project) {
  return project.name.trim().toLowerCase().contains('terrasen');
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
