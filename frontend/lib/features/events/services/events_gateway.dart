import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../attendance/services/attendance_service.dart';
import '../../poles/models/pole_management_models.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_management_models.dart';
import '../../projects/services/projects_service.dart';
import '../models/event_center_models.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import 'events_service.dart';

abstract class EventsGateway {
  Future<List<EventModel>> loadEvents();
  Future<EventModel> loadEvent(String eventId);
  Future<EventReferenceData> loadReferences();
  Future<EventModel> createEvent(EventMutationDraft draft);
  Future<EventModel> updateEvent(String eventId, EventMutationDraft draft);
  Future<EventModel> register(String eventId);
  Future<EventModel> unregister(String eventId);
  Future<List<EventParticipantModel>> loadParticipants(String eventId);
  Future<void> createAttendanceSession(EventModel event);
  Future<void> deleteEvent(String eventId);
}

class ApiEventsGateway implements EventsGateway {
  final EventsService _events;
  final PolesService _poles;
  final ProjectsService _projects;
  final AttendanceService _attendance;
  final AuthService _auth;
  Future<EventReferenceData>? _references;

  ApiEventsGateway({
    EventsService? eventsService,
    PolesService? polesService,
    ProjectsService? projectsService,
    AttendanceService? attendanceService,
    AuthService? authService,
  }) : _events = eventsService ?? EventsService(),
       _poles = polesService ?? PolesService(),
       _projects = projectsService ?? ProjectsService(),
       _attendance = attendanceService ?? AttendanceService(),
       _auth = authService ?? AuthService();

  @override
  Future<List<EventModel>> loadEvents() => _events.getEvents();

  @override
  Future<EventModel> loadEvent(String eventId) => _events.getEvent(eventId);

  @override
  Future<EventReferenceData> loadReferences() =>
      _references ??= _loadReferences();

  Future<EventReferenceData> _loadReferences() async {
    final userData =
        await _auth.getCachedCurrentUser() ?? await _auth.getCurrentUser();
    final user = UserExperience.fromJson(userData);
    final results = await Future.wait([
      _poles.getPoles(),
      _projects.getProjects(),
    ]);
    final poles = results[0] as List;
    final projects = results[1] as List;
    final global = user.isAdmin || user.isTeamLeader || user.isSecretary;
    if (global) {
      return EventReferenceData(
        poles: poles.cast(),
        projects: projects.cast(),
        isGlobalManager: true,
      );
    }

    final managedPoles = <String>{};
    final managedProjects = <String>{};
    if (user.isProjectOrPoleLead) {
      await Future.wait([
        for (final pole in poles)
          _poles
              .getPoleMembers(pole.id)
              .then((members) {
                if (members.any(
                  (member) =>
                      member.id == user.id &&
                      member.isActive != false &&
                      PolePositionPresentation.isLeadership(
                        member.polePosition,
                      ),
                )) {
                  managedPoles.add(pole.id);
                }
              })
              .catchError((_) {}),
        for (final project in projects)
          _projects
              .getProjectMembers(project.id)
              .then((members) {
                if (ProjectManagementPermissions.canManage(user, members)) {
                  managedProjects.add(project.id);
                }
              })
              .catchError((_) {}),
      ]);
    }
    return EventReferenceData(
      poles: poles.cast(),
      projects: projects.cast(),
      managedPoleIds: managedPoles,
      managedProjectIds: managedProjects,
    );
  }

  @override
  Future<EventModel> createEvent(EventMutationDraft draft) =>
      _events.createEvent(
        title: draft.title,
        description: draft.description,
        eventType: draft.eventType,
        location: draft.location,
        startTime: draft.startTime,
        endTime: draft.endTime,
        budget: draft.budget,
        maxParticipants: draft.maxParticipants,
        requiresRegistration: draft.requiresRegistration,
        attendanceEnabled: draft.attendanceEnabled,
        poleId: draft.poleId,
        projectId: draft.projectId,
        seasonId: draft.seasonId,
      );

  @override
  Future<EventModel> updateEvent(String eventId, EventMutationDraft draft) =>
      _events.updateEvent(
        eventId: eventId,
        title: draft.title,
        description: draft.description,
        eventType: draft.eventType,
        location: draft.location,
        startTime: draft.startTime,
        endTime: draft.endTime,
        clearEndTime: draft.endTime == null,
        poleId: draft.poleId ?? '',
        projectId: draft.projectId ?? '',
        budget: draft.budget,
        maxParticipants: draft.maxParticipants,
        requiresRegistration: draft.requiresRegistration,
        attendanceEnabled: draft.attendanceEnabled,
        reportUrl: draft.reportUrl,
      );

  @override
  Future<EventModel> register(String eventId) => _events.register(eventId);

  @override
  Future<EventModel> unregister(String eventId) => _events.unregister(eventId);

  @override
  Future<List<EventParticipantModel>> loadParticipants(String eventId) =>
      _events.getParticipants(eventId);

  @override
  Future<void> createAttendanceSession(EventModel event) =>
      _attendance.createSession(
        title: event.title,
        description: event.description ?? '',
        sessionType: 'event',
        scheduledAt: event.startTime,
        scopeType: event.projectId != null
            ? 'project'
            : event.poleId != null
            ? 'pole'
            : 'club',
        eventId: event.id,
        poleId: event.poleId,
        projectId: event.projectId,
      );

  @override
  Future<void> deleteEvent(String eventId) => _events.deleteEvent(eventId);
}
