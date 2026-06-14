import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/event_model.dart';

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
      },
    );

    if (response is Map<String, dynamic>) {
      return EventModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de l’événement.');
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
