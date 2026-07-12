class AttendanceNfcTagModel {
  final String id;
  final String memberId;
  final String? tagLabel;
  final String tagType;
  final String status;
  final String maskedTag;
  final String? assignedById;
  final DateTime? assignedAt;
  final String? revokedById;
  final DateTime? revokedAt;
  final DateTime? lastUsedAt;

  const AttendanceNfcTagModel({
    required this.id,
    required this.memberId,
    this.tagLabel,
    required this.tagType,
    required this.status,
    required this.maskedTag,
    this.assignedById,
    this.assignedAt,
    this.revokedById,
    this.revokedAt,
    this.lastUsedAt,
  });

  factory AttendanceNfcTagModel.fromJson(Map<String, dynamic> json) {
    return AttendanceNfcTagModel(
      id: json['id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      tagLabel: json['tag_label']?.toString(),
      tagType: json['tag_type']?.toString() ?? 'nfc_uid',
      status: json['status']?.toString() ?? 'active',
      maskedTag: json['masked_tag']?.toString() ?? 'Badge ****',
      assignedById: json['assigned_by_id']?.toString(),
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? ''),
      revokedById: json['revoked_by_id']?.toString(),
      revokedAt: DateTime.tryParse(json['revoked_at']?.toString() ?? ''),
      lastUsedAt: DateTime.tryParse(json['last_used_at']?.toString() ?? ''),
    );
  }

  bool get isActive => status == 'active';
}

class AttendanceNfcCheckInResultModel {
  final bool success;
  final String result;
  final String? memberDisplayName;
  final String? attendanceStatus;
  final String message;
  final DateTime? recordedAt;

  const AttendanceNfcCheckInResultModel({
    required this.success,
    required this.result,
    this.memberDisplayName,
    this.attendanceStatus,
    required this.message,
    this.recordedAt,
  });

  factory AttendanceNfcCheckInResultModel.fromJson(Map<String, dynamic> json) {
    return AttendanceNfcCheckInResultModel(
      success: json['success'] == true,
      result: json['result']?.toString() ?? 'unknown',
      memberDisplayName: json['member_display_name']?.toString(),
      attendanceStatus: json['attendance_status']?.toString(),
      message: json['message']?.toString() ?? 'Pointage NFC traite.',
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? ''),
    );
  }
}
