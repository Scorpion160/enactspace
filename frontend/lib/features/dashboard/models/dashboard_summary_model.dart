class DashboardSummaryModel {
  final DashboardProfileModel profile;
  final DashboardCountsModel counts;
  final List<DashboardActivityModel> recentActivity;

  const DashboardSummaryModel({
    required this.profile,
    required this.counts,
    required this.recentActivity,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      profile: DashboardProfileModel.fromJson(_map(json['profile'])),
      counts: DashboardCountsModel.fromJson(_map(json['counts'])),
      recentActivity: _list(json['recent_activity'])
          .whereType<Map<String, dynamic>>()
          .map(DashboardActivityModel.fromJson)
          .toList(),
    );
  }
}

class DashboardProfileModel {
  final String id;
  final String displayName;
  final String status;
  final String profileType;
  final List<String> roles;
  final bool isAlumni;
  final bool isEnacchef;
  final bool canViewGlobal;
  final bool canViewGlobalMembers;
  final bool canViewGlobalAttendance;
  final bool canViewAttendance;
  final bool canViewFinance;
  final bool canManageDocuments;
  final bool canViewRecruitment;

  const DashboardProfileModel({
    required this.id,
    required this.displayName,
    required this.status,
    required this.profileType,
    required this.roles,
    required this.isAlumni,
    required this.isEnacchef,
    required this.canViewGlobal,
    required this.canViewGlobalMembers,
    required this.canViewGlobalAttendance,
    required this.canViewAttendance,
    required this.canViewFinance,
    required this.canManageDocuments,
    required this.canViewRecruitment,
  });

  factory DashboardProfileModel.fromJson(Map<String, dynamic> json) {
    return DashboardProfileModel(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Enacteur',
      status: json['status']?.toString() ?? 'active',
      profileType: json['profile_type']?.toString() ?? 'enacteur',
      roles: _list(json['roles']).map((role) => role.toString()).toList(),
      isAlumni: json['is_alumni'] == true,
      isEnacchef: json['is_enacchef'] == true,
      canViewGlobal: json['can_view_global'] == true,
      canViewGlobalMembers: json['can_view_global_members'] == true,
      canViewGlobalAttendance: json['can_view_global_attendance'] == true,
      canViewAttendance: json['can_view_attendance'] == true,
      canViewFinance: json['can_view_finance'] == true,
      canManageDocuments: json['can_manage_documents'] == true,
      canViewRecruitment: json['can_view_recruitment'] == true,
    );
  }
}

class DashboardCountsModel {
  final Map<String, dynamic> values;

  const DashboardCountsModel({required this.values});

  factory DashboardCountsModel.fromJson(Map<String, dynamic> json) {
    return DashboardCountsModel(values: json);
  }

  int integer(String key) {
    final value = values[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double decimal(String key) {
    final value = values[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool hasValue(String key) => values[key] != null;
}

class DashboardActivityModel {
  final String type;
  final String title;
  final DateTime createdAt;
  final String route;

  const DashboardActivityModel({
    required this.type,
    required this.title,
    required this.createdAt,
    required this.route,
  });

  factory DashboardActivityModel.fromJson(Map<String, dynamic> json) {
    return DashboardActivityModel(
      type: json['type']?.toString() ?? 'activity',
      title: json['title']?.toString() ?? 'Activité',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      route: json['route']?.toString() ?? '/dashboard',
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return {};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const [];
}
