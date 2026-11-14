import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_service.dart';
import '../../../shared/ui/app_components.dart';
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
  final String? initialPoleId, initialProjectId;

  const TasksScreen({
    super.key,
    this.gateway,
    this.initialView = TaskCenterView.all,
    this.clock,
    this.initialPoleId,
    this.initialProjectId,
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
  late final Future<String?> _layoutPreference;
  bool _kanban = false;
  bool _layoutChanged = false;
  int _loadRevision = 0;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiTasksGateway();
    _poleId = widget.initialPoleId;
    _projectId = widget.initialProjectId;
    _view = widget.initialView;
    _layoutPreference = widget.gateway == null
        ? _layoutPreferenceKey()
        : Future.value(null);
    _restoreLayout();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _gateway.loadCenter(_view);
      if (mounted && revision == _loadRevision) setState(() => _data = data);
    } catch (error) {
      if (mounted && revision == _loadRevision) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _layoutPreferenceKey() async {
    final user = await AuthService().getCachedCurrentUser();
    final id = user?['id']?.toString();
    return id == null || id.isEmpty ? null : 'tasks.kanban.$id';
  }

  Future<void> _restoreLayout() async {
    try {
      final key = await _layoutPreference;
      if (key == null) return;
      final preferences = await SharedPreferences.getInstance();
      if (mounted && !_layoutChanged && preferences.getBool(key) == true) {
        setState(() => _kanban = true);
      }
    } catch (_) {
      // The list is available even when local preferences are unavailable.
    }
  }

  Future<void> _selectLayout(bool kanban) async {
    setState(() {
      _layoutChanged = true;
      _kanban = kanban;
    });
    try {
      final key = await _layoutPreference;
      if (key == null) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, _kanban);
    } catch (_) {
      // Keep the selected layout for this visit.
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

  Future<void> _open(TaskModel task) async {
    await context.push<void>('/tasks/${task.id}', extra: _gateway);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final tasks = _visibleTasks;
    return Material(
      type: MaterialType.transparency,
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 560 ? 14.0 : 24.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        Wrap(
                          key: const Key('tasks-views'),
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final view in TaskCenterView.values)
                              ChoiceChip(
                                label: Text(view.label),
                                selected: _view == view,
                                onSelected: _loading
                                    ? null
                                    : (selected) {
                                        if (!selected) return;
                                        setState(() => _view = view);
                                        _load();
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (data != null) ...[
                          Wrap(
                            key: const Key('tasks-layout'),
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ChoiceChip(
                                avatar: const Icon(Icons.view_list_rounded),
                                label: const Text('Liste'),
                                selected: !_kanban,
                                onSelected: (_) => _selectLayout(false),
                              ),
                              ChoiceChip(
                                avatar: const Icon(Icons.view_kanban_rounded),
                                label: const Text('Kanban'),
                                selected: _kanban,
                                onSelected: (_) => _selectLayout(true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                        ],
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
                            '${tasks.length} ${tasks.length == 1 ? 'tâche' : 'tâches'}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          if (_kanban)
                            TaskBoard(
                              tasks: tasks,
                              data: data,
                              now: _now,
                              onOpen: _open,
                            )
                          else
                            TaskCenterList(
                              tasks: tasks,
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onCreate;
  const _Header({required this.canCreate, required this.onCreate});

  @override
  Widget build(BuildContext context) => AppModuleHeader(
    title: 'Centre de tâches',
    subtitle: 'Retrouvez les tâches de l’équipe et suivez leur avancement.',
    icon: Icons.task_alt_rounded,
    actions: [
      if (canCreate)
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('Créer une tâche'),
        ),
    ],
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
            label: Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
