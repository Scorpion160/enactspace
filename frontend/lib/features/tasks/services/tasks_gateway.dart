import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/task_assignee_model.dart';
import '../models/task_center_models.dart';
import '../models/task_model.dart';
import 'tasks_service.dart';

abstract interface class TasksGateway {
  Future<TaskCenterData> loadCenter(
    TaskCenterView view, {
    bool includeDirectory = true,
  });

  Future<TaskDetailData> loadDetail(String taskId);
  Future<List<MemberModel>> membersForPole(String poleId);
  Future<List<MemberModel>> membersForProject(String projectId);
  Future<TaskModel> createTask(TaskCreateInput input);
  Future<TaskModel> updateTask(String taskId, TaskUpdateInput input);
  Future<TaskModel> changeStatus(String taskId, String status);
  Future<TaskModel> submitProof(String taskId, String proofUrl);
  Future<TaskModel> validateTask(String taskId);
  void invalidate();
}

class ApiTasksGateway implements TasksGateway {
  final TasksService _tasks;
  final MembersService _members;
  final PolesService _poles;
  final ProjectsService _projects;
  final AuthService _auth;
  final Map<String, Future<List<TaskAssigneeModel>>> _assigneeCache = {};
  Future<List<MemberModel>>? _memberCache;
  Future<List<PoleModel>>? _poleCache;
  Future<List<ProjectModel>>? _projectCache;

  ApiTasksGateway({
    TasksService? tasksService,
    MembersService? membersService,
    PolesService? polesService,
    ProjectsService? projectsService,
    AuthService? authService,
  }) : _tasks = tasksService ?? TasksService(),
       _members = membersService ?? MembersService(),
       _poles = polesService ?? PolesService(),
       _projects = projectsService ?? ProjectsService(),
       _auth = authService ?? AuthService();

  Future<List<MemberModel>> _loadMembers() =>
      _memberCache ??= _members.getMembers();
  Future<List<PoleModel>> _loadPoles() => _poleCache ??= _poles.getPoles();
  Future<List<ProjectModel>> _loadProjects() =>
      _projectCache ??= _projects.getProjects();
  Future<List<TaskAssigneeModel>> _loadAssignees(String taskId) =>
      _assigneeCache.putIfAbsent(taskId, () => _tasks.getTaskAssignees(taskId));

  @override
  Future<TaskCenterData> loadCenter(
    TaskCenterView view, {
    bool includeDirectory = true,
  }) async {
    final tasksFuture = switch (view) {
      TaskCenterView.all => _tasks.getTasks(),
      TaskCenterView.mine => _tasks.getMyTasks(),
      TaskCenterView.late => _tasks.getLateTasks(),
    };
    final userFuture = _auth.getCurrentUser();
    final membersFuture = includeDirectory
        ? _loadMembers()
        : Future.value(const <MemberModel>[]);
    final polesFuture = includeDirectory
        ? _loadPoles()
        : Future.value(const <PoleModel>[]);
    final projectsFuture = includeDirectory
        ? _loadProjects()
        : Future.value(const <ProjectModel>[]);

    final results = await Future.wait<Object>([
      tasksFuture,
      userFuture,
      membersFuture,
      polesFuture,
      projectsFuture,
    ]);
    final tasks = results[0] as List<TaskModel>;
    final user = UserExperience.fromJson(results[1] as Map<String, dynamic>);
    final batch = await loadTaskAssigneesInParallel(tasks, _loadAssignees);
    for (final taskId in batch.failures) {
      _assigneeCache.remove(taskId);
    }

    return TaskCenterData(
      tasks: tasks,
      members: results[2] as List<MemberModel>,
      poles: results[3] as List<PoleModel>,
      projects: results[4] as List<ProjectModel>,
      assigneesByTaskId: batch.values,
      assigneeErrorTaskIds: batch.failures,
      canCreate:
          user.isAdmin ||
          user.isTeamLeader ||
          user.isSecretary ||
          user.isProjectOrPoleLead,
      requiresManagedScope:
          user.isProjectOrPoleLead &&
          !user.isAdmin &&
          !user.isTeamLeader &&
          !user.isSecretary,
    );
  }

  @override
  Future<TaskDetailData> loadDetail(String taskId) async {
    final taskFuture = _tasks.getTask(taskId);
    final membersFuture = _loadMembers();
    final polesFuture = _loadPoles();
    final projectsFuture = _loadProjects();
    final results = await Future.wait<Object>([
      taskFuture,
      membersFuture,
      polesFuture,
      projectsFuture,
    ]);
    final task = results[0] as TaskModel;
    var unavailable = false;
    List<TaskAssigneeModel> assignees;
    try {
      assignees = await _loadAssignees(taskId);
    } catch (_) {
      unavailable = true;
      assignees = const [];
      _assigneeCache.remove(taskId);
    }
    final poles = results[2] as List<PoleModel>;
    final projects = results[3] as List<ProjectModel>;
    return TaskDetailData(
      task: task,
      assignees: assignees,
      members: results[1] as List<MemberModel>,
      pole: _find(poles, (item) => item.id == task.poleId),
      project: _find(projects, (item) => item.id == task.projectId),
      assigneesUnavailable: unavailable,
    );
  }

  @override
  Future<List<MemberModel>> membersForPole(String poleId) =>
      _poles.getPoleMembers(poleId);

  @override
  Future<List<MemberModel>> membersForProject(String projectId) async {
    final values = await Future.wait<Object>([
      _projects.getProjectMembers(projectId),
      _loadMembers(),
    ]);
    final ids = (values[0] as List)
        .map((item) => (item as dynamic).userId.toString())
        .toSet();
    return (values[1] as List<MemberModel>)
        .where((member) => ids.contains(member.id))
        .toList();
  }

  @override
  Future<TaskModel> createTask(TaskCreateInput input) async {
    final task = await _tasks.createTask(
      title: input.title,
      description: input.description,
      priority: input.priority,
      dueDate: input.dueDate,
      proofRequired: input.proofRequired,
      assigneeIds: input.assigneeIds,
      poleId: input.poleId,
      projectId: input.projectId,
    );
    invalidate();
    return task;
  }

  @override
  Future<TaskModel> updateTask(String taskId, TaskUpdateInput input) async {
    final task = await _tasks.updateTask(
      taskId: taskId,
      title: input.title,
      description: input.description,
      priority: input.priority,
      status: input.status,
      dueDate: input.dueDate,
      proofRequired: input.proofRequired,
      proofUrl: input.proofUrl,
    );
    invalidate();
    return task;
  }

  @override
  Future<TaskModel> changeStatus(String taskId, String status) async {
    final task = await _tasks.changeStatus(taskId: taskId, status: status);
    invalidate();
    return task;
  }

  @override
  Future<TaskModel> submitProof(String taskId, String proofUrl) async {
    final task = await _tasks.submitProof(taskId: taskId, proofUrl: proofUrl);
    invalidate();
    return task;
  }

  @override
  Future<TaskModel> validateTask(String taskId) async {
    final task = await _tasks.validateTask(taskId);
    invalidate();
    return task;
  }

  @override
  void invalidate() {
    _assigneeCache.clear();
  }
}

class TaskAssigneeBatch {
  final Map<String, List<TaskAssigneeModel>> values;
  final Set<String> failures;

  const TaskAssigneeBatch({required this.values, required this.failures});
}

Future<TaskAssigneeBatch> loadTaskAssigneesInParallel(
  Iterable<TaskModel> tasks,
  Future<List<TaskAssigneeModel>> Function(String taskId) loader,
) async {
  final values = <String, List<TaskAssigneeModel>>{};
  final failures = <String>{};
  await Future.wait(
    tasks.map((task) async {
      try {
        values[task.id] = await loader(task.id);
      } catch (_) {
        failures.add(task.id);
        values[task.id] = const [];
      }
    }),
  );
  return TaskAssigneeBatch(values: values, failures: failures);
}

T? _find<T>(Iterable<T> values, bool Function(T) matches) {
  for (final value in values) {
    if (matches(value)) return value;
  }
  return null;
}
