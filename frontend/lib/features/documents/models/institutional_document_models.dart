class InstitutionalFieldModel {
  final String name;
  final String label;
  final String type;
  final bool required;
  final Map<String, dynamic> metadata;

  const InstitutionalFieldModel({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    this.metadata = const {},
  });

  factory InstitutionalFieldModel.fromJson(Map<String, dynamic> json) {
    return InstitutionalFieldModel(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      required: json['required'] == true,
      metadata: Map<String, dynamic>.from(json),
    );
  }
}

class InstitutionalTemplateModel {
  final String code;
  final String label;
  final String version;
  final String category;
  final String visibility;
  final String scope;
  final String referencePrefix;
  final String slogan;
  final bool requiresSgValidation;
  final bool requiresTlApproval;
  final bool canCreate;
  final List<InstitutionalFieldModel> fields;

  const InstitutionalTemplateModel({
    required this.code,
    required this.label,
    required this.version,
    required this.category,
    required this.visibility,
    required this.scope,
    required this.referencePrefix,
    required this.slogan,
    required this.requiresSgValidation,
    required this.requiresTlApproval,
    required this.canCreate,
    required this.fields,
  });

  factory InstitutionalTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    return InstitutionalTemplateModel(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'internal',
      scope: json['scope']?.toString() ?? 'club',
      referencePrefix: json['reference_prefix']?.toString() ?? '',
      slogan: json['slogan']?.toString() ?? '',
      requiresSgValidation: json['requires_sg_validation'] == true,
      requiresTlApproval: json['requires_tl_approval'] == true,
      canCreate: json['can_create'] == true,
      fields: rawFields is List
          ? rawFields
                .whereType<Map>()
                .map(
                  (item) => InstitutionalFieldModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }

  bool get requiresPole => scope == 'pole_required' || scope == 'veille_required';
  bool get requiresProject => scope == 'project_required';
  bool get hasOptionalScope => scope == 'optional';
  bool get isVeilleOnly => scope == 'veille_required';

  String get approvalLabel {
    if (requiresSgValidation && requiresTlApproval) {
      return 'Validation SG puis approbation Team Leader';
    }
    if (requiresSgValidation) return 'Validation Secrétariat Général';
    if (requiresTlApproval) return 'Approbation Team Leader';
    return 'Validation automatique';
  }
}

class InstitutionalDocumentRequestModel {
  final String id;
  final String templateCode;
  final String templateLabel;
  final String templateVersion;
  final String status;
  final Map<String, dynamic> payload;
  final String requestedBy;
  final String? submittedBy;
  final String? sgValidatedBy;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;
  final String? cancellationReason;
  final String? poleId;
  final String? projectId;
  final String? eventId;
  final String? seasonId;
  final int? sequenceNumber;
  final String? officialReference;
  final String? generatedDocumentId;
  final String? createdAt;
  final String? updatedAt;
  final bool canEdit;
  final bool canSubmit;
  final bool canSgValidate;
  final bool canApprove;
  final bool canCancel;

  const InstitutionalDocumentRequestModel({
    required this.id,
    required this.templateCode,
    required this.templateLabel,
    required this.templateVersion,
    required this.status,
    required this.payload,
    required this.requestedBy,
    this.submittedBy,
    this.sgValidatedBy,
    this.approvedBy,
    this.rejectedBy,
    this.rejectionReason,
    this.cancellationReason,
    this.poleId,
    this.projectId,
    this.eventId,
    this.seasonId,
    this.sequenceNumber,
    this.officialReference,
    this.generatedDocumentId,
    this.createdAt,
    this.updatedAt,
    required this.canEdit,
    required this.canSubmit,
    required this.canSgValidate,
    required this.canApprove,
    required this.canCancel,
  });

  factory InstitutionalDocumentRequestModel.fromJson(Map<String, dynamic> json) {
    return InstitutionalDocumentRequestModel(
      id: json['id']?.toString() ?? '',
      templateCode: json['template_code']?.toString() ?? '',
      templateLabel: json['template_label']?.toString() ?? '',
      templateVersion: json['template_version']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      requestedBy: json['requested_by']?.toString() ?? '',
      submittedBy: json['submitted_by']?.toString(),
      sgValidatedBy: json['sg_validated_by']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      rejectedBy: json['rejected_by']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      eventId: json['event_id']?.toString(),
      seasonId: json['season_id']?.toString(),
      sequenceNumber: int.tryParse(json['sequence_number']?.toString() ?? ''),
      officialReference: json['official_reference']?.toString(),
      generatedDocumentId: json['generated_document_id']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      canEdit: json['can_edit'] == true,
      canSubmit: json['can_submit'] == true,
      canSgValidate: json['can_sg_validate'] == true,
      canApprove: json['can_approve'] == true,
      canCancel: json['can_cancel'] == true,
    );
  }

  bool get isPendingReview =>
      status == 'pending_sg_validation' || status == 'pending_approval';
  bool get isValidated => status == 'validated';
  bool get isGenerated => status == 'generated' || generatedDocumentId != null;

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Brouillon';
      case 'pending_sg_validation':
        return 'À valider par le SG';
      case 'pending_approval':
        return 'À approuver par le Team Leader';
      case 'validated':
        return 'Validé — PDF à générer';
      case 'generated':
        return 'PDF officiel généré';
      case 'rejected':
        return 'À corriger';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }
}

class InstitutionalGenerationResult {
  final InstitutionalDocumentRequestModel request;
  final String? documentId;
  final String? fileId;
  final String? fileUrl;
  final String? officialReference;
  final bool alreadyGenerated;

  const InstitutionalGenerationResult({
    required this.request,
    this.documentId,
    this.fileId,
    this.fileUrl,
    this.officialReference,
    required this.alreadyGenerated,
  });

  factory InstitutionalGenerationResult.fromJson(Map<String, dynamic> json) {
    final rawRequest = json['request'];
    if (rawRequest is! Map) {
      throw const FormatException('Réponse de génération invalide.');
    }
    return InstitutionalGenerationResult(
      request: InstitutionalDocumentRequestModel.fromJson(
        Map<String, dynamic>.from(rawRequest),
      ),
      documentId: json['document_id']?.toString(),
      fileId: json['file_id']?.toString(),
      fileUrl: json['file_url']?.toString(),
      officialReference: json['official_reference']?.toString(),
      alreadyGenerated: json['already_generated'] == true,
    );
  }
}
