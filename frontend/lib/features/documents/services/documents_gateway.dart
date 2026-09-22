import 'dart:typed_data';

import '../../events/services/events_service.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/services/projects_portfolio_gateway.dart';
import '../../projects/services/projects_service.dart';
import '../models/document_center_models.dart';
import '../models/document_model.dart';
import 'documents_service.dart';

class DocumentFilters {
  final String? search;
  final String? category;
  final String? status;
  final String? visibility;
  final String? poleId;
  final String? projectId;
  final String? eventId;
  final bool? isTemplate;
  final bool? isOfficial;

  const DocumentFilters({
    this.search,
    this.category,
    this.status,
    this.visibility,
    this.poleId,
    this.projectId,
    this.eventId,
    this.isTemplate,
    this.isOfficial,
  });
}

abstract class DocumentsGateway {
  Future<List<DocumentModel>> loadDocuments([DocumentFilters filters]);
  Future<DocumentModel> loadDocument(String documentId);
  Future<DocumentReferenceData> loadReferences();
  Future<DocumentUploadedFileModel> uploadFile({
    required String fileName,
    required Uint8List bytes,
    required String visibility,
  });
  Future<DocumentModel> createDocument(DocumentMutationDraft draft);
  Future<DocumentModel> updateDocument(
    String documentId,
    DocumentMutationDraft draft, {
    bool replaceFile,
  });
  Future<DocumentModel> submit(String documentId);
  Future<DocumentModel> validate(String documentId);
  Future<DocumentModel> unvalidate(String documentId);
  Future<DocumentModel> reject(String documentId, String reason);
  Future<DocumentModel> archive(String documentId);
  Future<void> deleteDocument(String documentId);
}

class ApiDocumentsGateway implements DocumentsGateway {
  final DocumentsService _documents;
  final PolesService _poles;
  final ProjectsService _projects;
  final EventsService _events;
  final ProjectsPortfolioGateway _portfolio;
  Future<DocumentReferenceData>? _references;

  ApiDocumentsGateway({
    DocumentsService? documentsService,
    PolesService? polesService,
    ProjectsService? projectsService,
    EventsService? eventsService,
    ProjectsPortfolioGateway? portfolioGateway,
  }) : _documents = documentsService ?? DocumentsService(),
       _poles = polesService ?? PolesService(),
       _projects = projectsService ?? ProjectsService(),
       _events = eventsService ?? EventsService(),
       _portfolio = portfolioGateway ?? ApiProjectsPortfolioGateway();

  @override
  Future<List<DocumentModel>> loadDocuments([
    DocumentFilters filters = const DocumentFilters(),
  ]) => _documents.getDocuments(
    search: filters.search,
    category: filters.category,
    status: filters.status,
    visibility: filters.visibility,
    poleId: filters.poleId,
    projectId: filters.projectId,
    eventId: filters.eventId,
    isTemplate: filters.isTemplate,
    isOfficial: filters.isOfficial,
  );

  @override
  Future<DocumentModel> loadDocument(String documentId) =>
      _documents.getDocument(documentId);

  @override
  Future<DocumentReferenceData> loadReferences() =>
      _references ??= _loadReferences();

  Future<DocumentReferenceData> _loadReferences() async {
    final unavailable = <String>{};
    Future<List<T>> isolated<T>(String name, Future<List<T>> source) async {
      try {
        return await source;
      } catch (_) {
        unavailable.add(name);
        return <T>[];
      }
    }

    final values = await Future.wait([
      isolated('poles', _poles.getPoles()),
      isolated('projects', _projects.getProjects()),
      isolated('events', _events.getEvents()),
      isolated('seasons', _portfolio.loadSeasons()),
    ]);
    return DocumentReferenceData(
      poles: values[0].cast(),
      projects: values[1].cast(),
      events: values[2].cast(),
      seasons: values[3].cast(),
      unavailableSources: unavailable,
    );
  }

  @override
  Future<DocumentUploadedFileModel> uploadFile({
    required String fileName,
    required Uint8List bytes,
    required String visibility,
  }) => _documents.uploadDocumentFile(
    fileName: fileName,
    bytes: bytes,
    visibility: visibility,
  );

  @override
  Future<DocumentModel> createDocument(DocumentMutationDraft draft) =>
      _documents.createDocument(
        title: draft.title,
        description: draft.description,
        fileUrl: draft.fileUrl,
        fileId: draft.fileId,
        fileType: draft.fileType,
        category: draft.category,
        visibility: draft.visibility,
        poleId: draft.poleId,
        projectId: draft.projectId,
        eventId: draft.eventId,
        seasonId: draft.seasonId,
        isTemplate: draft.isTemplate,
      );

  @override
  Future<DocumentModel> updateDocument(
    String documentId,
    DocumentMutationDraft draft, {
    bool replaceFile = false,
  }) => _documents.updateDocument(
    documentId: documentId,
    title: draft.title,
    description: draft.description,
    fileUrl: replaceFile ? draft.fileUrl ?? '' : null,
    fileId: replaceFile ? draft.fileId ?? '' : null,
    fileType: replaceFile ? draft.fileType ?? '' : null,
    category: draft.category,
    visibility: draft.visibility,
    poleId: draft.poleId ?? '',
    projectId: draft.projectId ?? '',
    eventId: draft.eventId ?? '',
    seasonId: draft.seasonId ?? '',
    isTemplate: draft.isTemplate,
  );

  @override
  Future<DocumentModel> submit(String documentId) =>
      _documents.submitDocument(documentId);
  @override
  Future<DocumentModel> validate(String documentId) =>
      _documents.validateDocument(documentId);
  @override
  Future<DocumentModel> unvalidate(String documentId) =>
      _documents.unvalidateDocument(documentId);
  @override
  Future<DocumentModel> reject(String documentId, String reason) =>
      _documents.rejectDocument(documentId: documentId, reason: reason);
  @override
  Future<DocumentModel> archive(String documentId) =>
      _documents.archiveDocument(documentId);
  @override
  Future<void> deleteDocument(String documentId) =>
      _documents.deleteDocument(documentId);
}
