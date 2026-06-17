class ArchiveImpactSummaryModel {
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

  const ArchiveImpactSummaryModel({
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
  });
}

class ArchiveProjectModel {
  final String id;
  final String name;
  final String summary;
  final int launchYear;
  final int? archiveYear;
  final String locality;
  final String target;
  final String problem;
  final String solution;
  final List<String> actions;
  final List<String> sdgs;
  final List<String> products;
  final double revenue;
  final double profit;
  final int jobs;
  final int impactedLives;
  final int savedLives;
  final int plantedTrees;
  final List<String> partners;
  final List<String> awards;
  final List<String> documents;
  final List<String> members;
  final List<String> lessons;
  final String? logoAsset;
  final String status;
  final bool expansionReady;

  const ArchiveProjectModel({
    required this.id,
    required this.name,
    required this.summary,
    required this.launchYear,
    this.archiveYear,
    required this.locality,
    required this.target,
    required this.problem,
    required this.solution,
    required this.actions,
    required this.sdgs,
    required this.products,
    required this.revenue,
    required this.profit,
    required this.jobs,
    required this.impactedLives,
    required this.savedLives,
    required this.plantedTrees,
    required this.partners,
    required this.awards,
    required this.documents,
    required this.members,
    required this.lessons,
    this.logoAsset,
    required this.status,
    required this.expansionReady,
  });

  String get periodLabel {
    final end = archiveYear == null ? 'en mémoire' : archiveYear.toString();
    return '$launchYear - $end';
  }
}

class HallOfFameItemModel {
  final String title;
  final String period;
  final String description;
  final String type;
  final String? imageAsset;

  const HallOfFameItemModel({
    required this.title,
    required this.period,
    required this.description,
    required this.type,
    this.imageAsset,
  });
}

class ArchivesHomeData {
  final ArchiveImpactSummaryModel summary;
  final List<ArchiveProjectModel> projects;
  final List<HallOfFameItemModel> hallOfFame;
  final List<ArchiveOfficialDocumentModel> officialDocuments;

  const ArchivesHomeData({
    required this.summary,
    required this.projects,
    required this.hallOfFame,
    this.officialDocuments = const [],
  });
}

class ArchiveOfficialDocumentModel {
  final String id;
  final String title;
  final String category;
  final String visibility;
  final String? fileUrl;
  final String? projectId;
  final String? poleId;
  final String? eventId;
  final String createdAtLabel;

  const ArchiveOfficialDocumentModel({
    required this.id,
    required this.title,
    required this.category,
    required this.visibility,
    required this.fileUrl,
    required this.projectId,
    required this.poleId,
    required this.eventId,
    required this.createdAtLabel,
  });
}
