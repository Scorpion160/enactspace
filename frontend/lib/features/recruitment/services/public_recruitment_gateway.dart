import 'dart:io';

import 'package:http/http.dart' show ClientException;

import '../../../core/api/api_client.dart';
import '../models/application_model.dart';
import '../models/application_tracking_model.dart';
import '../models/public_application_draft.dart';
import '../models/recruitment_campaign_model.dart';
import 'recruitment_service.dart';

enum PublicRecruitmentFailureKind { notFound, network, server }

class PublicRecruitmentFailure implements Exception {
  final PublicRecruitmentFailureKind kind;

  const PublicRecruitmentFailure(this.kind);
}

abstract class PublicRecruitmentGateway {
  Future<List<RecruitmentCampaignModel>> loadCampaigns();

  Future<ApplicationModel> submitApplication(PublicApplicationDraft draft);

  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  });
}

class RecruitmentPublicGateway implements PublicRecruitmentGateway {
  final RecruitmentService _service;

  RecruitmentPublicGateway({RecruitmentService? service})
    : _service = service ?? RecruitmentService();

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      _guard(_service.getPublicCampaigns);

  @override
  Future<ApplicationModel> submitApplication(PublicApplicationDraft draft) {
    return _guard(
      () => _service.createApplication(
        campaignId: draft.campaignId,
        firstName: draft.firstName,
        lastName: draft.lastName,
        email: draft.email,
        gender: draft.gender,
        phone: draft.phone,
        department: draft.department,
        studyLevel: draft.studyLevel,
        className: draft.className,
        motivation: draft.motivation,
        knownEnactusFrom: draft.knownEnactusFrom,
        enactusKnowledge: draft.enactusKnowledge,
        otherClubs: draft.otherClubs,
        contribution: draft.contribution,
        projectIdeas: draft.projectIdeas,
        leadershipProfile: draft.leadershipProfile,
        preferredPole: draft.preferredPole,
        projectInterest: draft.projectInterest,
        associativeExperience: draft.associativeExperience,
        availability: draft.availability,
        publicComment: draft.publicComment,
        cvUrl: draft.cvUrl,
        motivationLetterUrl: draft.motivationLetterUrl,
        attachmentUrl: draft.attachmentUrl,
      ),
    );
  }

  @override
  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  }) {
    return _guard(
      () => _service.trackApplication(applicationId: code, email: email),
    );
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw PublicRecruitmentFailure(
        error.statusCode == 404
            ? PublicRecruitmentFailureKind.notFound
            : PublicRecruitmentFailureKind.server,
      );
    } on SocketException {
      throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.network,
      );
    } on ClientException {
      throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.network,
      );
    } on PublicRecruitmentFailure {
      rethrow;
    } catch (_) {
      throw const PublicRecruitmentFailure(PublicRecruitmentFailureKind.server);
    }
  }
}
