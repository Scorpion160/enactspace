import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';

class EventsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  EventsService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<EventModel>> getEvents() async {
    final token = await _requireToken();
    final response = await _apiClient.get('/events/', token: token);

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(EventModel.fromJson).toList();
  }

  Future<EventModel> getEvent(String eventId) async {
    final token = await _requireToken();
    final response = await _apiClient.get('/events/$eventId', token: token);
    if (response is Map<String, dynamic>) return EventModel.fromJson(response);
    throw Exception('Événement introuvable.');
  }

  Future<EventModel> createEvent({
    required String title,
    required String description,
    required String eventType,
    required String location,
    required DateTime startTime,
    DateTime? endTime,
    required double budget,
    int? maxParticipants,
    required bool requiresRegistration,
    required bool attendanceEnabled,
    String? poleId,
    String? projectId,
    String? seasonId,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/events/',
      token: token,
      data: {
        'title': title.trim(),
        'description': _nullable(description),
        'event_type': eventType,
        'location': _nullable(location),
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'budget': budget,
        'max_participants': maxParticipants,
        'requires_registration': requiresRegistration,
        'attendance_enabled': attendanceEnabled,
        'pole_id': _nullableId(poleId),
        'project_id': _nullableId(projectId),
        'season_id': _nullableId(seasonId),
      },
    );

    if (response is Map<String, dynamic>) {
      return EventModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de l’événement.');
  }

  Future<EventModel> updateEvent({
    required String eventId,
    String? title,
    String? description,
    String? eventType,
    String? location,
    DateTime? startTime,
    String? reportUrl,
    DateTime? endTime,
    bool clearEndTime = false,
    String? poleId,
    String? projectId,
    double? budget,
    int? maxParticipants,
    bool? requiresRegistration,
    bool? attendanceEnabled,
  }) async {
    final token = await _requireToken();
    final data = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': _nullable(description),
      'event_type': ?eventType,
      if (location != null) 'location': _nullable(location),
      if (startTime != null) 'start_time': startTime.toIso8601String(),
      if (endTime != null) 'end_time': endTime.toIso8601String(),
      if (clearEndTime) 'end_time': null,
      if (poleId != null) 'pole_id': _nullableId(poleId),
      if (projectId != null) 'project_id': _nullableId(projectId),
      'budget': ?budget,
      'max_participants': ?maxParticipants,
      'requires_registration': ?requiresRegistration,
      'attendance_enabled': ?attendanceEnabled,
      if (reportUrl != null) 'report_url': _nullable(reportUrl),
    };
    final response = await _apiClient.patchJson(
      '/events/$eventId',
      token: token,
      data: data,
    );

    if (response is Map<String, dynamic>) {
      return EventModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la mise à jour de l’événement.');
  }

  Future<EventModel> register(String eventId) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/events/$eventId/register',
      token: token,
      data: {},
    );
    if (response is Map<String, dynamic>) {
      return EventModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors de l’inscription.');
  }

  Future<EventModel> unregister(String eventId) async {
    final token = await _requireToken();
    final response = await _apiClient.delete(
      '/events/$eventId/register',
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return EventModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors du désistement.');
  }

  Future<List<EventParticipantModel>> getParticipants(String eventId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/events/$eventId/participants',
      token: token,
    );
    return _extractList(response)
        .whereType<Map<String, dynamic>>()
        .map(EventParticipantModel.fromJson)
        .toList();
  }

  Future<void> deleteEvent(String eventId) async {
    final token = await _requireToken();
    await _apiClient.delete('/events/$eventId', token: token);
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

  String? _nullableId(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty || trimmed == 'all' ? null : trimmed;
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
