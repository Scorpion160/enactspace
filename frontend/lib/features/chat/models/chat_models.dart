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
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.content,
    required this.messageType,
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
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
