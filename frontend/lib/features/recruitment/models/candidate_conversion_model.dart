import '../../poles/models/pole_model.dart';
import '../../projects/models/project_model.dart';

class CandidateConversionCatalog {
  final List<PoleModel> poles;
  final List<ProjectModel> projects;

  const CandidateConversionCatalog({
    required this.poles,
    required this.projects,
  });
}

class CandidateConversionRequest {
  final String applicationId;
  final String password;
  final String profileType;
  final String? corePoleId;
  final List<String> supportPoleIds;
  final String? projectId;

  const CandidateConversionRequest({
    required this.applicationId,
    required this.password,
    required this.profileType,
    this.corePoleId,
    this.supportPoleIds = const [],
    this.projectId,
  });
}

enum CandidateConversionOperation {
  created,
  existingAccountActivated,
  alreadyLinked,
  unknown,
}

class CandidateConversionResult {
  final String userId;
  final String profileType;
  final String? corePoleId;
  final String? projectId;
  final CandidateConversionOperation operation;
  final String message;

  const CandidateConversionResult({
    required this.userId,
    required this.profileType,
    this.corePoleId,
    this.projectId,
    required this.operation,
    required this.message,
  });

  factory CandidateConversionResult.fromResponse(
    Map<String, dynamic> response, {
    required CandidateConversionRequest request,
  }) {
    final message = response['message']?.toString().trim() ?? '';
    final normalized = message.toLowerCase();
    final operation =
        normalized.contains('créé avec succès') ||
            normalized.contains('cree avec succes')
        ? CandidateConversionOperation.created
        : normalized.contains('existait déjà') ||
              normalized.contains('existait deja')
        ? CandidateConversionOperation.existingAccountActivated
        : normalized.contains('existe déjà') ||
              normalized.contains('existe deja')
        ? CandidateConversionOperation.alreadyLinked
        : CandidateConversionOperation.unknown;

    return CandidateConversionResult(
      userId: response['user_id']?.toString() ?? '',
      profileType: response['profile_type']?.toString() ?? request.profileType,
      corePoleId: response['core_pole_id']?.toString() ?? request.corePoleId,
      projectId: response['project_id']?.toString() ?? request.projectId,
      operation: operation,
      message: message.isEmpty ? 'Intégration terminée.' : message,
    );
  }

  String get operationLabel => switch (operation) {
    CandidateConversionOperation.created => 'Compte membre créé',
    CandidateConversionOperation.existingAccountActivated =>
      'Compte existant activé et lié',
    CandidateConversionOperation.alreadyLinked =>
      'Candidature déjà liée à un membre',
    CandidateConversionOperation.unknown => 'Compte membre intégré',
  };

  String get profileLabel => switch (profileType.trim().toLowerCase()) {
    'enactrice' => 'Enactrice',
    _ => 'Enacteur',
  };
}
