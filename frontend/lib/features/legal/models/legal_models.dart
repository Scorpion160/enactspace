class LegalDocument {
  final String id;
  final String type;
  final String version;
  final String title;
  final String content;
  final DateTime? effectiveAt;
  final bool requiresAcceptance;

  const LegalDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.title,
    required this.content,
    required this.effectiveAt,
    required this.requiresAcceptance,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
    id: json['id']?.toString() ?? '',
    type: json['document_type']?.toString() ?? '',
    version: json['version']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    effectiveAt: DateTime.tryParse(json['effective_at']?.toString() ?? ''),
    requiresAcceptance: json['requires_acceptance'] == true,
  );

  bool matchesStatus(LegalStatus status) =>
      id == status.documentId &&
      version == status.version &&
      type == status.type;
}

class LegalStatus {
  final String type;
  final String documentId;
  final String version;
  final bool requiresAcceptance;
  final bool accepted;

  const LegalStatus({
    required this.type,
    required this.documentId,
    required this.version,
    required this.requiresAcceptance,
    required this.accepted,
  });

  factory LegalStatus.fromJson(Map<String, dynamic> json) => LegalStatus(
    type: json['document_type']?.toString() ?? '',
    documentId: json['document_id']?.toString() ?? '',
    version: json['version']?.toString() ?? '',
    requiresAcceptance: json['requires_acceptance'] == true,
    accepted: json['accepted'] == true,
  );

  bool get pending => requiresAcceptance && !accepted;
}
