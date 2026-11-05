import 'package:flutter/material.dart';
import 'application_status_presentation.dart';
import 'recruitment_schedule_model.dart';

class ApplicationTrackingModel {
  final String applicationId;
  final String trackingCode;
  final String campaignTitle;
  final String firstName;
  final String lastName;
  final String email;
  final String? department;
  final String? studyLevel;
  final String? preferredPole;
  final String? projectInterest;
  final String status;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final String nextStep;
  final String? candidateMessage;
  final String? interviewDetails;
  final String? finalResult;
  final bool accountCreated;
  final String? personalityStatus;
  final DateTime? personalityDueAt;
  final String? screeningResult;
  final RecruitmentScheduleModel? selectionSchedule;

  const ApplicationTrackingModel({
    required this.applicationId,
    required this.trackingCode,
    required this.campaignTitle,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.department,
    required this.studyLevel,
    required this.preferredPole,
    required this.projectInterest,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    required this.nextStep,
    required this.candidateMessage,
    required this.interviewDetails,
    required this.finalResult,
    required this.accountCreated,
    this.personalityStatus,
    this.personalityDueAt,
    this.screeningResult,
    this.selectionSchedule,
  });

  factory ApplicationTrackingModel.fromJson(Map<String, dynamic> json) {
    return ApplicationTrackingModel(
      screeningResult: json['screening_result']?.toString(),
      selectionSchedule: RecruitmentScheduleModel.fromJson(json['selection_schedule']),
      applicationId: json['application_id']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString() ?? '',
      campaignTitle: json['campaign_title']?.toString() ?? 'Recrutement',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: json['department']?.toString(),
      studyLevel: json['study_level']?.toString(),
      preferredPole: json['preferred_pole']?.toString(),
      projectInterest: json['project_interest']?.toString(),
      status: json['status']?.toString() ?? 'submitted',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      nextStep: json['next_step']?.toString() ?? '',
      candidateMessage: json['candidate_message']?.toString(),
      interviewDetails: json['interview_details']?.toString(),
      finalResult: json['final_result']?.toString(),
      accountCreated: json['account_created'] == true,
      personalityStatus: json['personality_status']?.toString(),
      personalityDueAt: DateTime.tryParse(
        json['personality_due_at']?.toString() ?? '',
      ),
    );
  }

  ApplicationStatusPresentation get presentation {
    if (screeningResult == 'not_shortlisted') {
      return const ApplicationStatusPresentation(
        status: 'rejected',
        title: 'Dossier non retenu',
        explanation: 'La sélection s’arrête après l’étude de ton dossier pour cette campagne.',
        nextAction: 'Merci pour le temps consacré à ta candidature. Tu peux suivre les prochaines campagnes et les activités du club.',
        timelineStep: 2,
        icon: Icons.info_outline_rounded,
        terminalException: true,
      );
    }
    if (screeningResult == 'shortlisted' && status == 'under_review') {
      return const ApplicationStatusPresentation(
        status: 'under_review',
        title: 'Dossier retenu',
        explanation: 'Ton dossier est retenu pour un entretien avec l’équipe.',
        nextAction: 'Les informations de l’entretien te seront communiquées dans le suivi et par e-mail.',
        timelineStep: 2,
        icon: Icons.fact_check_outlined,
      );
    }
    return ApplicationStatusPresentation.fromStatus(status);
  }

  String get statusLabel =>
      ApplicationStatusPresentation.fromStatus(status).title;

  String get candidateName {
    final parts = [
      if (firstName.trim().isNotEmpty) firstName.trim(),
      if (lastName.trim().isNotEmpty) lastName.trim(),
    ];
    return parts.isEmpty ? email : parts.join(' ');
  }

  String get candidateSummary {
    final items = [
      if (department?.trim().isNotEmpty == true) department!.trim(),
      if (studyLevel?.trim().isNotEmpty == true) studyLevel!.trim(),
      if (preferredPole?.trim().isNotEmpty == true) preferredPole!.trim(),
      if (projectInterest?.trim().isNotEmpty == true) projectInterest!.trim(),
      if (email.trim().isNotEmpty) email.trim(),
    ];
    return items.join(' · ');
  }

  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isWaitingList => status == 'waiting_list';
  bool get isCancelled => status == 'cancelled';
  bool get hasFinalResult => finalResult?.trim().isNotEmpty == true;
  bool get hasInterviewDetails => interviewDetails?.trim().isNotEmpty == true;

  int get currentStep {
    switch (status) {
      case 'submitted':
      case 'received':
        return 0;
      case 'under_review':
      case 'preselected':
        return screeningResult == 'shortlisted' ? 2 : 1;
      case 'interview_scheduled':
      case 'interview':
        return 3;
      case 'accepted':
      case 'rejected':
      case 'waiting_list':
      case 'cancelled':
        return screeningResult == 'not_shortlisted' ? 2 : 4;
      default:
        return 0;
    }
  }
}
