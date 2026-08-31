import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/task_center_models.dart';
import '../models/task_model.dart';
import '../services/tasks_gateway.dart';
import '../widgets/task_form_dialog.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final TasksGateway? gateway;

  const TaskDetailScreen({super.key, required this.taskId, this.gateway});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TasksGateway _gateway;
  TaskDetailData? _data;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiTasksGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _gateway.loadDetail(widget.taskId);
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<TaskModel> Function() action, String success) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(_message(error)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeStatus(TaskModel task) async {
    var selected = task.status;
    final status = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Changer le statut'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: const [
              DropdownMenuItem(value: 'a_faire', child: Text('À faire')),
              DropdownMenuItem(value: 'en_cours', child: Text('En cours')),
              DropdownMenuItem(value: 'bloque', child: Text('Bloqué')),
              DropdownMenuItem(value: 'termine', child: Text('Terminé')),
              DropdownMenuItem(value: 'valide', child: Text('Validé')),
              DropdownMenuItem(value: 'annule', child: Text('Annulé')),
            ],
            onChanged: (value) =>
                setDialogState(() => selected = value ?? selected),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (status != null && status != task.status) {
      await _run(
        () => _gateway.changeStatus(task.id, status),
        'Statut mis à jour.',
      );
    }
  }

  Future<void> _proof(TaskModel task) async {
    final controller = TextEditingController(text: task.proofUrl ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soumettre une preuve'),
        content: TextField(
          key: const Key('task-proof-url'),
          controller: controller,
          decoration: const InputDecoration(labelText: 'Lien de preuve'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value?.isNotEmpty == true) {
      await _run(
        () => _gateway.submitProof(task.id, value!),
        'Preuve enregistrée.',
      );
    }
  }

  Future<void> _edit(TaskModel task) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskFormDialog.edit(gateway: _gateway, task: task),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 560 ? 14.0 : 24.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(padding, 18, padding, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('/tasks'),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Centre de tâches'),
                      ),
                    ),
                    if (_loading)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(42),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_error != null)
                      _DetailError(message: _error!, onRetry: _load)
                    else if (_data != null)
                      _TaskDetailBody(
                        data: _data!,
                        submitting: _submitting,
                        onStatus: _changeStatus,
                        onProof: _proof,
                        onEdit: _edit,
                        onValidate: (task) => _run(
                          () => _gateway.validateTask(task.id),
                          'Tâche validée.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskDetailBody extends StatelessWidget {
  final TaskDetailData data;
  final bool submitting;
  final ValueChanged<TaskModel> onStatus;
  final ValueChanged<TaskModel> onProof;
  final ValueChanged<TaskModel> onEdit;
  final ValueChanged<TaskModel> onValidate;

  const _TaskDetailBody({
    required this.data,
    required this.submitting,
    required this.onStatus,
    required this.onProof,
    required this.onEdit,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    final task = data.task;
    final assigneeNames = data.assignees.map((item) {
      for (final member in data.members) {
        if (member.id == item.userId) return member.displayName;
      }
      return 'Membre';
    }).toList();
    final technicalDates = <String>[
      if (task.createdAt != null) 'Créée le ${_dateTime(task.createdAt!)}',
      if (task.updatedAt != null)
        'Mise à jour le ${_dateTime(task.updatedAt!)}',
      if (task.completedAt != null)
        'Terminée le ${_dateTime(task.completedAt!)}',
      if (task.validatedAt != null)
        'Validée le ${_dateTime(task.validatedAt!)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  task.description?.trim().isNotEmpty == true
                      ? task.description!
                      : 'Aucune description.',
                  style: const TextStyle(
                    color: AppTheme.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(task.statusLabel)),
                    Chip(label: Text(task.priorityLabel)),
                    Chip(label: Text(task.dueDateLabel)),
                    if (task.isLateAt(DateTime.now()))
                      const Chip(
                        avatar: Icon(Icons.warning_rounded, color: Colors.red),
                        label: Text('En retard'),
                      ),
                  ],
                ),
                if (task.canManage || task.currentUserAssigned) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: submitting ? null : () => onStatus(task),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Changer le statut'),
                      ),
                      OutlinedButton.icon(
                        onPressed: submitting ? null : () => onProof(task),
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Preuve'),
                      ),
                      if (task.canManage)
                        OutlinedButton.icon(
                          onPressed: submitting ? null : () => onEdit(task),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Modifier'),
                        ),
                      if (task.canManage)
                        FilledButton.icon(
                          onPressed: submitting || task.status != 'termine'
                              ? null
                              : () => onValidate(task),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Valider'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Assignés',
          icon: Icons.people_alt_rounded,
          child: data.assigneesUnavailable
              ? const Text('Assignés indisponibles pour le moment.')
              : Text(
                  assigneeNames.isEmpty
                      ? 'Aucun assigné.'
                      : assigneeNames.join(', '),
                ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Périmètre',
          icon: Icons.account_tree_rounded,
          child: Text(
            [
                  if (data.pole != null) 'Pôle : ${data.pole!.name}',
                  if (data.project != null) 'Projet : ${data.project!.name}',
                ].isEmpty
                ? 'Aucun pôle ou projet rattaché.'
                : [
                    if (data.pole != null) 'Pôle : ${data.pole!.name}',
                    if (data.project != null) 'Projet : ${data.project!.name}',
                  ].join('\n'),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Preuve',
          icon: Icons.link_rounded,
          child: Text(
            task.proofUrl?.trim().isNotEmpty == true
                ? task.proofUrl!
                : (task.proofRequired
                      ? 'Preuve requise, non fournie.'
                      : 'Aucune preuve requise.'),
          ),
        ),
        if (technicalDates.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            title: 'Historique technique',
            icon: Icons.history_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: technicalDates.map(Text.new).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DetailError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

String _dateTime(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
