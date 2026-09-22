import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/documents/models/document_model.dart';
import 'package:frontend/features/events/models/event_model.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/poles/models/pole_management_models.dart';
import 'package:frontend/features/poles/models/pole_portfolio_models.dart';
import 'package:frontend/features/poles/screens/pole_detail_screen.dart';
import 'package:frontend/features/poles/screens/poles_portfolio_screen.dart';
import 'package:frontend/features/poles/services/poles_portfolio_gateway.dart';
import 'package:frontend/features/posts/models/post_model.dart';
import 'package:frontend/features/tasks/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('présentations Pôles', () {
    test('humanise les types sans exposer une valeur inconnue', () {
      expect(PoleTypePresentation.label('metier'), 'Pôle cœur');
      expect(PoleTypePresentation.label('support'), 'Pôle support');
      expect(PoleTypePresentation.label('legacy_type'), 'Type non reconnu');
    });

    test('humanise les six statuts de tâche', () {
      expect(PoleTaskPresentation.statusLabel('a_faire'), 'À faire');
      expect(PoleTaskPresentation.statusLabel('en_cours'), 'En cours');
      expect(PoleTaskPresentation.statusLabel('bloque'), 'Bloqué');
      expect(PoleTaskPresentation.statusLabel('termine'), 'Terminé');
      expect(PoleTaskPresentation.statusLabel('valide'), 'Validé');
      expect(PoleTaskPresentation.statusLabel('annule'), 'Annulé');
      expect(PoleTaskPresentation.statusLabel('legacy'), 'Statut non reconnu');
    });

    test('humanise les priorités sans enum brut', () {
      expect(PoleTaskPresentation.priorityLabel('basse'), 'Basse');
      expect(PoleTaskPresentation.priorityLabel('normale'), 'Normale');
      expect(PoleTaskPresentation.priorityLabel('haute'), 'Haute');
      expect(PoleTaskPresentation.priorityLabel('urgente'), 'Urgente');
      expect(
        PoleTaskPresentation.priorityLabel('legacy'),
        'Priorité non reconnue',
      );
    });

    test('détecte uniquement les statuts terminaux', () {
      expect(PoleTaskPresentation.isTerminal('termine'), isTrue);
      expect(PoleTaskPresentation.isTerminal('valide'), isTrue);
      expect(PoleTaskPresentation.isTerminal('annule'), isTrue);
      expect(PoleTaskPresentation.isTerminal('bloque'), isFalse);
    });

    test('reconnaît uniquement la gouvernance canonique', () async {
      final gateway = _FakePolesGateway.standard();
      gateway.members['tech'] = [
        _member('legacy', 'Legacy', 'chef'),
        _member('lead', 'Awa Technique', 'chef_pole'),
      ];
      final item = await _item(gateway, 'tech');
      expect(item.lead?.displayName, 'Awa Technique');
      expect(
        item.activeMembers.map((e) => e.polePosition),
        isNot(contains('x')),
      );
    });

    test('pluralise les blocages et retards', () async {
      final item = await _item(_FakePolesGateway.standard(), 'tech');
      expect(item.alerts.labels, ['1 tâche bloquée', '1 tâche en retard']);
    });
  });

  group('portefeuille Pôles', () {
    testWidgets('affiche un portefeuille chargé', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.text('Portefeuille des pôles'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Audit Pôle Sans Équipe'), findsOneWidget);
    });

    testWidgets('affiche le chargement global', (tester) async {
      final gateway = _FakePolesGateway.standard()
        ..polesCompleter = Completer<List<PoleModel>>();
      await tester.pumpWidget(_app(PolesPortfolioScreen(gateway: gateway)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('distingue erreur de liste et liste vide', (tester) async {
      await _pumpPortfolio(
        tester,
        _FakePolesGateway.standard()..polesError = true,
      );
      expect(find.text('Impossible de charger les pôles'), findsOneWidget);
      expect(find.text('Aucun pôle'), findsNothing);
    });

    testWidgets('affiche le vrai état vide', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard()..poles = []);
      expect(find.text('Aucun pôle'), findsOneWidget);
    });

    testWidgets('filtre par nom et sigle', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      await tester.enterText(find.byType(TextField), 'APE');
      await tester.pump();
      expect(find.text('Audit Pôle Sans Équipe'), findsOneWidget);
      expect(find.text('Technique'), findsNothing);
    });

    testWidgets('filtre par type', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      await tester.tap(find.text('Tous les types'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pôle support').last);
      await tester.pumpAndSettle();
      expect(find.text('Audit Pôle Sans Équipe'), findsOneWidget);
      expect(find.text('Technique'), findsNothing);
    });

    testWidgets('filtre par responsable', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      await tester.tap(find.text('Tous les responsables'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Awa Technique').last);
      await tester.pumpAndSettle();
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Audit Pôle Sans Équipe'), findsNothing);
    });

    testWidgets('filtre les blocages', (tester) async {
      await _selectAlert(tester, 'Avec blocage');
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Audit Pôle Sans Équipe'), findsNothing);
    });

    testWidgets('filtre les retards', (tester) async {
      await _selectAlert(tester, 'En retard');
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Audit Pôle Sans Équipe'), findsNothing);
    });

    testWidgets('filtre les pôles sans chef', (tester) async {
      await _selectAlert(tester, 'Sans chef');
      expect(find.text('Audit Pôle Sans Équipe'), findsOneWidget);
      expect(find.text('Technique'), findsNothing);
    });

    testWidgets('filtre les pôles sans équipe', (tester) async {
      await _selectAlert(tester, 'Sans équipe');
      expect(find.text('Audit Pôle Sans Équipe'), findsOneWidget);
      expect(find.text('Technique'), findsNothing);
    });

    testWidgets('réinitialise les filtres', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pump();
      expect(find.text('Technique'), findsOneWidget);
    });

    testWidgets('présente le type inconnu sans enum brut', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.textContaining('Type non reconnu'), findsWidgets);
      expect(find.textContaining('legacy_type'), findsNothing);
    });

    testWidgets('affiche chef et adjoint canoniques', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(
        find.textContaining('Chef de pôle : Awa Technique'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Adjoint du pôle : Moussa Technique'),
        findsOneWidget,
      );
    });

    testWidgets('humanise les absences de gouvernance', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.textContaining('Aucun chef de pôle affecté'), findsWidgets);
      expect(find.textContaining('Aucun adjoint affecté'), findsWidgets);
    });

    testWidgets('humanise le pôle sans équipe', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.text('Aucune équipe affectée'), findsOneWidget);
      expect(find.textContaining('0 actif(s)'), findsNothing);
    });

    testWidgets('affiche la prochaine action future et son porteur', (
      tester,
    ) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.text('AUDIT-POLE-NEXT-ACTION-001'), findsOneWidget);
      expect(find.textContaining('Fatou Porteuse'), findsOneWidget);
    });

    testWidgets('distingue prochaine action absente et indisponible', (
      tester,
    ) async {
      final gateway = _FakePolesGateway.standard()..taskErrors.add('unknown');
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Aucune prochaine action planifiée'), findsOneWidget);
      expect(find.text('Prochaine action indisponible'), findsOneWidget);
    });

    testWidgets('affiche blocage et retard réels', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.text('1 tâche bloquée'), findsOneWidget);
      expect(find.text('1 tâche en retard'), findsOneWidget);
    });

    testWidgets('une erreur membres partielle ne casse pas la liste', (
      tester,
    ) async {
      final gateway = _FakePolesGateway.standard()..memberErrors.add('empty');
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Audit Pôle Sans Équipe'), findsOneWidget);
      expect(find.text('Équipe indisponible'), findsOneWidget);
    });

    testWidgets('une erreur tâches partielle ne casse pas la liste', (
      tester,
    ) async {
      final gateway = _FakePolesGateway.standard()..taskErrors.add('empty');
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Alertes indisponibles'), findsOneWidget);
    });

    testWidgets('supprime complètement le score Santé', (tester) async {
      await _pumpPortfolio(tester, _FakePolesGateway.standard());
      expect(find.textContaining('Santé du pôle'), findsNothing);
      expect(find.textContaining('santé'), findsNothing);
    });

    testWidgets('ouvre la fiche via l’action dédiée', (tester) async {
      PolePortfolioItem? opened;
      await _setDesktop(tester);
      await tester.pumpWidget(
        _app(
          PolesPortfolioScreen(
            gateway: _FakePolesGateway.standard(),
            onOpenPole: (item) => opened = item,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Ouvrir le pôle').first,
      );
      expect(opened?.pole.id, 'tech');
    });

    testWidgets('reste sans overflow à 390 px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(PolesPortfolioScreen(gateway: _FakePolesGateway.standard())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Filtres et recherche'), findsOneWidget);
    });
  });

  group('fiche Pôle', () {
    testWidgets('affiche une vraie page de résumé', (tester) async {
      await _pumpDetail(tester, _FakePolesGateway.standard(), 'tech');
      expect(find.text('Résumé'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Équipe'), findsOneWidget);
      expect(find.text('Travail'), findsOneWidget);
    });

    testWidgets('affiche la gouvernance canonique dans l’équipe', (
      tester,
    ) async {
      await _pumpDetail(tester, _FakePolesGateway.standard(), 'tech');
      expect(find.text('Awa Technique'), findsWidgets);
      expect(find.text('Moussa Technique'), findsWidgets);
    });

    testWidgets('humanise tâches, statuts et priorités', (tester) async {
      await _pumpDetail(tester, _FakePolesGateway.standard(), 'tech');
      await _scrollDetail(tester, 500);
      expect(find.textContaining('Bloqué · Urgente'), findsOneWidget);
      expect(find.textContaining('En retard'), findsWidgets);
      expect(find.textContaining('a_faire'), findsNothing);
    });

    testWidgets('affiche l’événement futur et les posts dans Activité', (
      tester,
    ) async {
      await _pumpDetail(tester, _FakePolesGateway.standard(), 'tech');
      await tester.scrollUntilVisible(
        find.text('AUDIT-POLE-EVENT-FUTURE-001'),
        350,
      );
      expect(find.text('AUDIT-POLE-EVENT-FUTURE-001'), findsOneWidget);
      expect(find.text('Point officiel du pôle'), findsOneWidget);
    });

    testWidgets('distingue activité vide et indisponible', (tester) async {
      final emptyGateway = _FakePolesGateway.standard()
        ..events = []
        ..posts['empty'] = [];
      await _pumpDetail(tester, emptyGateway, 'empty');
      await _scrollDetail(tester, 900);
      expect(find.text('Aucune activité récente'), findsOneWidget);

      final errorGateway = _FakePolesGateway.standard()..postsError = true;
      await _pumpDetail(tester, errorGateway, 'tech');
      await _scrollDetail(tester, 900);
      expect(find.text('Activité indisponible'), findsOneWidget);
    });

    testWidgets('affiche les documents filtrés par pôle', (tester) async {
      final gateway = _FakePolesGateway.standard();
      await _pumpDetail(tester, gateway, 'tech');
      await tester.scrollUntilVisible(find.text('Document audit 1'), 450);
      expect(find.text('Document audit 1'), findsOneWidget);
      expect(gateway.documentRequests, ['tech']);
    });

    testWidgets('distingue documents vides et indisponibles', (tester) async {
      final emptyGateway = _FakePolesGateway.standard()
        ..documents['empty'] = [];
      await _pumpDetail(tester, emptyGateway, 'empty');
      await _scrollDetail(tester, 1400);
      expect(find.text('Aucun document pour ce pôle'), findsOneWidget);

      final errorGateway = _FakePolesGateway.standard()
        ..documentErrors.add('tech');
      await _pumpDetail(tester, errorGateway, 'tech');
      await _scrollDetail(tester, 1400);
      expect(find.text('Documents indisponibles'), findsOneWidget);
    });

    testWidgets('affiche Non renseigné pour les champs partiels', (
      tester,
    ) async {
      await _pumpDetail(tester, _FakePolesGateway.standard(), 'empty');
      expect(find.text('Non renseigné'), findsNWidgets(2));
      expect(find.text('Aucune équipe affectée'), findsWidgets);
    });

    testWidgets('supporte une URL directe /poles/:poleId', (tester) async {
      final gateway = _FakePolesGateway.standard();
      final router = GoRouter(
        initialLocation: '/poles/tech',
        routes: [
          GoRoute(
            path: '/poles',
            builder: (_, _) => PolesPortfolioScreen(gateway: gateway),
            routes: [
              GoRoute(
                path: ':poleId',
                builder: (_, state) => PoleDetailScreen(
                  poleId: state.pathParameters['poleId']!,
                  gateway: gateway,
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Résumé'), findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
    });
  });
}

Future<void> _selectAlert(WidgetTester tester, String label) async {
  await _pumpPortfolio(tester, _FakePolesGateway.standard());
  await tester.tap(find.text('Toutes les situations'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpPortfolio(
  WidgetTester tester,
  _FakePolesGateway gateway,
) async {
  await _setDesktop(tester);
  await tester.pumpWidget(_app(PolesPortfolioScreen(gateway: gateway)));
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakePolesGateway gateway,
  String poleId,
) async {
  await _setDesktop(tester);
  final item = await _item(gateway, poleId);
  await tester.pumpWidget(
    _app(
      PoleDetailScreen(
        key: UniqueKey(),
        poleId: poleId,
        gateway: gateway,
        initialItem: item,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollDetail(WidgetTester tester, double distance) async {
  await tester.drag(find.byType(CustomScrollView), Offset(0, -distance));
  await tester.pumpAndSettle();
}

Future<PolePortfolioItem> _item(
  _FakePolesGateway gateway,
  String poleId,
) async => (await loadPolesPortfolio(
  gateway,
)).firstWhere((item) => item.pole.id == poleId);

Future<void> _setDesktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
  home: child,
);

class _FakePolesGateway implements PolesPortfolioGateway {
  List<PoleModel> poles;
  final Map<String, List<MemberModel>> members;
  final Map<String, List<TaskModel>> tasks;
  final Map<String, List<PoleAssignee>> assignees;
  final Map<String, List<DocumentModel>> documents;
  final Map<String, List<PostModel>> posts;
  List<EventModel> events;
  Completer<List<PoleModel>>? polesCompleter;
  bool polesError = false;
  bool postsError = false;
  bool eventsError = false;
  final Set<String> memberErrors = {};
  final Set<String> taskErrors = {};
  final Set<String> documentErrors = {};
  final List<String> documentRequests = [];

  _FakePolesGateway({
    required this.poles,
    required this.members,
    required this.tasks,
    required this.assignees,
    required this.documents,
    required this.posts,
    required this.events,
  });

  factory _FakePolesGateway.standard() => _FakePolesGateway(
    poles: [
      _pole('tech', 'Technique', 'TECH', 'metier'),
      _pole('empty', 'Audit Pôle Sans Équipe', 'APE', 'support', partial: true),
      _pole('unknown', 'Laboratoire Audit', 'LAB', 'legacy_type'),
    ],
    members: {
      'tech': [
        _member('lead', 'Awa Technique', 'chef_pole'),
        _member('deputy', 'Moussa Technique', 'adjoint_chef_pole'),
        _member('owner', 'Fatou Porteuse', 'membre'),
      ],
      'empty': [],
      'unknown': [_member('member', 'Membre Audit', 'membre')],
    },
    tasks: {
      'tech': [
        _task(
          'future',
          'AUDIT-POLE-NEXT-ACTION-001',
          'a_faire',
          'haute',
          '2099-04-15T17:00:00',
        ),
        _task(
          'blocked',
          'Blocage canonique',
          'bloque',
          'urgente',
          '2020-01-01T12:00:00',
        ),
      ],
      'empty': [],
      'unknown': [],
    },
    assignees: {
      'future': const [
        PoleAssignee(userId: 'owner', displayName: 'Fatou Porteuse'),
      ],
      'blocked': const [],
    },
    documents: {
      'tech': [
        DocumentModel.fromJson({
          'id': 'doc1',
          'title': 'Document audit 1',
          'category': 'rapport',
          'status': 'validated',
          'pole_id': 'tech',
          'created_at': '2026-08-01T10:00:00',
          'file_url': '/audit/document.pdf',
        }),
      ],
      'empty': [],
      'unknown': [],
    },
    posts: {
      'tech': [
        PostModel.fromJson({
          'id': 'post1',
          'author_id': 'lead',
          'title': 'Point officiel du pôle',
          'content': 'Avancement réel de la semaine.',
          'pole_id': 'tech',
          'created_at': '2026-08-01T10:00:00',
        }),
      ],
      'empty': [],
      'unknown': [],
    },
    events: [
      EventModel.fromJson({
        'id': 'event1',
        'title': 'AUDIT-POLE-EVENT-FUTURE-001',
        'pole_id': 'tech',
        'start_time': '2099-04-20T10:00:00',
        'location': 'Salle Audit Pôle A1',
        'created_at': '2026-08-01T10:00:00',
      }),
    ],
  );

  @override
  Future<UserExperience> loadCurrentUser() async => UserExperience.fromJson({
    'id': 'viewer',
    'email': 'viewer@example.test',
    'status': 'active',
    'roles': ['enacteur'],
  });

  @override
  Future<List<PoleModel>> loadPoles() async {
    if (polesError) throw Exception('liste indisponible');
    if (polesCompleter != null) return polesCompleter!.future;
    return poles;
  }

  @override
  Future<List<MemberModel>> loadMembers(String poleId) async {
    if (memberErrors.contains(poleId)) throw Exception('membres indisponibles');
    return members[poleId] ?? [];
  }

  @override
  Future<List<MemberModel>> loadMemberDirectory() async => const [];

  @override
  Future<List<TaskModel>> loadTasks(String poleId) async {
    if (taskErrors.contains(poleId)) throw Exception('tâches indisponibles');
    return tasks[poleId] ?? [];
  }

  @override
  Future<List<PoleAssignee>> loadTaskAssignees(String taskId) async =>
      assignees[taskId] ?? [];

  @override
  Future<List<DocumentModel>> loadDocuments(String poleId) async {
    documentRequests.add(poleId);
    if (documentErrors.contains(poleId)) {
      throw Exception('documents indisponibles');
    }
    return documents[poleId] ?? [];
  }

  @override
  Future<List<PostModel>> loadPosts(String poleId) async {
    if (postsError) throw Exception('posts indisponibles');
    return posts[poleId] ?? [];
  }

  @override
  Future<List<EventModel>> loadEvents() async {
    if (eventsError) throw Exception('événements indisponibles');
    return events;
  }

  @override
  Future<PoleModel> createPole(PoleMutationDraft draft) =>
      throw UnimplementedError();

  @override
  Future<PoleModel> updatePole(String poleId, PoleMutationDraft draft) =>
      throw UnimplementedError();

  @override
  Future<PoleMemberMutationResult> assignPoleMember({
    required String poleId,
    required String userId,
    required String position,
  }) => throw UnimplementedError();

  @override
  Future<void> removePoleMember({
    required String poleId,
    required String userId,
  }) => throw UnimplementedError();
}

PoleModel _pole(
  String id,
  String name,
  String shortName,
  String type, {
  bool partial = false,
}) => PoleModel.fromJson({
  'id': id,
  'name': name,
  'short_name': shortName,
  'type': type,
  'description': partial ? null : 'Description opérationnelle',
  'objectives': partial ? null : 'Objectifs opérationnels',
  'created_at': '2026-01-01T00:00:00',
});

MemberModel _member(String id, String name, String position) =>
    MemberModel.fromJson({
      'id': id,
      'email': '$id@example.test',
      'full_name': name,
      'pole_position': position,
      'is_active': true,
    });

TaskModel _task(
  String id,
  String title,
  String status,
  String priority,
  String due,
) => TaskModel.fromJson({
  'id': id,
  'title': title,
  'status': status,
  'priority': priority,
  'due_date': due,
  'pole_id': 'tech',
});
