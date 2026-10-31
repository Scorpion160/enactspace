import 'recruitment_question_model.dart';

class RecruitmentCampaignModel {
  final List<RecruitmentApplicationQuestion> applicationQuestions;
  final String? questionnaireVersion;
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
  final DateTime? serverTime;
  final DateTime? receivedAt;
  final DateTime? opensAt;
  final DateTime? closesAt;

  const RecruitmentCampaignModel({
    this.applicationQuestions = defaultRecruitmentQuestions,
    this.questionnaireVersion,
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
    this.serverTime,
    this.receivedAt,
    this.opensAt,
    this.closesAt,
  });

  factory RecruitmentCampaignModel.fromJson(Map<String, dynamic> json) {
    return RecruitmentCampaignModel(
      applicationQuestions: json['application_questions'] is List
          ? (json['application_questions'] as List)
                .whereType<Map>()
                .map(
                  (q) => RecruitmentApplicationQuestion.fromJson(
                    Map<String, dynamic>.from(q),
                  ),
                )
                .toList()
          : defaultRecruitmentQuestions,
      questionnaireVersion: json['questionnaire_version']?.toString(),
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
      serverTime: DateTime.tryParse(
        json['server_time']?.toString() ?? '',
      )?.toUtc(),
      receivedAt: DateTime.now().toUtc(),
      opensAt: DateTime.tryParse(json['opens_at']?.toString() ?? '')?.toUtc(),
      closesAt: DateTime.tryParse(json['closes_at']?.toString() ?? '')?.toUtc(),
    );
  }

  DateTime? get startDateValue => DateTime.tryParse(startDate ?? '');

  DateTime? get endDateValue => DateTime.tryParse(endDate ?? '');

  DateTime get currentTime => serverTime != null && receivedAt != null
      ? serverTime!.add(DateTime.now().toUtc().difference(receivedAt!))
      : DateTime.now().toUtc();

  DateTime? get openingInstant {
    final date = startDateValue;
    return opensAt ??
        (date == null ? null : DateTime.utc(date.year, date.month, date.day));
  }

  DateTime? get closingInstant {
    final date = endDateValue;
    return closesAt ??
        (date == null
            ? null
            : DateTime.utc(date.year, date.month, date.day + 1));
  }

  bool isOpenAt(DateTime now) =>
      isActive &&
      (openingInstant == null || !now.isBefore(openingInstant!)) &&
      (closingInstant == null || now.isBefore(closingInstant!));

  RecruitmentCampaignModel copyWith({
    String? title,
    String? description,
    String? startDate,
    String? endDate,
    bool? isActive,
    List<RecruitmentApplicationQuestion>? applicationQuestions,
  }) => RecruitmentCampaignModel(
    applicationQuestions: applicationQuestions ?? this.applicationQuestions,
    questionnaireVersion: questionnaireVersion,
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
    serverTime: serverTime,
    receivedAt: receivedAt,
    opensAt: startDate == null ? opensAt : null,
    closesAt: endDate == null ? closesAt : null,
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
