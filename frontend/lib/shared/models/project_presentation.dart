class ProjectPhoto {
  final String asset;
  final String caption;
  const ProjectPhoto({required this.asset, required this.caption});
  static List<ProjectPhoto> parse(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .where(
          (row) =>
              row['asset'] is String &&
              (row['asset'] as String).startsWith(
                'assets/heritage/resources/',
              ) &&
              !(row['asset'] as String).contains('..'),
        )
        .map(
          (row) => ProjectPhoto(
            asset: row['asset'],
            caption: row['caption']?.toString() ?? 'Enactus ESP',
          ),
        )
        .toList(growable: false);
  }
}

class ProjectPresentationSection {
  final String title;
  final String body;
  const ProjectPresentationSection({required this.title, required this.body});
  factory ProjectPresentationSection.fromJson(Map<String, dynamic> json) =>
      ProjectPresentationSection(
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
      );
}

class ProjectReferenceDocument {
  final String title;
  final String asset;
  final String description;
  final String filename;
  final int pages;
  const ProjectReferenceDocument({
    required this.title,
    required this.asset,
    required this.description,
    required this.filename,
    required this.pages,
  });

  static bool isAllowedAsset(String value) => const {
    'assets/documents/aquatus-synthese.pdf',
    'assets/documents/shery-presentation.pdf',
    'assets/documents/men-nan-presentation.pdf',
    'assets/documents/terrasen-world-cup.pdf',
  }.contains(value);

  static List<ProjectReferenceDocument> parse(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((raw) {
          final json = Map<String, dynamic>.from(raw);
          return ProjectReferenceDocument(
            title: json['title']?.toString() ?? 'Dossier du projet',
            asset: json['asset']?.toString() ?? '',
            description: json['description']?.toString() ?? '',
            filename: json['filename']?.toString() ?? 'dossier-projet.pdf',
            pages: int.tryParse(json['pages']?.toString() ?? '') ?? 0,
          );
        })
        .where((document) => isAllowedAsset(document.asset))
        .toList(growable: false);
  }
}

class ProjectPresentation {
  final String id;
  final int? originYear;
  final String name;
  final String description;
  final String impactSummary;
  final String? imageAsset;
  final List<ProjectPresentationSection> sections;
  final List<ProjectReferenceDocument> documents;
  final List<ProjectPhoto> gallery;
  const ProjectPresentation({
    required this.id,
    this.originYear,
    required this.name,
    required this.description,
    required this.impactSummary,
    required this.imageAsset,
    required this.sections,
    required this.documents,
    this.gallery = const [],
  });

  static ProjectPresentation? parse(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final rawSections = json['sections'];
    return ProjectPresentation(
      id: json['id']?.toString() ?? '',
      originYear: int.tryParse(json['origin_year']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      impactSummary: json['impact_summary']?.toString() ?? '',
      imageAsset: json['image_asset']?.toString(),
      sections: rawSections is List
          ? rawSections
                .whereType<Map>()
                .map(
                  (row) => ProjectPresentationSection.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const [],
      documents: ProjectReferenceDocument.parse(json['documents']),
      gallery: ProjectPhoto.parse(json['gallery']),
    );
  }
}
