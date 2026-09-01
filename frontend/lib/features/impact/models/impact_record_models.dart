String impactStatusLabel(String status) => switch (status) {
  'draft' => 'Brouillon',
  'submitted' => 'Soumis',
  'under_review' => 'En vérification',
  'validated' => 'Validé',
  'rejected' => 'Rejeté',
  'archived' => 'Archivé',
  _ => 'Statut indisponible',
};

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
  final int directBeneficiaries;
  final int indirectBeneficiaries;
  final int reach;
  final int jobsCreated;
  final double revenueGenerated;
  final double profitOrSurplus;
  final double costSavings;
  final int livesImpacted;
  final int treesPlanted;
  final double wasteReduced;
  final double waterSaved;
  final double co2Reduced;
  final List<String> sdgs;
  final String? evidenceNotes;
  final String? methodology;
  final String? projectionNext12Months;
  final String status;
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
    required this.canManage,
    required this.canValidate,
  });
  String get statusLabel => impactStatusLabel(status);
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
        directBeneficiaries: _i(j['direct_beneficiaries']),
        indirectBeneficiaries: _i(j['indirect_beneficiaries']),
        reach: _i(j['reach']),
        jobsCreated: _i(j['jobs_created']),
        revenueGenerated: _d(j['revenue_generated']),
        profitOrSurplus: _d(j['profit_or_surplus']),
        costSavings: _d(j['cost_savings']),
        livesImpacted: _i(j['lives_impacted']),
        treesPlanted: _i(j['trees_planted']),
        wasteReduced: _d(j['waste_reduced']),
        waterSaved: _d(j['water_saved']),
        co2Reduced: _d(j['co2_reduced']),
        sdgs: _list(j['sdgs']),
        evidenceNotes: j['evidence_notes']?.toString(),
        methodology: j['methodology']?.toString(),
        projectionNext12Months: j['projection_next_12_months']?.toString(),
        status: _s(j['status'], 'draft'),
        canManage: j['can_manage'] == true,
        canValidate: j['can_validate'] == true,
      );
}

class ImpactMetricModel {
  final String id;
  final String title;
  final String category;
  final String unit;
  final double value;
  final String? source;
  final String? methodologyNote;
  final String? evidenceFileId;
  final String status;
  final String? rejectionReason;
  const ImpactMetricModel({
    required this.id,
    required this.title,
    required this.category,
    required this.unit,
    required this.value,
    required this.source,
    required this.methodologyNote,
    required this.evidenceFileId,
    required this.status,
    required this.rejectionReason,
  });
  String get categoryLabel => impactCategoryLabel(category);
  String get unitLabel => impactUnitLabel(unit);
  String get statusLabel => impactStatusLabel(status);
  factory ImpactMetricModel.fromJson(Map<String, dynamic> j) =>
      ImpactMetricModel(
        id: _s(j['id']),
        title: _s(j['title'], 'Indicateur'),
        category: _s(j['category'], 'autre'),
        unit: _s(j['unit'], 'autre'),
        value: _d(j['value']),
        source: j['source']?.toString(),
        methodologyNote: j['methodology_note']?.toString(),
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
  final String? rejectionReason;
  const ImpactEvidenceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.metricId,
    required this.fileId,
    required this.status,
    required this.rejectionReason,
  });
  String get categoryLabel => impactCategoryLabel(category);
  String get statusLabel => impactStatusLabel(status);
  factory ImpactEvidenceModel.fromJson(Map<String, dynamic> j) =>
      ImpactEvidenceModel(
        id: _s(j['id']),
        title: _s(j['title'], 'Preuve'),
        description: j['description']?.toString(),
        category: _s(j['category'], 'autre'),
        metricId: j['metric_id']?.toString(),
        fileId: (j['file_id'] ?? j['evidence_file_id'])?.toString(),
        status: _s(j['status'], 'draft'),
        rejectionReason: j['rejection_reason']?.toString(),
      );
}

String _s(dynamic v, [String fallback = '']) {
  final text = v?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
List<String> _list(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
