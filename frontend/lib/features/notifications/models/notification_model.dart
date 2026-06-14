class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String? message;
  final String type;
  final bool isRead;
  final String? relatedType;
  final String? relatedId;
  final String? readAt;
  final String? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    this.message,
    required this.type,
    required this.isRead,
    this.relatedType,
    this.relatedId,
    this.readAt,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString(),
      type: json['type']?.toString() ?? 'system',
      isRead: json['is_read'] == true,
      relatedType: json['related_type']?.toString(),
      relatedId: json['related_id']?.toString(),
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  NotificationModel copyWith({bool? isRead, String? readAt}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedType: relatedType,
      relatedId: relatedId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  String? get routePath {
    final source =
        (relatedType == null || relatedType!.isEmpty ? type : relatedType!)
            .toLowerCase();

    if (source.contains('task')) return '/tasks';
    if (source.contains('attendance') || source.contains('presence')) {
      return '/attendance';
    }
    if (source.contains('payment') || source.contains('finance')) {
      return '/finance';
    }
    if (source.contains('document')) return '/documents';
    if (source.contains('recruitment')) return '/recruitment';
    if (source.contains('post') || source.contains('communication')) {
      return '/posts';
    }
    if (source.contains('chat') || source.contains('message')) return '/chat';
    if (source.contains('event')) return '/events';
    if (source.contains('project')) return '/projects';
    if (source.contains('pole')) return '/poles';

    return null;
  }

  String get typeLabel {
    switch (type) {
      case 'task_assigned':
        return 'Tâche assignée';
      case 'deadline_near':
        return 'Échéance proche';
      case 'attendance':
        return 'Présence';
      case 'payment':
        return 'Paiement';
      case 'document':
        return 'Document';
      case 'recruitment':
        return 'Recrutement';
      case 'system':
        return 'Système';
      default:
        return type;
    }
  }

  String get createdAtLabel {
    if (createdAt == null || createdAt!.isEmpty) return 'Date inconnue';

    final date = DateTime.tryParse(createdAt!);
    if (date == null) return createdAt!;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year à $hour:$minute';
  }
}
