import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/task_center_models.dart';
import '../models/task_model.dart';
import '../services/tasks_gateway.dart';
import '../widgets/task_filters.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/task_list.dart';

class TasksScreen extends StatefulWidget {
  final TasksGateway? gateway;
  final TaskCenterView initialView;
  final DateTime Function()? clock;

  const TasksScreen({
    super.key,
    this.gateway,
    this.initialView = TaskCenterView.all,
    this.clock,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TasksGateway _gateway;
  late TaskCenterView _view;
  final _search = TextEditingController();
  TaskCenterData? _data;
  bool _loading = true;
  String? _error;
  String _status = 'all';
  String _priority = 'all';
  String? _poleId;
  String? _projectId;
  String? _assigneeId;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiTasksGateway();
    _view = widget.initialView;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _gateway.loadCenter(_view);
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskModel> get _visibleTasks {
    final data = _data;
    if (data == null) return const [];
    final query = _search.text.trim().toLowerCase();
    return data.tasks.where((task) {
      final assignees = data.assigneesByTaskId[task.id] ?? const [];
      final names = assignees
          .map((item) => data.member(item.userId)?.displayName ?? '')
          .join(' ');
      final searchable = [
        task.title,
        task.description ?? '',
        task.statusLabel,
        task.priorityLabel,
        names,
      ].join(' ').toLowerCase();
      return (query.isEmpty || searchable.contains(query)) &&
          (_status == 'all' || task.status == _status) &&
          (_priority == 'all' || task.priority == _priority) &&
          (_poleId == null || task.poleId == _poleId) &&
          (_projectId == null || task.projectId == _projectId) &&
          (_assigneeId == null ||
              assignees.any((item) => item.userId == _assigneeId)) &&
          (_view != TaskCenterView.mine || task.currentUserAssigned) &&
          (_view != TaskCenterView.late || task.isLateAt(_now));
    }).toList()..sort((a, b) {
      final lateCompare = (b.isLateAt(_now) ? 1 : 0).compareTo(
        a.isLateAt(_now) ? 1 : 0,
      );
      if (lateCompare != 0) return lateCompare;
      return (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999));
    });
  }

  void _reset() {
    _search.clear();
    setState(() {
      _status = 'all';
      _priority = 'all';
      _poleId = null;
      _projectId = null;
      _assigneeId = null;
    });
  }

  Future<void> _create() async {
    final data = _data;
    if (data == null) return;
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskFormDialog.create(gateway: _gateway, data: data),
    );
    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tâche créée avec succès.')),
        );
      }
    }
  }

  void _open(TaskModel task) =>
      context.go('/tasks/${task.id}', extra: _gateway);

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < 560 ? 14.0 : 24.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        canCreate: data?.canCreate == true,
                        onCreate: _create,
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<TaskCenterView>(
                        key: const Key('tasks-views'),
                        segments: TaskCenterView.values
                            .map(
                              (view) => ButtonSegment(
                                value: view,
                                label: Text(view.label),
                              ),
                            )
                            .toList(),
                        selected: {_view},
                        showSelectedIcon: false,
                        onSelectionChanged: _loading
                            ? null
                            : (values) {
                                setState(() => _view = values.first);
                                _load();
                              },
                      ),
                      const SizedBox(height: 14),
                      if (data != null)
                        TaskFiltersBar(
                          searchController: _search,
                          status: _status,
                          priority: _priority,
                          poleId: _poleId,
                          projectId: _projectId,
                          assigneeId: _assigneeId,
                          poles: data.poles,
                          projects: data.projects,
                          members: data.members,
                          onStatusChanged: (value) =>
                              setState(() => _status = value),
                          onPriorityChanged: (value) =>
                              setState(() => _priority = value),
                          onPoleChanged: (value) =>
                              setState(() => _poleId = value),
                          onProjectChanged: (value) =>
                              setState(() => _projectId = value),
                          onAssigneeChanged: (value) =>
                              setState(() => _assigneeId = value),
                          onSearchChanged: () => setState(() {}),
                          onReset: _reset,
                        ),
                      const SizedBox(height: 14),
                      if (_loading)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(42),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (_error != null)
                        _ErrorState(message: _error!, onRetry: _load)
                      else if (data != null) ...[
                        Text(
                          '${_visibleTasks.length} tâche(s)',
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TaskCenterList(
                          tasks: _visibleTasks,
                          data: data,
                          now: _now,
                          onOpen: _open,
                        ),
                      ],
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

class _Header extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onCreate;
  const _Header({required this.canCreate, required this.onCreate});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centre de tâches',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 5),
              Text(
                'Priorisez, filtrez et ouvrez chaque tâche sans perdre le contexte.',
                style: TextStyle(color: AppTheme.secondaryText),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                if (canCreate) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Créer une tâche'),
                  ),
                ],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              if (canCreate)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Créer une tâche'),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
