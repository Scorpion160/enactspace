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

  const ChatThreadModel({
    required this.id,
    required this.title,
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
  });

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    return ChatThreadModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
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
    };
  }

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    if (threadType == 'direct') return 'Discussion directe';
    if (threadType == 'club') return 'Club Enactus';
    return 'Conversation';
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
