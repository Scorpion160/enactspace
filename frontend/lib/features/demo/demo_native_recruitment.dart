import '../recruitment/models/application_model.dart';
import '../recruitment/models/application_review_model.dart';
import '../recruitment/models/recruitment_campaign_model.dart';
import '../recruitment/services/internal_recruitment_gateway.dart';
import '../recruitment/services/recruitment_service.dart';
import '../poles/services/poles_service.dart';
import '../projects/services/projects_service.dart';
import 'demo_native_transport.dart';
import 'demo_recruitment_gateway.dart';

class DemoNativeRecruitmentGateway extends RecruitmentServiceGateway {
  DemoNativeRecruitmentGateway(
    this.source,
    DemoNativeApi api,
    DemoNativeAuth auth,
  ) : super(
        service: RecruitmentService(apiClient: api, authService: auth),
        polesService: PolesService(apiClient: api, authService: auth),
        projectsService: ProjectsService(apiClient: api, authService: auth),
      );
  final DemoRecruitmentGateway source;
  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      source.loadCampaigns();
  @override
  Future<List<ApplicationModel>> loadApplications() async => [
    for (final entry in source.statuses.entries)
      ApplicationModel(
        id: entry.key,
        campaignId: DemoRecruitmentGateway.campaign.id,
        firstName: entry.key.split(' ').first,
        lastName: 'Démo',
        email: DemoRecruitmentGateway.email,
        status: entry.value,
        department: 'Génie Électrique',
        studyLevel: 'DIC2',
        className: '2026-2027',
        trackingCode: DemoRecruitmentGateway.code,
        canConvert: false,
        isAnonymized: false,
      ),
  ];
  @override
  Future<ApplicationModel> loadApplication(
    String applicationId, {
    bool anonymized = false,
  }) async =>
      (await loadApplications()).firstWhere((a) => a.id == applicationId);
  @override
  Future<List<ApplicationReviewModel>> loadReviews(
    String applicationId,
  ) async => [];
  @override
  Future<ApplicationModel> changeStatus({
    required String applicationId,
    required String status,
  }) async {
    source.changeStatus(applicationId, status);
    return loadApplication(applicationId);
  }

  @override
  Future<ApplicationModel> scheduleInterview({
    required String applicationId,
    required DateTime interviewAt,
    String? location,
    String? link,
    String? jury,
    String? note,
  }) async {
    source.changeStatus(applicationId, 'interview_scheduled');
    return loadApplication(applicationId);
  }
}
