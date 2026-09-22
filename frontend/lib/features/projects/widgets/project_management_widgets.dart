import 'package:flutter/material.dart';

import '../models/project_management_models.dart';
import '../models/project_model.dart';
import '../models/project_portfolio_models.dart';

class ProjectManagementSection extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onChangeStatus;

  const ProjectManagementSection({
    super.key,
    required this.onEdit,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Gestion du projet',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Gestion du projet',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier le projet'),
          ),
          FilledButton.tonalIcon(
            onPressed: onChangeStatus,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Changer le statut'),
          ),
        ],
      ),
    ),
  );
}

class ProjectFormDialog extends StatefulWidget {
  final ProjectModel? project;
  final List<ProjectSeasonOption> seasons;
  final Future<ProjectModel> Function(ProjectMutationDraft draft) onSubmit;

  const ProjectFormDialog({
    super.key,
    required this.project,
    required this.seasons,
    required this.onSubmit,
  });

  bool get isEditing => project != null;

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _problem;
  late final TextEditingController _solution;
  late final TextEditingController _objectives;
  late final TextEditingController _impact;
  late final TextEditingController _budget;
  late final TextEditingController _start;
  late final TextEditingController _end;
  String? _seasonId;
  late String _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _name = TextEditingController(text: project?.name ?? '');
    _description = TextEditingController(text: project?.description ?? '');
    _problem = TextEditingController(text: project?.problemStatement ?? '');
    _solution = TextEditingController(text: project?.solution ?? '');
    _objectives = TextEditingController(text: project?.objectives ?? '');
    _impact = TextEditingController(text: project?.expectedImpact ?? '');
    _budget = TextEditingController(
      text: project == null ? '0' : _number(project.budgetEstimated),
    );
    _start = TextEditingController(text: _date(project?.startedAt));
    _end = TextEditingController(text: _date(project?.endedAt));
    _seasonId = project?.seasonId;
    _status = project?.status ?? 'idee';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _problem,
      _solution,
      _objectives,
      _impact,
      _budget,
      _start,
      _end,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isEditing
                          ? 'Modifier le projet'
                          : 'Nouveau projet',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  key: const Key('project-form-scroll'),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const _FormSectionTitle('Informations principales'),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nom *'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Le nom est requis.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    const _FormSectionTitle('Cadrage'),
                    _LongField(controller: _problem, label: 'Problème'),
                    _LongField(controller: _solution, label: 'Solution'),
                    _LongField(controller: _objectives, label: 'Objectifs'),
                    _LongField(controller: _impact, label: 'Impact attendu'),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        final fields = [
                          TextFormField(
                            controller: _budget,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Budget estimé',
                            ),
                            validator: (value) => _parseNumber(value) == null
                                ? 'Saisissez un budget numérique valide.'
                                : null,
                          ),
                          DropdownButtonFormField<String?>(
                            initialValue:
                                widget.seasons.any(
                                  (season) => season.id == _seasonId,
                                )
                                ? _seasonId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Saison',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Aucune saison'),
                              ),
                              ...widget.seasons.map(
                                (season) => DropdownMenuItem<String?>(
                                  value: season.id,
                                  child: Text(
                                    '${season.name}${season.isCurrent ? ' · Actuelle' : ''}',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => _seasonId = value,
                          ),
                        ];
                        if (compact) {
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 12),
                              fields[1],
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!widget.isEditing)
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Statut initial',
                        ),
                        items: ProjectStatusPresentation.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(
                                  ProjectStatusPresentation.label(status),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _status = value!),
                      ),
                    const SizedBox(height: 18),
                    const _FormSectionTitle('Calendrier'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _start,
                            decoration: const InputDecoration(
                              labelText: 'Date de début',
                              hintText: 'JJ/MM/AAAA',
                            ),
                            validator: _dateValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _end,
                            decoration: const InputDecoration(
                              labelText: 'Date de fin',
                              hintText: 'JJ/MM/AAAA',
                            ),
                            validator: (value) {
                              final invalid = _dateValidator(value);
                              if (invalid != null) return invalid;
                              final start = _parseDate(_start.text);
                              final end = _parseDate(value ?? '');
                              if (start != null &&
                                  end != null &&
                                  end.isBefore(start)) {
                                return 'La fin doit être postérieure ou égale au début.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _InlineError(message: _error!),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _error != null
                                ? 'Réessayer'
                                : widget.isEditing
                                ? 'Enregistrer les modifications'
                                : 'Créer le projet',
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

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (!ProjectStatusPresentation.values.contains(_status)) {
      setState(() => _error = 'Le statut sélectionné est invalide.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(
        ProjectMutationDraft(
          seasonId: _seasonId,
          name: _name.text,
          description: _description.text,
          problemStatement: _problem.text,
          solution: _solution.text,
          objectives: _objectives.text,
          expectedImpact: _impact.text,
          budgetEstimated: _parseNumber(_budget.text)!,
          status: _status,
          startedAt: _parseDate(_start.text),
          endedAt: _parseDate(_end.text),
        ),
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = _humanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class ProjectStatusDialog extends StatefulWidget {
  final ProjectPortfolioItem item;
  final Future<ProjectModel> Function(String targetStatus) onSubmit;

  const ProjectStatusDialog({
    super.key,
    required this.item,
    required this.onSubmit,
  });

  @override
  State<ProjectStatusDialog> createState() => _ProjectStatusDialogState();
}

class _ProjectStatusDialogState extends State<ProjectStatusDialog> {
  String? _target;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final project = widget.item.project;
    final target = _target;
    return AlertDialog(
      title: Text(_title(target)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('project-status-target'),
                initialValue: target,
                decoration: const InputDecoration(labelText: 'Nouveau statut'),
                items: ProjectStatusPresentation.values
                    .where((status) => status != project.status)
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(ProjectStatusPresentation.label(status)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _target = value;
                        _error = null;
                      }),
              ),
              if (target != null) ...[
                const SizedBox(height: 18),
                ProjectStatusChangeSummary(
                  item: widget.item,
                  targetStatus: target,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _InlineError(message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: target == null || _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_error != null ? 'Réessayer' : _confirmLabel(target)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    final target = _target;
    if (target == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.onSubmit(target);
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (mounted) setState(() => _error = _humanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _title(String? target) => switch (target) {
    'termine' => 'Marquer ce projet comme terminé ?',
    'suspendu' => 'Suspendre ce projet ?',
    _ => 'Mettre à jour le statut du projet',
  };

  String _confirmLabel(String? target) => switch (target) {
    'termine' => 'Marquer comme terminé',
    'suspendu' => 'Suspendre le projet',
    _ => 'Confirmer',
  };
}

class ProjectStatusChangeSummary extends StatelessWidget {
  final ProjectPortfolioItem item;
  final String targetStatus;

  const ProjectStatusChangeSummary({
    super.key,
    required this.item,
    required this.targetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    final tasks = item.tasks ?? const [];
    final nonTerminal = tasks
        .where((task) => !ProjectTaskPresentation.isTerminal(task.status))
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${ProjectStatusPresentation.label(project.status)} → ${ProjectStatusPresentation.label(targetStatus)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(_explanation(targetStatus)),
            if (targetStatus == 'termine') ...[
              const SizedBox(height: 10),
              Text('$nonTerminal tâche(s) encore non terminale(s).'),
              Text(
                '${item.alerts.blockedCount} bloquée(s) · ${item.alerts.overdueCount} en retard.',
              ),
              const Text(
                'Ces éléments sont informatifs et ne bloquent pas la transition.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _explanation(String target) => switch (target) {
    'termine' =>
      'Le projet sera marqué comme terminé. Aucune tâche ne sera modifiée automatiquement.',
    'suspendu' => 'Le projet restera consultable pendant sa suspension.',
    _ => 'Le nouveau statut sera appliqué après votre confirmation.',
  };
}

class _FormSectionTitle extends StatelessWidget {
  final String text;
  const _FormSectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class _LongField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _LongField({required this.controller, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      maxLines: 2,
    ),
  );
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: const Text('La demande n’a pas abouti'),
        subtitle: Text(message),
      ),
    ),
  );
}

String _humanError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty
      ? 'Une erreur est survenue. Vous pouvez réessayer.'
      : text;
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

double? _parseNumber(String? value) => double.tryParse(
  (value ?? '').trim().replaceAll(' ', '').replaceAll(',', '.'),
);

String? _dateValidator(String? value) {
  if ((value ?? '').trim().isEmpty) return null;
  return _parseDate(value!) == null ? 'Utilisez le format JJ/MM/AAAA.' : null;
}

DateTime? _parseDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String _date(DateTime? value) {
  if (value == null) return '';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
