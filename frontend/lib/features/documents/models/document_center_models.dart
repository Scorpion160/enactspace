import '../../events/models/event_model.dart';
import '../../poles/models/pole_model.dart';
import '../../projects/models/project_management_models.dart';
import '../../projects/models/project_model.dart';
import 'document_model.dart';

class DocumentMutationDraft {
  final String title;
  final String description;
  final String? fileUrl;
  final String? fileId;
  final String? fileType;
  final String category;
  final String visibility;
  final String? poleId;
  final String? projectId;
  final String? eventId;
  final String? seasonId;
  final bool isTemplate;

  const DocumentMutationDraft({
    required this.title,
    required this.description,
    this.fileUrl,
    this.fileId,
    this.fileType,
    required this.category,
    required this.visibility,
    this.poleId,
    this.projectId,
    this.eventId,
    this.seasonId,
    required this.isTemplate,
  });

  factory DocumentMutationDraft.fromDocument(DocumentModel document) =>
      DocumentMutationDraft(
        title: document.title,
        description: document.description ?? '',
        fileUrl: document.fileUrl,
        fileId: document.fileId,
        fileType: document.fileType,
        category: document.category,
        visibility: document.visibility,
        poleId: document.poleId,
        projectId: document.projectId,
        eventId: document.eventId,
        seasonId: document.seasonId,
        isTemplate: document.isTemplate,
      );

  bool get hasFile =>
      (fileUrl?.trim().isNotEmpty ?? false) ||
      (fileId?.trim().isNotEmpty ?? false);
}

class DocumentFormResult {
  final DocumentMutationDraft draft;
  final bool replaceFile;
  const DocumentFormResult({required this.draft, required this.replaceFile});
}

class DocumentReferenceData {
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final List<EventModel> events;
  final List<ProjectSeasonOption> seasons;
  final Set<String> unavailableSources;

  const DocumentReferenceData({
    this.poles = const [],
    this.projects = const [],
    this.events = const [],
    this.seasons = const [],
    this.unavailableSources = const {},
  });

  String? poleName(String? id) =>
      _name(id, poles.map((item) => MapEntry(item.id, item.name)));
  String? projectName(String? id) =>
      _name(id, projects.map((item) => MapEntry(item.id, item.name)));
  String? eventName(String? id) =>
      _name(id, events.map((item) => MapEntry(item.id, item.title)));
  String? seasonName(String? id) =>
      _name(id, seasons.map((item) => MapEntry(item.id, item.name)));

  static String? _name(String? id, Iterable<MapEntry<String, String>> items) {
    if (id == null) return null;
    for (final item in items) {
      if (item.key == id) return item.value;
    }
    return null;
  }
}
