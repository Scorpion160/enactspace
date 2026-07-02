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
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return _demoDashboard();

      final responses = await Future.wait([
        _apiClient.get('/impact/summary', token: token),
        _apiClient.get('/impact/projects', token: token),
      ]);

      final summary = responses[0];
      final projectsResponse = responses[1];
      if (summary is! Map<String, dynamic> || projectsResponse is! List) {
        return _demoDashboard();
      }

      final projects = projectsResponse
          .whereType<Map<String, dynamic>>()
          .map(_projectFromJson)
          .toList();

      if (projects.isEmpty) return _demoDashboard();

      final fallback = _demoDashboard();
      return ImpactDashboardData(
        organization: _organizationFromJson(summary['organization'], projects),
        historicalImpact: _historicalFromJson(summary['historical_impact']),
        projects: projects,
        enacteurs: fallback.enacteurs,
        poles: fallback.poles,
      );
    } catch (_) {
      return _demoDashboard();
    }
  }

  ImpactDashboardData _demoDashboard() {
    const projects = [
      ProjectImpactMetricModel(
        id: 'p1',
        projectName: 'Green Campus ESP',
        status: 'Actif',
        poleName: 'Environnement',
        projectLead: 'Awa Diagne',
        deputyLead: 'Mamadou Fall',
        sdgs: ['ODD 11', 'ODD 12', 'ODD 13'],
        problem: 'Gestion insuffisante des déchets et faible tri à la source.',
        solution:
            'Collecte intelligente, sensibilisation et valorisation locale.',
        targetBeneficiaries: 'Étudiants, personnel ESP et riverains',
        directImpact: 184,
        indirectImpact: 920,
        reach: 3200,
        revenue: 480000,
        surplus: 122000,
        jobsCreated: 12,
        livesImpacted: 184,
        treesPlanted: 240,
        wasteReduced: 180,
        waterSaved: 0,
        co2Reduced: 32,
        planetImpact: 76,
        evidenceCount: 7,
        methodology: 'Pesées hebdomadaires, enquêtes et photos géolocalisées.',
        assumptions:
            'Projection basée sur 18 semaines de collecte et trois sites pilotes.',
        budgetUsed: 310000,
        progress: 72,
        completedTasks: 34,
        lateTasks: 4,
        documentsCount: 12,
        innovationScore: 82,
        businessViabilityScore: 68,
        scalabilityScore: 74,
        competitionReadinessScore: 70,
      ),
      ProjectImpactMetricModel(
        id: 'p2',
        projectName: 'Sama Skills',
        status: 'Prototype',
        poleName: 'Éducation',
        projectLead: 'Cheikh Ndiaye',
        deputyLead: 'Fatou Sarr',
        sdgs: ['ODD 4', 'ODD 8'],
        problem:
            'Manque de repères pratiques pour l’insertion des jeunes apprenants.',
        solution:
            'Parcours courts, ateliers soft skills et mentorat alumni ciblé.',
        targetBeneficiaries: 'Étudiants de première et deuxième année',
        directImpact: 96,
        indirectImpact: 410,
        reach: 1450,
        revenue: 210000,
        surplus: 46000,
        jobsCreated: 6,
        livesImpacted: 96,
        treesPlanted: 0,
        wasteReduced: 0,
        waterSaved: 0,
        co2Reduced: 0,
        planetImpact: 28,
        evidenceCount: 3,
        methodology: 'Feuilles de présence, quiz avant/après et entretiens.',
        assumptions:
            'Impact indirect estimé par diffusion des ressources aux promotions.',
        budgetUsed: 180000,
        progress: 48,
        completedTasks: 21,
        lateTasks: 7,
        documentsCount: 6,
        innovationScore: 69,
        businessViabilityScore: 57,
        scalabilityScore: 71,
        competitionReadinessScore: 52,
      ),
      ProjectImpactMetricModel(
        id: 'p3',
        projectName: 'Market Link',
        status: 'Exploration',
        poleName: 'Entrepreneuriat',
        projectLead: 'Mouhamed Ba',
        deputyLead: 'Ndeye Gueye',
        sdgs: [],
        problem:
            'Petits vendeurs peu visibles et difficulté à suivre les ventes.',
        solution:
            'Mini vitrine numérique, suivi simple des revenus et relais campus.',
        targetBeneficiaries: 'Micro-vendeurs et associations étudiantes',
        directImpact: 42,
        indirectImpact: 180,
        reach: 740,
        revenue: 95000,
        surplus: 14000,
        jobsCreated: 3,
        livesImpacted: 42,
        treesPlanted: 0,
        wasteReduced: 0,
        waterSaved: 0,
        co2Reduced: 0,
        planetImpact: 18,
        evidenceCount: 1,
        methodology: 'Entretiens exploratoires et registre de ventes pilote.',
        assumptions:
            'Les projections financières restent à confirmer avec plus de données.',
        budgetUsed: 88000,
        progress: 31,
        completedTasks: 12,
        lateTasks: 6,
        documentsCount: 3,
        innovationScore: 73,
        businessViabilityScore: 62,
        scalabilityScore: 66,
        competitionReadinessScore: 34,
      ),
    ];

    const poles = [
      PolePerformanceModel(
        poleName: 'Veille & Recrutement',
        activeMembers: 9,
        attendanceRate: 84,
        completedTasks: 38,
        lateTasks: 5,
        documentsCount: 11,
        postsCount: 9,
        linkedProjects: 2,
        academyProgress: 62,
        alerts: 1,
      ),
      PolePerformanceModel(
        poleName: 'Projets',
        activeMembers: 14,
        attendanceRate: 78,
        completedTasks: 61,
        lateTasks: 12,
        documentsCount: 18,
        postsCount: 13,
        linkedProjects: 5,
        academyProgress: 56,
        alerts: 2,
      ),
      PolePerformanceModel(
        poleName: 'Communication',
        activeMembers: 8,
        attendanceRate: 88,
        completedTasks: 44,
        lateTasks: 3,
        documentsCount: 14,
        postsCount: 27,
        linkedProjects: 3,
        academyProgress: 69,
        alerts: 0,
      ),
    ];

    const enacteurs = [
      EnacteurPerformanceModel(
        memberName: 'Awa Diagne',
        attendanceRate: 92,
        punctualityRate: 86,
        completedTasks: 18,
        validatedTasks: 15,
        projectContributions: 10,
        eventsParticipation: 5,
        producedDocuments: 7,
        usefulPosts: 6,
        academyLessonsCompleted: 9,
        passedQuizzes: 5,
        badges: 4,
        leadershipScore: 82,
        collaborationScore: 88,
      ),
      EnacteurPerformanceModel(
        memberName: 'Cheikh Ndiaye',
        attendanceRate: 81,
        punctualityRate: 79,
        completedTasks: 15,
        validatedTasks: 11,
        projectContributions: 8,
        eventsParticipation: 4,
        producedDocuments: 4,
        usefulPosts: 5,
        academyLessonsCompleted: 7,
        passedQuizzes: 4,
        badges: 3,
        leadershipScore: 74,
        collaborationScore: 80,
      ),
      EnacteurPerformanceModel(
        memberName: 'Fatou Sarr',
        attendanceRate: 88,
        punctualityRate: 84,
        completedTasks: 14,
        validatedTasks: 13,
        projectContributions: 7,
        eventsParticipation: 6,
        producedDocuments: 6,
        usefulPosts: 7,
        academyLessonsCompleted: 8,
        passedQuizzes: 6,
        badges: 4,
        leadershipScore: 79,
        collaborationScore: 91,
      ),
    ];

    return ImpactDashboardData(
      organization: OrganizationPerformanceModel(
        activeMembers: 46,
        attendanceRate: 82,
        retentionRate: 76,
        completedTasks: 176,
        lateTasks: 24,
        activeProjects: projects.length,
        directImpactTotal: projects.fold(
          0,
          (sum, item) => sum + item.directImpact,
        ),
        indirectImpactTotal: projects.fold(
          0,
          (sum, item) => sum + item.indirectImpact,
        ),
        reachTotal: projects.fold(0, (sum, item) => sum + item.reach),
        revenueTotal: projects.fold(0, (sum, item) => sum + item.revenue),
        surplusTotal: projects.fold(0, (sum, item) => sum + item.surplus),
        officialDocuments: projects.fold(
          0,
          (sum, item) => sum + item.documentsCount,
        ),
        competitionReadiness:
            projects.fold(
              0.0,
              (sum, item) => sum + item.competitionReadinessScore,
            ) /
            projects.length,
        academyParticipation: 61,
        communicationEngagement: 74,
        financialHealth: 69,
      ),
      historicalImpact: HistoricalImpactModel(
        createdProjects: 5,
        developingProjects: 4,
        developedProducts: 14,
        touchedSdgs: 11,
        createdJobs: 227,
        savedLives: 206,
        plantedTrees: 1425,
        cumulativeUsdGains: 46236.7,
        cumulativeFcfaGains: 27468761,
        impactedLives: 15900,
        emblematicProjects: [
          'DIMBALI',
          'DECONAANE',
          'JAVELISEL',
          'MOBIGEL',
          'MEUNE NAGN',
          'SOUKHALI',
        ],
        distinctions: [
          'Champion National 2017',
          'Champion National 2018',
          'Demi-finaliste compétition internationale 2018',
          'Premier Prix d’Excellence Fondation Sonatel',
        ],
      ),
      projects: projects,
      enacteurs: enacteurs,
      poles: poles,
      usesDemoData: true,
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
    final fallback = _demoDashboard().organization;

    return OrganizationPerformanceModel(
      activeMembers: _int(
        json['active_members'],
        fallback: fallback.activeMembers,
      ),
      attendanceRate: _double(
        json['attendance_rate'],
        fallback: fallback.attendanceRate,
      ),
      retentionRate: _double(
        json['retention_rate'],
        fallback: fallback.retentionRate,
      ),
      completedTasks: _int(
        json['completed_tasks'],
        fallback: fallback.completedTasks,
      ),
      lateTasks: _int(json['late_tasks'], fallback: fallback.lateTasks),
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
      competitionReadiness: _double(
        json['competition_readiness'],
        fallback: fallback.competitionReadiness,
      ),
      academyParticipation: _double(
        json['academy_participation'],
        fallback: fallback.academyParticipation,
      ),
      communicationEngagement: _double(
        json['communication_engagement'],
        fallback: fallback.communicationEngagement,
      ),
      financialHealth: _double(
        json['financial_health'],
        fallback: fallback.financialHealth,
      ),
    );
  }

  HistoricalImpactModel _historicalFromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final fallback = _demoDashboard().historicalImpact;

    return HistoricalImpactModel(
      createdProjects: _int(
        json['created_projects'],
        fallback: fallback.createdProjects,
      ),
      developingProjects: _int(
        json['developing_projects'],
        fallback: fallback.developingProjects,
      ),
      developedProducts: _int(
        json['developed_products'],
        fallback: fallback.developedProducts,
      ),
      touchedSdgs: _int(json['touched_sdgs'], fallback: fallback.touchedSdgs),
      createdJobs: _int(json['created_jobs'], fallback: fallback.createdJobs),
      savedLives: _int(json['saved_lives'], fallback: fallback.savedLives),
      plantedTrees: _int(
        json['planted_trees'],
        fallback: fallback.plantedTrees,
      ),
      cumulativeUsdGains: _double(
        json['cumulative_usd_gains'],
        fallback: fallback.cumulativeUsdGains,
      ),
      cumulativeFcfaGains: _double(
        json['cumulative_fcfa_gains'],
        fallback: fallback.cumulativeFcfaGains,
      ),
      impactedLives: _int(
        json['impacted_lives'],
        fallback: fallback.impactedLives,
      ),
      emblematicProjects: _stringList(
        json['emblematic_projects'],
        fallback: fallback.emblematicProjects,
      ),
      distinctions: _stringList(
        json['distinctions'],
        fallback: fallback.distinctions,
      ),
    );
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
