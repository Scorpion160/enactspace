import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/impact_models.dart';

class ImpactService {
  final ApiClient _apiClient;
  final AuthService _authService;

  ImpactService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<ImpactDashboardData> getDashboard() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }

    final responses = await Future.wait([
      _apiClient.get('/impact/summary', token: token),
      _apiClient.get('/impact/projects', token: token),
    ]);

    final summary = responses[0];
    final projectsResponse = responses[1];
    if (summary is! Map<String, dynamic> || projectsResponse is! List) {
      throw Exception('Données Impact indisponibles.');
    }

    final projects = projectsResponse
        .whereType<Map<String, dynamic>>()
        .map(projectFromJson)
        .toList();

    return ImpactDashboardData(
      organization: organizationFromJson(summary['organization'], projects),
      historicalImpact: _historicalFromJson(summary['historical_impact']),
      projects: projects,
      enacteurs: _enacteursFromJson(summary['enacteurs']),
      poles: _polesFromJson(summary['poles']),
    );
  }

  ProjectImpactMetricModel projectFromJson(Map<String, dynamic> json) {
    return ProjectImpactMetricModel(
      id: _string(json['id'], fallback: 'project'),
      projectName: _string(json['project_name'], fallback: 'Projet'),
      status: _string(json['status'], fallback: 'Actif'),
      poleName: _string(json['pole_name'], fallback: 'Projet'),
      projectLead: _string(json['project_lead'], fallback: 'Non assigné'),
      deputyLead: _string(json['deputy_lead'], fallback: 'Non assigné'),
      sdgs: _stringList(json['sdgs']),
      problem: _string(json['problem'], fallback: 'Problème à documenter'),
      solution: _string(json['solution'], fallback: 'Solution à documenter'),
      targetBeneficiaries: _string(
        json['target_beneficiaries'],
        fallback: 'Bénéficiaires à préciser',
      ),
      directImpact: _nullableInt(json['direct_impact']),
      indirectImpact: _nullableInt(json['indirect_impact']),
      reach: _nullableInt(json['reach']),
      revenue: _nullableDouble(json['revenue']),
      surplus: _nullableDouble(json['surplus']),
      jobsCreated: _nullableInt(json['jobs_created']),
      livesImpacted: _nullableInt(json['lives_impacted']),
      treesPlanted: _nullableInt(json['trees_planted']),
      wasteReduced: _nullableDouble(json['waste_reduced']),
      waterSaved: _nullableDouble(json['water_saved']),
      co2Reduced: _nullableDouble(json['co2_reduced']),
      planetImpact: _nullableDouble(json['planet_impact']),
      evidenceCount: _int(json['evidence_count']),
      verifiedEvidenceCount: _int(json['verified_evidence_count']),
      methodology: _nullableString(json['methodology']),
      assumptions: _nullableString(json['assumptions']),
      budgetUsed: _double(json['budget_used']),
      progress: _double(json['progress']),
      completedTasks: _int(json['completed_tasks']),
      lateTasks: _int(json['late_tasks']),
      documentsCount: _int(json['documents_count']),
      innovationScore: _nullableDouble(json['innovation_score']),
      businessViabilityScore: _nullableDouble(json['business_viability_score']),
      scalabilityScore: _nullableDouble(json['scalability_score']),
      competitionReadinessScore: _nullableDouble(
        json['competition_readiness_score'],
      ),
      claims: _claimsFromJson(json['claims']),
    );
  }

  OrganizationPerformanceModel organizationFromJson(
    dynamic value,
    List<ProjectImpactMetricModel> projects,
  ) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return OrganizationPerformanceModel(
      activeMembers: _int(json['active_members']),
      attendanceRate: _nullableDouble(json['attendance_rate']),
      retentionRate: _nullableDouble(json['retention_rate']),
      completedTasks: _int(json['completed_tasks']),
      lateTasks: _int(json['late_tasks']),
      activeProjects: _int(json['active_projects'], fallback: projects.length),
      directImpactTotal: _nullableInt(json['direct_impact_total']),
      indirectImpactTotal: _nullableInt(json['indirect_impact_total']),
      reachTotal: _nullableInt(json['reach_total']),
      jobsCreatedTotal: _nullableInt(json['jobs_created_total']),
      livesImpactedTotal: _nullableInt(json['lives_impacted_total']),
      treesPlantedTotal: _nullableInt(json['trees_planted_total']),
      validatedEvidenceCount: _int(json['validated_evidence_count']),
      touchedSdgs: _nullableInt(json['touched_sdgs']),
      revenueTotal: _nullableDouble(json['revenue_total']),
      surplusTotal: _nullableDouble(json['surplus_total']),
      officialDocuments: _int(
        json['official_documents'],
        fallback: projects.fold(0, (sum, item) => sum + item.documentsCount),
      ),
      competitionReadiness: _nullableDouble(json['competition_readiness']),
      academyParticipation: _nullableDouble(json['academy_participation']),
      communicationEngagement: _nullableDouble(
        json['communication_engagement'],
      ),
      financialHealth: _nullableDouble(json['financial_health']),
    );
  }

  HistoricalImpactModel? _historicalFromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final json = value;
    return HistoricalImpactModel(
      createdProjects: _int(json['created_projects']),
      developingProjects: _int(json['developing_projects']),
      developedProducts: _int(json['developed_products']),
      touchedSdgs: _int(json['touched_sdgs']),
      createdJobs: _int(json['created_jobs']),
      savedLives: _int(json['saved_lives']),
      plantedTrees: _int(json['planted_trees']),
      cumulativeUsdGains: _double(json['cumulative_usd_gains']),
      cumulativeFcfaGains: _double(json['cumulative_fcfa_gains']),
      impactedLives: _int(json['impacted_lives']),
      emblematicProjects: _stringList(json['emblematic_projects']),
      distinctions: _stringList(json['distinctions']),
    );
  }

  List<ImpactClaimModel> _claimsFromJson(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().map((json) {
      return ImpactClaimModel(
        id: _string(json['id'], fallback: ''),
        semanticKey: _string(json['semantic_key'], fallback: ''),
        title: _string(json['title'], fallback: 'Indicateur'),
        value: _nullableDouble(json['value']),
        unit: _string(json['unit'], fallback: ''),
        claimType: _string(json['claim_type'], fallback: 'HISTORICAL_CLAIM'),
        validationStatus: _string(json['validation_status'], fallback: 'DRAFT'),
        periodStart: _nullableString(json['period_start']),
        periodEnd: _nullableString(json['period_end']),
        populationScope: _nullableString(json['population_scope']),
        source: _nullableString(json['source']),
        sourceReference: _nullableString(json['source_reference']),
        methodology: _nullableString(json['methodology']),
        notesLimitations: _nullableString(json['notes_limitations']),
        evidenceCount: _int(json['evidence_count']),
      );
    }).toList();
  }

  List<EnacteurPerformanceModel> _enacteursFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => EnacteurPerformanceModel(
            memberName: _string(json['member_name'], fallback: 'Membre'),
            attendanceRate: _double(json['attendance_rate']),
            punctualityRate: _double(json['punctuality_rate']),
            completedTasks: _int(json['completed_tasks']),
            validatedTasks: _int(json['validated_tasks']),
            projectContributions: _int(json['project_contributions']),
            eventsParticipation: _int(json['events_participation']),
            producedDocuments: _int(json['produced_documents']),
            usefulPosts: _int(json['useful_posts']),
            academyLessonsCompleted: _int(json['academy_lessons_completed']),
            passedQuizzes: _int(json['passed_quizzes']),
            badges: _int(json['badges']),
            leadershipScore: _double(json['leadership_score']),
            collaborationScore: _double(json['collaboration_score']),
          ),
        )
        .toList();
  }

  List<PolePerformanceModel> _polesFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => PolePerformanceModel(
            poleName: _string(json['pole_name'], fallback: 'Pôle'),
            activeMembers: _int(json['active_members']),
            attendanceRate: _double(json['attendance_rate']),
            completedTasks: _int(json['completed_tasks']),
            lateTasks: _int(json['late_tasks']),
            documentsCount: _int(json['documents_count']),
            postsCount: _int(json['posts_count']),
            linkedProjects: _int(json['linked_projects']),
            academyProgress: _double(json['academy_progress']),
            alerts: _int(json['alerts']),
          ),
        )
        .toList();
  }

  String _string(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _int(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _nullableInt(dynamic value) {
    if (value == null) return null;
    return num.tryParse(value.toString())?.round();
  }

  double _double(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<String> _stringList(dynamic value, {List<String> fallback = const []}) {
    if (value is! List) return fallback;
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
