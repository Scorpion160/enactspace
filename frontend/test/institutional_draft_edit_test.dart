import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/documents/models/document_center_models.dart';
import 'package:frontend/features/documents/models/institutional_document_models.dart';
import 'package:frontend/features/documents/services/institutional_documents_gateway.dart';
import 'package:frontend/features/documents/widgets/institutional_request_form.dart';
import 'package:frontend/features/members/models/member_model.dart';

class _Gateway implements InstitutionalDocumentsGateway {
  @override
  Future<DocumentReferenceData> loadReferences() async => const DocumentReferenceData();
  @override
  Future<List<MemberModel>> loadMembers() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('editing a saved preview keeps unchanged structured and legacy fields', (tester) async {
    final payload = <String, dynamic>{
      'location': 'Salle 12',
      'decisions': [{'title': 'Décision', 'details': 'Texte | avec séparateur', 'extra': 'Conserver'}],
      'legacy_field': {'important': true},
    };
    final template = InstitutionalTemplateModel.fromJson({
      'code': 'pv_reunion_generale', 'label': 'PV', 'version': '2.0', 'scope': 'club',
      'fields': [
        {'name': 'location', 'label': 'Lieu', 'type': 'text'},
        {'name': 'decisions', 'label': 'Décisions', 'type': 'decision_list'},
      ],
    });
    final request = InstitutionalDocumentRequestModel.fromJson({
      'id': 'draft-1', 'template_code': template.code, 'status': 'draft',
      'requested_by': 'user-1', 'payload': payload, 'season_id': 'season-1',
    });
    InstitutionalRequestFormResult? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        result = await showInstitutionalRequestFormDialog(context,
            gateway: _Gateway(), template: template, request: request);
      }, child: const Text('Modifier')),
    ))));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Salle 12'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Salle 14');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result!.payload['location'], 'Salle 14');
    expect(result!.payload['decisions'], payload['decisions']);
    expect(result!.payload['legacy_field'], payload['legacy_field']);
    expect(result!.seasonId, 'season-1');
    expect(request.payload, payload);
  });
}
