class AttendanceExpectedMemberModel {
  final String id;
  final String sessionId;
  final String userId;
  final bool isRequired;
  final String? createdAt;

  const AttendanceExpectedMemberModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.isRequired,
    this.createdAt,
  });

  factory AttendanceExpectedMemberModel.fromJson(Map<String, dynamic> json) {
    return AttendanceExpectedMemberModel(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      isRequired: json['is_required'] is bool
          ? json['is_required'] as bool
          : true,
      createdAt: json['created_at']?.toString(),
    );
  }
}
