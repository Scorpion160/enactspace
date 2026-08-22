import '../models/application_model.dart';
import '../models/application_review_model.dart';
import '../models/recruitment_campaign_model.dart';
import 'recruitment_service.dart';

abstract interface class InternalRecruitmentGateway {
  Future<List<RecruitmentCampaignModel>> loadCampaigns();

  Future<List<ApplicationModel>> loadApplications();

  Future<ApplicationModel> loadApplication(String applicationId);

  Future<List<ApplicationReviewModel>> loadReviews(String applicationId);
}

class RecruitmentServiceGateway implements InternalRecruitmentGateway {
  final RecruitmentService service;

  RecruitmentServiceGateway({RecruitmentService? service})
    : service = service ?? RecruitmentService();

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      service.getCampaigns();

  @override
  Future<List<ApplicationModel>> loadApplications() =>
      service.getApplications();

  @override
  Future<ApplicationModel> loadApplication(String applicationId) =>
      service.getApplication(applicationId);

  @override
  Future<List<ApplicationReviewModel>> loadReviews(String applicationId) =>
      service.getApplicationReviews(applicationId);
}
