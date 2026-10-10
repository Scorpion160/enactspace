class ApplicationReviewModel {
  final String id;
  final String applicationId;
  final String reviewerId;
  final String? reviewerName;
  final double? score;
  final Map<String, dynamic>? criteriaAssessment;
  final String? comment;
  final String recommendation;
  final String? createdAt;
  final String? updatedAt;

  const ApplicationReviewModel({
    required this.id,
    required this.applicationId,
    required this.reviewerId,
    this.reviewerName,
    this.score,
    this.criteriaAssessment,
    this.comment,
    required this.recommendation,
    this.createdAt,
    this.updatedAt,
  });

  factory ApplicationReviewModel.fromJson(Map<String, dynamic> json) {
    return ApplicationReviewModel(
      id: json['id']?.toString() ?? '',
      applicationId: json['application_id']?.toString() ?? '',
      reviewerId: json['reviewer_id']?.toString() ?? '',
      reviewerName: json['reviewer_name']?.toString(),
      score: double.tryParse(json['score']?.toString() ?? ''),
      criteriaAssessment: json['criteria_assessment'] is Map
          ? Map<String, dynamic>.from(json['criteria_assessment'] as Map)
          : null,
      comment: json['comment']?.toString(),
      recommendation: json['recommendation']?.toString() ?? 'reserve',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
