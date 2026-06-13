class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String userId;
  final String status;
  final String? checkinTime;
  final String? justification;
  final int? penaltyAmount;

  const AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.status,
    this.checkinTime,
    this.justification,
    this.penaltyAmount,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      checkinTime: json['checkin_time']?.toString(),
      justification: json['justification']?.toString(),
      penaltyAmount: json['penalty_amount'] is int
          ? json['penalty_amount'] as int
          : int.tryParse(json['penalty_amount']?.toString() ?? ''),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'present':
        return 'Présent';
      case 'retard':
        return 'Retard';
      case 'absent_justifie':
      case 'absence_justifiee':
        return 'Absence justifiée';
      case 'absent_non_justifie':
      case 'absence_non_justifiee':
        return 'Absence non justifiée';
      default:
        return status;
    }
  }
}
