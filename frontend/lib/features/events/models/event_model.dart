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
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
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
      case 'interclub':
        return 'Interclubs';
      case 'yendoutu':
        return 'Yendoutu';
      default:
        return 'Réunion';
    }
  }
}
