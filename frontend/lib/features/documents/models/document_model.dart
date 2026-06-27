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
  final bool canManage;
  final bool canValidate;
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
    required this.canManage,
    required this.canValidate,
    this.validatedBy,
    this.validatedAt,
    this.createdAt,
    this.updatedAt,
  });

  static const List<DocumentCategoryOption> categoryOptions = [
    DocumentCategoryOption('general', 'Général', 'Documents transversaux'),
    DocumentCategoryOption('pv', 'PV', 'Comptes rendus de réunion'),
    DocumentCategoryOption('rapport', 'Rapport', 'Rapports et synthèses'),
    DocumentCategoryOption(
      'rapport_terrain',
      'Rapport terrain',
      'Visites, missions et bilans mensuels',
    ),
    DocumentCategoryOption(
      'preuve_impact',
      'Preuve impact',
      'Bénéficiaires, photos preuve, recueil impact',
    ),
    DocumentCategoryOption('budget', 'Budget', 'Budgétisations et devis'),
    DocumentCategoryOption('finance', 'Finance', 'Paiements et trésorerie'),
    DocumentCategoryOption('fiche_projet', 'Fiche projet', 'Cadrage projet'),
    DocumentCategoryOption('pitch_deck', 'Pitch deck', 'Présentations'),
    DocumentCategoryOption(
      'competition',
      'Compétition',
      'World Cup, jury, annual report',
    ),
    DocumentCategoryOption(
      'support_formation',
      'Support formation',
      'Guides et contenus Academy',
    ),
    DocumentCategoryOption('photo', 'Photo', 'Albums et preuves visuelles'),
    DocumentCategoryOption('video', 'Vidéo', 'Vidéos et interviews'),
    DocumentCategoryOption('media', 'Média', 'Presse et communication'),
    DocumentCategoryOption(
      'code_source',
      'Code source',
      'Dépôts et livrables IT',
    ),
    DocumentCategoryOption('technique', 'Technique', 'Plans et prototypes'),
    DocumentCategoryOption('recherche', 'Recherche', 'Études et analyses'),
    DocumentCategoryOption(
      'administratif',
      'Administratif',
      'Lettres, autorisations et demandes',
    ),
    DocumentCategoryOption('juridique', 'Juridique', 'Textes et règlements'),
    DocumentCategoryOption(
      'discipline',
      'Discipline',
      'Notifications confidentielles',
    ),
    DocumentCategoryOption('presence', 'Présence', 'Absences et assiduité'),
    DocumentCategoryOption('voyage', 'Voyage', 'Missions, bus et itinéraires'),
    DocumentCategoryOption(
      'communication',
      'Communication',
      'Posts et supports',
    ),
    DocumentCategoryOption(
      'rh_recrutement',
      'RH/Recrutement',
      'Candidatures et sélections',
    ),
    DocumentCategoryOption('partenariat', 'Partenariat', 'Sponsors et appels'),
    DocumentCategoryOption('modele', 'Modèle', 'Canevas réutilisables'),
    DocumentCategoryOption('autre', 'Autre', 'Document non classé'),
  ];

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
      canManage: json['can_manage'] == true,
      canValidate: json['can_validate'] == true,
      validatedBy: json['validated_by']?.toString(),
      validatedAt: json['validated_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  static String categoryTitle(String value) {
    return categoryOptions
        .firstWhere(
          (option) => option.value == value,
          orElse: () => DocumentCategoryOption(value, value, value),
        )
        .label;
  }

  String get categoryLabel => categoryTitle(category);

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
    final normalized = fileType?.trim().replaceAll('.', '').toUpperCase();
    return normalized == null || normalized.isEmpty ? 'Fichier' : normalized;
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

class DocumentCategoryOption {
  final String value;
  final String label;
  final String hint;

  const DocumentCategoryOption(this.value, this.label, this.hint);
}
