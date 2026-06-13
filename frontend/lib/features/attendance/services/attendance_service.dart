import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_expected_member_model.dart';
import '../models/attendance_record_model.dart';

class AttendanceService {
  final ApiClient _apiClient;
  final AuthService _authService;

  AttendanceService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<AttendanceSessionModel>> getSessions() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.get('/attendance/sessions', token: token);

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
        .map(AttendanceSessionModel.fromJson)
        .toList();
  }

  Future<AttendanceSessionModel> createSession({
    required String title,
    required String description,
    required String sessionType,
    required DateTime scheduledAt,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/attendance/sessions',
      token: token,
      data: {
        'title': title.trim(),
        'description': description.trim(),
        'session_type': sessionType,
        'scheduled_at': scheduledAt.toIso8601String(),
        'event_id': null,
        'pole_id': null,
        'project_id': null,
      },
    );

    if (response is Map<String, dynamic>) {
      return AttendanceSessionModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de la session.');
  }

  Future<List<AttendanceExpectedMemberModel>> getExpectedMembers(
    String sessionId,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.get(
      '/attendance/expected-members/$sessionId',
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
        .map(AttendanceExpectedMemberModel.fromJson)
        .toList();
  }

  Future<List<AttendanceRecordModel>> getRecordsBySession(
    String sessionId,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.get(
      '/attendance/records/$sessionId',
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
        .map(AttendanceRecordModel.fromJson)
        .toList();
  }

  Future<void> addExpectedMember({
    required String sessionId,
    required String userId,
    bool isRequired = true,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _apiClient.postJson(
      '/attendance/expected-members',
      token: token,
      data: {
        'session_id': sessionId,
        'user_id': userId,
        'is_required': isRequired,
      },
    );
  }

  Future<AttendanceRecordModel> createManualAttendance({
    required String sessionId,
    required String userId,
    required String status,
    String? justification,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/attendance/manual',
      token: token,
      data: {
        'session_id': sessionId,
        'user_id': userId,
        'status': status,
        'justification': justification,
      },
    );

    if (response is Map<String, dynamic>) {
      return AttendanceRecordModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la saisie de présence.');
  }

  Future<void> closeSession(String sessionId) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _apiClient.postJson(
      '/attendance/sessions/$sessionId/close',
      token: token,
      data: {},
    );
  }
}
