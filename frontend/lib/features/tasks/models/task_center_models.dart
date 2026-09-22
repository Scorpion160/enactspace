import '../../members/models/member_model.dart';
import '../../poles/models/pole_model.dart';
import '../../projects/models/project_model.dart';
import 'task_assignee_model.dart';
import 'task_model.dart';

enum TaskCenterView { all, mine, late }

extension TaskCenterViewPresentation on TaskCenterView {
  String get queryValue => switch (this) {
    TaskCenterView.all => 'all',
    TaskCenterView.mine => 'my',
    TaskCenterView.late => 'late',
  };

  String get label => switch (this) {
    TaskCenterView.all => 'Toutes visibles',
    TaskCenterView.mine => 'Mes tâches',
    TaskCenterView.late => 'En retard',
  };

  static TaskCenterView fromQuery(String? value) => switch (value) {
    'my' => TaskCenterView.mine,
    'late' => TaskCenterView.late,
    _ => TaskCenterView.all,
  };
}

class TaskCenterData {
  final List<TaskModel> tasks;
  final List<MemberModel> members;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final Map<String, List<TaskAssigneeModel>> assigneesByTaskId;
  final Set<String> assigneeErrorTaskIds;
  final bool canCreate;
  final bool requiresManagedScope;

  const TaskCenterData({
    required this.tasks,
    this.members = const [],
    this.poles = const [],
    this.projects = const [],
    this.assigneesByTaskId = const {},
    this.assigneeErrorTaskIds = const {},
    this.canCreate = false,
    this.requiresManagedScope = false,
  });

  MemberModel? member(String id) =>
      _firstWhereOrNull(members, (item) => item.id == id);

  PoleModel? pole(String? id) =>
      id == null ? null : _firstWhereOrNull(poles, (item) => item.id == id);

  ProjectModel? project(String? id) =>
      id == null ? null : _firstWhereOrNull(projects, (item) => item.id == id);
}

class TaskDetailData {
  final TaskModel task;
  final List<TaskAssigneeModel> assignees;
  final List<MemberModel> members;
  final PoleModel? pole;
  final ProjectModel? project;
  final bool assigneesUnavailable;

  const TaskDetailData({
    required this.task,
    this.assignees = const [],
    this.members = const [],
    this.pole,
    this.project,
    this.assigneesUnavailable = false,
  });
}

class TaskCreateInput {
  final String title;
  final String description;
  final String priority;
  final DateTime? dueDate;
  final bool proofRequired;
  final List<String> assigneeIds;
  final String? poleId;
  final String? projectId;

  const TaskCreateInput({
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.proofRequired,
    required this.assigneeIds,
    this.poleId,
    this.projectId,
  });
}

class TaskUpdateInput {
  final String title;
  final String description;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final bool proofRequired;
  final String? proofUrl;

  const TaskUpdateInput({
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.proofRequired,
    required this.proofUrl,
  });
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) matches) {
  for (final value in values) {
    if (matches(value)) return value;
  }
  return null;
}
