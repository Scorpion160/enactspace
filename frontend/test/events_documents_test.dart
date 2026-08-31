import 'dart:convert';
import 'dart:typed_data';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/documents/models/document_center_models.dart';
import 'package:frontend/features/documents/models/document_model.dart';
import 'package:frontend/features/documents/screens/document_detail_screen.dart';
import 'package:frontend/features/documents/screens/documents_screen.dart';
import 'package:frontend/features/documents/services/documents_gateway.dart';
import 'package:frontend/features/documents/services/documents_service.dart';
import 'package:frontend/features/events/models/event_center_models.dart';
import 'package:frontend/features/events/models/event_model.dart';
import 'package:frontend/features/events/models/event_participant_model.dart';
import 'package:frontend/features/events/screens/event_detail_screen.dart';
import 'package:frontend/features/events/screens/events_screen.dart';
import 'package:frontend/features/events/services/events_gateway.dart';
import 'package:frontend/features/events/services/events_service.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'enactspace_token': 'test-token',
    }),
  );

  group('Événements', () {
    testWidgets('liste, périodes, recherche et enums humanisés', (
      tester,
    ) async {
      final gateway = MemoryEventsGateway(
        events: [
          _event(),
          _event(
            id: 'past',
            title: 'Ancien atelier',
            start: DateTime.now().subtract(const Duration(days: 2)),
            type: 'field_trip',
          ),
        ],
      );
      await _pump(tester, EventsScreen(gateway: gateway));
      expect(find.text('Atelier solaire'), findsOneWidget);
      expect(find.text('Ancien atelier'), findsNothing);
      await tester.tap(find.text('Tous'));
      await tester.pump();
      expect(find.text('Ancien atelier'), findsOneWidget);
      expect(find.text('Terrain'), findsOneWidget);
      expect(find.text('field_trip'), findsNothing);
    });

    for (final access in <String, EventReferenceData>{
      'gestionnaire global': _refs(global: true),
      'chef de pôle': _refs(managedPole: true),
      'chef de projet': _refs(managedProject: true),
    }.entries) {
      testWidgets('création disponible pour ${access.key}', (tester) async {
        await _pump(
          tester,
          EventsScreen(
            gateway: MemoryEventsGateway(
              events: [_event()],
              references: access.value,
            ),
          ),
        );
        expect(find.byKey(const Key('create-event')), findsOneWidget);
      });
    }

    testWidgets('utilisateur simple sans création', (tester) async {
      await _pump(
        tester,
        EventsScreen(
          gateway: MemoryEventsGateway(events: [_event()], references: _refs()),
        ),
      );
      expect(find.byKey(const Key('create-event')), findsNothing);
    });

    test('création transporte season_id, pole_id et project_id', () async {
      Map<String, dynamic>? payload;
      final api = ApiClient(
        client: MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(_eventJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await EventsService(apiClient: api).createEvent(
        title: 'Atelier',
        description: '',
        eventType: 'training',
        location: '',
        startTime: DateTime(2026, 9, 2),
        budget: 0,
        requiresRegistration: true,
        attendanceEnabled: true,
        seasonId: 'season-1',
        poleId: 'pole-1',
        projectId: 'project-1',
      );
      expect(payload!['season_id'], 'season-1');
      expect(payload!['pole_id'], 'pole-1');
      expect(payload!['project_id'], 'project-1');
    });

    test('édition événement expose le contrat complet', () async {
      Map<String, dynamic>? payload;
      final api = ApiClient(
        client: MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(_eventJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await EventsService(apiClient: api).updateEvent(
        eventId: 'event-1',
        title: 'Nouveau',
        description: 'Description',
        eventType: 'training',
        location: 'Dakar',
        startTime: DateTime(2026, 9, 2),
        endTime: DateTime(2026, 9, 2, 18),
        poleId: 'pole-1',
        projectId: 'project-1',
        budget: 12000,
        maxParticipants: 40,
        requiresRegistration: true,
        attendanceEnabled: false,
        reportUrl: 'https://example.test/report',
      );
      expect(
        payload!.keys,
        containsAll([
          'title',
          'description',
          'event_type',
          'location',
          'start_time',
          'end_time',
          'pole_id',
          'project_id',
          'budget',
          'max_participants',
          'requires_registration',
          'attendance_enabled',
          'report_url',
        ]),
      );
    });

    testWidgets('fiche, inscription, participants lazy et can_manage', (
      tester,
    ) async {
      final gateway = MemoryEventsGateway(events: [_event(canManage: true)]);
      await _pump(
        tester,
        EventDetailScreen(eventId: 'event-1', gateway: gateway),
      );
      expect(find.text('Résumé'), findsOneWidget);
      expect(find.text('S’inscrire'), findsOneWidget);
      expect(gateway.participantLoads, 0);
      await tester.scrollUntilVisible(
        find.byKey(const Key('load-event-participants')),
        300,
      );
      await tester.tap(find.byKey(const Key('load-event-participants')));
      await tester.pumpAndSettle();
      expect(gateway.participantLoads, 1);
      expect(find.text('Awa Ndiaye'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('event-registration-action')),
        -300,
      );
      await tester.tap(find.byKey(const Key('event-registration-action')));
      await tester.pumpAndSettle();
      expect(gateway.registerCalls, 1);
      expect(find.text('Se désinscrire'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('delete-event')),
        300,
      );
      expect(find.byKey(const Key('delete-event')), findsOneWidget);
    });

    testWidgets('route détail URL directe', (tester) async {
      final gateway = MemoryEventsGateway(events: [_event()]);
      final router = GoRouter(
        initialLocation: '/events/event-1',
        routes: [
          GoRoute(
            path: '/events/:id',
            builder: (_, state) => EventDetailScreen(
              eventId: state.pathParameters['id']!,
              gateway: gateway,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Atelier solaire'), findsOneWidget);
    });

    testWidgets('mobile 390 sans overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        EventsScreen(gateway: MemoryEventsGateway(events: [_event()])),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Documents', () {
    test('statuts et visibilités sont humanisés', () {
      const labels = {
        'draft': 'Brouillon',
        'submitted': 'Soumis',
        'pending_validation': 'En attente de validation',
        'validated': 'Validé',
        'rejected': 'Rejeté',
        'archived': 'Archivé',
        'expired': 'Expiré',
      };
      for (final entry in labels.entries) {
        expect(_document(status: entry.key).statusLabel, entry.value);
      }
      expect(
        _document(visibility: 'public_club').visibilityLabel,
        'Tout le club',
      );
      expect(_document(visibility: 'internal').visibilityLabel, 'Membres');
      expect(
        _document(visibility: 'pole_only').visibilityLabel,
        'Pôle sélectionné',
      );
      expect(
        _document(visibility: 'project_only').visibilityLabel,
        'Projet sélectionné',
      );
      expect(
        _document(visibility: 'enacchef_only').visibilityLabel,
        'Responsables',
      );
    });

    test('transport liste ajoute status_filter', () async {
      Uri? uri;
      final service = DocumentsService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            uri = request.url;
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      await service.getDocuments(status: 'pending_validation');
      expect(uri!.queryParameters['status_filter'], 'pending_validation');
    });

    test('création exige file_url ou file_id', () async {
      final service = DocumentsService();
      expect(
        () => service.createDocument(
          title: 'Doc',
          category: 'general',
          visibility: 'internal',
        ),
        throwsArgumentError,
      );
    });

    test(
      'édition préserve le fichier sans remplacement dans le gateway',
      () async {
        final gateway = MemoryDocumentsGateway(
          documents: [_document(fileId: 'file-existing')],
        );
        final draft = DocumentMutationDraft.fromDocument(
          gateway.documents.first,
        );
        await gateway.updateDocument('doc-1', draft, replaceFile: false);
        expect(gateway.lastReplaceFile, isFalse);
        expect(gateway.documents.first.fileId, 'file-existing');
      },
    );

    testWidgets('centre, recherche et filtres catégorie/statut/visibilité', (
      tester,
    ) async {
      final gateway = MemoryDocumentsGateway(documents: [_document()]);
      await _pump(tester, DocumentsScreen(gateway: gateway));
      expect(find.text('Rapport annuel'), findsOneWidget);
      expect(find.text('En attente de validation'), findsOneWidget);
      await tester.tap(find.text('Tous les statuts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Validé').last);
      await tester.pumpAndSettle();
      expect(gateway.lastFilters?.status, 'validated');
    });

    testWidgets('can_manage et can_validate pilotent le workflow complet', (
      tester,
    ) async {
      final gateway = MemoryDocumentsGateway(
        documents: [
          _document(canManage: true, canValidate: true, status: 'draft'),
        ],
      );
      await _pump(
        tester,
        DocumentDetailScreen(documentId: 'doc-1', gateway: gateway),
      );
      expect(find.text('Modifier document'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Soumettre'), 300);
      expect(find.text('Soumettre'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(find.text('Rejeter'), findsOneWidget);
      expect(find.text('Archiver'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('delete-document')),
        300,
      );
      expect(find.byKey(const Key('delete-document')), findsOneWidget);
    });

    testWidgets('rejet exige un motif et conserve le dialogue', (tester) async {
      final gateway = MemoryDocumentsGateway(
        documents: [_document(canValidate: true)],
      );
      await _pump(
        tester,
        DocumentDetailScreen(documentId: 'doc-1', gateway: gateway),
      );
      await tester.scrollUntilVisible(find.text('Rejeter'), 300);
      await tester.tap(find.text('Rejeter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-rejection')));
      await tester.pump();
      expect(find.text('Le motif est obligatoire.'), findsOneWidget);
      expect(gateway.rejectCalls, 0);
    });

    testWidgets('fiche affiche motif de rejet et expiration', (tester) async {
      final gateway = MemoryDocumentsGateway(
        documents: [
          _document(
            status: 'rejected',
            rejectionReason: 'Signature manquante',
            expiresAt: '2026-10-01T10:00:00Z',
          ),
        ],
      );
      await _pump(
        tester,
        DocumentDetailScreen(documentId: 'doc-1', gateway: gateway),
      );
      await tester.scrollUntilVisible(
        find.textContaining('Signature manquante'),
        300,
      );
      expect(find.textContaining('Signature manquante'), findsOneWidget);
      expect(find.text('Expiration'), findsOneWidget);
    });

    testWidgets('route détail URL directe', (tester) async {
      final gateway = MemoryDocumentsGateway(documents: [_document()]);
      final router = GoRouter(
        initialLocation: '/documents/doc-1',
        routes: [
          GoRoute(
            path: '/documents/:id',
            builder: (_, state) => DocumentDetailScreen(
              documentId: state.pathParameters['id']!,
              gateway: gateway,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Rapport annuel'), findsOneWidget);
    });

    testWidgets('mobile 390 utilise des cartes verticales sans overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        DocumentsScreen(
          gateway: MemoryDocumentsGateway(documents: [_document()]),
        ),
      );
      expect(find.text('Filtres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('double workflow est sérialisable par le gateway mémoire', () async {
      final gateway = MemoryDocumentsGateway(
        documents: [_document(canManage: true, canValidate: true)],
      );
      await gateway.submit('doc-1');
      await gateway.validate('doc-1');
      await gateway.unvalidate('doc-1');
      await gateway.reject('doc-1', 'Motif');
      await gateway.archive('doc-1');
      expect([
        gateway.submitCalls,
        gateway.validateCalls,
        gateway.unvalidateCalls,
        gateway.rejectCalls,
        gateway.archiveCalls,
      ], everyElement(1));
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

EventModel _event({
  String id = 'event-1',
  String title = 'Atelier solaire',
  DateTime? start,
  String type = 'training',
  bool canManage = false,
}) => EventModel(
  id: id,
  seasonId: 'season-1',
  title: title,
  description: 'Préparation terrain',
  eventType: type,
  location: 'Dakar',
  startTime: start ?? DateTime.now().add(const Duration(days: 2)),
  endTime: null,
  poleId: 'pole-1',
  projectId: null,
  budget: 10000,
  maxParticipants: 30,
  requiresRegistration: true,
  attendanceEnabled: true,
  reportUrl: null,
  createdBy: 'user-1',
  registeredCount: 4,
  currentUserRegistered: false,
  canManage: canManage,
  createdAt: DateTime(2026),
);
Map<String, dynamic> _eventJson() => {
  'id': 'event-1',
  'title': 'Atelier',
  'event_type': 'training',
  'start_time': '2026-09-02T10:00:00Z',
  'budget': 0,
  'requires_registration': true,
  'attendance_enabled': true,
  'registered_count': 0,
  'current_user_registered': false,
  'can_manage': true,
  'created_at': '2026-08-31T00:00:00Z',
};
EventReferenceData _refs({
  bool global = false,
  bool managedPole = false,
  bool managedProject = false,
}) => EventReferenceData(
  poles: [
    PoleModel(
      id: 'pole-1',
      seasonId: 'season-1',
      name: 'Communication',
      shortName: 'COM',
      type: 'support',
      description: null,
      objectives: null,
      createdAt: DateTime(2026),
    ),
  ],
  projects: [
    ProjectModel(
      id: 'project-1',
      seasonId: 'season-1',
      name: 'SunuTech',
      description: null,
      problemStatement: null,
      solution: null,
      objectives: null,
      expectedImpact: null,
      budgetEstimated: 0,
      status: 'actif',
      startedAt: null,
      endedAt: null,
      createdAt: DateTime(2026),
    ),
  ],
  managedPoleIds: managedPole ? {'pole-1'} : {},
  managedProjectIds: managedProject ? {'project-1'} : {},
  isGlobalManager: global,
);

class MemoryEventsGateway implements EventsGateway {
  List<EventModel> events;
  final EventReferenceData references;
  int participantLoads = 0, registerCalls = 0;
  MemoryEventsGateway({required this.events, EventReferenceData? references})
    : references = references ?? _refs();
  @override
  Future<List<EventModel>> loadEvents() async => events;
  @override
  Future<EventModel> loadEvent(String id) async =>
      events.firstWhere((e) => e.id == id);
  @override
  Future<EventReferenceData> loadReferences() async => references;
  @override
  Future<EventModel> createEvent(EventMutationDraft draft) async {
    final value = _event(id: 'created', title: draft.title);
    events = [value, ...events];
    return value;
  }

  @override
  Future<EventModel> updateEvent(String id, EventMutationDraft draft) async =>
      events.firstWhere((e) => e.id == id).copyWith(title: draft.title);
  @override
  Future<EventModel> register(String id) async {
    registerCalls++;
    final value = events
        .firstWhere((e) => e.id == id)
        .copyWith(currentUserRegistered: true, registeredCount: 5);
    events = [value];
    return value;
  }

  @override
  Future<EventModel> unregister(String id) async => events
      .firstWhere((e) => e.id == id)
      .copyWith(currentUserRegistered: false);
  @override
  Future<List<EventParticipantModel>> loadParticipants(String id) async {
    participantLoads++;
    return [
      EventParticipantModel(
        id: 'p1',
        userId: 'u1',
        displayName: 'Awa Ndiaye',
        email: 'awa@example.test',
        photoUrl: null,
        registeredAt: DateTime(2026),
      ),
    ];
  }

  @override
  Future<void> createAttendanceSession(EventModel event) async {}
  @override
  Future<void> deleteEvent(String id) async =>
      events.removeWhere((e) => e.id == id);
}

DocumentModel _document({
  String status = 'pending_validation',
  String visibility = 'internal',
  bool canManage = false,
  bool canValidate = false,
  String? fileId = 'file-1',
  String? rejectionReason,
  String? expiresAt,
}) => DocumentModel(
  id: 'doc-1',
  title: 'Rapport annuel',
  description: 'Bilan des activités',
  fileUrl: 'https://example.test/rapport.pdf',
  fileId: fileId,
  fileType: 'pdf',
  status: status,
  category: 'rapport',
  visibility: visibility,
  uploadedBy: 'Awa',
  poleId: 'pole-1',
  projectId: null,
  eventId: null,
  seasonId: 'season-1',
  isTemplate: false,
  isOfficial: status == 'validated',
  canManage: canManage,
  canValidate: canValidate,
  validatedBy: null,
  validatedAt: null,
  rejectedBy: status == 'rejected' ? 'Modérateur' : null,
  rejectedAt: null,
  rejectionReason: rejectionReason,
  isPermanent: status == 'validated',
  expiresAt: expiresAt,
  createdAt: '2026-08-31T10:00:00Z',
  updatedAt: null,
);

class MemoryDocumentsGateway implements DocumentsGateway {
  List<DocumentModel> documents;
  DocumentFilters? lastFilters;
  bool? lastReplaceFile;
  int submitCalls = 0,
      validateCalls = 0,
      unvalidateCalls = 0,
      rejectCalls = 0,
      archiveCalls = 0;
  MemoryDocumentsGateway({required this.documents});
  @override
  Future<List<DocumentModel>> loadDocuments([
    DocumentFilters filters = const DocumentFilters(),
  ]) async {
    lastFilters = filters;
    return documents;
  }

  @override
  Future<DocumentModel> loadDocument(String id) async =>
      documents.firstWhere((d) => d.id == id);
  @override
  Future<DocumentReferenceData> loadReferences() async => DocumentReferenceData(
    poles: _refs().poles,
    projects: _refs().projects,
    events: [_event()],
  );
  @override
  Future<DocumentUploadedFileModel> uploadFile({
    required String fileName,
    required Uint8List bytes,
    required String visibility,
  }) async => DocumentUploadedFileModel(
    fileId: 'uploaded',
    downloadUrl: 'https://example.test/$fileName',
    fileName: fileName,
    fileType: 'pdf',
    sizeBytes: bytes.length,
  );
  @override
  Future<DocumentModel> createDocument(DocumentMutationDraft draft) async {
    final value = _document();
    documents = [value, ...documents];
    return value;
  }

  @override
  Future<DocumentModel> updateDocument(
    String id,
    DocumentMutationDraft draft, {
    bool replaceFile = false,
  }) async {
    lastReplaceFile = replaceFile;
    return documents.firstWhere((d) => d.id == id);
  }

  @override
  Future<DocumentModel> submit(String id) async {
    submitCalls++;
    return documents.first;
  }

  @override
  Future<DocumentModel> validate(String id) async {
    validateCalls++;
    return documents.first;
  }

  @override
  Future<DocumentModel> unvalidate(String id) async {
    unvalidateCalls++;
    return documents.first;
  }

  @override
  Future<DocumentModel> reject(String id, String reason) async {
    rejectCalls++;
    return documents.first;
  }

  @override
  Future<DocumentModel> archive(String id) async {
    archiveCalls++;
    return documents.first;
  }

  @override
  Future<void> deleteDocument(String id) async =>
      documents.removeWhere((d) => d.id == id);
}
