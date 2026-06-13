class ApplicationReviewModel {
  final String id;
  final String applicationId;
  final String reviewerId;
  final double? score;
  final String? comment;
  final String recommendation;
  final String? createdAt;
  final String? updatedAt;

  const ApplicationReviewModel({
    required this.id,
    required this.applicationId,
    required this.reviewerId,
    this.score,
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
      score: double.tryParse(json['score']?.toString() ?? ''),
      comment: json['comment']?.toString(),
      recommendation: json['recommendation']?.toString() ?? 'reserve',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
