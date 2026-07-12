import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/attendance_session_model.dart';
import '../models/attendance_expected_member_model.dart';
import '../models/attendance_qr_model.dart';
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
    String scopeType = 'club',
    String? eventId,
    String? poleId,
    String? projectId,
    String? groupName,
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
        'session_type': sessionType == 'activity'
            ? 'field_activity'
            : sessionType,
        'scope_type': scopeType,
        'group_name': groupName,
        'scheduled_at': scheduledAt.toIso8601String(),
        'event_id': eventId,
        'pole_id': poleId,
        'project_id': projectId,
        'status': 'draft',
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
      '/attendance/sessions/$sessionId/records',
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

  Future<List<AttendanceRecordModel>> getMyRecords() async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.get(
      '/attendance/my-records',
      token: token,
    );

    final rawList = response is List ? response : const <dynamic>[];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecordModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> getStats({String? month}) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connectÃ©.');
    }

    final query = month == null ? '' : '?month=$month';
    final response = await _apiClient.get(
      '/attendance/stats$query',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {};
  }

  Future<String> getMonthlyExportCsv({String? month}) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connectÃ©.');
    }

    final query = month == null ? '' : '?month=$month';
    final response = await http.get(
      Uri.parse('${ApiClient.baseUrl}/attendance/monthly-export$query'),
      headers: {'Accept': 'text/csv', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return utf8.decode(response.bodyBytes);
    }

    throw Exception('Export impossible (${response.statusCode}).');
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
    String? justificationStatus,
    int? delayMinutes,
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
        'justification_reason': justification,
        'justification_status': justificationStatus,
        'delay_minutes': delayMinutes,
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

  Future<AttendanceSessionModel> openSession(String sessionId) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connectÃ©.');
    }

    final response = await _apiClient.postJson(
      '/attendance/sessions/$sessionId/open',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return AttendanceSessionModel.fromJson(response);
    }

    throw Exception('RÃ©ponse invalide lors de lâ€™ouverture de la session.');
  }

  Future<AttendanceQrTokenModel> createQrToken(String sessionId) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecte.');
    }

    final response = await _apiClient.postJson(
      '/attendance/sessions/$sessionId/qr-token',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return AttendanceQrTokenModel.fromJson(response);
    }

    throw Exception('Reponse QR invalide.');
  }

  Future<AttendanceQrStatusModel> getQrStatus(String sessionId) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecte.');
    }

    final response = await _apiClient.get(
      '/attendance/sessions/$sessionId/qr-status',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return AttendanceQrStatusModel.fromJson(response);
    }

    throw Exception('Statut QR indisponible.');
  }

  Future<AttendanceQrScanResultModel> scanQrToken(String qrToken) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecte.');
    }

    final response = await _apiClient.postJson(
      '/attendance/scan-qr',
      token: token,
      data: {'token': qrToken},
    );

    if (response is Map<String, dynamic>) {
      return AttendanceQrScanResultModel.fromJson(response);
    }

    throw Exception('Scan QR invalide.');
  }

  Future<List<AttendanceQrAuditLogModel>> getQrAuditLogs(
    String sessionId,
  ) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecte.');
    }

    final response = await _apiClient.get(
      '/audit/logs?entity_type=attendance_session&entity_id=$sessionId&limit=50',
      token: token,
    );

    final rawList = response is List ? response : const <dynamic>[];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(AttendanceQrAuditLogModel.fromJson)
        .where((log) => log.action.startsWith('attendance_qr'))
        .toList();
  }

  Future<AttendanceRecordModel> submitJustification({
    required String recordId,
    required String reason,
    String? fileId,
    String? fileUrl,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connectÃ©.');
    }

    final response = await _apiClient.postJson(
      '/attendance/records/$recordId/justify',
      token: token,
      data: {'reason': reason.trim(), 'file_id': fileId, 'file_url': fileUrl},
    );

    if (response is Map<String, dynamic>) {
      return AttendanceRecordModel.fromJson(response);
    }

    throw Exception('RÃ©ponse invalide lors de la justification.');
  }

  Future<AttendanceRecordModel> approveJustification({
    required String recordId,
    String? reason,
  }) {
    return _reviewJustification(
      recordId: recordId,
      action: 'approve',
      reason: reason,
    );
  }

  Future<AttendanceRecordModel> rejectJustification({
    required String recordId,
    required String reason,
  }) {
    return _reviewJustification(
      recordId: recordId,
      action: 'reject',
      reason: reason,
    );
  }

  Future<AttendanceRecordModel> _reviewJustification({
    required String recordId,
    required String action,
    String? reason,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connectÃ©.');
    }

    final response = await _apiClient.postJson(
      '/attendance/records/$recordId/justification/$action',
      token: token,
      data: {'reason': reason?.trim()},
    );

    if (response is Map<String, dynamic>) {
      return AttendanceRecordModel.fromJson(response);
    }

    throw Exception('RÃ©ponse invalide lors de la revue de justification.');
  }
}
