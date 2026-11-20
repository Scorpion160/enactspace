import '../../../core/auth/user_experience.dart';
import '../../../core/push/push_lifecycle_controller.dart';
import '../../../core/push/push_gateway.dart';
import '../../../core/theme/appearance_controller.dart';
import '../academy/services/academy_gateway.dart';
import '../alumni/services/alumni_gateway.dart';
import '../alumni/services/alumni_service.dart';
import '../archives/services/archives_gateway.dart';
import '../archives/services/archives_service.dart';
import '../attendance/services/attendance_service.dart';
import '../chat/services/chat_service.dart';
import '../dashboard/services/dashboard_gateway.dart';
import '../dashboard/services/dashboard_service.dart';
import '../documents/services/documents_gateway.dart';
import '../documents/services/institutional_documents_gateway.dart';
import '../documents/services/institutional_documents_service.dart';
import '../events/services/events_gateway.dart';
import '../events/services/events_service.dart';
import '../finance/services/finance_service.dart';
import '../gamification/services/games_service.dart';
import '../gamification/services/gamification_gateway.dart';
import '../gamification/services/gamification_service.dart';
import '../help/services/help_gateway.dart';
import '../impact/services/impact_gateway.dart';
import '../impact/services/impact_service.dart';
import '../meetings/services/meetings_service.dart';
import '../members/services/members_service.dart';
import '../notifications/services/notifications_gateway.dart';
import '../notifications/services/notifications_service.dart';
import '../poles/services/poles_portfolio_gateway.dart';
import '../poles/services/poles_service.dart';
import '../posts/services/posts_service.dart';
import '../profile/services/my_profile_service.dart';
import '../projects/services/projects_portfolio_gateway.dart';
import '../projects/services/projects_service.dart';
import '../settings/controllers/settings_controller.dart';
import '../settings/services/academic_profile_service.dart';
import '../settings/services/settings_gateway.dart';
import '../settings/services/team_years_gateway.dart';
import '../tasks/services/tasks_gateway.dart';
import '../tasks/services/tasks_service.dart';
import '../veille/services/veille_gateway.dart';
import 'demo_native_data.dart';
import 'demo_native_transport.dart';
import 'demo_native_recruitment.dart';
import 'demo_recruitment_gateway.dart';
import 'demo_session.dart';

/// Explicit dependency graph. Production factories and singletons are unchanged.
class DemoNativeRuntime {
  DemoNativeRuntime(DemoProfile profile) : data = DemoNativeData(profile);
  final DemoNativeData data;
  late final api = DemoNativeApi(data);
  late final auth = DemoNativeAuth(data);
  late final user = UserExperience.fromJson(data.user);
  late final appearance = AppearanceController(store: DemoAppearanceStore());
  late final members = MembersService(apiClient: api, authService: auth);
  late final polesService = PolesService(apiClient: api, authService: auth);
  late final projectsService = ProjectsService(
    apiClient: api,
    authService: auth,
  );
  late final tasksService = TasksService(apiClient: api, authService: auth);
  late final eventsService = EventsService(apiClient: api, authService: auth);
  late final attendance = AttendanceService(apiClient: api, authService: auth);
  late final notificationsService = NotificationsService(
    apiClient: api,
    authService: auth,
  );
  late final chatService = ChatService(apiClient: api, authService: auth);
  late final finance = FinanceService(apiClient: api, authService: auth);
  late final games = GamesService(api: api, auth: auth);
  late final meetings = MeetingsService(apiClient: api, authService: auth);
  late final myProfile = MyProfileService(apiClient: api, authService: auth);
  late final academicProfile = AcademicProfileService(
    apiClient: api,
    authService: auth,
  );
  late final years = ApiTeamYearsGateway(api: api, auth: auth);
  late final dashboard = ApiDashboardGateway(
    service: DashboardService(apiClient: api, authService: auth),
  );
  late final projects = ApiProjectsPortfolioGateway(
    apiClient: api,
    authService: auth,
  );
  late final poles = ApiPolesPortfolioGateway(
    apiClient: api,
    authService: auth,
  );
  late final alumni = ApiAlumniGateway(
    alumniService: AlumniService(apiClient: api, authService: auth),
    authService: auth,
    membersService: members,
    projectsService: projectsService,
    polesService: polesService,
  );
  late final archives = ApiArchivesGateway(
    service: ArchivesService(apiClient: api, authService: auth),
    authService: auth,
  );
  late final events = ApiEventsGateway(
    eventsService: eventsService,
    polesService: polesService,
    projectsService: projectsService,
    attendanceService: attendance,
    authService: auth,
  );
  late final tasks = ApiTasksGateway(
    tasksService: tasksService,
    membersService: members,
    polesService: polesService,
    projectsService: projectsService,
    authService: auth,
  );
  late final academy = ApiAcademyGateway(
    apiClient: api,
    authService: DemoNativeAuth(data, cacheProfile: false),
  );
  late final chat = DemoNativeChatGateway(
    chatService: chatService,
    authService: auth,
    polesService: polesService,
    projectsService: projectsService,
    realtimeService: DemoNativeRealtime(data),
  );
  late final notifications = ApiNotificationsGateway(
    notificationsService: notificationsService,
    realtimeService: DemoNativeRealtime(data),
  );
  late final posts = DemoNativePostsGateway(
    api,
    postsService: PostsService(apiClient: api, authService: auth),
    membersService: members,
    authService: auth,
    polesService: polesService,
    projectsService: projectsService,
  );
  late final documents = ApiDocumentsGateway(
    documentsService: DemoNativeDocumentsService(api, auth),
    polesService: polesService,
    projectsService: projectsService,
    eventsService: eventsService,
    portfolioGateway: projects,
  );
  late final institutionalDocuments = ApiInstitutionalDocumentsGateway(
    service: InstitutionalDocumentsService(apiClient: api, authService: auth),
    documentsGateway: documents,
    membersService: members,
    authService: auth,
  );
  late final impact = ApiImpactGateway(
    service: ImpactService(apiClient: api, authService: auth),
    apiClient: api,
    authService: auth,
  );
  late final gamification = ApiGamificationGateway(
    service: GamificationService(apiClient: api, authService: auth),
    authService: auth,
    membersService: members,
    polesService: polesService,
  );
  late final veille = ApiVeilleGateway(apiClient: api, authService: auth);
  late final help = ApiHelpGateway(apiClient: api, authService: auth);
  late final settings = SettingsController(
    gateway: ApiSettingsGateway(apiClient: api, authService: auth),
    appearance: appearance,
    presentationMode: true,
    pushController: PushLifecycleController(
      pushPlatform: DemoNativePushPlatform(),
      pushGateway: ApiPushGateway(apiClient: api, authService: auth),
      authService: auth,
    ),
  );
  final recruitment = DemoRecruitmentGateway();
  late final internalRecruitment = DemoNativeRecruitmentGateway(
    recruitment,
    api,
    auth,
  );

  void dispose() {
    // Owned controllers are lightweight; uninitialized late values are not read.
    recruitment.dispose();
    api.media.clear();
  }
}
