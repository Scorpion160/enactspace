class UserPreferences {
  final String locale;
  final String theme;
  final bool inAppNotifications;
  final bool emailNotifications;
  final bool pushNotifications;

  const UserPreferences({
    required this.locale,
    required this.theme,
    required this.inAppNotifications,
    required this.emailNotifications,
    required this.pushNotifications,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      locale: json['locale']?.toString() ?? 'fr',
      theme: json['theme']?.toString() ?? 'system',
      inAppNotifications: json['notification_in_app_enabled'] == true,
      emailNotifications: json['notification_email_enabled'] == true,
      pushNotifications: json['notification_push_enabled'] == true,
    );
  }
}

class AccountDataExport {
  final Map<String, dynamic> payload;

  const AccountDataExport(this.payload);

  String? get generatedAt => payload['metadata'] is Map
      ? (payload['metadata'] as Map)['generated_at']?.toString()
      : null;
}

class AccountDeletionRequest {
  final String id;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? cancelledAt;
  final String? reason;

  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.cancelledAt,
    this.reason,
  });

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      requestedAt:
          DateTime.tryParse(json['requested_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      processedAt: DateTime.tryParse(json['processed_at']?.toString() ?? ''),
      cancelledAt: DateTime.tryParse(json['cancelled_at']?.toString() ?? ''),
      reason: json['reason']?.toString(),
    );
  }

  bool get canCancel => status == 'pending';
  bool get canRequestAgain => status == 'cancelled' || status == 'rejected';

  String get statusLabel => switch (status) {
    'pending' => 'En attente',
    'cancelled' => 'Annulée',
    'approved' => 'Approuvée',
    'completed' => 'Terminée',
    'rejected' => 'Refusée',
    _ => 'État inconnu',
  };
}
