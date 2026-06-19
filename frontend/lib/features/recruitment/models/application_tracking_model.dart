class ApplicationTrackingModel {
  final String applicationId;
  final String campaignTitle;
  final String status;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final String nextStep;
  final bool accountCreated;

  const ApplicationTrackingModel({
    required this.applicationId,
    required this.campaignTitle,
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
      status: json['status']?.toString() ?? 'received',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      nextStep: json['next_step']?.toString() ?? '',
      accountCreated: json['account_created'] == true,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'received':
        return 'Candidature reçue';
      case 'preselected':
        return 'Présélectionnée';
      case 'interview':
        return 'Entretien';
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Non retenue';
      default:
        return status;
    }
  }

  int get currentStep {
    switch (status) {
      case 'received':
        return 0;
      case 'preselected':
        return 1;
      case 'interview':
        return 2;
      case 'accepted':
      case 'rejected':
        return 3;
      default:
        return 0;
    }
  }
}
