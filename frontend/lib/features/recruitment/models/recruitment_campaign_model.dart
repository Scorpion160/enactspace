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

  DateTime? get startDateValue => DateTime.tryParse(startDate ?? '');

  DateTime? get endDateValue => DateTime.tryParse(endDate ?? '');

  RecruitmentCampaignModel copyWith({
    String? title,
    String? description,
    String? startDate,
    String? endDate,
    bool? isActive,
  }) => RecruitmentCampaignModel(
    id: id,
    seasonId: seasonId,
    title: title ?? this.title,
    description: description ?? this.description,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isActive: isActive ?? this.isActive,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  String get periodLabel {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    if (start == null && end == null) return 'Dates à confirmer';
    if (start == null) return 'Jusqu’au $end';
    if (end == null) return 'À partir du $start';
    return 'Du $start au $end';
  }

  static String? _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return null;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }
}
