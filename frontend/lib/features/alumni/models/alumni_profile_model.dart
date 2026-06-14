class AlumniProfileModel {
  final String id;
  final String userId;
  final int? graduationYear;
  final String? currentCompany;
  final String? currentPosition;
  final String? domain;
  final String? skills;
  final String? experienceSummary;
  final bool availableForMentoring;
  final String? linkedinUrl;
  final String? portfolioUrl;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlumniProfileModel({
    required this.id,
    required this.userId,
    required this.graduationYear,
    required this.currentCompany,
    required this.currentPosition,
    required this.domain,
    required this.skills,
    required this.experienceSummary,
    required this.availableForMentoring,
    required this.linkedinUrl,
    required this.portfolioUrl,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlumniProfileModel.fromJson(Map<String, dynamic> json) {
    return AlumniProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      graduationYear: int.tryParse(json['graduation_year']?.toString() ?? ''),
      currentCompany: json['current_company']?.toString(),
      currentPosition: json['current_position']?.toString(),
      domain: json['domain']?.toString(),
      skills: json['skills']?.toString(),
      experienceSummary: json['experience_summary']?.toString(),
      availableForMentoring: json['available_for_mentoring'] == true,
      linkedinUrl: json['linkedin_url']?.toString(),
      portfolioUrl: json['portfolio_url']?.toString(),
      visibility: json['visibility']?.toString() ?? 'internal',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get visibilityLabel {
    switch (visibility) {
      case 'alumni_only':
        return 'Alumni';
      case 'enacchef_only':
        return 'Bureau';
      case 'private':
        return 'Privé';
      default:
        return 'Interne';
    }
  }
}
