import '../models/application_model.dart';
import '../models/application_review_model.dart';
import '../models/candidate_conversion_model.dart';
import '../models/recruitment_campaign_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/services/projects_service.dart';
import 'recruitment_service.dart';

abstract interface class InternalRecruitmentGateway {
  Future<List<RecruitmentCampaignModel>> loadCampaigns();

  Future<RecruitmentCampaignModel> createCampaign({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive,
  });

  Future<RecruitmentCampaignModel> updateCampaign({
    required String campaignId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  });

  Future<void> deleteCampaign(String campaignId);

  Future<List<ApplicationModel>> loadApplications();

  Future<ApplicationModel> loadApplication(String applicationId);

  Future<List<ApplicationReviewModel>> loadReviews(String applicationId);

  Future<ApplicationModel> changeStatus({
    required String applicationId,
    required String status,
  });

  Future<ApplicationModel> scheduleInterview({
    required String applicationId,
    required DateTime interviewAt,
    String? location,
    String? link,
    String? jury,
    String? note,
  });

  Future<CandidateConversionCatalog> loadConversionCatalog();

  Future<CandidateConversionResult> convertCandidate(
    CandidateConversionRequest request,
  );
}

class RecruitmentServiceGateway implements InternalRecruitmentGateway {
  final RecruitmentService service;
  final PolesService polesService;
  final ProjectsService projectsService;

  RecruitmentServiceGateway({
    RecruitmentService? service,
    PolesService? polesService,
    ProjectsService? projectsService,
  }) : service = service ?? RecruitmentService(),
       polesService = polesService ?? PolesService(),
       projectsService = projectsService ?? ProjectsService();

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      service.getCampaigns();

  @override
  Future<RecruitmentCampaignModel> createCampaign({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) => service.createCampaign(
    title: title,
    description: description,
    startDate: startDate,
    endDate: endDate,
    isActive: isActive,
  );

  @override
  Future<RecruitmentCampaignModel> updateCampaign({
    required String campaignId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) => service.updateCampaign(
    campaignId: campaignId,
    title: title,
    description: description,
    startDate: startDate,
    endDate: endDate,
    isActive: isActive,
  );

  @override
  Future<void> deleteCampaign(String campaignId) =>
      service.deleteCampaign(campaignId);

  @override
  Future<List<ApplicationModel>> loadApplications() =>
      service.getApplications();

  @override
  Future<ApplicationModel> loadApplication(String applicationId) =>
      service.getApplication(applicationId);

  @override
  Future<List<ApplicationReviewModel>> loadReviews(String applicationId) =>
      service.getApplicationReviews(applicationId);

  @override
  Future<ApplicationModel> changeStatus({
    required String applicationId,
    required String status,
  }) => service.changeApplicationStatus(
    applicationId: applicationId,
    status: status,
  );

  @override
  Future<ApplicationModel> scheduleInterview({
    required String applicationId,
    required DateTime interviewAt,
    String? location,
    String? link,
    String? jury,
    String? note,
  }) => service.scheduleInterview(
    applicationId: applicationId,
    interviewAt: interviewAt,
    location: location,
    link: link,
    jury: jury,
    note: note,
  );

  @override
  Future<CandidateConversionCatalog> loadConversionCatalog() async {
    final results = await Future.wait<dynamic>([
      polesService.getPoles(),
      projectsService.getProjects(),
    ]);
    return CandidateConversionCatalog(
      poles: (results[0] as List).cast(),
      projects: (results[1] as List).cast(),
    );
  }

  @override
  Future<CandidateConversionResult> convertCandidate(
    CandidateConversionRequest request,
  ) async {
    final response = await service.convertToUser(
      applicationId: request.applicationId,
      password: request.password,
      profileType: request.profileType,
      corePoleId: request.corePoleId,
      supportPoleIds: request.supportPoleIds,
      projectId: request.projectId,
    );
    return CandidateConversionResult.fromResponse(response, request: request);
  }
}
