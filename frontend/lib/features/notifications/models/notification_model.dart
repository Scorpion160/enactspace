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
    if (source.contains('absence')) return '/attendance';
    if (source.contains('payment') ||
        source.contains('finance') ||
        source.contains('fee')) {
      return '/finance';
    }
    if (source.contains('document')) return '/documents';
    if (source.contains('recruitment') || source.contains('application')) {
      return '/recruitment';
    }
    if (source.contains('post') || source.contains('communication')) {
      return '/posts';
    }
    if (source.contains('announcement')) return '/posts';
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
      case 'task_late':
        return 'Tache en retard';
      case 'new_announcement':
        return 'Annonce';
      case 'event_scheduled':
        return 'Evenement';
      case 'absence_recorded':
        return 'Absence';
      case 'fee_due':
        return 'Cotisation';
      case 'payment_validated':
        return 'Paiement valide';
      case 'application_received':
        return 'Candidature recue';
      case 'recruitment_update':
        return 'Recrutement';
      case 'document_shared':
        return 'Document partage';
      case 'mentorship_assigned':
        return 'Mentorat';
      case 'chat_message':
        return 'Nouveau message';
      case 'post_comment':
        return 'Nouveau commentaire';
      case 'post_reaction':
        return 'Nouvelle réaction';
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
