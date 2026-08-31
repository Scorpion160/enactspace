import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../documents/models/document_model.dart';
import '../../events/models/event_model.dart';
import '../../members/models/member_model.dart';
import '../../posts/models/post_model.dart';
import '../../tasks/models/task_assignee_model.dart';
import '../../tasks/models/task_model.dart';
import '../models/pole_model.dart';
import '../models/pole_management_models.dart';
import '../models/pole_portfolio_models.dart';

abstract class PolesPortfolioGateway {
  Future<UserExperience> loadCurrentUser();
  Future<List<PoleModel>> loadPoles();
  Future<List<MemberModel>> loadMembers(String poleId);
  Future<List<MemberModel>> loadMemberDirectory();
  Future<List<TaskModel>> loadTasks(String poleId);
  Future<List<PoleAssignee>> loadTaskAssignees(String taskId);
  Future<List<DocumentModel>> loadDocuments(String poleId);
  Future<List<PostModel>> loadPosts(String poleId);
  Future<List<EventModel>> loadEvents();
  Future<PoleModel> createPole(PoleMutationDraft draft);
  Future<PoleModel> updatePole(String poleId, PoleMutationDraft draft);
  Future<PoleMemberMutationResult> assignPoleMember({
    required String poleId,
    required String userId,
    required String position,
  });
  Future<void> removePoleMember({
    required String poleId,
    required String userId,
  });
}

class ApiPolesPortfolioGateway implements PolesPortfolioGateway {
  final ApiClient _apiClient;
  final AuthService _authService;
  Future<String>? _token;
  Future<List<PoleModel>>? _poles;
  Future<List<EventModel>>? _events;
  Future<Map<String, MemberModel>>? _directory;
  final Map<String, Future<List<MemberModel>>> _members = {};
  final Map<String, Future<List<TaskModel>>> _tasks = {};
  final Map<String, Future<List<PoleAssignee>>> _assignees = {};
  final Map<String, Future<List<DocumentModel>>> _documents = {};
  final Map<String, Future<List<PostModel>>> _posts = {};

  ApiPolesPortfolioGateway({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  @override
  Future<UserExperience> loadCurrentUser() async =>
      UserExperience.fromJson(await _authService.getCurrentUser());

  @override
  Future<List<PoleModel>> loadPoles() =>
      _poles ??= _getList('/poles/', PoleModel.fromJson);

  @override
  Future<List<MemberModel>> loadMembers(String poleId) => _members.putIfAbsent(
    poleId,
    () => _getList('/poles/$poleId/members', MemberModel.fromJson),
  );

  @override
  Future<List<MemberModel>> loadMemberDirectory() async =>
      (await _loadDirectory()).values.toList();

  @override
  Future<List<TaskModel>> loadTasks(String poleId) => _tasks.putIfAbsent(
    poleId,
    () => _getList('/tasks/pole/$poleId', TaskModel.fromJson),
  );

  @override
  Future<List<PoleAssignee>> loadTaskAssignees(String taskId) {
    return _assignees.putIfAbsent(taskId, () async {
      final results = await Future.wait([
        _getList('/tasks/$taskId/assignees', TaskAssigneeModel.fromJson),
        _loadDirectory(),
      ]);
      final assigned = results[0] as List<TaskAssigneeModel>;
      final directory = results[1] as Map<String, MemberModel>;
      return assigned.map((assignment) {
        return PoleAssignee(
          userId: assignment.userId,
          displayName:
              directory[assignment.userId]?.displayName ??
              'Porteur non renseigné',
        );
      }).toList();
    });
  }

  @override
  Future<List<DocumentModel>> loadDocuments(String poleId) {
    return _documents.putIfAbsent(
      poleId,
      () => _getList(
        '/documents/?pole_id=${Uri.encodeQueryComponent(poleId)}',
        DocumentModel.fromJson,
      ),
    );
  }

  @override
  Future<List<PostModel>> loadPosts(String poleId) {
    return _posts.putIfAbsent(
      poleId,
      () => _getList(
        '/posts/?pole_id=${Uri.encodeQueryComponent(poleId)}',
        PostModel.fromJson,
      ),
    );
  }

  @override
  Future<List<EventModel>> loadEvents() =>
      _events ??= _getList('/events/', EventModel.fromJson);

  @override
  Future<PoleModel> createPole(PoleMutationDraft draft) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.postJson(
      '/poles/',
      token: token,
      data: draft.toJson(),
    );
    final pole = _parsePole(response);
    _invalidatePoleData();
    return pole;
  }

  @override
  Future<PoleModel> updatePole(String poleId, PoleMutationDraft draft) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.patchJson(
      '/poles/$poleId',
      token: token,
      data: draft.toJson(),
    );
    final pole = _parsePole(response);
    _invalidatePoleData();
    return pole;
  }

  @override
  Future<PoleMemberMutationResult> assignPoleMember({
    required String poleId,
    required String userId,
    required String position,
  }) async {
    final token = await (_token ??= _requireToken());
    final response = await _apiClient.postJson(
      '/poles/$poleId/members',
      token: token,
      data: {'user_id': userId, 'position': position},
    );
    if (response is! Map) throw Exception('Réponse membership invalide.');
    final map = Map<String, dynamic>.from(response);
    final membership = MemberModel.fromJson(map);
    _members.remove(poleId);
    final kind = map['reactivated'] == true
        ? PoleMemberMutationKind.reactivated
        : position == PolePositionPresentation.member
        ? PoleMemberMutationKind.assigned
        : PoleMemberMutationKind.responsibilityUpdated;
    return PoleMemberMutationResult(membership: membership, kind: kind);
  }

  @override
  Future<void> removePoleMember({
    required String poleId,
    required String userId,
  }) async {
    final token = await (_token ??= _requireToken());
    await _apiClient.delete('/poles/$poleId/members/$userId', token: token);
    _members.remove(poleId);
  }

  PoleModel _parsePole(dynamic response) {
    if (response is Map) {
      return PoleModel.fromJson(Map<String, dynamic>.from(response));
    }
    throw Exception('Réponse pôle invalide.');
  }

  void _invalidatePoleData() {
    _poles = null;
    _members.clear();
    _tasks.clear();
    _assignees.clear();
    _documents.clear();
    _posts.clear();
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
    return raw
        .whereType<Map>()
        .map((item) => parser(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }
}
