import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/chat_models.dart';
import 'chat_service.dart';

abstract interface class ChatGateway {
  Stream<Map<String, dynamic>> get events;

  Future<void> startRealtime();
  Future<void> disposeRealtime();
  void sendRealtime(Map<String, dynamic> event);

  Future<UserExperience> getCurrentUser();
  Future<List<PoleModel>> getPoles();
  Future<List<ProjectModel>> getProjects();
  Future<List<ChatContactModel>> getContacts({String? search});
  Future<List<ChatThreadModel>> getThreads();
  Future<List<ChatThreadModel>> getCachedThreads({required String userId});
  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  });
  Future<Set<String>> getPinnedThreadIds({required String userId});
  Future<Set<String>> getHiddenThreadIds({required String userId});
  Future<void> setThreadHidden({
    required String userId,
    required String threadId,
    required bool hidden,
  });
  Future<void> setThreadPinned({
    required String userId,
    required String threadId,
    required bool pinned,
  });
  Future<Set<String>> getPinnedMessageIds({
    required String userId,
    required String threadId,
  });
  Future<void> setMessagePinned({
    required String userId,
    required String threadId,
    required String messageId,
    required bool pinned,
  });
  Future<ChatThreadModel> createThread({
    String? title,
    required String threadType,
    required List<String> participantIds,
    String? scopeType,
    String? scopeId,
  });
  Future<List<ChatMessageModel>> getMessages(String threadId);
  Future<void> markThreadAsRead(String threadId);
  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  });
  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  });
  Future<ChatMediaCacheSettings> getMediaCacheSettings({
    required String userId,
  });
  Future<void> setMediaCacheSettings({
    required String userId,
    required ChatMediaCacheSettings settings,
  });
  Future<int> estimateLocalMediaCacheBytes({required String userId});
  Future<int> clearLocalMediaCache({required String userId});
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
  });
  Future<void> reactToMessage({
    required String threadId,
    required String messageId,
    required String reactionType,
  });
  Future<void> deleteMessageReaction({
    required String threadId,
    required String messageId,
  });
  Future<void> addParticipants({
    required String threadId,
    required List<String> userIds,
  });
  Future<List<ChatThreadMemberModel>> getParticipants(String threadId);
  Future<void> updateParticipantRole({
    required String threadId,
    required String userId,
    required String participantRole,
  });
  Future<void> removeParticipant({
    required String threadId,
    required String userId,
  });
  Future<void> deleteThread(String threadId);
  Future<ChatUploadedMediaModel> uploadMediaBase64({
    required String fileName,
    required String dataBase64,
    required String messageType,
    String? threadId,
    String? contentType,
  });
}

class ApiChatGateway implements ChatGateway {
  final ChatService _chat;
  final AuthService _auth;
  final PolesService _poles;
  final ProjectsService _projects;
  final RealtimeService _realtime;

  ApiChatGateway({
    ChatService? chatService,
    AuthService? authService,
    PolesService? polesService,
    ProjectsService? projectsService,
    RealtimeService? realtimeService,
  }) : _chat = chatService ?? ChatService(),
       _auth = authService ?? AuthService(),
       _poles = polesService ?? PolesService(),
       _projects = projectsService ?? ProjectsService(),
       _realtime = realtimeService ?? RealtimeService();

  @override
  Stream<Map<String, dynamic>> get events => _realtime.events;
  @override
  Future<void> startRealtime() => _realtime.start();
  @override
  Future<void> disposeRealtime() => _realtime.dispose();
  @override
  void sendRealtime(Map<String, dynamic> event) => _realtime.send(event);
  @override
  Future<UserExperience> getCurrentUser() async =>
      UserExperience.fromJson(await _auth.getCurrentUser());
  @override
  Future<List<PoleModel>> getPoles() => _poles.getPoles();
  @override
  Future<List<ProjectModel>> getProjects() => _projects.getProjects();
  @override
  Future<List<ChatContactModel>> getContacts({String? search}) =>
      _chat.getContacts(search: search);
  @override
  Future<List<ChatThreadModel>> getThreads() => _chat.getThreads();
  @override
  Future<List<ChatThreadModel>> getCachedThreads({required String userId}) =>
      _chat.getCachedThreads(userId: userId);
  @override
  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  }) => _chat.cacheThreads(userId: userId, threads: threads);
  @override
  Future<Set<String>> getPinnedThreadIds({required String userId}) =>
      _chat.getPinnedThreadIds(userId: userId);
  @override
  Future<Set<String>> getHiddenThreadIds({required String userId}) =>
      _chat.getHiddenThreadIds(userId: userId);
  @override
  Future<void> setThreadHidden({
    required String userId,
    required String threadId,
    required bool hidden,
  }) =>
      _chat.setThreadHidden(userId: userId, threadId: threadId, hidden: hidden);
  @override
  Future<void> setThreadPinned({
    required String userId,
    required String threadId,
    required bool pinned,
  }) =>
      _chat.setThreadPinned(userId: userId, threadId: threadId, pinned: pinned);
  @override
  Future<Set<String>> getPinnedMessageIds({
    required String userId,
    required String threadId,
  }) => _chat.getPinnedMessageIds(userId: userId, threadId: threadId);
  @override
  Future<void> setMessagePinned({
    required String userId,
    required String threadId,
    required String messageId,
    required bool pinned,
  }) => _chat.setMessagePinned(
    userId: userId,
    threadId: threadId,
    messageId: messageId,
    pinned: pinned,
  );
  @override
  Future<ChatThreadModel> createThread({
    String? title,
    required String threadType,
    required List<String> participantIds,
    String? scopeType,
    String? scopeId,
  }) => _chat.createThread(
    title: title,
    threadType: threadType,
    participantIds: participantIds,
    scopeType: scopeType,
    scopeId: scopeId,
  );
  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) =>
      _chat.getMessages(threadId);
  @override
  Future<void> markThreadAsRead(String threadId) =>
      _chat.markThreadAsRead(threadId);
  @override
  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  }) => _chat.getCachedMessages(userId: userId, threadId: threadId);
  @override
  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  }) => _chat.cacheMessages(
    userId: userId,
    threadId: threadId,
    messages: messages,
  );
  @override
  Future<ChatMediaCacheSettings> getMediaCacheSettings({
    required String userId,
  }) => _chat.getMediaCacheSettings(userId: userId);
  @override
  Future<void> setMediaCacheSettings({
    required String userId,
    required ChatMediaCacheSettings settings,
  }) => _chat.setMediaCacheSettings(userId: userId, settings: settings);
  @override
  Future<int> estimateLocalMediaCacheBytes({required String userId}) =>
      _chat.estimateLocalMediaCacheBytes(userId: userId);
  @override
  Future<int> clearLocalMediaCache({required String userId}) =>
      _chat.clearLocalMediaCache(userId: userId);
  @override
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
  }) => _chat.sendMessage(
    threadId: threadId,
    content: content,
    messageType: messageType,
    attachmentFileId: attachmentFileId,
    attachmentUrl: attachmentUrl,
    attachmentName: attachmentName,
    attachmentMimeType: attachmentMimeType,
    attachmentSizeBytes: attachmentSizeBytes,
    durationSeconds: durationSeconds,
    thumbnailUrl: thumbnailUrl,
    stickerPack: stickerPack,
  );
  @override
  Future<void> reactToMessage({
    required String threadId,
    required String messageId,
    required String reactionType,
  }) => _chat.reactToMessage(
    threadId: threadId,
    messageId: messageId,
    reactionType: reactionType,
  );
  @override
  Future<void> deleteMessageReaction({
    required String threadId,
    required String messageId,
  }) => _chat.deleteMessageReaction(threadId: threadId, messageId: messageId);
  @override
  Future<void> addParticipants({
    required String threadId,
    required List<String> userIds,
  }) => _chat.addParticipants(threadId: threadId, userIds: userIds);
  @override
  Future<List<ChatThreadMemberModel>> getParticipants(String threadId) =>
      _chat.getParticipants(threadId);
  @override
  Future<void> updateParticipantRole({
    required String threadId,
    required String userId,
    required String participantRole,
  }) => _chat.updateParticipantRole(
    threadId: threadId,
    userId: userId,
    participantRole: participantRole,
  );
  @override
  Future<void> removeParticipant({
    required String threadId,
    required String userId,
  }) => _chat.removeParticipant(threadId: threadId, userId: userId);
  @override
  Future<void> deleteThread(String threadId) => _chat.deleteThread(threadId);
  @override
  Future<ChatUploadedMediaModel> uploadMediaBase64({
    required String fileName,
    required String dataBase64,
    required String messageType,
    String? threadId,
    String? contentType,
  }) => _chat.uploadMediaBase64(
    fileName: fileName,
    dataBase64: dataBase64,
    messageType: messageType,
    threadId: threadId,
    contentType: contentType,
  );
}
