import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../documents/models/document_model.dart';
import '../../events/models/event_model.dart';
import '../../members/models/member_model.dart';
import '../../tasks/models/task_assignee_model.dart';
import '../../tasks/models/task_model.dart';
import '../models/project_member_model.dart';
import '../models/project_management_models.dart';
import '../models/project_model.dart';
import '../models/project_portfolio_models.dart';
import '../models/project_team_management_models.dart';

abstract class ProjectsPortfolioGateway {
  Future<UserExperience> loadCurrentUser();
  Future<List<ProjectModel>> loadProjects();
  Future<List<ProjectSeasonOption>> loadSeasons();
  Future<Map<String, ProjectImpactSnapshot>> loadImpact();
  Future<List<ProjectMemberModel>> loadMembers(String projectId);
  Future<List<MemberModel>> loadMemberDirectory();
  Future<List<TaskModel>> loadTasks(String projectId);
  Future<List<ProjectAssignee>> loadTaskAssignees(String taskId);
  Future<List<DocumentModel>> loadDocuments(String projectId);
  Future<List<EventModel>> loadEvents();
  Future<ProjectModel> createProject(ProjectMutationDraft draft);
  Future<ProjectModel> updateProject(
    String projectId,
    ProjectMutationDraft draft,
  );
  Future<ProjectModel> changeProjectStatus(
    ProjectModel project,
    String targetStatus,
  );
  Future<ProjectMemberMutationResult> assignProjectMember({
    required String projectId,
    required String userId,
    required String position,
  });
  Future<ProjectMemberModel> removeProjectMember({
    required String projectId,
    required String userId,
  });
}

class ApiProjectsPortfolioGateway implements ProjectsPortfolioGateway {
  final ApiClient _apiClient;
  final AuthService _authService;
  Future<String>? _token;
  Future<List<ProjectModel>>? _projects;
  Future<List<ProjectSeasonOption>>? _seasons;
  Future<Map<String, ProjectImpactSnapshot>>? _impact;
  Future<List<EventModel>>? _events;
  Future<Map<String, MemberModel>>? _directory;
  final Map<String, Future<List<ProjectMemberModel>>> _members = {};
  final Map<String, Future<List<TaskModel>>> _tasks = {};
  final Map<String, Future<List<ProjectAssignee>>> _assignees = {};
  final Map<String, Future<List<DocumentModel>>> _documents = {};

  ApiProjectsPortfolioGateway({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  @override
  Future<UserExperience> loadCurrentUser() async =>
      UserExperience.fromJson(await _authService.getCurrentUser());

  @override
  Future<List<ProjectModel>> loadProjects() =>
      _projects ??= _getList('/projects/', ProjectModel.fromJson);

  @override
  Future<List<ProjectSeasonOption>> loadSeasons() =>
      _seasons ??= _getList('/seasons/', ProjectSeasonOption.fromJson);

  @override
  Future<Map<String, ProjectImpactSnapshot>> loadImpact() {
    return _impact ??= () async {
      final snapshots = await _getList(
        '/impact/projects',
        ProjectImpactSnapshot.fromJson,
      );
      return {for (final snapshot in snapshots) snapshot.projectId: snapshot};
    }();
  }

  @override
  Future<List<ProjectMemberModel>> loadMembers(String projectId) =>
      _members.putIfAbsent(
        projectId,
        () => _getList(
          '/projects/$projectId/members',
          ProjectMemberModel.fromJson,
        ),
      );

  @override
  Future<List<MemberModel>> loadMemberDirectory() async =>
      (await _loadDirectory()).values.toList();

  @override
  Future<List<TaskModel>> loadTasks(String projectId) => _tasks.putIfAbsent(
    projectId,
    () => _getList('/tasks/project/$projectId', TaskModel.fromJson),
  );

  @override
  Future<List<ProjectAssignee>> loadTaskAssignees(String taskId) {
    return _assignees.putIfAbsent(taskId, () async {
      final results = await Future.wait([
        _getList('/tasks/$taskId/assignees', TaskAssigneeModel.fromJson),
        _loadDirectory(),
      ]);
      final assigned = results[0] as List<TaskAssigneeModel>;
      final directory = results[1] as Map<String, MemberModel>;
      return assigned.map((item) {
        final member = directory[item.userId];
        return ProjectAssignee(
          userId: item.userId,
          displayName: member?.displayName ?? 'Responsable non renseigné',
        );
      }).toList();
    });
  }

  @override
  Future<List<DocumentModel>> loadDocuments(String projectId) {
    return _documents.putIfAbsent(
      projectId,
      () => _getList(
        '/documents/?project_id=${Uri.encodeQueryComponent(projectId)}',
        DocumentModel.fromJson,
      ),
    );
  }

  @override
  Future<List<EventModel>> loadEvents() =>
      _events ??= _getList('/events/', EventModel.fromJson);

  @override
  Future<ProjectModel> createProject(ProjectMutationDraft draft) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.postJson(
      '/projects/',
      token: token,
      data: draft.toCreateJson(),
    );
    final project = _parseProject(response);
    _invalidateProjectData();
    return project;
  }

  @override
  Future<ProjectModel> updateProject(
    String projectId,
    ProjectMutationDraft draft,
  ) async {
    return _patchProject(projectId, draft.toUpdateJson());
  }

  @override
  Future<ProjectModel> changeProjectStatus(
    ProjectModel project,
    String targetStatus,
  ) {
    return _patchProject(
      project.id,
      ProjectStatusMutationPayload.build(project, targetStatus),
    );
  }

  @override
  Future<ProjectMemberMutationResult> assignProjectMember({
    required String projectId,
    required String userId,
    required String position,
  }) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.postJson(
      '/projects/$projectId/members',
      token: token,
      data: {'user_id': userId, 'position': position},
    );
    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse membership invalide.');
    }
    final membership = ProjectMemberModel.fromJson(response);
    _members.remove(projectId);
    return ProjectMemberMutationResult(membership: membership);
  }

  @override
  Future<ProjectMemberModel> removeProjectMember({
    required String projectId,
    required String userId,
  }) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.delete(
      '/projects/$projectId/members/$userId',
      token: token,
    );
    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse membership invalide.');
    }
    _members.remove(projectId);
    return ProjectMemberModel.fromJson(response);
  }

  Future<ProjectModel> _patchProject(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.patchJson(
      '/projects/$projectId',
      token: token,
      data: data,
    );
    final project = _parseProject(response);
    _invalidateProjectData();
    return project;
  }

  ProjectModel _parseProject(dynamic response) {
    if (response is Map<String, dynamic>) {
      return ProjectModel.fromJson(response);
    }
    throw Exception('Réponse projet invalide.');
  }

  void _invalidateProjectData() {
    _projects = null;
    _impact = null;
    _members.clear();
    _tasks.clear();
    _assignees.clear();
    _documents.clear();
  }

  Future<Map<String, MemberModel>> _loadDirectory() {
    return _directory ??= () async {
      final members = await _getList('/users/directory', MemberModel.fromJson);
      return {for (final member in members) member.id: member};
    }();
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.get(path, token: token);
    final raw = switch (response) {
      List<dynamic> value => value,
      Map<dynamic, dynamic> value when value['data'] is List =>
        value['data'] as List<dynamic>,
      Map<dynamic, dynamic> value when value['items'] is List =>
        value['items'] as List<dynamic>,
      _ => const <dynamic>[],
    };
    return raw.whereType<Map<String, dynamic>>().map(parser).toList();
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }
    return token;
  }
}
