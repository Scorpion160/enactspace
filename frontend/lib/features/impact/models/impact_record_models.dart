String impactStatusLabel(String status) => switch (status) {
  'DRAFT' || 'draft' => 'Brouillon · à vérifier',
  'EVIDENCE_PENDING' || 'submitted' => 'Preuve attendue',
  'EVIDENCE_ATTACHED' => 'Preuve jointe · à vérifier',
  'UNDER_REVIEW' || 'under_review' => 'En vérification',
  'VERIFIED' || 'validated' => 'Vérifié',
  'REJECTED' || 'rejected' => 'Rejeté',
  'SUPERSEDED' || 'archived' => 'Remplacé',
  _ => 'Statut indisponible',
};

String impactClaimTypeLabel(String claimType) => switch (claimType) {
  'MEASURED' => 'Mesuré',
  'ESTIMATE' => 'Estimation',
  'PROJECTION' => 'Projection',
  'HISTORICAL_CLAIM' => 'Historique déclaré',
  _ => 'Type indisponible',
};

String impactValueLabel(num? value) =>
    value == null ? 'Non renseigné' : '$value';

String impactCategoryLabel(String category) => switch (category) {
  'social' => 'Social',
  'economique' => 'Économique',
  'environmental' || 'environnemental' => 'Environnemental',
  'formation' => 'Formation',
  'sensibilisation' => 'Sensibilisation',
  _ => 'Autre',
};

String impactUnitLabel(String unit) => switch (unit) {
  'personnes' => 'Personnes',
  'FCFA' => 'FCFA',
  'emplois' => 'Emplois',
  'arbres' => 'Arbres',
  'kg' => 'kg',
  'litres' => 'Litres',
  'pourcentage' => 'Pourcentage',
  _ => 'Autre',
};

class ImpactRecordModel {
  final String id;
  final String projectId;
  final String? seasonId;
  final String title;
  final String? summary;
  final String? problemStatement;
  final String? solutionSummary;
  final String? targetPopulation;
  final int? directBeneficiaries;
  final int? indirectBeneficiaries;
  final int? reach;
  final int? jobsCreated;
  final double? revenueGenerated;
  final double? profitOrSurplus;
  final double? costSavings;
  final int? livesImpacted;
  final int? treesPlanted;
  final double? wasteReduced;
  final double? waterSaved;
  final double? co2Reduced;
  final List<String> sdgs;
  final String? evidenceNotes;
  final String? methodology;
  final String? projectionNext12Months;
  final String status;
  final String validationStatus;
  final bool canManage;
  final bool canValidate;

  const ImpactRecordModel({
    required this.id,
    required this.projectId,
    required this.seasonId,
    required this.title,
    required this.summary,
    required this.problemStatement,
    required this.solutionSummary,
    required this.targetPopulation,
    required this.directBeneficiaries,
    required this.indirectBeneficiaries,
    required this.reach,
    required this.jobsCreated,
    required this.revenueGenerated,
    required this.profitOrSurplus,
    required this.costSavings,
    required this.livesImpacted,
    required this.treesPlanted,
    required this.wasteReduced,
    required this.waterSaved,
    required this.co2Reduced,
    required this.sdgs,
    required this.evidenceNotes,
    required this.methodology,
    required this.projectionNext12Months,
    required this.status,
    this.validationStatus = 'DRAFT',
    required this.canManage,
    required this.canValidate,
  });
  String get statusLabel => validationStatus == 'VERIFIED' || status == 'validated'
      ? 'Fiche vérifiée'
      : impactStatusLabel(validationStatus);
  factory ImpactRecordModel.fromJson(Map<String, dynamic> j) =>
      ImpactRecordModel(
        id: _s(j['id'] ?? j['impact_project_id']),
        projectId: _s(j['project_id']),
        seasonId: j['season_id']?.toString(),
        title: _s(j['title'], 'Fiche Impact'),
        summary: j['summary']?.toString(),
        problemStatement: j['problem_statement']?.toString(),
        solutionSummary: j['solution_summary']?.toString(),
        targetPopulation: j['target_population']?.toString(),
        directBeneficiaries: _nullableInt(j['direct_beneficiaries']),
        indirectBeneficiaries: _nullableInt(j['indirect_beneficiaries']),
        reach: _nullableInt(j['reach']),
        jobsCreated: _nullableInt(j['jobs_created']),
        revenueGenerated: _nullableDouble(j['revenue_generated']),
        profitOrSurplus: _nullableDouble(j['profit_or_surplus']),
        costSavings: _nullableDouble(j['cost_savings']),
        livesImpacted: _nullableInt(j['lives_impacted']),
        treesPlanted: _nullableInt(j['trees_planted']),
        wasteReduced: _nullableDouble(j['waste_reduced']),
        waterSaved: _nullableDouble(j['water_saved']),
        co2Reduced: _nullableDouble(j['co2_reduced']),
        sdgs: _list(j['sdgs']),
        evidenceNotes: j['evidence_notes']?.toString(),
        methodology: j['methodology']?.toString(),
        projectionNext12Months: j['projection_next_12_months']?.toString(),
        status: _s(j['status'], 'draft'),
        validationStatus: _s(j['validation_status'] ?? j['status'], 'DRAFT'),
        canManage: j['can_manage'] == true,
        canValidate: j['can_validate'] == true,
      );
}

class ImpactMetricModel {
  final String id;
  final String semanticKey;
  final String title;
  final String category;
  final String unit;
  final double? value;
  final String claimType;
  final String validationStatus;
  final String? periodStart;
  final String? periodEnd;
  final String? populationScope;
  final String? source;
  final String? sourceReference;
  final String? methodologyNote;
  final String? notesLimitations;
  final String? evidenceFileId;
  final String status;
  final String? rejectionReason;
  const ImpactMetricModel({
    required this.id,
    required this.semanticKey,
    required this.title,
    required this.category,
    required this.unit,
    required this.value,
    required this.claimType,
    required this.validationStatus,
    required this.periodStart,
    required this.periodEnd,
    required this.populationScope,
    required this.source,
    required this.sourceReference,
    required this.methodologyNote,
    required this.notesLimitations,
    required this.evidenceFileId,
    required this.status,
    required this.rejectionReason,
  });
  String get categoryLabel => impactCategoryLabel(category);
  String get unitLabel => impactUnitLabel(unit);
  String get statusLabel => impactStatusLabel(validationStatus);
  String get claimTypeLabel => impactClaimTypeLabel(claimType);
  bool get isRealized =>
      claimType == 'MEASURED' && validationStatus == 'VERIFIED';
  factory ImpactMetricModel.fromJson(Map<String, dynamic> j) =>
      ImpactMetricModel(
        id: _s(j['id']),
        semanticKey: _s(j['semantic_key']),
        title: _s(j['title'], 'Indicateur'),
        category: _s(j['category'], 'autre'),
        unit: _s(j['unit'], 'autre'),
        value: _nullableDouble(j['value']),
        claimType: _s(j['claim_type'], 'HISTORICAL_CLAIM'),
        validationStatus: _s(j['validation_status'] ?? j['status'], 'DRAFT'),
        periodStart: j['period_start']?.toString(),
        periodEnd: j['period_end']?.toString(),
        populationScope: j['population_scope']?.toString(),
        source: j['source']?.toString(),
        sourceReference: j['source_reference']?.toString(),
        methodologyNote: j['methodology_note']?.toString(),
        notesLimitations: j['notes_limitations']?.toString(),
        evidenceFileId: j['evidence_file_id']?.toString(),
        status: _s(j['status'], 'draft'),
        rejectionReason: j['rejection_reason']?.toString(),
      );
}

class ImpactEvidenceModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? metricId;
  final String? fileId;
  final String status;
  final String validationStatus;
  final String? rejectionReason;
  const ImpactEvidenceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.metricId,
    required this.fileId,
    required this.status,
    required this.validationStatus,
    required this.rejectionReason,
  });
  String get categoryLabel => impactCategoryLabel(category);
  String get statusLabel => impactStatusLabel(validationStatus);
  factory ImpactEvidenceModel.fromJson(Map<String, dynamic> j) =>
      ImpactEvidenceModel(
        id: _s(j['id']),
        title: _s(j['title'], 'Preuve'),
        description: j['description']?.toString(),
        category: _s(j['category'], 'autre'),
        metricId: j['metric_id']?.toString(),
        fileId: (j['file_id'] ?? j['evidence_file_id'])?.toString(),
        status: _s(j['status'], 'draft'),
        validationStatus: _s(
          j['validation_status'] ?? j['status'],
          'EVIDENCE_ATTACHED',
        ),
        rejectionReason: j['rejection_reason']?.toString(),
      );
}

String _s(dynamic v, [String fallback = '']) {
  final text = v?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

int? _nullableInt(dynamic v) =>
    v == null ? null : num.tryParse(v.toString())?.round();
double? _nullableDouble(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());
List<String> _list(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
