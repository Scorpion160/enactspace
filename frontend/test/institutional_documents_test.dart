import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/documents/models/institutional_document_models.dart';

void main() {
  group('InstitutionalTemplateModel', () {
    test('parses dynamic fields and permissions', () {
      final model = InstitutionalTemplateModel.fromJson({
        'code': 'notification_renvoi',
        'label': 'Notification de renvoi',
        'version': '2.0',
        'category': 'discipline',
        'visibility': 'private',
        'scope': 'veille_required',
        'reference_prefix': 'REN',
        'slogan': 'Empowering our society is our priority',
        'requires_sg_validation': true,
        'requires_tl_approval': true,
        'can_create': true,
        'fields': [
          {
            'name': 'member_id',
            'label': 'Membre concerné',
            'type': 'user',
            'required': true,
          },
        ],
      });

      expect(model.code, 'notification_renvoi');
      expect(model.isVeilleOnly, isTrue);
      expect(model.requiresPole, isTrue);
      expect(model.canCreate, isTrue);
      expect(model.fields.single.name, 'member_id');
      expect(model.fields.single.required, isTrue);
      expect(
        model.approvalLabel,
        'Validation SG puis approbation Team Leader',
      );
    });
  });

  group('InstitutionalDocumentRequestModel', () {
    test('exposes backend action flags and official reference', () {
      final model = InstitutionalDocumentRequestModel.fromJson({
        'id': 'request-1',
        'template_code': 'demande_bus',
        'template_label': 'Demande de mise à disposition de bus',
        'template_version': '2.0',
        'status': 'pending_sg_validation',
        'payload': {'passenger_count': 25},
        'requested_by': 'user-1',
        'pole_id': 'pole-1',
        'official_reference': null,
        'can_edit': false,
        'can_submit': false,
        'can_sg_validate': true,
        'can_approve': false,
        'can_cancel': false,
      });

      expect(model.canSgValidate, isTrue);
      expect(model.isPendingReview, isTrue);
      expect(model.statusLabel, 'À valider par le SG');
      expect(model.payload['passenger_count'], 25);
    });

    test('recognizes generated official document', () {
      final model = InstitutionalDocumentRequestModel.fromJson({
        'id': 'request-2',
        'template_code': 'pv_pole',
        'template_label': 'PV réunion de pôle',
        'template_version': '2.0',
        'status': 'generated',
        'payload': const {},
        'requested_by': 'user-1',
        'official_reference': 'EESP/PV-POLE/2026-2027/001',
        'generated_document_id': 'document-1',
        'can_edit': false,
        'can_submit': false,
        'can_sg_validate': false,
        'can_approve': false,
        'can_cancel': false,
      });

      expect(model.isGenerated, isTrue);
      expect(model.generatedDocumentId, 'document-1');
      expect(model.statusLabel, 'PDF officiel généré');
    });
  });

  test('generation response returns linked request and document', () {
    final result = InstitutionalGenerationResult.fromJson({
      'request': {
        'id': 'request-3',
        'template_code': 'demande_rse',
        'template_label': 'Demande RSE',
        'template_version': '2.0',
        'status': 'generated',
        'payload': const {},
        'requested_by': 'user-1',
        'generated_document_id': 'document-3',
        'can_edit': false,
        'can_submit': false,
        'can_sg_validate': false,
        'can_approve': false,
        'can_cancel': false,
      },
      'document_id': 'document-3',
      'file_id': 'file-3',
      'file_url': '/api/files/file-3/download',
      'official_reference': 'EESP/RSE/2026-2027/001',
      'already_generated': false,
    });

    expect(result.documentId, 'document-3');
    expect(result.fileId, 'file-3');
    expect(result.request.isGenerated, isTrue);
    expect(result.alreadyGenerated, isFalse);
  });
}
