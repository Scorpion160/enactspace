class ProjectMemberModel {
  final String id;
  final String projectId;
  final String userId;
  final String position;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isActive;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String status;

  const ProjectMemberModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.position,
    required this.joinedAt,
    required this.leftAt,
    required this.isActive,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.status,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      position: json['position']?.toString() ?? 'membre',
      joinedAt:
          DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      leftAt: DateTime.tryParse(json['left_at']?.toString() ?? ''),
      isActive: json['is_active'] != false,
      displayName: json['display_name']?.toString() ?? 'Membre projet',
      email: json['email']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      status: json['status']?.toString() ?? 'active',
    );
  }

  String get positionLabel {
    switch (position) {
      case 'chef_projet':
        return 'Chef de projet';
      case 'adjoint_chef_projet':
        return 'Adjoint chef de projet';
      default:
        return 'Membre projet';
    }
  }
}
