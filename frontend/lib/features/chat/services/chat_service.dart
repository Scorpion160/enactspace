import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/storage/session_private_data.dart';
import '../models/chat_models.dart';
import 'chat_offline_cache.dart';

class ChatMediaCacheSettings {
  final bool autoDownloadMedia;
  final String ephemeralDuration;

  const ChatMediaCacheSettings({
    this.autoDownloadMedia = true,
    this.ephemeralDuration = '7d',
  });

  ChatMediaCacheSettings copyWith({
    bool? autoDownloadMedia,
    String? ephemeralDuration,
  }) {
    return ChatMediaCacheSettings(
      autoDownloadMedia: autoDownloadMedia ?? this.autoDownloadMedia,
      ephemeralDuration: ephemeralDuration ?? this.ephemeralDuration,
    );
  }
}

class ChatService {
  final ApiClient _apiClient;
  final AuthService _authService;
  final ChatOfflineCacheStore _offlineCache;
  Future<void>? _legacyCachePurge;

  ChatService({
    ApiClient? apiClient,
    AuthService? authService,
    ChatOfflineCacheStore? offlineCache,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authService = authService ?? AuthService(),
       _offlineCache = offlineCache ?? const SecureChatOfflineCacheStore();

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

  Future<int> getUnreadCount() async {
    final token = await _requireToken();
    final response = await _apiClient.get('/chat/unread-count', token: token);

    if (response is Map<String, dynamic>) {
      return int.tryParse(response['unread_count']?.toString() ?? '0') ?? 0;
    }

    return 0;
  }

  Future<List<ChatThreadModel>> getCachedThreads({
    required String userId,
  }) async {
    await _purgeLegacyContentCache();
    final memory = sessionPrivateMemoryCache.read<List<ChatThreadModel>>(
      _threadsCacheKey(userId),
    );
    if (memory != null) return List<ChatThreadModel>.of(memory);

    final payload = await _readOfflineCache();
    final items = payload[_threadsCacheKey(userId)];
    if (items is! List) return const [];
    final threads = items
        .whereType<Map<String, dynamic>>()
        .map(ChatThreadModel.fromJson)
        .toList();
    sessionPrivateMemoryCache.write(_threadsCacheKey(userId), threads);
    return threads;
  }

  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  }) async {
    await _purgeLegacyContentCache();
    sessionPrivateMemoryCache.write(
      _threadsCacheKey(userId),
      List<ChatThreadModel>.of(threads),
    );
    final payload = await _readOfflineCache();
    payload[_threadsCacheKey(userId)] = threads
        .map((item) => item.toJson())
        .toList();
    await _writeOfflineCache(payload);
  }

  Future<Set<String>> getPinnedThreadIds({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pinnedThreadsKey(userId))?.toSet() ?? {};
  }

  Future<Set<String>> getHiddenThreadIds({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenThreadsKey(userId))?.toSet() ?? {};
  }

  Future<void> setThreadHidden({
    required String userId,
    required String threadId,
    required bool hidden,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_hiddenThreadsKey(userId))?.toSet() ?? {};
    if (hidden) {
      ids.add(threadId);
    } else {
      ids.remove(threadId);
    }
    await prefs.setStringList(_hiddenThreadsKey(userId), ids.toList());
  }

  Future<void> setThreadPinned({
    required String userId,
    required String threadId,
    required bool pinned,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_pinnedThreadsKey(userId))?.toSet() ?? {};
    if (pinned) {
      ids.add(threadId);
    } else {
      ids.remove(threadId);
    }
    await prefs.setStringList(_pinnedThreadsKey(userId), ids.toList());
  }

  Future<Set<String>> getPinnedMessageIds({
    required String userId,
    required String threadId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pinnedMessagesKey(userId, threadId))?.toSet() ??
        {};
  }

  Future<void> setMessagePinned({
    required String userId,
    required String threadId,
    required String messageId,
    required bool pinned,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        prefs.getStringList(_pinnedMessagesKey(userId, threadId))?.toSet() ??
        {};
    if (pinned) {
      ids.add(messageId);
    } else {
      ids.remove(messageId);
    }
    await prefs.setStringList(
      _pinnedMessagesKey(userId, threadId),
      ids.toList(),
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

  Future<void> markThreadAsRead(String threadId) async {
    final token = await _requireToken();
    await _apiClient.postJson(
      '/chat/threads/$threadId/read',
      token: token,
      data: {},
    );
  }

  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  }) async {
    await _purgeLegacyContentCache();
    final key = _messagesCacheKey(userId, threadId);
    final memory = sessionPrivateMemoryCache.read<List<ChatMessageModel>>(key);
    if (memory != null) return List<ChatMessageModel>.of(memory);

    final payload = await _readOfflineCache();
    final items = payload[key];
    if (items is! List) return const [];
    final messages = items
        .whereType<Map<String, dynamic>>()
        .map(ChatMessageModel.fromJson)
        .toList();
    sessionPrivateMemoryCache.write(key, messages);
    return messages;
  }

  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  }) async {
    await _purgeLegacyContentCache();
    final key = _messagesCacheKey(userId, threadId);
    sessionPrivateMemoryCache.write(key, List<ChatMessageModel>.of(messages));
    final payload = await _readOfflineCache();
    payload[key] = messages.map((item) => item.toJson()).toList();
    await _writeOfflineCache(payload);
  }

  Future<List<Map<String, dynamic>>> getPendingMessages({
    required String userId,
    required String threadId,
  }) async {
    final payload = await _readOfflineCache();
    final items = payload[_outboxKey(userId, threadId)];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> cachePendingMessage({
    required String userId,
    required String threadId,
    required Map<String, dynamic> message,
  }) async {
    final payload = await _readOfflineCache();
    final key = _outboxKey(userId, threadId);
    final clientMessageId = message['client_message_id']?.toString();
    final items = payload[key] is List
        ? List<dynamic>.of(payload[key] as List)
        : <dynamic>[];
    items.removeWhere(
      (item) =>
          item is Map &&
          item['client_message_id']?.toString() == clientMessageId,
    );
    items.add(Map<String, dynamic>.of(message));
    payload[key] = items;
    await _writeOfflineCache(payload);
  }

  Future<void> removePendingMessage({
    required String userId,
    required String threadId,
    required String clientMessageId,
  }) async {
    final payload = await _readOfflineCache();
    final key = _outboxKey(userId, threadId);
    final items = payload[key];
    if (items is! List) return;
    items.removeWhere(
      (item) =>
          item is Map &&
          item['client_message_id']?.toString() == clientMessageId,
    );
    if (items.isEmpty) {
      payload.remove(key);
    } else {
      payload[key] = items;
    }
    await _writeOfflineCache(payload);
  }

  Future<ChatMediaCacheSettings> getMediaCacheSettings({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ChatMediaCacheSettings(
      autoDownloadMedia: prefs.getBool(_mediaAutoDownloadKey(userId)) ?? true,
      ephemeralDuration:
          prefs.getString(_mediaEphemeralDurationKey(userId)) ?? '7d',
    );
  }

  Future<void> setMediaCacheSettings({
    required String userId,
    required ChatMediaCacheSettings settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _mediaAutoDownloadKey(userId),
      settings.autoDownloadMedia,
    );
    await prefs.setString(
      _mediaEphemeralDurationKey(userId),
      settings.ephemeralDuration,
    );
  }

  Future<int> estimateLocalMediaCacheBytes({required String userId}) async {
    await _purgeLegacyContentCache();
    var total = 0;
    for (final key in sessionPrivateMemoryCache.keys.toList()) {
      if (!key.startsWith(_messagesCachePrefix(userId))) continue;
      final messages = sessionPrivateMemoryCache.read<List<ChatMessageModel>>(
        key,
      );
      for (final message in messages ?? const <ChatMessageModel>[]) {
        if (message.isMedia) {
          total += message.attachmentSizeBytes ?? 0;
        }
      }
    }
    return total;
  }

  Future<int> clearLocalMediaCache({required String userId}) async {
    final keys = sessionPrivateMemoryCache.keys
        .where((key) => key.startsWith(_messagesCachePrefix(userId)))
        .toList();
    for (final key in keys) {
      sessionPrivateMemoryCache.remove(key);
    }
    final preferences = await SharedPreferences.getInstance();
    final legacyRemoved = await purgeLegacyChatContentPreferences(preferences);
    return keys.length + legacyRemoved;
  }

  Future<Uint8List> loadMediaBytes(String url) async {
    final token = await _requireToken();
    final bytes = await _apiClient.getBytes(url, token: token);
    return Uint8List.fromList(bytes);
  }

  Future<ChatMessageModel> sendMessage({
    required String threadId,
    required String content,
    String messageType = 'text',
    String? attachmentFileId,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    int? durationSeconds,
    String? thumbnailUrl,
    String? stickerPack,
    String? clientMessageId,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads/$threadId/messages',
      token: token,
      data: {
        'content': content.trim(),
        'message_type': messageType,
        'attachment_file_id': _nullable(attachmentFileId),
        'attachment_url': _nullable(attachmentUrl),
        'attachment_name': _nullable(attachmentName),
        'attachment_mime_type': _nullable(attachmentMimeType),
        'attachment_size_bytes': attachmentSizeBytes,
        'duration_seconds': durationSeconds,
        'thumbnail_url': _nullable(thumbnailUrl),
        'sticker_pack': _nullable(stickerPack),
        'client_message_id': _nullable(clientMessageId),
      },
    );

    if (response is Map<String, dynamic>) {
      return ChatMessageModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’envoi du message.');
  }

  Future<void> reactToMessage({
    required String threadId,
    required String messageId,
    required String reactionType,
  }) async {
    final token = await _requireToken();
    await _apiClient.postJson(
      '/chat/threads/$threadId/messages/$messageId/reaction',
      token: token,
      data: {'reaction_type': reactionType},
    );
  }

  Future<void> deleteMessageReaction({
    required String threadId,
    required String messageId,
  }) async {
    final token = await _requireToken();
    await _apiClient.delete(
      '/chat/threads/$threadId/messages/$messageId/reaction',
      token: token,
    );
  }

  Future<ChatMessageModel> createPoll({
    required String threadId,
    required String question,
    required List<String> options,
    bool allowsMultiple = false,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads/$threadId/polls',
      token: token,
      data: {
        'question': question.trim(),
        'options': options.map((item) => item.trim()).toList(),
        'allows_multiple': allowsMultiple,
      },
    );
    if (response is Map<String, dynamic>) {
      return ChatMessageModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors de la création du sondage.');
  }

  Future<ChatPollModel> votePoll({
    required String threadId,
    required String pollId,
    required List<String> optionIds,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/chat/threads/$threadId/polls/$pollId/vote',
      token: token,
      data: {'option_ids': optionIds},
    );
    if (response is Map<String, dynamic>) {
      return ChatPollModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors du vote.');
  }

  Future<ChatPollModel> clearPollVote({
    required String threadId,
    required String pollId,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.delete(
      '/chat/threads/$threadId/polls/$pollId/vote',
      token: token,
    );
    if (response is Map<String, dynamic>) {
      return ChatPollModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors de l’annulation du vote.');
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

  Future<List<ChatThreadMemberModel>> getParticipants(String threadId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/chat/threads/$threadId/participants',
      token: token,
    );

    return _extractList(response)
        .whereType<Map<String, dynamic>>()
        .map(ChatThreadMemberModel.fromJson)
        .toList();
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
    String? threadId,
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
        'thread_id': _nullable(threadId),
      },
    );

    if (response is Map<String, dynamic>) {
      return ChatUploadedMediaModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’upload du média.');
  }

  Future<Map<String, dynamic>> _readOfflineCache() async {
    try {
      final raw = await _offlineCache.read();
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        await _offlineCache.delete();
        return <String, dynamic>{};
      }
      final entries = decoded['entries'];
      return entries is Map<String, dynamic>
          ? Map<String, dynamic>.of(entries)
          : <String, dynamic>{};
    } catch (_) {
      try {
        await _offlineCache.delete();
      } catch (_) {}
      return <String, dynamic>{};
    }
  }

  Future<void> _writeOfflineCache(Map<String, dynamic> entries) async {
    try {
      await _offlineCache.write(
        jsonEncode({
          'version': 1,
          'cached_at': DateTime.now().toUtc().toIso8601String(),
          'entries': entries,
        }),
      );
    } catch (_) {
      // A secure-storage failure must not block the online chat.
    }
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

  String _pinnedThreadsKey(String userId) {
    return 'enactspace_chat_pinned_threads_$userId';
  }

  String _hiddenThreadsKey(String userId) {
    return 'enactspace_chat_hidden_threads_$userId';
  }

  String _messagesCacheKey(String userId, String threadId) {
    return '${_messagesCachePrefix(userId)}$threadId';
  }

  String _messagesCachePrefix(String userId) {
    return 'enactspace_chat_messages_${userId}_';
  }

  String _outboxKey(String userId, String threadId) {
    return 'enactspace_chat_outbox_${userId}_$threadId';
  }

  String _pinnedMessagesKey(String userId, String threadId) {
    return 'enactspace_chat_pinned_messages_${userId}_$threadId';
  }

  String _mediaAutoDownloadKey(String userId) {
    return 'enactspace_chat_media_auto_download_$userId';
  }

  String _mediaEphemeralDurationKey(String userId) {
    return 'enactspace_chat_media_ephemeral_duration_$userId';
  }

  Future<void> _purgeLegacyContentCache() {
    return _legacyCachePurge ??= SharedPreferences.getInstance().then(
      purgeLegacyChatContentPreferences,
    );
  }
}
