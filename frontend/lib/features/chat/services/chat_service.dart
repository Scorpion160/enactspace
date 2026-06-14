import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/chat_models.dart';

class ChatService {
  final ApiClient _apiClient;
  final AuthService _authService;

  ChatService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<ChatContactModel>> getContacts({String? search}) async {
    final token = await _requireToken();
    final path = search == null || search.trim().isEmpty
        ? '/chat/contacts'
        : '/chat/contacts?search=${Uri.encodeQueryComponent(search.trim())}';
    final response = await _apiClient.get(path, token: token);

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(ChatContactModel.fromJson).toList();
  }

  Future<List<ChatThreadModel>> getThreads() async {
    final token = await _requireToken();
    final response = await _apiClient.get('/chat/threads', token: token);

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(ChatThreadModel.fromJson).toList();
  }

  Future<ChatThreadModel> createThread({
    String? title,
    required String threadType,
    required List<String> participantIds,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads',
      token: token,
      data: {
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
        'thread_type': threadType,
        'participant_ids': participantIds,
      },
    );

    if (response is Map<String, dynamic>) {
      return ChatThreadModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de conversation.');
  }

  Future<List<ChatMessageModel>> getMessages(String threadId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/chat/threads/$threadId/messages',
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(ChatMessageModel.fromJson).toList();
  }

  Future<ChatMessageModel> sendMessage({
    required String threadId,
    required String content,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads/$threadId/messages',
      token: token,
      data: {'content': content.trim(), 'message_type': 'text'},
    );

    if (response is Map<String, dynamic>) {
      return ChatMessageModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’envoi du message.');
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
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
