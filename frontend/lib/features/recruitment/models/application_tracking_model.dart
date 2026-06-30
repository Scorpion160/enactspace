class ApplicationTrackingModel {
  final String applicationId;
  final String campaignTitle;
  final String firstName;
  final String lastName;
  final String email;
  final String? department;
  final String? studyLevel;
  final String status;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final String nextStep;
  final bool accountCreated;

  const ApplicationTrackingModel({
    required this.applicationId,
    required this.campaignTitle,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.department,
    required this.studyLevel,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    required this.nextStep,
    required this.accountCreated,
  });

  factory ApplicationTrackingModel.fromJson(Map<String, dynamic> json) {
    return ApplicationTrackingModel(
      applicationId: json['application_id']?.toString() ?? '',
      campaignTitle: json['campaign_title']?.toString() ?? 'Recrutement',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: json['department']?.toString(),
      studyLevel: json['study_level']?.toString(),
      status: json['status']?.toString() ?? 'submitted',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      nextStep: json['next_step']?.toString() ?? '',
      accountCreated: json['account_created'] == true,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'submitted':
      case 'received':
        return 'Candidature reçue';
      case 'under_review':
        return 'En cours d’étude';
      case 'interview_scheduled':
        return 'Entretien programmé';
      case 'preselected':
        return 'Présélectionnée';
      case 'interview':
        return 'Entretien';
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Non retenue';
      case 'waiting_list':
        return 'Liste d’attente';
      case 'cancelled':
        return 'Clôturée';
      default:
        return status;
    }
  }

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
      if (email.trim().isNotEmpty) email.trim(),
    ];
    return items.join(' · ');
  }

  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isWaitingList => status == 'waiting_list';
  bool get isCancelled => status == 'cancelled';

  int get currentStep {
    switch (status) {
      case 'submitted':
      case 'received':
        return 0;
      case 'under_review':
      case 'preselected':
        return 1;
      case 'interview_scheduled':
      case 'interview':
        return 2;
      case 'accepted':
      case 'rejected':
      case 'waiting_list':
      case 'cancelled':
        return 3;
      default:
        return 0;
    }
  }
}
