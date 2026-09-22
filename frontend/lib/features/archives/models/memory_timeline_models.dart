import 'archive_contract_models.dart';

class MemorySourceCapability {
  final String type;
  final String url;

  const MemorySourceCapability({required this.type, required this.url});

  factory MemorySourceCapability.fromJson(Map<String, dynamic> json) =>
      MemorySourceCapability(
        type: archiveString(json['type']),
        url: archiveString(json['url']),
      );
}

class MemorySourceProvenance {
  final String id;
  final String type;
  final String label;
  final MemorySourceCapability? capability;

  const MemorySourceProvenance({
    required this.id,
    required this.type,
    required this.label,
    this.capability,
  });

  factory MemorySourceProvenance.fromJson(Map<String, dynamic> json) {
    final rawCapability = json['capability'];
    return MemorySourceProvenance(
      id: archiveString(json['id']),
      type: archiveString(json['type'], fallback: 'source'),
      label: archiveString(json['label'], fallback: 'Source institutionnelle'),
      capability: rawCapability is Map
          ? MemorySourceCapability.fromJson(archiveMap(rawCapability))
          : null,
    );
  }
}

class MemoryRelatedEntity {
  final String type;
  final String id;
  final String label;
  final bool available;

  const MemoryRelatedEntity({
    required this.type,
    required this.id,
    required this.label,
    this.available = true,
  });

  factory MemoryRelatedEntity.fromJson(Map<String, dynamic> json) =>
      MemoryRelatedEntity(
        type: archiveString(json['type']),
        id: archiveString(json['id']),
        label: archiveString(json['label'], fallback: 'Élément indisponible'),
        available: json['available'] != false,
      );
}

class MemoryTimelineItem {
  final String id;
  final String resourceType;
  final String title;
  final String? summary;
  final int year;
  final DateTime? effectiveDate;
  final String datePrecision;
  final String validationStatus;
  final String origin;
  final DateTime? capturedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? validatedAt;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final String? sourceEntityVersion;
  final MemorySourceProvenance? source;
  final List<MemoryRelatedEntity> relatedEntities;

  const MemoryTimelineItem({
    required this.id,
    required this.resourceType,
    required this.title,
    required this.year,
    required this.datePrecision,
    required this.validationStatus,
    required this.origin,
    this.summary,
    this.effectiveDate,
    this.capturedAt,
    this.createdAt,
    this.updatedAt,
    this.validatedAt,
    this.sourceEntityType,
    this.sourceEntityId,
    this.sourceEntityVersion,
    this.source,
    this.relatedEntities = const [],
  });

  factory MemoryTimelineItem.fromJson(Map<String, dynamic> json) {
    final sourceJson = json['source'];
    final related = json['related_entities'];
    return MemoryTimelineItem(
      id: archiveString(json['id']),
      resourceType: archiveString(json['resource_type']),
      title: archiveString(json['title'], fallback: 'Repère institutionnel'),
      summary: archiveNullableString(json['summary']),
      year: archiveNullableInt(json['year']) ?? 0,
      effectiveDate: archiveDate(json['effective_date']),
      datePrecision: archiveString(json['date_precision'], fallback: 'year'),
      validationStatus: archiveString(
        json['validation_status'],
        fallback: 'HISTORICAL_REPORTED',
      ),
      origin: archiveString(json['origin'], fallback: 'manual'),
      capturedAt: archiveDate(json['captured_at']),
      createdAt: archiveDate(json['created_at']),
      updatedAt: archiveDate(json['updated_at']),
      validatedAt: archiveDate(json['validated_at']),
      sourceEntityType: archiveNullableString(json['source_entity_type']),
      sourceEntityId: archiveNullableString(json['source_entity_id']),
      sourceEntityVersion: archiveNullableString(json['source_entity_version']),
      source: sourceJson is Map
          ? MemorySourceProvenance.fromJson(archiveMap(sourceJson))
          : null,
      relatedEntities: related is List
          ? related
                .whereType<Map>()
                .map((value) => MemoryRelatedEntity.fromJson(archiveMap(value)))
                .toList(growable: false)
          : const [],
    );
  }

  String get trustLabel => memoryTrustLabel(validationStatus);
  String get originLabel =>
      origin == 'operational' ? 'Origine système' : 'Saisie manuelle';
  String get dateLabel => effectiveDate == null
      ? '$year · année seulement'
      : '${effectiveDate!.day.toString().padLeft(2, '0')}/'
            '${effectiveDate!.month.toString().padLeft(2, '0')}/'
            '${effectiveDate!.year}';
  bool get hasUnavailableRelation =>
      relatedEntities.any((entity) => !entity.available);
}

class MemoryTimelinePage {
  final List<MemoryTimelineItem> items;
  final String? nextCursor;

  const MemoryTimelinePage({required this.items, this.nextCursor});

  factory MemoryTimelinePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return MemoryTimelinePage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((value) => MemoryTimelineItem.fromJson(archiveMap(value)))
                .toList(growable: false)
          : const [],
      nextCursor: archiveNullableString(json['next_cursor']),
    );
  }
}

class MemoryTimelineFilters {
  final int? startYear;
  final int? endYear;
  final String? resourceType;
  final String? projectId;
  final String? poleId;
  final String? memberId;
  final String? eventId;
  final String? search;
  final bool review;

  const MemoryTimelineFilters({
    this.startYear,
    this.endYear,
    this.resourceType,
    this.projectId,
    this.poleId,
    this.memberId,
    this.eventId,
    this.search,
    this.review = false,
  });

  MemoryTimelineFilters copyWith({String? search, bool? review}) =>
      MemoryTimelineFilters(
        startYear: startYear,
        endYear: endYear,
        resourceType: resourceType,
        projectId: projectId,
        poleId: poleId,
        memberId: memberId,
        eventId: eventId,
        search: search,
        review: review ?? this.review,
      );

  bool get isFiltered =>
      startYear != null ||
      endYear != null ||
      resourceType != null ||
      projectId != null ||
      poleId != null ||
      memberId != null ||
      eventId != null ||
      (search?.isNotEmpty ?? false) ||
      review;

  Map<String, Object?> toQuery({String? cursor, int limit = 25}) => {
    'start_year': startYear,
    'end_year': endYear,
    'type': resourceType,
    'project_id': projectId,
    'pole_id': poleId,
    'member_id': memberId,
    'event_id': eventId,
    'search': search,
    if (review) 'review': true,
    'limit': limit,
    'cursor': cursor,
  };
}

String memoryTrustLabel(String value) => switch (value.toUpperCase()) {
  'VERIFIED' => 'Vérifié',
  'HISTORICAL_REPORTED' => 'Signalé historiquement',
  'EVIDENCE_PENDING' => 'Preuve attendue',
  'EVIDENCE_ATTACHED' => 'Preuve jointe',
  'UNDER_REVIEW' => 'En vérification',
  'REJECTED' => 'Rejeté',
  'SUPERSEDED' => 'Remplacé',
  _ => archiveTechnicalValueLabel(value),
};
