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
                        _ProjectsGrid(projects: _filteredProjects),
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

  const _ProjectsGrid({required this.projects});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: projects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count == 1 ? 1.24 : 0.94,
          ),
          itemBuilder: (context, index) {
            return _ProjectCard(project: projects[index]);
          },
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;

  const _ProjectCard({required this.project});

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
            const Spacer(),
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
