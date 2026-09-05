import '../../../core/auth/user_experience.dart';

const archiveCategories = <String>[
  'Projet historique',
  'Prix / distinction',
  'Compétition',
  'Rapport annuel',
  'Article presse',
  'Photo',
  'Vidéo',
  'Document officiel',
  'Témoignage',
  'Ancien membre / Alumni',
  'Événement',
  'Autre',
];

const archiveVisibilities = <String>[
  'interne',
  'enacchefs',
  'alumni',
  'public',
  'privé',
];

String archiveStatusLabel(String value) => switch (value.toLowerCase()) {
  'draft' => 'Brouillon',
  'submitted' => 'Soumis',
  'validated' => 'Validé',
  'rejected' => 'Rejeté',
  'archived' => 'Archivé',
  'hidden' => 'Masqué',
  'under_review' => 'En vérification',
  _ => archiveTechnicalValueLabel(value),
};

String archiveVisibilityLabel(String value) => switch (value.toLowerCase()) {
  'interne' => 'Membres',
  'enacchefs' => 'Responsables',
  'alumni' => 'Alumni',
  'public' => 'Public',
  'privé' => 'Privé',
  _ => archiveTechnicalValueLabel(value),
};

String historicalProjectStatusLabel(String value) =>
    switch (value.toLowerCase()) {
      'historique' => 'Historique',
      'archive' || 'archivé' => 'Archivé',
      'continue' || 'continué' => 'Continué',
      'developpement' || 'développement' => 'En développement',
      _ => archiveTechnicalValueLabel(value),
    };

String historicalMediaTypeLabel(String value) => switch (value.toLowerCase()) {
  'image' || 'photo' => 'Photo',
  'video' => 'Vidéo',
  'lien_video' => 'Lien vidéo',
  'article_presse' => 'Article de presse',
  'rapport' => 'Rapport',
  'presentation' => 'Présentation',
  'document' => 'Document',
  _ => archiveTechnicalValueLabel(value),
};

String historicalDocumentTypeLabel(String value) =>
    switch (value.trim().toLowerCase()) {
      'official_document' || 'document_officiel' => 'Document officiel',
      'annual_report' || 'rapport_annuel' => 'Rapport annuel',
      'presentation' => 'Présentation',
      'minutes' || 'meeting_minutes' || 'proces_verbal' => 'Procès-verbal',
      'press_article' || 'article_presse' => 'Article de presse',
      'report' || 'rapport' => 'Rapport',
      _ => archiveTechnicalValueLabel(value),
    };

String hallOfFameEntryTypeLabel(String value) =>
    switch (value.trim().toLowerCase()) {
      'transmission' => 'Transmission',
      'distinction' || 'award' => 'Distinction',
      'competition' || 'competition_win' => 'Compétition',
      'milestone' => 'Moment clé',
      _ => archiveTechnicalValueLabel(value),
    };

String archiveTechnicalValueLabel(String value) {
  final words = value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (words.isEmpty) return 'Non renseigné';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

bool isPersistedArchiveRecord(String id) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(id);

class ArchivePermissions {
  final bool canCreate;
  final bool canValidate;
  final bool canExport;

  const ArchivePermissions({
    this.canCreate = false,
    this.canValidate = false,
    this.canExport = false,
  });

  factory ArchivePermissions.fromUser(UserExperience? user) {
    final canValidate =
        user != null && (user.isAdmin || user.isTeamLeader || user.isSecretary);
    return ArchivePermissions(
      canCreate: user?.isEnacchef == true || user?.isAdmin == true,
      canValidate: canValidate,
      canExport: canValidate,
    );
  }
}

class ArchiveFileModel {
  final String id;
  final String name;
  final String? downloadUrl;
  final String? previewUrl;
  final int? sizeBytes;

  const ArchiveFileModel({
    required this.id,
    required this.name,
    this.downloadUrl,
    this.previewUrl,
    this.sizeBytes,
  });

  factory ArchiveFileModel.fromJson(Map<String, dynamic> json) =>
      ArchiveFileModel(
        id: archiveString(json['id']),
        name: archiveString(json['name'], fallback: 'Fichier'),
        downloadUrl: archiveNullableString(json['download_url']),
        previewUrl: archiveNullableString(json['preview_url']),
        sizeBytes: archiveNullableInt(json['size_bytes']),
      );
}

class ArchiveItemModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final int? year;
  final String? seasonId;
  final String? projectId;
  final String? poleId;
  final String? documentId;
  final String? fileId;
  final String visibility;
  final String status;
  final bool isFeatured;
  final bool isPublic;
  final String? sourceLabel;
  final String? sourceUrl;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final String? createdById;
  final String? validatedById;
  final DateTime? validatedAt;
  final String? rejectedById;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ArchiveFileModel? file;

  const ArchiveItemModel({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.year,
    this.seasonId,
    this.projectId,
    this.poleId,
    this.documentId,
    this.fileId,
    this.visibility = 'interne',
    this.status = 'draft',
    this.isFeatured = false,
    this.isPublic = false,
    this.sourceLabel,
    this.sourceUrl,
    this.tags = const [],
    this.metadata = const {},
    this.createdById,
    this.validatedById,
    this.validatedAt,
    this.rejectedById,
    this.rejectedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.file,
  });

  factory ArchiveItemModel.fromJson(Map<String, dynamic> json) =>
      ArchiveItemModel(
        id: archiveString(json['id']),
        title: archiveString(json['title'], fallback: 'Archive sans titre'),
        description: archiveNullableString(json['description']),
        category: archiveString(json['category'], fallback: 'Autre'),
        year: archiveNullableInt(json['year']),
        seasonId: archiveNullableString(json['season_id']),
        projectId: archiveNullableString(json['project_id']),
        poleId: archiveNullableString(json['pole_id']),
        documentId: archiveNullableString(json['document_id']),
        fileId: archiveNullableString(json['file_id']),
        visibility: archiveString(json['visibility'], fallback: 'interne'),
        status: archiveString(json['status'], fallback: 'draft'),
        isFeatured: json['is_featured'] == true,
        isPublic: json['is_public'] == true,
        sourceLabel: archiveNullableString(json['source_label']),
        sourceUrl: archiveNullableString(json['source_url']),
        tags: archiveStrings(json['tags']),
        metadata: archiveMap(json['metadata_json']),
        createdById: archiveNullableString(json['created_by_id']),
        validatedById: archiveNullableString(json['validated_by_id']),
        validatedAt: archiveDate(json['validated_at']),
        rejectedById: archiveNullableString(json['rejected_by_id']),
        rejectedAt: archiveDate(json['rejected_at']),
        rejectionReason: archiveNullableString(json['rejection_reason']),
        createdAt: archiveDate(json['created_at']),
        updatedAt: archiveDate(json['updated_at']),
        file: archiveFile(json['file']),
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
  String get statusLabel => archiveStatusLabel(status);
  String get visibilityLabel => archiveVisibilityLabel(visibility);

  String? get humanMetadataNote {
    for (final key in const ['note', 'summary', 'context', 'legacy_note']) {
      final value = archiveNullableString(metadata[key]);
      if (value != null) return value;
    }
    return null;
  }
}

class HistoricalProjectModel {
  final String id;
  final String? archiveItemId;
  final String name;
  final int? year;
  final String? seasonLabel;
  final String? description;
  final String? problem;
  final String? solution;
  final String? impactSummary;
  final String status;
  final String? linkedProjectId;
  final List<String> keyMembers;
  final List<String> awards;
  final List<String> documentIds;
  final List<String> mediaFileIds;

  const HistoricalProjectModel({
    required this.id,
    required this.name,
    this.archiveItemId,
    this.year,
    this.seasonLabel,
    this.description,
    this.problem,
    this.solution,
    this.impactSummary,
    this.status = 'historique',
    this.linkedProjectId,
    this.keyMembers = const [],
    this.awards = const [],
    this.documentIds = const [],
    this.mediaFileIds = const [],
  });

  factory HistoricalProjectModel.fromJson(Map<String, dynamic> json) =>
      HistoricalProjectModel(
        id: archiveString(json['id']),
        archiveItemId: archiveNullableString(json['archive_item_id']),
        name: archiveString(json['name'], fallback: 'Projet historique'),
        year: archiveNullableInt(json['year']),
        seasonLabel: archiveNullableString(json['season_label']),
        description: archiveNullableString(json['description']),
        problem: archiveNullableString(json['problem']),
        solution: archiveNullableString(json['solution']),
        impactSummary: archiveNullableString(json['impact_summary']),
        status: archiveString(json['status'], fallback: 'historique'),
        linkedProjectId: archiveNullableString(json['linked_project_id']),
        keyMembers: archiveStrings(json['key_members']),
        awards: archiveStrings(json['awards']),
        documentIds: archiveStrings(json['document_ids']),
        mediaFileIds: archiveStrings(json['media_file_ids']),
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
  String get statusLabel => historicalProjectStatusLabel(status);
  String get periodLabel =>
      seasonLabel ?? year?.toString() ?? 'Période non renseignée';
}

class ArchiveAwardModel {
  final String id;
  final String title;
  final int? year;
  final String? competition;
  final String? rank;
  final String? result;
  final String? description;
  final String? archivedProjectId;
  final String? fileId;
  final String? mediaUrl;
  final bool isFeatured;

  const ArchiveAwardModel({
    required this.id,
    required this.title,
    this.year,
    this.competition,
    this.rank,
    this.result,
    this.description,
    this.archivedProjectId,
    this.fileId,
    this.mediaUrl,
    this.isFeatured = false,
  });

  factory ArchiveAwardModel.fromJson(Map<String, dynamic> json) =>
      ArchiveAwardModel(
        id: archiveString(json['id']),
        title: archiveString(json['title'], fallback: 'Distinction'),
        year: archiveNullableInt(json['year']),
        competition: archiveNullableString(json['competition']),
        rank: archiveNullableString(json['rank']),
        result: archiveNullableString(json['result']),
        description: archiveNullableString(json['description']),
        archivedProjectId: archiveNullableString(json['archived_project_id']),
        fileId: archiveNullableString(json['file_id']),
        mediaUrl: archiveNullableString(json['media_url']),
        isFeatured: json['is_featured'] == true,
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
}

class ArchiveCompetitionModel {
  final String id;
  final String name;
  final int? year;
  final String? stage;
  final String? result;
  final String? location;
  final String? description;
  final List<String> projectIds;
  final List<String> awardIds;
  final String? fileId;
  final bool isFeatured;

  const ArchiveCompetitionModel({
    required this.id,
    required this.name,
    this.year,
    this.stage,
    this.result,
    this.location,
    this.description,
    this.projectIds = const [],
    this.awardIds = const [],
    this.fileId,
    this.isFeatured = false,
  });

  factory ArchiveCompetitionModel.fromJson(Map<String, dynamic> json) =>
      ArchiveCompetitionModel(
        id: archiveString(json['id']),
        name: archiveString(json['name'], fallback: 'Compétition'),
        year: archiveNullableInt(json['year']),
        stage: archiveNullableString(json['stage']),
        result: archiveNullableString(json['result']),
        location: archiveNullableString(json['location']),
        description: archiveNullableString(json['description']),
        projectIds: archiveStrings(json['project_ids']),
        awardIds: archiveStrings(json['award_ids']),
        fileId: archiveNullableString(json['file_id']),
        isFeatured: json['is_featured'] == true,
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
}

class ArchiveMediaModel {
  final String id;
  final String title;
  final String mediaType;
  final int? year;
  final String? description;
  final String? projectId;
  final String? fileId;
  final String? externalUrl;
  final bool isFeatured;
  final ArchiveFileModel? file;

  const ArchiveMediaModel({
    required this.id,
    required this.title,
    required this.mediaType,
    this.year,
    this.description,
    this.projectId,
    this.fileId,
    this.externalUrl,
    this.isFeatured = false,
    this.file,
  });

  factory ArchiveMediaModel.fromJson(Map<String, dynamic> json) =>
      ArchiveMediaModel(
        id: archiveString(json['id']),
        title: archiveString(json['title'], fallback: 'Média historique'),
        mediaType: archiveString(json['media_type'], fallback: 'document'),
        year: archiveNullableInt(json['year']),
        description: archiveNullableString(json['description']),
        projectId: archiveNullableString(json['project_id']),
        fileId: archiveNullableString(json['file_id']),
        externalUrl: archiveNullableString(json['external_url']),
        isFeatured: json['is_featured'] == true,
        file: archiveFile(json['file']),
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
  String get mediaTypeLabel => historicalMediaTypeLabel(mediaType);
}

class ArchiveDocumentModel {
  final String id;
  final String title;
  final String documentType;
  final int? year;
  final String? description;
  final String? documentId;
  final String? fileId;
  final String? sourceLabel;
  final String visibility;
  final bool isFeatured;
  final ArchiveFileModel? file;

  const ArchiveDocumentModel({
    required this.id,
    required this.title,
    required this.documentType,
    this.year,
    this.description,
    this.documentId,
    this.fileId,
    this.sourceLabel,
    this.visibility = 'interne',
    this.isFeatured = false,
    this.file,
  });

  factory ArchiveDocumentModel.fromJson(Map<String, dynamic> json) =>
      ArchiveDocumentModel(
        id: archiveString(json['id']),
        title: archiveString(json['title'], fallback: 'Document historique'),
        documentType: archiveString(json['document_type'], fallback: 'Autre'),
        year: archiveNullableInt(json['year']),
        description: archiveNullableString(json['description']),
        documentId: archiveNullableString(json['document_id']),
        fileId: archiveNullableString(json['file_id']),
        sourceLabel: archiveNullableString(json['source_label']),
        visibility: archiveString(json['visibility'], fallback: 'interne'),
        isFeatured: json['is_featured'] == true,
        file: archiveFile(json['file']),
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
  String get documentTypeLabel => historicalDocumentTypeLabel(documentType);
}

class HallOfFameEntryModel {
  final String id;
  final String? archiveItemId;
  final String title;
  final String? subtitle;
  final String entryType;
  final int? year;
  final String? description;
  final num? scoreValue;
  final String? scoreLabel;
  final String? fileId;
  final String? externalUrl;
  final int orderIndex;
  final bool isFeatured;
  final ArchiveFileModel? file;

  const HallOfFameEntryModel({
    required this.id,
    required this.title,
    required this.entryType,
    this.archiveItemId,
    this.subtitle,
    this.year,
    this.description,
    this.scoreValue,
    this.scoreLabel,
    this.fileId,
    this.externalUrl,
    this.orderIndex = 0,
    this.isFeatured = false,
    this.file,
  });

  factory HallOfFameEntryModel.fromJson(Map<String, dynamic> json) =>
      HallOfFameEntryModel(
        id: archiveString(json['id']),
        archiveItemId: archiveNullableString(json['archive_item_id']),
        title: archiveString(json['title'], fallback: 'Moment marquant'),
        subtitle: archiveNullableString(json['subtitle']),
        entryType: archiveString(json['entry_type'], fallback: 'Moment'),
        year: archiveNullableInt(json['year']),
        description: archiveNullableString(json['description']),
        scoreValue: json['score_value'] is num
            ? json['score_value'] as num
            : num.tryParse('${json['score_value'] ?? ''}'),
        scoreLabel: archiveNullableString(json['score_label']),
        fileId: archiveNullableString(json['file_id']),
        externalUrl: archiveNullableString(json['external_url']),
        orderIndex: archiveNullableInt(json['order_index']) ?? 0,
        isFeatured: json['is_featured'] == true,
        file: archiveFile(json['file']),
      );

  bool get isPersisted => isPersistedArchiveRecord(id);
  String get entryTypeLabel => hallOfFameEntryTypeLabel(entryType);
}

class HistoricalStatisticModel {
  final String id;
  final String metricKey;
  final String label;
  final num? value;
  final String? unit;
  final String? description;
  final String? sourceLabel;
  final String status;
  final DateTime? validatedAt;

  const HistoricalStatisticModel({
    required this.id,
    required this.metricKey,
    required this.label,
    required this.value,
    this.unit,
    this.description,
    this.sourceLabel,
    this.status = 'draft',
    this.validatedAt,
  });

  factory HistoricalStatisticModel.fromJson(
    Map<String, dynamic> json,
  ) => HistoricalStatisticModel(
    id: archiveString(json['id'], fallback: archiveString(json['metric_key'])),
    metricKey: archiveString(json['metric_key']),
    label: archiveString(json['label'], fallback: 'Indicateur historique'),
    value: json['value'] is num
        ? json['value'] as num
        : num.tryParse('${json['value'] ?? ''}'),
    unit: archiveNullableString(json['unit']),
    description: archiveNullableString(json['description']),
    sourceLabel: archiveNullableString(json['source_label'] ?? json['source']),
    status: archiveString(json['status'], fallback: 'draft'),
    validatedAt: archiveDate(json['validated_at']),
  );

  bool get isPersisted => isPersistedArchiveRecord(id);
  bool get isValidated => status.toLowerCase() == 'validated';
  String get statusLabel => archiveStatusLabel(status);
  String get confidenceLabel =>
      isValidated ? 'Historique validé' : 'Historique à confirmer';
}

class ArchiveImpactSummaryModel {
  final Map<String, num> values;

  const ArchiveImpactSummaryModel({this.values = const {}});

  factory ArchiveImpactSummaryModel.fromJson(Map<String, dynamic> json) {
    final nested = archiveMap(json['summary']);
    final source = nested.isNotEmpty ? nested : json;
    return ArchiveImpactSummaryModel(
      values: {
        for (final entry in source.entries)
          if (entry.value is num) entry.key: entry.value as num,
      },
    );
  }
}

class ArchivesHomeData {
  final ArchivePermissions permissions;
  final ArchiveImpactSummaryModel summary;
  final List<HistoricalStatisticModel> statistics;
  final List<HistoricalProjectModel> projects;
  final List<ArchiveAwardModel> awards;
  final List<ArchiveCompetitionModel> competitions;
  final List<ArchiveMediaModel> media;
  final List<ArchiveDocumentModel> documents;
  final List<HallOfFameEntryModel> hallOfFame;

  const ArchivesHomeData({
    this.permissions = const ArchivePermissions(),
    this.summary = const ArchiveImpactSummaryModel(),
    this.statistics = const [],
    this.projects = const [],
    this.awards = const [],
    this.competitions = const [],
    this.media = const [],
    this.documents = const [],
    this.hallOfFame = const [],
  });
}

Map<String, dynamic> archivePayload(Map<String, dynamic> values) => {
  for (final entry in values.entries)
    if (entry.value != null) entry.key: entry.value,
};

String archiveString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? archiveNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? archiveNullableInt(dynamic value) =>
    value is int ? value : int.tryParse('${value ?? ''}');

DateTime? archiveDate(dynamic value) => DateTime.tryParse('${value ?? ''}');

List<String> archiveStrings(dynamic value) => value is List
    ? value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

Map<String, dynamic> archiveMap(dynamic value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : const {};

ArchiveFileModel? archiveFile(dynamic value) =>
    value is Map ? ArchiveFileModel.fromJson(archiveMap(value)) : null;
