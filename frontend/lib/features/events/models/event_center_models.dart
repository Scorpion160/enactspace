import '../../poles/models/pole_model.dart';
import '../../projects/models/project_model.dart';
import 'event_model.dart';

enum EventCenterPeriod { upcoming, past, all }

class EventMutationDraft {
  final String? seasonId;
  final String title;
  final String description;
  final String eventType;
  final String location;
  final DateTime startTime;
  final DateTime? endTime;
  final String? poleId;
  final String? projectId;
  final double budget;
  final int? maxParticipants;
  final bool requiresRegistration;
  final bool attendanceEnabled;
  final String reportUrl;

  const EventMutationDraft({
    this.seasonId,
    required this.title,
    required this.description,
    required this.eventType,
    required this.location,
    required this.startTime,
    this.endTime,
    this.poleId,
    this.projectId,
    required this.budget,
    this.maxParticipants,
    required this.requiresRegistration,
    required this.attendanceEnabled,
    this.reportUrl = '',
  });

  factory EventMutationDraft.fromEvent(EventModel event) => EventMutationDraft(
    seasonId: event.seasonId,
    title: event.title,
    description: event.description ?? '',
    eventType: event.eventType,
    location: event.location ?? '',
    startTime: event.startTime,
    endTime: event.endTime,
    poleId: event.poleId,
    projectId: event.projectId,
    budget: event.budget,
    maxParticipants: event.maxParticipants,
    requiresRegistration: event.requiresRegistration,
    attendanceEnabled: event.attendanceEnabled,
    reportUrl: event.reportUrl ?? '',
  );
}

class EventReferenceData {
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final Set<String> managedPoleIds;
  final Set<String> managedProjectIds;
  final bool isGlobalManager;

  const EventReferenceData({
    this.poles = const [],
    this.projects = const [],
    this.managedPoleIds = const {},
    this.managedProjectIds = const {},
    this.isGlobalManager = false,
  });

  bool get canCreate =>
      isGlobalManager ||
      managedPoleIds.isNotEmpty ||
      managedProjectIds.isNotEmpty;

  List<PoleModel> get creatablePoles => isGlobalManager
      ? poles
      : poles.where((pole) => managedPoleIds.contains(pole.id)).toList();

  List<ProjectModel> get creatableProjects => isGlobalManager
      ? projects
      : projects
            .where((project) => managedProjectIds.contains(project.id))
            .toList();

  String? poleName(String? id) => id == null
      ? null
      : poles
            .where((pole) => pole.id == id)
            .map((pole) => pole.name)
            .firstOrNull;

  String? projectName(String? id) => id == null
      ? null
      : projects
            .where((project) => project.id == id)
            .map((project) => project.name)
            .firstOrNull;
}
