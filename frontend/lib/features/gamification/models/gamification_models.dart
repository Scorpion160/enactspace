class EngagementPointModel {
  final String id;
  final String userId;
  final String? seasonId;
  final String? poleId;
  final String? projectId;
  final String sourceType;
  final String? sourceId;
  final int points;
  final String? reason;
  final String? awardedBy;
  final DateTime createdAt;

  const EngagementPointModel({
    required this.id,
    required this.userId,
    required this.seasonId,
    required this.poleId,
    required this.projectId,
    required this.sourceType,
    required this.sourceId,
    required this.points,
    required this.reason,
    required this.awardedBy,
    required this.createdAt,
  });

  factory EngagementPointModel.fromJson(Map<String, dynamic> json) {
    return EngagementPointModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      sourceType: json['source_type']?.toString() ?? 'manual',
      sourceId: json['source_id']?.toString(),
      points: int.tryParse(json['points']?.toString() ?? '') ?? 0,
      reason: json['reason']?.toString(),
      awardedBy: json['awarded_by']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class BadgeModel {
  final String id;
  final String name;
  final String label;
  final String? description;
  final String? iconUrl;
  final DateTime createdAt;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.iconUrl,
    required this.createdAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Badge',
      description: json['description']?.toString(),
      iconUrl: json['icon_url']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class UserBadgeModel {
  final String id;
  final String userId;
  final String badgeId;
  final String? seasonId;
  final String? awardedBy;
  final DateTime awardedAt;

  const UserBadgeModel({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.seasonId,
    required this.awardedBy,
    required this.awardedAt,
  });

  factory UserBadgeModel.fromJson(Map<String, dynamic> json) {
    return UserBadgeModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      badgeId: json['badge_id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      awardedBy: json['awarded_by']?.toString(),
      awardedAt:
          DateTime.tryParse(json['awarded_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class UserRankingModel {
  final String userId;
  final int totalPoints;

  const UserRankingModel({required this.userId, required this.totalPoints});

  factory UserRankingModel.fromJson(Map<String, dynamic> json) {
    return UserRankingModel(
      userId: json['user_id']?.toString() ?? '',
      totalPoints: int.tryParse(json['total_points']?.toString() ?? '') ?? 0,
    );
  }
}

class PoleRankingModel {
  final String poleId;
  final int totalPoints;

  const PoleRankingModel({required this.poleId, required this.totalPoints});

  factory PoleRankingModel.fromJson(Map<String, dynamic> json) {
    return PoleRankingModel(
      poleId: json['pole_id']?.toString() ?? '',
      totalPoints: int.tryParse(json['total_points']?.toString() ?? '') ?? 0,
    );
  }
}

class MonthlyWinnerModel {
  final int month;
  final int year;
  final String? userId;
  final String? poleId;
  final int totalPoints;

  const MonthlyWinnerModel({
    required this.month,
    required this.year,
    required this.userId,
    required this.poleId,
    required this.totalPoints,
  });

  factory MonthlyWinnerModel.fromJson(Map<String, dynamic> json) {
    return MonthlyWinnerModel(
      month:
          int.tryParse(json['month']?.toString() ?? '') ?? DateTime.now().month,
      year: int.tryParse(json['year']?.toString() ?? '') ?? DateTime.now().year,
      userId: json['user_id']?.toString(),
      poleId: json['pole_id']?.toString(),
      totalPoints: int.tryParse(json['total_points']?.toString() ?? '') ?? 0,
    );
  }
}
