import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/task_model.dart';
import '../models/task_assignee_model.dart';

class TasksService {
  final ApiClient _apiClient;
  final AuthService _authService;

  TasksService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<TaskModel>> getTasks() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/tasks/', token: token);

    final List<dynamic> rawList;

    if (response is List) {
      rawList = response;
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List;
    } else if (response is Map && response['items'] is List) {
      rawList = response['items'] as List;
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(TaskModel.fromJson)
        .toList();
  }

  Future<TaskModel> createTask({
    required String title,
    required String description,
    required String priority,
    required DateTime? dueDate,
    required bool proofRequired,
    required List<String> assigneeIds,
    String? poleId,
    String? projectId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/tasks/',
      token: token,
      data: {
        'title': title.trim(),
        'description': description.trim(),
        'priority': priority,
        'due_date': dueDate?.toIso8601String(),
        'proof_required': proofRequired,
        'assignee_ids': assigneeIds,
        'pole_id': poleId,
        'project_id': projectId,
      },
    );

    if (response is Map<String, dynamic>) {
      return TaskModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de tâche.');
  }

  Future<TaskModel> changeStatus({
    required String taskId,
    required String status,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/tasks/$taskId/status',
      token: token,
      data: {'status': status},
    );

    if (response is Map<String, dynamic>) {
      return TaskModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du changement de statut.');
  }

  Future<TaskModel> submitProof({
    required String taskId,
    required String proofUrl,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/tasks/$taskId/proof',
      token: token,
      data: {'proof_url': proofUrl.trim()},
    );

    if (response is Map<String, dynamic>) {
      return TaskModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’envoi de preuve.');
  }

  Future<TaskModel> validateTask(String taskId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/tasks/$taskId/validate',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return TaskModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la validation de tâche.');
  }

  Future<List<TaskAssigneeModel>> getTaskAssignees(String taskId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get(
      '/tasks/$taskId/assignees',
      token: token,
    );

    final List<dynamic> rawList;

    if (response is List) {
      rawList = response;
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List;
    } else if (response is Map && response['items'] is List) {
      rawList = response['items'] as List;
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(TaskAssigneeModel.fromJson)
        .toList();
  }

  Future<List<TaskModel>> getMyTasks() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/tasks/my', token: token);

    final List<dynamic> rawList;

    if (response is List) {
      rawList = response;
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List;
    } else if (response is Map && response['items'] is List) {
      rawList = response['items'] as List;
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(TaskModel.fromJson)
        .toList();
  }

  Future<List<TaskModel>> getLateTasks() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/tasks/late', token: token);

    final List<dynamic> rawList;

    if (response is List) {
      rawList = response;
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List;
    } else if (response is Map && response['items'] is List) {
      rawList = response['items'] as List;
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(TaskModel.fromJson)
        .toList();
  }
}
