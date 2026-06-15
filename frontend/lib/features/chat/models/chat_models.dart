import '../../../core/api/api_client.dart';

class ChatContactModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String status;
  final String? photoUrl;

  const ChatContactModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.status,
    required this.photoUrl,
  });

  factory ChatContactModel.fromJson(Map<String, dynamic> json) {
    return ChatContactModel(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      photoUrl: json['photo_url']?.toString(),
    );
  }

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return name.isNotEmpty ? name : email;
  }
}

class ChatThreadModel {
  final String id;
  final String? title;
  final String? serverDisplayTitle;
  final String? avatarUrl;
  final String threadType;
  final String? scopeType;
  final String? scopeId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int participantsCount;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String currentUserRole;
  final List<ChatThreadMemberModel> participantsPreview;

  const ChatThreadModel({
    required this.id,
    required this.title,
    required this.serverDisplayTitle,
    required this.avatarUrl,
    required this.threadType,
    required this.scopeType,
    required this.scopeId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.participantsCount,
    required this.unreadCount,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.currentUserRole,
    required this.participantsPreview,
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    final participants = json['participants_preview'] is List
        ? (json['participants_preview'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ChatThreadMemberModel.fromJson)
              .toList()
        : <ChatThreadMemberModel>[];

    return ChatThreadModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      serverDisplayTitle: json['display_title']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      threadType: json['thread_type']?.toString() ?? 'group',
      scopeType: json['scope_type']?.toString(),
      scopeId: json['scope_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      participantsCount:
          int.tryParse(json['participants_count']?.toString() ?? '') ?? 0,
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '') ?? 0,
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: DateTime.tryParse(
        json['last_message_at']?.toString() ?? '',
      ),
      currentUserRole: json['current_user_role']?.toString() ?? 'member',
      participantsPreview: participants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'display_title': serverDisplayTitle,
      'avatar_url': avatarUrl,
      'thread_type': threadType,
      'scope_type': scopeType,
      'scope_id': scopeId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'participants_count': participantsCount,
      'unread_count': unreadCount,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'current_user_role': currentUserRole,
      'participants_preview': participantsPreview
          .map((participant) => participant.toJson())
          .toList(),
    };
  }

  String get displayTitle {
    if (serverDisplayTitle != null && serverDisplayTitle!.trim().isNotEmpty) {
      return serverDisplayTitle!.trim();
    }
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    if (threadType == 'direct') return 'Discussion directe';
    if (threadType == 'club') return 'Club Enactus';
    return 'Conversation';
  }

  bool get canManageMembers =>
      currentUserRole == 'owner' || currentUserRole == 'admin';

  String? get absoluteAvatarUrl {
    final url = avatarUrl;
    if (url == null || url.trim().isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiClient.serverUrl}$url';
  }
}

class ChatThreadMemberModel {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String status;
  final String? photoUrl;
  final String participantRole;

  const ChatThreadMemberModel({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.status,
    required this.photoUrl,
    required this.participantRole,
  });

  factory ChatThreadMemberModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadMemberModel(
      userId: json['user_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      participantRole: json['participant_role']?.toString() ?? 'member',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'status': status,
      'photo_url': photoUrl,
      'participant_role': participantRole,
    };
  }

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return name.isNotEmpty ? name : email;
  }
}

class ChatMessageModel {
  final String id;
  final String threadId;
  final String authorId;
  final String content;
  final String messageType;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final String? stickerPack;
  final int reactionsCount;
  final Map<String, int> reactionsSummary;
  final String? currentUserReaction;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.content,
    required this.messageType,
    required this.attachmentUrl,
    required this.attachmentName,
    required this.attachmentMimeType,
    required this.attachmentSizeBytes,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.stickerPack,
    required this.reactionsCount,
    required this.reactionsSummary,
    required this.currentUserReaction,
    required this.createdAt,
    required this.editedAt,
    required this.deletedAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      threadId: json['thread_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      attachmentUrl: json['attachment_url']?.toString(),
      attachmentName: json['attachment_name']?.toString(),
      attachmentMimeType: json['attachment_mime_type']?.toString(),
      attachmentSizeBytes: int.tryParse(
        json['attachment_size_bytes']?.toString() ?? '',
      ),
      durationSeconds: int.tryParse(json['duration_seconds']?.toString() ?? ''),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      stickerPack: json['sticker_pack']?.toString(),
      reactionsCount:
          int.tryParse(json['reactions_count']?.toString() ?? '') ?? 0,
      reactionsSummary: _parseReactionsSummary(json['reactions_summary']),
      currentUserReaction: json['current_user_reaction']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      editedAt: DateTime.tryParse(json['edited_at']?.toString() ?? ''),
      deletedAt: DateTime.tryParse(json['deleted_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thread_id': threadId,
      'author_id': authorId,
      'content': content,
      'message_type': messageType,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_mime_type': attachmentMimeType,
      'attachment_size_bytes': attachmentSizeBytes,
      'duration_seconds': durationSeconds,
      'thumbnail_url': thumbnailUrl,
      'sticker_pack': stickerPack,
      'reactions_count': reactionsCount,
      'reactions_summary': reactionsSummary,
      'current_user_reaction': currentUserReaction,
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  bool get isMedia => messageType != 'text';

  String? get absoluteAttachmentUrl {
    final url = attachmentUrl;
    if (url == null || url.trim().isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiClient.serverUrl}$url';
  }

  String get attachmentLabel {
    final name = attachmentName?.trim();
    if (name != null && name.isNotEmpty) return name;

    switch (messageType) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Vidéo';
      case 'audio':
        return 'Message audio';
      case 'document':
        return 'Document';
      case 'sticker':
        return 'Sticker';
      default:
        return 'Média';
    }
  }
}

Map<String, int> _parseReactionsSummary(dynamic value) {
  if (value is! Map) return {};

  return value.map((key, count) {
    return MapEntry(key.toString(), int.tryParse(count?.toString() ?? '') ?? 0);
  });
}

class ChatUploadedMediaModel {
  final String url;
  final String fileName;
  final String? contentType;
  final int sizeBytes;
  final String messageType;

  const ChatUploadedMediaModel({
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.messageType,
  });

  factory ChatUploadedMediaModel.fromJson(Map<String, dynamic> json) {
    return ChatUploadedMediaModel(
      url: json['url']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      contentType: json['content_type']?.toString(),
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
      messageType: json['message_type']?.toString() ?? 'document',
    );
  }

  String get absoluteUrl {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiClient.serverUrl}$url';
  }
}
