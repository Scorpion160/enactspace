import 'package:flutter/material.dart';

import '../../../core/widgets/app_form_dialog.dart';

import '../../members/models/member_model.dart';
import '../models/task_center_models.dart';
import '../models/task_model.dart';
import '../services/tasks_gateway.dart';

class TaskFormDialog extends StatefulWidget {
  final TasksGateway gateway;
  final TaskCenterData? centerData;
  final TaskModel? task;

  const TaskFormDialog.create({
    super.key,
    required this.gateway,
    required TaskCenterData data,
  }) : centerData = data,
       task = null;

  const TaskFormDialog.edit({
    super.key,
    required this.gateway,
    required this.task,
  }) : centerData = null;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _proofUrl;
  final TextEditingController _deadlineReason = TextEditingController();
  final TextEditingController _assigneeSearch = TextEditingController();
  late String _priority;
  late String _status;
  DateTime? _dueDate;
  late bool _proofRequired;
  String? _poleId;
  String? _projectId;
  final Set<String> _assigneeIds = {};
  List<MemberModel> _eligibleMembers = const [];
  bool _loadingScope = false;
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.task != null;

  List<MemberModel> get _visibleEligibleMembers {
    final query = _assigneeSearch.text.trim().toLowerCase();
    final members = _eligibleMembers.where((member) {
      return query.isEmpty ||
          member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.departmentLabel.toLowerCase().contains(query);
    }).toList();
    members.sort(MemberModel.compareAlphabetically);
    return members;
  }

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _proofUrl = TextEditingController(text: task?.proofUrl ?? '');
    _priority = task?.priority ?? 'normale';
    _status = task?.status ?? 'a_faire';
    _dueDate = task?.dueAt;
    _proofRequired = task?.proofRequired ?? false;
    final data = widget.centerData;
    _eligibleMembers = data?.requiresManagedScope == true
        ? const []
        : (data?.members ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _proofUrl.dispose();
    _deadlineReason.dispose();
    _assigneeSearch.dispose();
    super.dispose();
  }

  Future<void> _selectScope({String? poleId, String? projectId}) async {
    _assigneeSearch.clear();
    setState(() {
      _poleId = poleId;
      _projectId = projectId;
      _assigneeIds.clear();
      _loadingScope = poleId != null || projectId != null;
      _eligibleMembers = _loadingScope
          ? const []
          : widget.centerData?.members ?? const [];
      _error = null;
    });
    if (!_loadingScope) return;
    try {
      final members = poleId != null
          ? await widget.gateway.membersForPole(poleId)
          : await widget.gateway.membersForProject(projectId!);
      if (mounted) setState(() => _eligibleMembers = members);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loadingScope = false);
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (value != null && mounted) setState(() => _dueDate = value);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final data = widget.centerData;
    if (!_editing &&
        data?.requiresManagedScope == true &&
        _poleId == null &&
        _projectId == null) {
      setState(
        () => _error = 'Sélectionnez le pôle ou projet que vous dirigez.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_editing) {
        await widget.gateway.updateTask(
          widget.task!.id,
          TaskUpdateInput(
            title: _title.text,
            description: _description.text,
            priority: _priority,
            status: _status,
            dueDate: _dueDate,
            deadlineChangeReason: _dueDate != widget.task!.dueAt
                ? _deadlineReason.text
                : null,
            proofRequired: _proofRequired,
            proofUrl: _proofUrl.text.trim().isEmpty ? null : _proofUrl.text,
          ),
        );
      } else {
        await widget.gateway.createTask(
          TaskCreateInput(
            title: _title.text,
            description: _description.text,
            priority: _priority,
            dueDate: _dueDate,
            proofRequired: _proofRequired,
            assigneeIds: _assigneeIds.toList(),
            poleId: _poleId,
            projectId: _projectId,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.centerData;
    return AppFormDialog(
      icon: Icons.task_alt_rounded,
      description: 'Précisez le résultat attendu et les personnes concernées.',
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: Text(_editing ? 'Modifier la tâche' : 'Créer une tâche'),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width.clamp(280, 620).toDouble(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    key: const Key('task-form-error'),
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const Key('task-title'),
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'Le titre est obligatoire.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnelle)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priorité'),
                  items: const [
                    DropdownMenuItem(value: 'basse', child: Text('Basse')),
                    DropdownMenuItem(value: 'normale', child: Text('Normale')),
                    DropdownMenuItem(value: 'haute', child: Text('Haute')),
                    DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _priority = value ?? _priority),
                ),
                if (_editing) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      DropdownMenuItem(
                        value: 'a_faire',
                        child: Text('À faire'),
                      ),
                      DropdownMenuItem(
                        value: 'en_cours',
                        child: Text('En cours'),
                      ),
                      DropdownMenuItem(value: 'bloque', child: Text('Bloqué')),
                      DropdownMenuItem(
                        value: 'termine',
                        child: Text('Terminé'),
                      ),
                      if (!widget.task!.currentUserAssigned)
                        const DropdownMenuItem(
                          value: 'valide',
                          child: Text('Validé'),
                        ),
                      DropdownMenuItem(value: 'annule', child: Text('Annulé')),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _status = value ?? _status),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    _dueDate == null ? 'Sans échéance' : _formatDate(_dueDate!),
                  ),
                ),
                if (_editing && _dueDate != widget.task!.dueAt) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deadlineReason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Pourquoi ajuster cette échéance ?',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 6
                        ? 'Expliquez le changement d’échéance.'
                        : null,
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _proofRequired,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _proofRequired = value),
                  title: const Text('Preuve requise'),
                ),
                if (_editing)
                  const Text(
                    'Joignez le justificatif depuis le suivi de la tâche.',
                    style: TextStyle(height: 1.5),
                  ),
                if (!_editing && data != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _poleId,
                    decoration: const InputDecoration(
                      labelText: 'Pôle (optionnel)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Aucun pôle'),
                      ),
                      ...data.poles.map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => _selectScope(poleId: value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    decoration: const InputDecoration(
                      labelText: 'Projet (optionnel)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Aucun projet'),
                      ),
                      ...data.projects.map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (value) => _selectScope(projectId: value),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Assignés',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (_loadingScope)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_eligibleMembers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Aucun membre disponible pour ce périmètre.'),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _assigneeSearch,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'Rechercher un Enacteur',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_visibleEligibleMembers.isEmpty)
                      const Text('Aucun Enacteur ne correspond à la recherche.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _visibleEligibleMembers
                            .map(
                              (member) => FilterChip(
                                label: Text(member.displayName),
                                selected: _assigneeIds.contains(member.id),
                                onSelected: _submitting
                                    ? null
                                    : (selected) => setState(
                                        () => selected
                                            ? _assigneeIds.add(member.id)
                                            : _assigneeIds.remove(member.id),
                                      ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('task-form-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
