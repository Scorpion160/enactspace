class SupportMessage {
  final String id;
  final String? authorId;
  final String message;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.authorId,
    required this.message,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
    id: json['id']?.toString() ?? '',
    authorId: json['author_id']?.toString(),
    message: json['message']?.toString() ?? '',
    createdAt:
        _helpTime(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class SupportTicket {
  final String id;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final DateTime updatedAt;
  final String? userId, assignedToId, requesterName;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.updatedAt,
    this.messages = const [],
    this.userId,
    this.assignedToId,
    this.requesterName,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id']?.toString() ?? '',
    subject: json['subject']?.toString() ?? '',
    category: json['category']?.toString() ?? 'general',
    status: json['status']?.toString() ?? 'open',
    priority: json['priority']?.toString() ?? 'normal',
    updatedAt:
        _helpTime(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    userId: json['user_id']?.toString(),
    assignedToId: json['assigned_to_id']?.toString(),
    requesterName: json['requester_name']?.toString(),
    messages: (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromJson)
        .toList(),
  );

  SupportTicket withMessages(List<SupportMessage> value) => SupportTicket(
    id: id,
    subject: subject,
    category: category,
    status: status,
    priority: priority,
    updatedAt: updatedAt,
    messages: value,
    userId: userId,
    assignedToId: assignedToId,
    requesterName: requesterName,
  );
  bool get canReply => status != 'closed';

  String get categoryLabel => switch (category) {
    'account' => 'Compte',
    'access' => 'Accès',
    'technical' => 'Problème technique',
    'billing' => 'Paiement',
    'other' => 'Autre',
    _ => 'Question générale',
  };

  String get statusLabel => switch (status) {
    'in_progress' => 'En cours',
    'resolved' => 'Résolu',
    'closed' => 'Fermé',
    _ => 'Ouvert',
  };

  String get priorityLabel => switch (priority) {
    'low' => 'Faible',
    'high' => 'Élevée',
    'urgent' => 'Urgente',
    _ => 'Normale',
  };
}

class ProductFeedback {
  final String? publicReply;
  final DateTime? updatedAt;
  final String id;
  final String category;
  final String message;
  final int? rating;
  final String status;
  final DateTime createdAt;

  const ProductFeedback({
    required this.id,
    required this.category,
    required this.message,
    required this.rating,
    required this.status,
    required this.createdAt,
    this.publicReply,
    this.updatedAt,
  });

  factory ProductFeedback.fromJson(Map<String, dynamic> json) =>
      ProductFeedback(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? 'other',
        publicReply: json['public_reply']?.toString(),
        updatedAt: _helpTime(json['updated_at']),
        message: json['message']?.toString() ?? '',
        rating: json['rating'] as int?,
        status: json['status']?.toString() ?? 'new',
        createdAt:
            _helpTime(json['created_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  String get statusLabel => switch (status) {
    'reviewed' => 'Étudié',
    'planned' => 'Prévu',
    'closed' => 'Clôturé',
    _ => 'Reçu',
  };
  String get categoryLabel => switch (category) {
    'bug' => 'Problème',
    'idea' => 'Idée',
    'usability' => 'Facilité d’utilisation',
    _ => 'Autre',
  };
}

DateTime? _helpTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return null;
  final explicit = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text);
  return DateTime.tryParse(explicit ? text : '${text}Z');
}
