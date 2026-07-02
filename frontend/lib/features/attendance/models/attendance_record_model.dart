class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String userId;
  final String status;
  final String? checkinTime;
  final String? arrivalTime;
  final int? delayMinutes;
  final String? justification;
  final String justificationStatus;
  final String? justificationReason;
  final String? justificationFileId;
  final String? justificationFileUrl;
  final int? penaltyAmount;

  const AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.status,
    this.checkinTime,
    this.arrivalTime,
    this.delayMinutes,
    this.justification,
    this.justificationStatus = 'not_submitted',
    this.justificationReason,
    this.justificationFileId,
    this.justificationFileUrl,
    this.penaltyAmount,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      userId:
          json['user_id']?.toString() ?? json['member_id']?.toString() ?? '',
      status: _normalizeStatus(json['status']?.toString() ?? ''),
      checkinTime: json['checkin_time']?.toString(),
      arrivalTime:
          json['arrival_time']?.toString() ?? json['checkin_time']?.toString(),
      delayMinutes: int.tryParse(json['delay_minutes']?.toString() ?? ''),
      justification: json['justification']?.toString(),
      justificationStatus:
          json['justification_status']?.toString() ?? 'not_submitted',
      justificationReason: json['justification_reason']?.toString(),
      justificationFileId: json['justification_file_id']?.toString(),
      justificationFileUrl: json['justification_file_url']?.toString(),
      penaltyAmount: json['penalty_amount'] is int
          ? json['penalty_amount'] as int
          : int.tryParse(json['penalty_amount']?.toString() ?? ''),
    );
  }

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';
  bool get isJustifiedAbsence => status == 'justified_absence';
  bool get isExcused => status == 'excused';

  String get statusLabel {
    switch (status) {
      case 'present':
        return 'Present';
      case 'late':
        return 'En retard';
      case 'absent':
        return 'Absent';
      case 'justified_absence':
        return 'Absence justifiee';
      case 'excused':
        return 'Excuse';
      case 'not_recorded':
        return 'Non renseigne';
      default:
        return status;
    }
  }
}

String _normalizeStatus(String value) {
  switch (value) {
    case 'retard':
      return 'late';
    case 'absent_justifie':
    case 'absence_justifiee':
      return 'justified_absence';
    case 'absent_non_justifie':
    case 'absence_non_justifiee':
    case 'absence':
      return 'absent';
    case 'excuse':
    case 'mission_externe':
      return 'excused';
    default:
      return value;
  }
}
