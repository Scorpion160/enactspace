class AttendanceQrTokenModel {
  final String token;
  final DateTime expiresAt;
  final int rotationSeconds;
  final String sessionId;

  const AttendanceQrTokenModel({
    required this.token,
    required this.expiresAt,
    required this.rotationSeconds,
    required this.sessionId,
  });

  factory AttendanceQrTokenModel.fromJson(Map<String, dynamic> json) {
    return AttendanceQrTokenModel(
      token: json['token']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          DateTime.now(),
      rotationSeconds: _asInt(json['rotation_seconds']),
      sessionId: json['session_id']?.toString() ?? '',
    );
  }
}

class AttendanceQrStatusModel {
  final bool qrEnabled;
  final String sessionId;
  final String sessionStatus;
  final int expectedCount;
  final int presentCount;
  final int lateCount;
  final int remainingCount;
  final DateTime? lastScanAt;
  final String? lastScanStatus;

  const AttendanceQrStatusModel({
    required this.qrEnabled,
    required this.sessionId,
    required this.sessionStatus,
    required this.expectedCount,
    required this.presentCount,
    required this.lateCount,
    required this.remainingCount,
    this.lastScanAt,
    this.lastScanStatus,
  });

  factory AttendanceQrStatusModel.fromJson(Map<String, dynamic> json) {
    return AttendanceQrStatusModel(
      qrEnabled: json['qr_enabled'] == true,
      sessionId: json['session_id']?.toString() ?? '',
      sessionStatus: json['session_status']?.toString() ?? 'draft',
      expectedCount: _asInt(json['expected_count']),
      presentCount: _asInt(json['present_count']),
      lateCount: _asInt(json['late_count']),
      remainingCount: _asInt(json['remaining_count']),
      lastScanAt: DateTime.tryParse(json['last_scan_at']?.toString() ?? ''),
      lastScanStatus: json['last_scan_status']?.toString(),
    );
  }

  int get scannedCount => presentCount + lateCount;
}

class AttendanceQrScanResultModel {
  final bool success;
  final String result;
  final String? attendanceStatus;
  final String message;
  final DateTime? recordedAt;

  const AttendanceQrScanResultModel({
    required this.success,
    required this.result,
    this.attendanceStatus,
    required this.message,
    this.recordedAt,
  });

  factory AttendanceQrScanResultModel.fromJson(Map<String, dynamic> json) {
    return AttendanceQrScanResultModel(
      success: json['success'] == true,
      result: json['result']?.toString() ?? 'unknown',
      attendanceStatus: json['attendance_status']?.toString(),
      message: json['message']?.toString() ?? 'Pointage QR traite.',
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? ''),
    );
  }
}

class AttendanceQrAuditLogModel {
  final String id;
  final String? userId;
  final String action;
  final String? result;
  final String? recordId;
  final DateTime createdAt;

  const AttendanceQrAuditLogModel({
    required this.id,
    required this.userId,
    required this.action,
    required this.result,
    required this.recordId,
    required this.createdAt,
  });

  factory AttendanceQrAuditLogModel.fromJson(Map<String, dynamic> json) {
    final newValue = json['new_value'] is Map
        ? Map<String, dynamic>.from(json['new_value'] as Map)
        : const <String, dynamic>{};
    return AttendanceQrAuditLogModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      action: json['action']?.toString() ?? '',
      result: newValue['result']?.toString(),
      recordId: newValue['record_id']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
