import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/task_model.dart';
import '../services/tasks_service.dart';
import '../models/task_assignee_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TasksService _tasksService = TasksService();
  final MembersService _membersService = MembersService();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<TaskModel> _tasks = [];
  List<MemberModel> _members = [];
  List<PoleModel> _poles = [];
  List<ProjectModel> _projects = [];
  Map<String, List<TaskAssigneeModel>> _assigneesByTaskId = {};
  UserExperience? _userExperience;
  String _selectedView = 'all';
  String _priorityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = UserExperience.fromJson(await _authService.getCurrentUser());
      final Future<List<TaskModel>> tasksFuture;

      if (_selectedView == 'my') {
        tasksFuture = _tasksService.getMyTasks();
      } else if (_selectedView == 'late') {
        tasksFuture = _tasksService.getLateTasks();
      } else {
        tasksFuture = _tasksService.getTasks();
      }

      final results = await Future.wait([
        tasksFuture,
        _membersService.getMembers(),
        _polesService.getPoles(),
        _projectsService.getProjects(),
      ]);

      final tasks = results[0] as List<TaskModel>;
      final members = results[1] as List<MemberModel>;
      final poles = results[2] as List<PoleModel>;
      final projects = results[3] as List<ProjectModel>;

      final Map<String, List<TaskAssigneeModel>> assigneesMap = {};

      for (final task in tasks) {
        try {
          final assignees = await _tasksService.getTaskAssignees(task.id);
          assigneesMap[task.id] = assignees;
        } catch (_) {
          assigneesMap[task.id] = [];
        }
      }

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _members = members;
        _poles = poles;
        _projects = projects;
        _assigneesByTaskId = assigneesMap;
        _userExperience = user;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreateTaskDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final user = _userExperience;
        return CreateTaskDialog(
          tasksService: _tasksService,
          members: _members,
          poles: _poles,
          projects: _projects,
          requiresScope:
              user?.isProjectOrPoleLead == true &&
              user?.isAdmin != true &&
              user?.isTeamLeader != true &&
              user?.isSecretary != true,
        );
      },
    );

    if (created == true) {
      await _loadTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tâche créée avec succès.')));
    }
  }

  Future<void> _changeStatus(TaskModel task, String status) async {
    try {
      await _tasksService.changeStatus(taskId: task.id, status: status);
      await _loadTasks();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour : ${task.title}.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _submitProof(TaskModel task) async {
    final controller = TextEditingController(text: task.proofUrl ?? '');

    final proofUrl = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Soumettre une preuve'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Lien de preuve',
              hintText: 'https://...',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (proofUrl == null || proofUrl.isEmpty) return;

    try {
      await _tasksService.submitProof(taskId: task.id, proofUrl: proofUrl);
      await _loadTasks();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preuve enregistrée.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _validateTask(TaskModel task) async {
    try {
      await _tasksService.validateTask(task.id);
      await _loadTasks();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tâche validée : ${task.title}.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  List<TaskModel> _tasksByStatus(String status) {
    return _visibleTasks.where((task) => task.status == status).toList();
  }

  List<TaskModel> get _visibleTasks {
    final query = _searchController.text.trim().toLowerCase();

    return _tasks.where((task) {
      final assignees = _assigneesByTaskId[task.id] ?? [];
      final assigneeNames = assignees
          .map((assignee) {
            return _members
                .where((member) => member.id == assignee.userId)
                .map((member) => member.displayName)
                .join(' ');
          })
          .join(' ');
      final searchable = [
        task.title,
        task.description ?? '',
        task.priorityLabel,
        task.statusLabel,
        task.dueDateLabel,
        assigneeNames,
      ].join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || searchable.contains(query);
      final matchesPriority =
          _priorityFilter == 'all' || task.priority == _priorityFilter;

      return matchesQuery && matchesPriority;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canManageTasks = _userExperience?.canCreateTasks == true;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _TasksHeader(
            total: _visibleTasks.length,
            todo: _tasksByStatus('a_faire').length,
            doing: _tasksByStatus('en_cours').length,
            done: _tasksByStatus('termine').length,
            validated: _tasksByStatus('valide').length,
            onRefresh: _loadTasks,
            onCreate: canManageTasks ? _openCreateTaskDialog : null,
          ),
          const SizedBox(height: 18),
          _TaskViewFilters(
            selectedView: _selectedView,
            onChanged: (value) async {
              setState(() {
                _selectedView = value;
              });

              await _loadTasks();
            },
          ),
          const SizedBox(height: 18),
          _TaskSearchFilters(
            controller: _searchController,
            priorityFilter: _priorityFilter,
            onChanged: () => setState(() {}),
            onPriorityChanged: (value) {
              setState(() => _priorityFilter = value);
            },
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _loadTasks)
          else
            _KanbanBoard(
              todo: _tasksByStatus('a_faire'),
              doing: _tasksByStatus('en_cours'),
              done: _tasksByStatus('termine'),
              validated: _tasksByStatus('valide'),
              members: _members,
              assigneesByTaskId: _assigneesByTaskId,
              onChangeStatus: _changeStatus,
              onSubmitProof: _submitProof,
              onValidate: _validateTask,
            ),
        ],
      ),
    );
  }
}

class _TasksHeader extends StatelessWidget {
  final int total;
  final int todo;
  final int doing;
  final int done;
  final int validated;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;

  const _TasksHeader({
    required this.total,
    required this.todo,
    required this.doing,
    required this.done,
    required this.validated,
    required this.onRefresh,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        if (onCreate != null)
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer tâche'),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(
                    total: total,
                    todo: todo,
                    doing: doing,
                    done: done,
                    validated: validated,
                  ),
                ),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderIcon(),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _HeaderText(
                        total: total,
                        todo: todo,
                        doing: doing,
                        done: done,
                        validated: validated,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                actions,
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
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
        Icons.task_alt_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int todo;
  final int doing;
  final int done;
  final int validated;

  const _HeaderText({
    required this.total,
    required this.todo,
    required this.doing,
    required this.done,
    required this.validated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tâches',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$total tâche(s) • $todo à faire • $doing en cours • $done terminée(s) • $validated validée(s)',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }
}

class _KanbanBoard extends StatelessWidget {
  final List<TaskModel> todo;
  final List<TaskModel> doing;
  final List<TaskModel> done;
  final List<TaskModel> validated;
  final List<MemberModel> members;
  final Map<String, List<TaskAssigneeModel>> assigneesByTaskId;
  final Future<void> Function(TaskModel task, String status) onChangeStatus;
  final Future<void> Function(TaskModel task) onSubmitProof;
  final Future<void> Function(TaskModel task) onValidate;

  const _KanbanBoard({
    required this.todo,
    required this.doing,
    required this.done,
    required this.validated,
    required this.onChangeStatus,
    required this.onSubmitProof,
    required this.onValidate,
    required this.members,
    required this.assigneesByTaskId,
  });

  @override
  Widget build(BuildContext context) {
    final columns = [
      _KanbanColumnData(title: 'À faire', status: 'a_faire', tasks: todo),
      _KanbanColumnData(title: 'En cours', status: 'en_cours', tasks: doing),
      _KanbanColumnData(title: 'Terminé', status: 'termine', tasks: done),
      _KanbanColumnData(title: 'Validé', status: 'valide', tasks: validated),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth >= 1280
            ? ((constraints.maxWidth - 42) / 4).clamp(310.0, 360.0).toDouble()
            : constraints.maxWidth < 380
            ? (constraints.maxWidth - 24).clamp(260.0, 310.0).toDouble()
            : 310.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns.map((column) {
              return SizedBox(
                width: columnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _KanbanColumn(
                    data: column,
                    members: members,
                    assigneesByTaskId: assigneesByTaskId,
                    onChangeStatus: onChangeStatus,
                    onSubmitProof: onSubmitProof,
                    onValidate: onValidate,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _KanbanColumnData {
  final String title;
  final String status;
  final List<TaskModel> tasks;

  const _KanbanColumnData({
    required this.title,
    required this.status,
    required this.tasks,
  });
}

class _KanbanColumn extends StatelessWidget {
  final _KanbanColumnData data;
  final List<MemberModel> members;
  final Map<String, List<TaskAssigneeModel>> assigneesByTaskId;
  final Future<void> Function(TaskModel task, String status) onChangeStatus;
  final Future<void> Function(TaskModel task) onSubmitProof;
  final Future<void> Function(TaskModel task) onValidate;

  const _KanbanColumn({
    required this.data,
    required this.onChangeStatus,
    required this.onSubmitProof,
    required this.onValidate,
    required this.members,
    required this.assigneesByTaskId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        constraints: const BoxConstraints(minHeight: 420),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                Chip(label: Text(data.tasks.length.toString())),
              ],
            ),
            const SizedBox(height: 10),
            if (data.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Aucune tâche',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...data.tasks.map(
                (task) => _TaskCard(
                  task: task,
                  members: members,
                  assignees: assigneesByTaskId[task.id] ?? [],
                  onChangeStatus: onChangeStatus,
                  onSubmitProof: onSubmitProof,
                  onValidate: onValidate,
                  canManage: task.canManage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final Future<void> Function(TaskModel task, String status) onChangeStatus;
  final Future<void> Function(TaskModel task) onSubmitProof;
  final Future<void> Function(TaskModel task) onValidate;
  final List<MemberModel> members;
  final List<TaskAssigneeModel> assignees;
  final bool canManage;

  const _TaskCard({
    required this.task,
    required this.onChangeStatus,
    required this.onSubmitProof,
    required this.onValidate,
    required this.members,
    required this.assignees,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: const Color(0xFFF9F9F6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (task.description != null && task.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(task.priorityLabel)),
                Chip(label: Text(task.dueDateLabel)),
                if (task.proofRequired)
                  const Chip(label: Text('Preuve requise')),
                const SizedBox(height: 10),
                _TaskAssigneesPreview(members: members, assignees: assignees),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: task.status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'a_faire',
                        child: Text('À faire'),
                      ),
                      const DropdownMenuItem(
                        value: 'en_cours',
                        child: Text('En cours'),
                      ),
                      const DropdownMenuItem(
                        value: 'termine',
                        child: Text('Terminé'),
                      ),
                      if (canManage || task.status == 'valide')
                        const DropdownMenuItem(
                          value: 'valide',
                          child: Text('Validé'),
                        ),
                      const DropdownMenuItem(
                        value: 'bloque',
                        child: Text('Bloqué'),
                      ),
                    ],
                    onChanged: !canManage && task.status == 'valide'
                        ? null
                        : (value) {
                            if (value == null || value == task.status) return;
                            onChangeStatus(task, value);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onSubmitProof(task),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Preuve'),
                ),
                if (canManage)
                  ElevatedButton.icon(
                    onPressed: task.status == 'termine'
                        ? () => onValidate(task)
                        : null,
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Valider'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateTaskDialog extends StatefulWidget {
  final TasksService tasksService;
  final List<MemberModel> members;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final bool requiresScope;

  const CreateTaskDialog({
    super.key,
    required this.tasksService,
    required this.members,
    required this.poles,
    required this.projects,
    required this.requiresScope,
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'normale';
  DateTime? _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _proofRequired = false;
  final Set<String> _assigneeIds = {};
  String? _poleId;
  String? _projectId;
  late List<MemberModel> _eligibleMembers;
  bool _loadingScope = false;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _eligibleMembers = List<MemberModel>.from(widget.members);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() {
      _dueDate = selected;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.requiresScope && _poleId == null && _projectId == null) {
      setState(() {
        _error = 'Sélectionnez le pôle ou projet que vous dirigez.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.tasksService.createTask(
        title: _titleController.text,
        description: _descriptionController.text,
        priority: _priority,
        dueDate: _dueDate,
        proofRequired: _proofRequired,
        assigneeIds: _assigneeIds.toList(),
        poleId: _poleId,
        projectId: _projectId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String get _dueDateLabel {
    if (_dueDate == null) return 'Aucune échéance';

    final d = _dueDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _selectPole(String? poleId) async {
    setState(() {
      _poleId = poleId;
      _projectId = null;
      _assigneeIds.clear();
      _loadingScope = poleId != null;
      _eligibleMembers = poleId == null
          ? List<MemberModel>.from(widget.members)
          : [];
    });
    if (poleId == null) return;
    try {
      final members = await _polesService.getPoleMembers(poleId);
      if (!mounted) return;
      setState(() => _eligibleMembers = members);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loadingScope = false);
    }
  }

  Future<void> _selectProject(String? projectId) async {
    setState(() {
      _projectId = projectId;
      _poleId = null;
      _assigneeIds.clear();
      _loadingScope = projectId != null;
      _eligibleMembers = projectId == null
          ? List<MemberModel>.from(widget.members)
          : [];
    });
    if (projectId == null) return;
    try {
      final memberships = await _projectsService.getProjectMembers(projectId);
      final memberIds = memberships.map((item) => item.userId).toSet();
      if (!mounted) return;
      setState(() {
        _eligibleMembers = widget.members
            .where((member) => memberIds.contains(member.id))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loadingScope = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Créer une tâche'),
      content: SizedBox(
        width: _dialogWidth(context, 560),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le titre est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priorité',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'basse', child: Text('Basse')),
                    DropdownMenuItem(value: 'normale', child: Text('Normale')),
                    DropdownMenuItem(value: 'haute', child: Text('Haute')),
                    DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _priority = value);
                        },
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_rounded),
                    title: const Text('Échéance'),
                    subtitle: Text(_dueDateLabel),
                    trailing: TextButton(
                      onPressed: _loading ? null : _pickDueDate,
                      child: const Text('Choisir'),
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _proofRequired,
                  title: const Text('Preuve requise'),
                  subtitle: const Text(
                    'Empêche de terminer sans lien de preuve.',
                  ),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _proofRequired = value);
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(_poleId),
                  initialValue: _poleId,
                  decoration: const InputDecoration(
                    labelText: 'Pôle lié',
                    prefixIcon: Icon(Icons.hub_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Aucun pôle'),
                    ),
                    for (final pole in widget.poles)
                      DropdownMenuItem(
                        value: pole.id,
                        child: Text(pole.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _loading ? null : _selectPole,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(_projectId),
                  initialValue: _projectId,
                  decoration: const InputDecoration(
                    labelText: 'Projet lié',
                    prefixIcon: Icon(Icons.rocket_launch_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Aucun projet'),
                    ),
                    for (final project in widget.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(
                          project.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _loading ? null : _selectProject,
                ),
                const SizedBox(height: 8),
                if (_loadingScope)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assignés',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _eligibleMembers.map((member) {
                    final selected = _assigneeIds.contains(member.id);

                    return FilterChip(
                      selected: selected,
                      label: Text(member.displayName),
                      onSelected: _loading
                          ? null
                          : (value) {
                              setState(() {
                                if (value) {
                                  _assigneeIds.add(member.id);
                                } else {
                                  _assigneeIds.remove(member.id);
                                }
                              });
                            },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded),
          label: Text(_loading ? 'Création...' : 'Créer'),
        ),
      ],
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
              'Erreur de chargement',
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

class _TaskAssigneesPreview extends StatelessWidget {
  final List<MemberModel> members;
  final List<TaskAssigneeModel> assignees;

  const _TaskAssigneesPreview({required this.members, required this.assignees});

  @override
  Widget build(BuildContext context) {
    if (assignees.isEmpty) {
      return const Text(
        'Aucun assigné',
        style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
      );
    }

    final assignedMembers = assignees.map((assignee) {
      return members.firstWhere(
        (member) => member.id == assignee.userId,
        orElse: () => MemberModel(
          id: assignee.userId,
          email: '',
          firstName: 'Membre',
          lastName: 'inconnu',
        ),
      );
    }).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: assignedMembers.map((member) {
        return Chip(
          avatar: CircleAvatar(
            backgroundColor: AppTheme.enactusYellow,
            foregroundColor: AppTheme.softBlack,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
            ),
          ),
          label: Text(member.displayName),
        );
      }).toList(),
    );
  }
}

double _dialogWidth(BuildContext context, double maxWidth) {
  return (MediaQuery.sizeOf(context).width - 32).clamp(280.0, maxWidth);
}

class _TaskViewFilters extends StatelessWidget {
  final String selectedView;
  final ValueChanged<String> onChanged;

  const _TaskViewFilters({required this.selectedView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              selected: selectedView == 'all',
              label: const Text('Toutes les tâches'),
              avatar: const Icon(Icons.view_kanban_rounded, size: 18),
              onSelected: (_) => onChanged('all'),
            ),
            ChoiceChip(
              selected: selectedView == 'my',
              label: const Text('Mes tâches'),
              avatar: const Icon(Icons.person_rounded, size: 18),
              onSelected: (_) => onChanged('my'),
            ),
            ChoiceChip(
              selected: selectedView == 'late',
              label: const Text('En retard'),
              avatar: const Icon(Icons.warning_rounded, size: 18),
              onSelected: (_) => onChanged('late'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSearchFilters extends StatelessWidget {
  final TextEditingController controller;
  final String priorityFilter;
  final VoidCallback onChanged;
  final ValueChanged<String> onPriorityChanged;

  const _TaskSearchFilters({
    required this.controller,
    required this.priorityFilter,
    required this.onChanged,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final search = TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: 'Rechercher tâche, membre, statut',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Effacer',
                      ),
              ),
            );
            final filters = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PriorityChoice(
                  label: 'Toutes priorités',
                  value: 'all',
                  current: priorityFilter,
                  onSelected: onPriorityChanged,
                ),
                _PriorityChoice(
                  label: 'Basse',
                  value: 'basse',
                  current: priorityFilter,
                  onSelected: onPriorityChanged,
                ),
                _PriorityChoice(
                  label: 'Normale',
                  value: 'normale',
                  current: priorityFilter,
                  onSelected: onPriorityChanged,
                ),
                _PriorityChoice(
                  label: 'Haute',
                  value: 'haute',
                  current: priorityFilter,
                  onSelected: onPriorityChanged,
                ),
                _PriorityChoice(
                  label: 'Urgente',
                  value: 'urgente',
                  current: priorityFilter,
                  onSelected: onPriorityChanged,
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 14),
                  Flexible(child: filters),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 12), filters],
            );
          },
        ),
      ),
    );
  }
}

class _PriorityChoice extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;

  const _PriorityChoice({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      selectedColor: AppTheme.enactusYellow.withAlpha(120),
      onSelected: (_) => onSelected(value),
    );
  }
}
