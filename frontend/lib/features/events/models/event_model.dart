class EventModel {
  final String id;
  final String? seasonId;
  final String title;
  final String? description;
  final String eventType;
  final String? location;
  final DateTime startTime;
  final DateTime? endTime;
  final String? poleId;
  final String? projectId;
  final double budget;
  final int? maxParticipants;
  final bool requiresRegistration;
  final bool attendanceEnabled;
  final String? reportUrl;
  final String? createdBy;
  final int registeredCount;
  final bool currentUserRegistered;
  final bool canManage;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.seasonId,
    required this.title,
    required this.description,
    required this.eventType,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.poleId,
    required this.projectId,
    required this.budget,
    required this.maxParticipants,
    required this.requiresRegistration,
    required this.attendanceEnabled,
    required this.reportUrl,
    required this.createdBy,
    required this.registeredCount,
    required this.currentUserRegistered,
    required this.canManage,
    required this.createdAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      title: json['title']?.toString() ?? 'Événement sans titre',
      description: json['description']?.toString(),
      eventType: json['event_type']?.toString() ?? 'meeting',
      location: json['location']?.toString(),
      startTime:
          DateTime.tryParse(json['start_time']?.toString() ?? '') ??
          DateTime.now(),
      endTime: DateTime.tryParse(json['end_time']?.toString() ?? ''),
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      budget: double.tryParse(json['budget']?.toString() ?? '0') ?? 0,
      maxParticipants: int.tryParse(json['max_participants']?.toString() ?? ''),
      requiresRegistration: json['requires_registration'] == true,
      attendanceEnabled: json['attendance_enabled'] != false,
      reportUrl: json['report_url']?.toString(),
      createdBy: json['created_by']?.toString(),
      registeredCount:
          int.tryParse(json['registered_count']?.toString() ?? '') ?? 0,
      currentUserRegistered: json['current_user_registered'] == true,
      canManage: json['can_manage'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  EventModel copyWith({
    String? title,
    String? description,
    String? eventType,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    String? poleId,
    String? projectId,
    double? budget,
    int? maxParticipants,
    bool? requiresRegistration,
    bool? attendanceEnabled,
    String? reportUrl,
    int? registeredCount,
    bool? currentUserRegistered,
  }) {
    return EventModel(
      id: id,
      seasonId: seasonId,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      poleId: poleId ?? this.poleId,
      projectId: projectId ?? this.projectId,
      budget: budget ?? this.budget,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      requiresRegistration: requiresRegistration ?? this.requiresRegistration,
      attendanceEnabled: attendanceEnabled ?? this.attendanceEnabled,
      reportUrl: reportUrl ?? this.reportUrl,
      createdBy: createdBy,
      registeredCount: registeredCount ?? this.registeredCount,
      currentUserRegistered:
          currentUserRegistered ?? this.currentUserRegistered,
      canManage: canManage,
      createdAt: createdAt,
    );
  }

  bool get isUpcoming {
    return startTime.isAfter(DateTime.now());
  }

  String get typeLabel {
    switch (eventType) {
      case 'training':
        return 'Formation';
      case 'competition':
        return 'Compétition';
      case 'field_trip':
        return 'Terrain';
      case 'travel':
        return 'Voyage';
      case 'lab_test':
        return 'Test chimie';
      case 'workshop_test':
        return 'Test atelier';
      case 'campaign':
        return 'Campagne';
      case 'presentation':
        return 'Présentation';
      case 'social':
        return 'Social';
      case 'meeting':
        return 'Réunion';
      case 'interclub':
        return 'Interclubs';
      case 'yendoutu':
        return 'Yendoutu';
      default:
        return eventType
            .split('_')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  bool get isFull =>
      maxParticipants != null && registeredCount >= maxParticipants!;
}
