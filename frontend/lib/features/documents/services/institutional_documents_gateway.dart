import 'dart:typed_data';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../models/document_center_models.dart';
import '../models/institutional_document_models.dart';
import 'documents_gateway.dart';
import 'institutional_documents_service.dart';

abstract class InstitutionalDocumentsGateway {
  Future<List<InstitutionalTemplateModel>> loadTemplates();
  Future<List<InstitutionalDocumentRequestModel>> loadRequests({
    String? status,
    String? templateCode,
  });
  Future<DocumentReferenceData> loadReferences();
  Future<List<MemberModel>> loadMembers();
  Future<UserExperience?> loadCurrentUser();

  Future<InstitutionalDocumentRequestModel> createRequest({
    required InstitutionalTemplateModel template,
    required Map<String, dynamic> payload,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
  });

  Future<InstitutionalDocumentRequestModel> updateRequest({
    required InstitutionalDocumentRequestModel request,
    required Map<String, dynamic> payload,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
  });

  Future<InstitutionalDocumentRequestModel> submit(String requestId);
  Future<InstitutionalDocumentRequestModel> sgValidate(String requestId);
  Future<InstitutionalDocumentRequestModel> approve(String requestId);
  Future<InstitutionalDocumentRequestModel> reject(
    String requestId,
    String reason,
  );
  Future<InstitutionalDocumentRequestModel> cancel(
    String requestId, {
    String? reason,
  });
  Future<Uint8List> preview(String requestId);
  Future<InstitutionalGenerationResult> generate(String requestId);
  Future<bool> rendererAvailable();
}

class ApiInstitutionalDocumentsGateway implements InstitutionalDocumentsGateway {
  final InstitutionalDocumentsService _service;
  final DocumentsGateway _documentsGateway;
  final MembersService _membersService;
  final AuthService _authService;
  Future<DocumentReferenceData>? _references;
  Future<List<MemberModel>>? _members;

  ApiInstitutionalDocumentsGateway({
    InstitutionalDocumentsService? service,
    DocumentsGateway? documentsGateway,
    MembersService? membersService,
    AuthService? authService,
  }) : _service = service ?? InstitutionalDocumentsService(),
       _documentsGateway = documentsGateway ?? ApiDocumentsGateway(),
       _membersService = membersService ?? MembersService(),
       _authService = authService ?? AuthService();

  @override
  Future<List<InstitutionalTemplateModel>> loadTemplates() =>
      _service.getTemplates();

  @override
  Future<List<InstitutionalDocumentRequestModel>> loadRequests({
    String? status,
    String? templateCode,
  }) => _service.getRequests(status: status, templateCode: templateCode);

  @override
  Future<DocumentReferenceData> loadReferences() =>
      _references ??= _documentsGateway.loadReferences();

  @override
  Future<List<MemberModel>> loadMembers() =>
      _members ??= _membersService.getMembers();

  @override
  Future<UserExperience?> loadCurrentUser() async {
    var raw = await _authService.getCachedCurrentUser();
    raw ??= await _authService.getCurrentUser();
    if (raw == null) return null;
    return UserExperience.fromJson(raw);
  }

  @override
  Future<InstitutionalDocumentRequestModel> createRequest({
    required InstitutionalTemplateModel template,
    required Map<String, dynamic> payload,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
  }) => _service.createRequest(
    templateCode: template.code,
    payload: payload,
    poleId: poleId,
    projectId: projectId,
    eventId: eventId,
    seasonId: seasonId,
  );

  @override
  Future<InstitutionalDocumentRequestModel> updateRequest({
    required InstitutionalDocumentRequestModel request,
    required Map<String, dynamic> payload,
    String? poleId,
    String? projectId,
    String? eventId,
    String? seasonId,
  }) => _service.updateRequest(
    requestId: request.id,
    payload: payload,
    poleId: poleId,
    projectId: projectId,
    eventId: eventId,
    seasonId: seasonId,
  );

  @override
  Future<InstitutionalDocumentRequestModel> submit(String requestId) =>
      _service.submit(requestId);

  @override
  Future<InstitutionalDocumentRequestModel> sgValidate(String requestId) =>
      _service.sgValidate(requestId);

  @override
  Future<InstitutionalDocumentRequestModel> approve(String requestId) =>
      _service.approve(requestId);

  @override
  Future<InstitutionalDocumentRequestModel> reject(
    String requestId,
    String reason,
  ) => _service.reject(requestId, reason);

  @override
  Future<InstitutionalDocumentRequestModel> cancel(
    String requestId, {
    String? reason,
  }) => _service.cancel(requestId, reason: reason);

  @override
  Future<Uint8List> preview(String requestId) => _service.preview(requestId);

  @override
  Future<InstitutionalGenerationResult> generate(String requestId) =>
      _service.generate(requestId);

  @override
  Future<bool> rendererAvailable() => _service.rendererAvailable();
}
