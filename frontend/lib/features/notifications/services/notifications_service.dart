import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/notification_model.dart';

class NotificationsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  NotificationsService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<NotificationModel>> getNotifications({
    bool? unreadOnly,
    String? type,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final params = <String, String>{};

    if (unreadOnly != null) {
      params['unread_only'] = unreadOnly.toString();
    }

    if (type != null && type.isNotEmpty && type != 'all') {
      params['type_filter'] = type;
    }

    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final path = query.isEmpty ? '/notifications/' : '/notifications/?$query';

    final response = await _apiClient.get(path, token: token);

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  Future<int> getUnreadCount() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get(
      '/notifications/unread-count',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return int.tryParse(response['unread_count']?.toString() ?? '0') ?? 0;
    }

    return 0;
  }

  Future<NotificationModel> markAsRead(String notificationId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/notifications/$notificationId/read',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return NotificationModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du marquage comme lu.');
  }

  Future<int> markAllAsRead() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/notifications/read-all',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return int.tryParse(response['updated']?.toString() ?? '0') ?? 0;
    }

    return 0;
  }

  Future<void> deleteNotification(String notificationId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    await _apiClient.delete('/notifications/$notificationId', token: token);
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
