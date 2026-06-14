import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  Future<List<ChatThreadModel>> getCachedThreads({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_threadsCacheKey(userId));

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatThreadModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _threadsCacheKey(userId),
      jsonEncode(threads.map((thread) => thread.toJson()).toList()),
    );
  }

  Future<ChatThreadModel> createThread({
    String? title,
    required String threadType,
    required List<String> participantIds,
    String? scopeType,
    String? scopeId,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads',
      token: token,
      data: {
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
        'thread_type': threadType,
        'scope_type': _nullable(scopeType),
        'scope_id': _nullable(scopeId),
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

  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_messagesCacheKey(userId, threadId));

    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _messagesCacheKey(userId, threadId),
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<ChatMessageModel> sendMessage({
    required String threadId,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    int? durationSeconds,
    String? thumbnailUrl,
    String? stickerPack,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads/$threadId/messages',
      token: token,
      data: {
        'content': content.trim(),
        'message_type': messageType,
        'attachment_url': _nullable(attachmentUrl),
        'attachment_name': _nullable(attachmentName),
        'attachment_mime_type': _nullable(attachmentMimeType),
        'attachment_size_bytes': attachmentSizeBytes,
        'duration_seconds': durationSeconds,
        'thumbnail_url': _nullable(thumbnailUrl),
        'sticker_pack': _nullable(stickerPack),
      },
    );

    if (response is Map<String, dynamic>) {
      return ChatMessageModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’envoi du message.');
  }

  Future<void> addParticipants({
    required String threadId,
    required List<String> userIds,
  }) async {
    final token = await _requireToken();
    await _apiClient.postJson(
      '/chat/threads/$threadId/participants',
      token: token,
      data: {'user_ids': userIds},
    );
  }

  Future<void> updateParticipantRole({
    required String threadId,
    required String userId,
    required String participantRole,
  }) async {
    final token = await _requireToken();
    await _apiClient.patchJson(
      '/chat/threads/$threadId/participants/$userId/role',
      token: token,
      data: {'participant_role': participantRole},
    );
  }

  Future<void> removeParticipant({
    required String threadId,
    required String userId,
  }) async {
    final token = await _requireToken();
    await _apiClient.delete(
      '/chat/threads/$threadId/participants/$userId',
      token: token,
    );
  }

  Future<void> deleteThread(String threadId) async {
    final token = await _requireToken();
    await _apiClient.delete('/chat/threads/$threadId', token: token);
  }

  Future<ChatUploadedMediaModel> uploadMediaBase64({
    required String fileName,
    required String dataBase64,
    required String messageType,
    String? contentType,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/uploads',
      token: token,
      data: {
        'file_name': fileName.trim(),
        'content_type': _nullable(contentType),
        'data_base64': dataBase64.trim(),
        'message_type': messageType,
      },
    );

    if (response is Map<String, dynamic>) {
      return ChatUploadedMediaModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’upload du média.');
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

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _threadsCacheKey(String userId) {
    return 'enactspace_chat_threads_$userId';
  }

  String _messagesCacheKey(String userId, String threadId) {
    return 'enactspace_chat_messages_${userId}_$threadId';
  }
}
