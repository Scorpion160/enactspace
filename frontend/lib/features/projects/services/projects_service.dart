import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/project_model.dart';

class ProjectsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  ProjectsService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<ProjectModel>> getProjects() async {
    final token = await _requireToken();
    final response = await _apiClient.get('/projects/', token: token);

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(ProjectModel.fromJson).toList();
  }

  Future<ProjectModel> createProject({
    required String name,
    required String description,
    required String problemStatement,
    required String solution,
    required String objectives,
    required String expectedImpact,
    required double budgetEstimated,
    required String status,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/projects/',
      token: token,
      data: {
        'name': name.trim(),
        'description': _nullable(description),
        'problem_statement': _nullable(problemStatement),
        'solution': _nullable(solution),
        'objectives': _nullable(objectives),
        'expected_impact': _nullable(expectedImpact),
        'budget_estimated': budgetEstimated,
        'status': status,
        'started_at': _dateOnly(startedAt),
        'ended_at': _dateOnly(endedAt),
      },
    );

    if (response is Map<String, dynamic>) {
      return ProjectModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du projet.');
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    if (response is Map && response['items'] is List) {
      return response['items'] as List;
    }
    return [];
  }
}
