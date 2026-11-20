class ApplicationHistoryModel {
  final String id;
  final String kind;
  final String title;
  final DateTime occurredAt;
  final String actorName;
  final String? fromStatus;
  final String? toStatus;
  final DateTime? scheduledFor;

  const ApplicationHistoryModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.occurredAt,
    required this.actorName,
    this.fromStatus,
    this.toStatus,
    this.scheduledFor,
  });

  static ApplicationHistoryModel? tryParse(Map<String, dynamic> json) {
    final occurredAt = DateTime.tryParse(json['occurred_at']?.toString() ?? '');
    if (occurredAt == null) return null;
    return ApplicationHistoryModel(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Mise à jour du dossier',
      occurredAt: occurredAt.toLocal(),
      actorName: json['actor_name']?.toString() ?? 'L’équipe recrutement',
      fromStatus: json['from_status']?.toString(),
      toStatus: json['to_status']?.toString(),
      scheduledFor: DateTime.tryParse(
        json['scheduled_for']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
