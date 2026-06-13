class RecruitmentCampaignModel {
  final String id;
  final String? seasonId;
  final String title;
  final String? description;
  final String? startDate;
  final String? endDate;
  final bool isActive;
  final String? createdBy;
  final String? createdAt;
  final String? updatedAt;

  const RecruitmentCampaignModel({
    required this.id,
    this.seasonId,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    required this.isActive,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory RecruitmentCampaignModel.fromJson(Map<String, dynamic> json) {
    return RecruitmentCampaignModel(
      id: json['id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      title: json['title']?.toString() ?? 'Campagne sans titre',
      description: json['description']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      isActive: json['is_active'] == true,
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String get periodLabel {
    final start = startDate ?? 'Non défini';
    final end = endDate ?? 'Non défini';
    return '$start → $end';
  }
}
