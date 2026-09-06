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
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class SupportTicket {
  final String id;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final DateTime updatedAt;
  final List<SupportMessage> messages;

  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.updatedAt,
    this.messages = const [],
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id']?.toString() ?? '',
    subject: json['subject']?.toString() ?? '',
    category: json['category']?.toString() ?? 'general',
    status: json['status']?.toString() ?? 'open',
    priority: json['priority']?.toString() ?? 'normal',
    updatedAt:
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    messages: (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromJson)
        .toList(),
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
  });

  factory ProductFeedback.fromJson(Map<String, dynamic> json) =>
      ProductFeedback(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? 'other',
        message: json['message']?.toString() ?? '',
        rating: json['rating'] as int?,
        status: json['status']?.toString() ?? 'new',
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  String get categoryLabel => switch (category) {
    'bug' => 'Problème',
    'idea' => 'Idée',
    'usability' => 'Facilité d’utilisation',
    _ => 'Autre',
  };
}
