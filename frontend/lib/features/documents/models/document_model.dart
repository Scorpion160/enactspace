class DocumentModel {
  final String id;
  final String title;
  final String? description;
  final String? fileUrl;
  final String? fileType;
  final String category;
  final String visibility;
  final String? uploadedBy;
  final String? poleId;
  final String? projectId;
  final String? eventId;
  final String? seasonId;
  final bool isTemplate;
  final bool isOfficial;
  final String? validatedBy;
  final String? validatedAt;
  final String? createdAt;
  final String? updatedAt;

  const DocumentModel({
    required this.id,
    required this.title,
    this.description,
    this.fileUrl,
    this.fileType,
    required this.category,
    required this.visibility,
    this.uploadedBy,
    this.poleId,
    this.projectId,
    this.eventId,
    this.seasonId,
    required this.isTemplate,
    required this.isOfficial,
    this.validatedBy,
    this.validatedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Document sans titre',
      description: json['description']?.toString(),
      fileUrl: json['file_url']?.toString(),
      fileType: json['file_type']?.toString(),
      category: json['category']?.toString() ?? 'general',
      visibility: json['visibility']?.toString() ?? 'internal',
      uploadedBy: json['uploaded_by']?.toString(),
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      eventId: json['event_id']?.toString(),
      seasonId: json['season_id']?.toString(),
      isTemplate: json['is_template'] == true,
      isOfficial: json['is_official'] == true,
      validatedBy: json['validated_by']?.toString(),
      validatedAt: json['validated_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'general':
        return 'Général';
      case 'pv':
        return 'PV';
      case 'rapport':
        return 'Rapport';
      case 'budget':
        return 'Budget';
      case 'fiche_projet':
        return 'Fiche projet';
      case 'pitch_deck':
        return 'Pitch deck';
      case 'support_formation':
        return 'Support formation';
      case 'photo':
        return 'Photo';
      case 'video':
        return 'Vidéo';
      case 'code_source':
        return 'Code source';
      case 'administratif':
        return 'Administratif';
      case 'partenariat':
        return 'Partenariat';
      case 'autre':
        return 'Autre';
      default:
        return category;
    }
  }

  String get visibilityLabel {
    switch (visibility) {
      case 'public_club':
        return 'Club';
      case 'internal':
        return 'Interne';
      case 'pole_only':
        return 'Pôle uniquement';
      case 'project_only':
        return 'Projet uniquement';
      case 'enacchef_only':
        return 'Bureau uniquement';
      case 'private':
        return 'Privé';
      default:
        return visibility;
    }
  }

  String get fileTypeLabel {
    if (fileType == null || fileType!.trim().isEmpty) {
      return 'Fichier';
    }

    return fileType!.toUpperCase();
  }

  String get createdAtLabel {
    if (createdAt == null || createdAt!.isEmpty) return 'Date inconnue';

    final date = DateTime.tryParse(createdAt!);
    if (date == null) return createdAt!;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}
