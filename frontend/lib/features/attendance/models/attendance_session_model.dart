class AttendanceSessionModel {
  final String id;
  final String title;
  final String? description;
  final String? sessionType;
  final String scopeType;
  final String? groupName;
  final String? status;
  final String? scheduledAt;
  final String? startTime;
  final String? endTime;
  final String? eventId;
  final String? poleId;
  final String? projectId;
  final String? qrToken;
  final bool canManage;
  final int expectedCount;
  final int recordedCount;

  const AttendanceSessionModel({
    required this.id,
    required this.title,
    this.description,
    this.sessionType,
    this.scopeType = 'club',
    this.groupName,
    this.status,
    this.scheduledAt,
    this.startTime,
    this.endTime,
    this.eventId,
    this.poleId,
    this.projectId,
    this.qrToken,
    required this.canManage,
    this.expectedCount = 0,
    this.recordedCount = 0,
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
      scopeType: json['scope_type']?.toString() ?? _deriveScope(json),
      groupName: json['group_name']?.toString(),
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
      canManage: json['can_manage'] == true,
      expectedCount:
          int.tryParse(json['expected_count']?.toString() ?? '') ?? 0,
      recordedCount:
          int.tryParse(json['recorded_count']?.toString() ?? '') ?? 0,
    );
  }

  String get typeLabel {
    switch (sessionType) {
      case 'general_meeting':
        return 'Reunion generale';
      case 'pole_meeting':
        return 'Reunion pole';
      case 'project_meeting':
        return 'Reunion projet';
      case 'training':
        return 'Formation';
      case 'field_activity':
      case 'activity':
        return 'Activite terrain';
      case 'event':
        return 'Evenement';
      case 'exceptional':
        return 'Seance exceptionnelle';
      default:
        return sessionType ?? 'Session';
    }
  }

  String get scopeLabel {
    switch (scopeType) {
      case 'club':
        return 'Tout le club';
      case 'pole':
        return 'Pole';
      case 'project':
        return 'Projet';
      case 'group':
        return groupName ?? 'Groupe';
      default:
        return scopeType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'open':
        return 'Ouverte';
      case 'closed':
        return 'Cloturee';
      case 'draft':
        return 'Brouillon';
      case 'archived':
        return 'Archivee';
      case 'scheduled':
        return 'Planifiee';
      default:
        return status ?? 'Non defini';
    }
  }

  String get dateLabel {
    final raw = scheduledAt ?? startTime;

    if (raw == null || raw.isEmpty) {
      return 'Date non definie';
    }

    final date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) {
      return raw;
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year a $hour:$minute';
  }
}

String _deriveScope(Map<String, dynamic> json) {
  if (json['project_id'] != null) return 'project';
  if (json['pole_id'] != null) return 'pole';
  return 'club';
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
