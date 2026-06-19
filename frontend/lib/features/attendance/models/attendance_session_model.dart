class AttendanceSessionModel {
  final String id;
  final String title;
  final String? description;
  final String? sessionType;
  final String? status;
  final String? scheduledAt;
  final String? startTime;
  final String? endTime;
  final String? eventId;
  final String? poleId;
  final String? projectId;
  final String? qrToken;

  const AttendanceSessionModel({
    required this.id,
    required this.title,
    this.description,
    this.sessionType,
    this.status,
    this.scheduledAt,
    this.startTime,
    this.endTime,
    this.eventId,
    this.poleId,
    this.projectId,
    this.qrToken,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    final isClosed = json['is_closed'] == true;
    final checkinStart = json['checkin_start']?.toString();
    final scheduledAt = json['scheduled_at']?.toString();

    return AttendanceSessionModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Session sans titre',
      description: json['description']?.toString(),
      sessionType: json['session_type']?.toString(),
      status:
          json['status']?.toString() ??
          _deriveStatus(
            isClosed: isClosed,
            checkinStart: checkinStart,
            scheduledAt: scheduledAt,
          ),
      scheduledAt: scheduledAt,
      startTime: json['start_time']?.toString() ?? checkinStart,
      endTime: json['end_time']?.toString() ?? json['checkin_end']?.toString(),
      eventId: json['event_id']?.toString(),
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      qrToken: json['qr_token']?.toString(),
    );
  }

  String get typeLabel {
    switch (sessionType) {
      case 'general_meeting':
        return 'Réunion générale';
      case 'pole_meeting':
        return 'Réunion pôle';
      case 'project_meeting':
        return 'Réunion projet';
      case 'training':
        return 'Formation';
      case 'activity':
        return 'Activité';
      default:
        return sessionType ?? 'Session';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Ouverte';
      case 'closed':
        return 'Clôturée';
      case 'scheduled':
        return 'Planifiée';
      default:
        return status ?? 'Non défini';
    }
  }

  String get dateLabel {
    final raw = scheduledAt ?? startTime;

    if (raw == null || raw.isEmpty) {
      return 'Date non définie';
    }

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw;
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year à $hour:$minute';
  }
}

String _deriveStatus({
  required bool isClosed,
  required String? checkinStart,
  required String? scheduledAt,
}) {
  if (isClosed) return 'closed';

  final start = DateTime.tryParse(checkinStart ?? '');
  if (start != null && !start.isAfter(DateTime.now())) return 'open';

  final scheduled = DateTime.tryParse(scheduledAt ?? '');
  if (scheduled != null && !scheduled.isAfter(DateTime.now())) return 'open';

  return 'scheduled';
}
