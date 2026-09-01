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
        .map(_projectFromJson)
        .toList();

    return ImpactDashboardData(
      organization: _organizationFromJson(summary['organization'], projects),
      historicalImpact: _historicalFromJson(summary['historical_impact']),
      projects: projects,
      enacteurs: _enacteursFromJson(summary['enacteurs']),
      poles: _polesFromJson(summary['poles']),
    );
  }

  ProjectImpactMetricModel _projectFromJson(Map<String, dynamic> json) {
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
      directImpact: _int(json['direct_impact']),
      indirectImpact: _int(json['indirect_impact']),
      reach: _int(json['reach']),
      revenue: _double(json['revenue']),
      surplus: _double(json['surplus']),
      jobsCreated: _int(json['jobs_created']),
      livesImpacted: _int(json['lives_impacted']),
      treesPlanted: _int(json['trees_planted']),
      wasteReduced: _double(json['waste_reduced']),
      waterSaved: _double(json['water_saved']),
      co2Reduced: _double(json['co2_reduced']),
      planetImpact: _double(json['planet_impact']),
      evidenceCount: _int(json['evidence_count']),
      methodology: _string(json['methodology'], fallback: 'Méthode à préciser'),
      assumptions: _string(
        json['assumptions'],
        fallback: 'Hypothèses à préciser',
      ),
      budgetUsed: _double(json['budget_used']),
      progress: _double(json['progress']),
      completedTasks: _int(json['completed_tasks']),
      lateTasks: _int(json['late_tasks']),
      documentsCount: _int(json['documents_count']),
      innovationScore: _double(json['innovation_score']),
      businessViabilityScore: _double(json['business_viability_score']),
      scalabilityScore: _double(json['scalability_score']),
      competitionReadinessScore: _double(json['competition_readiness_score']),
    );
  }

  OrganizationPerformanceModel _organizationFromJson(
    dynamic value,
    List<ProjectImpactMetricModel> projects,
  ) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return OrganizationPerformanceModel(
      activeMembers: _int(json['active_members']),
      attendanceRate: _double(json['attendance_rate']),
      retentionRate: _double(json['retention_rate']),
      completedTasks: _int(json['completed_tasks']),
      lateTasks: _int(json['late_tasks']),
      activeProjects: _int(json['active_projects'], fallback: projects.length),
      directImpactTotal: _int(
        json['direct_impact_total'],
        fallback: projects.fold(0, (sum, item) => sum + item.directImpact),
      ),
      indirectImpactTotal: _int(
        json['indirect_impact_total'],
        fallback: projects.fold(0, (sum, item) => sum + item.indirectImpact),
      ),
      reachTotal: _int(
        json['reach_total'],
        fallback: projects.fold(0, (sum, item) => sum + item.reach),
      ),
      jobsCreatedTotal: _int(
        json['jobs_created_total'],
        fallback: projects.fold(0, (sum, item) => sum + item.jobsCreated),
      ),
      livesImpactedTotal: _int(
        json['lives_impacted_total'],
        fallback: projects.fold(0, (sum, item) => sum + item.livesImpacted),
      ),
      treesPlantedTotal: _int(
        json['trees_planted_total'],
        fallback: projects.fold(0, (sum, item) => sum + item.treesPlanted),
      ),
      validatedEvidenceCount: _int(
        json['validated_evidence_count'],
        fallback: projects.fold(0, (sum, item) => sum + item.evidenceCount),
      ),
      touchedSdgs: _int(
        json['touched_sdgs'],
        fallback: {
          for (final project in projects)
            for (final sdg in project.sdgs) sdg,
        }.length,
      ),
      revenueTotal: _double(
        json['revenue_total'],
        fallback: projects.fold<double>(0, (sum, item) => sum + item.revenue),
      ),
      surplusTotal: _double(
        json['surplus_total'],
        fallback: projects.fold<double>(0, (sum, item) => sum + item.surplus),
      ),
      officialDocuments: _int(
        json['official_documents'],
        fallback: projects.fold(0, (sum, item) => sum + item.documentsCount),
      ),
      competitionReadiness: _double(json['competition_readiness']),
      academyParticipation: _double(json['academy_participation']),
      communicationEngagement: _double(json['communication_engagement']),
      financialHealth: _double(json['financial_health']),
    );
  }

  HistoricalImpactModel _historicalFromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
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

  double _double(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<String> _stringList(dynamic value, {List<String> fallback = const []}) {
    if (value is! List) return fallback;
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
