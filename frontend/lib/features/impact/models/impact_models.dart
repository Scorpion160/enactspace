class ProjectImpactMetricModel {
  final String id;
  final String projectName;
  final String status;
  final String poleName;
  final String projectLead;
  final String deputyLead;
  final List<String> sdgs;
  final String problem;
  final String solution;
  final String targetBeneficiaries;
  final int directImpact;
  final int indirectImpact;
  final int reach;
  final double revenue;
  final double surplus;
  final int jobsCreated;
  final int livesImpacted;
  final int treesPlanted;
  final double wasteReduced;
  final double waterSaved;
  final double co2Reduced;
  final double planetImpact;
  final int evidenceCount;
  final String methodology;
  final String assumptions;
  final double budgetUsed;
  final double progress;
  final int completedTasks;
  final int lateTasks;
  final int documentsCount;
  final double innovationScore;
  final double businessViabilityScore;
  final double scalabilityScore;
  final double competitionReadinessScore;

  const ProjectImpactMetricModel({
    required this.id,
    required this.projectName,
    required this.status,
    required this.poleName,
    required this.projectLead,
    required this.deputyLead,
    required this.sdgs,
    required this.problem,
    required this.solution,
    required this.targetBeneficiaries,
    required this.directImpact,
    required this.indirectImpact,
    required this.reach,
    required this.revenue,
    required this.surplus,
    required this.jobsCreated,
    required this.livesImpacted,
    required this.treesPlanted,
    required this.wasteReduced,
    required this.waterSaved,
    required this.co2Reduced,
    required this.planetImpact,
    required this.evidenceCount,
    required this.methodology,
    required this.assumptions,
    required this.budgetUsed,
    required this.progress,
    required this.completedTasks,
    required this.lateTasks,
    required this.documentsCount,
    required this.innovationScore,
    required this.businessViabilityScore,
    required this.scalabilityScore,
    required this.competitionReadinessScore,
  });

  double get projectImpactScore {
    final directImpactScore = (directImpact / 200).clamp(0, 1) * 25;
    final viability = businessViabilityScore.clamp(0, 100) * 0.15;
    final innovation = innovationScore.clamp(0, 100) * 0.15;
    final evidence = (evidenceCount / 8).clamp(0, 1) * 15;
    final operational = progress.clamp(0, 100) * 0.10;
    final sdgAlignment = (sdgs.length / 4).clamp(0, 1) * 10;
    final scalability = scalabilityScore.clamp(0, 100) * 0.10;

    return directImpactScore +
        viability +
        innovation +
        evidence +
        operational +
        sdgAlignment +
        scalability;
  }

  bool get needsEvidence => evidenceCount < 2;
  bool get needsSdg => sdgs.isEmpty;
  int get totalBeneficiaries => directImpact + indirectImpact;
  bool get hasEnvironmentalImpact =>
      treesPlanted > 0 || wasteReduced > 0 || waterSaved > 0 || co2Reduced > 0;

  String get scoreLabel => '${projectImpactScore.toStringAsFixed(0)}/100';
}

class EnacteurPerformanceModel {
  final String memberName;
  final double attendanceRate;
  final double punctualityRate;
  final int completedTasks;
  final int validatedTasks;
  final int projectContributions;
  final int eventsParticipation;
  final int producedDocuments;
  final int usefulPosts;
  final int academyLessonsCompleted;
  final int passedQuizzes;
  final int badges;
  final double leadershipScore;
  final double collaborationScore;

  const EnacteurPerformanceModel({
    required this.memberName,
    required this.attendanceRate,
    required this.punctualityRate,
    required this.completedTasks,
    required this.validatedTasks,
    required this.projectContributions,
    required this.eventsParticipation,
    required this.producedDocuments,
    required this.usefulPosts,
    required this.academyLessonsCompleted,
    required this.passedQuizzes,
    required this.badges,
    required this.leadershipScore,
    required this.collaborationScore,
  });

  double get engagementScore {
    final taskScore = ((completedTasks + validatedTasks) / 24).clamp(0, 1) * 25;
    final attendanceScore =
        (((attendanceRate + punctualityRate) / 2).clamp(0, 100)) * 0.20;
    final academyScore =
        ((academyLessonsCompleted + passedQuizzes) / 16).clamp(0, 1) * 15;
    final contributionScore = (projectContributions / 12).clamp(0, 1) * 20;
    final communicationScore =
        ((usefulPosts + producedDocuments) / 12).clamp(0, 1) * 10;
    final leadership = leadershipScore.clamp(0, 100) * 0.06;
    final collaboration = collaborationScore.clamp(0, 100) * 0.04;

    return taskScore +
        attendanceScore +
        academyScore +
        contributionScore +
        communicationScore +
        leadership +
        collaboration;
  }
}

class PolePerformanceModel {
  final String poleName;
  final int activeMembers;
  final double attendanceRate;
  final int completedTasks;
  final int lateTasks;
  final int documentsCount;
  final int postsCount;
  final int linkedProjects;
  final double academyProgress;
  final int alerts;

  const PolePerformanceModel({
    required this.poleName,
    required this.activeMembers,
    required this.attendanceRate,
    required this.completedTasks,
    required this.lateTasks,
    required this.documentsCount,
    required this.postsCount,
    required this.linkedProjects,
    required this.academyProgress,
    required this.alerts,
  });

  double get healthScore {
    final members = (activeMembers / 12).clamp(0, 1) * 15;
    final attendance = attendanceRate.clamp(0, 100) * 0.20;
    final tasks =
        (completedTasks / (completedTasks + lateTasks + 1)).clamp(0, 1) * 25;
    final docs = (documentsCount / 10).clamp(0, 1) * 10;
    final communication = (postsCount / 12).clamp(0, 1) * 10;
    final projects = (linkedProjects / 4).clamp(0, 1) * 10;
    final academy = academyProgress.clamp(0, 100) * 0.10;
    final alertPenalty = (alerts * 4).clamp(0, 20);

    return (members +
            attendance +
            tasks +
            docs +
            communication +
            projects +
            academy -
            alertPenalty)
        .clamp(0, 100);
  }
}

class OrganizationPerformanceModel {
  final int activeMembers;
  final double attendanceRate;
  final double retentionRate;
  final int completedTasks;
  final int lateTasks;
  final int activeProjects;
  final int directImpactTotal;
  final int indirectImpactTotal;
  final int reachTotal;
  final double revenueTotal;
  final double surplusTotal;
  final int officialDocuments;
  final double competitionReadiness;
  final double academyParticipation;
  final double communicationEngagement;
  final double financialHealth;

  const OrganizationPerformanceModel({
    required this.activeMembers,
    required this.attendanceRate,
    required this.retentionRate,
    required this.completedTasks,
    required this.lateTasks,
    required this.activeProjects,
    required this.directImpactTotal,
    required this.indirectImpactTotal,
    required this.reachTotal,
    required this.revenueTotal,
    required this.surplusTotal,
    required this.officialDocuments,
    required this.competitionReadiness,
    required this.academyParticipation,
    required this.communicationEngagement,
    required this.financialHealth,
  });

  double get organizationHealthScore {
    final attendance = attendanceRate.clamp(0, 100) * 0.14;
    final retention = retentionRate.clamp(0, 100) * 0.12;
    final taskDelivery =
        (completedTasks / (completedTasks + lateTasks + 1)).clamp(0, 1) * 14;
    final projectActivity = (activeProjects / 8).clamp(0, 1) * 10;
    final impact = (directImpactTotal / 800).clamp(0, 1) * 12;
    final reach = (reachTotal / 5000).clamp(0, 1) * 8;
    final evidence = (officialDocuments / 35).clamp(0, 1) * 8;
    final competition = competitionReadiness.clamp(0, 100) * 0.08;
    final academy = academyParticipation.clamp(0, 100) * 0.06;
    final communication = communicationEngagement.clamp(0, 100) * 0.04;
    final finance = financialHealth.clamp(0, 100) * 0.04;

    return attendance +
        retention +
        taskDelivery +
        projectActivity +
        impact +
        reach +
        evidence +
        competition +
        academy +
        communication +
        finance;
  }
}

class HistoricalImpactModel {
  final int createdProjects;
  final int developingProjects;
  final int developedProducts;
  final int touchedSdgs;
  final int createdJobs;
  final int savedLives;
  final int plantedTrees;
  final double cumulativeUsdGains;
  final double cumulativeFcfaGains;
  final int impactedLives;
  final List<String> emblematicProjects;
  final List<String> distinctions;

  const HistoricalImpactModel({
    required this.createdProjects,
    required this.developingProjects,
    required this.developedProducts,
    required this.touchedSdgs,
    required this.createdJobs,
    required this.savedLives,
    required this.plantedTrees,
    required this.cumulativeUsdGains,
    required this.cumulativeFcfaGains,
    required this.impactedLives,
    required this.emblematicProjects,
    required this.distinctions,
  });
}

class ImpactDashboardData {
  final OrganizationPerformanceModel organization;
  final HistoricalImpactModel historicalImpact;
  final List<ProjectImpactMetricModel> projects;
  final List<EnacteurPerformanceModel> enacteurs;
  final List<PolePerformanceModel> poles;
  final bool usesDemoData;

  const ImpactDashboardData({
    required this.organization,
    required this.historicalImpact,
    required this.projects,
    required this.enacteurs,
    required this.poles,
    this.usesDemoData = false,
  });
}
