class MentorshipModel {
  final String id;
  final String alumniId;
  final String? projectId;
  final String? poleId;
  final String? assignedBy;
  final String? title;
  final String? objective;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MentorshipModel({
    required this.id,
    required this.alumniId,
    required this.projectId,
    required this.poleId,
    required this.assignedBy,
    required this.title,
    required this.objective,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MentorshipModel.fromJson(Map<String, dynamic> json) {
    return MentorshipModel(
      id: json['id']?.toString() ?? '',
      alumniId: json['alumni_id']?.toString() ?? '',
      projectId: json['project_id']?.toString(),
      poleId: json['pole_id']?.toString(),
      assignedBy: json['assigned_by']?.toString(),
      title: json['title']?.toString(),
      objective: json['objective']?.toString(),
      status: json['status']?.toString() ?? 'active',
      startedAt:
          DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['ended_at']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'paused':
        return 'En pause';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return 'Actif';
    }
  }
}
