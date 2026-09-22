import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/documents/models/document_model.dart';
import 'package:frontend/features/events/models/event_model.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/projects/models/project_member_model.dart';
import 'package:frontend/features/projects/models/project_management_models.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/models/project_portfolio_models.dart';
import 'package:frontend/features/projects/models/project_team_management_models.dart';
import 'package:frontend/features/projects/screens/project_detail_screen.dart';
import 'package:frontend/features/projects/screens/projects_portfolio_screen.dart';
import 'package:frontend/features/projects/services/projects_portfolio_gateway.dart';
import 'package:frontend/features/tasks/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('présentations Projets', () {
    test('humanise les sept statuts projet', () {
      expect(
        ProjectStatusPresentation.values
            .map(ProjectStatusPresentation.label)
            .toList(),
        [
          'Idée',
          'Étude',
          'Prototype',
          'Test',
          'Déploiement',
          'Terminé',
          'Suspendu',
        ],
      );
    });

    test('ne restitue pas un statut projet inconnu brut', () {
      expect(
        ProjectStatusPresentation.label('legacy_active'),
        'Statut non reconnu',
      );
    });

    test('humanise tous les statuts de tâche', () {
      expect(ProjectTaskPresentation.statusLabel('a_faire'), 'À faire');
      expect(ProjectTaskPresentation.statusLabel('en_cours'), 'En cours');
      expect(ProjectTaskPresentation.statusLabel('bloque'), 'Bloqué');
      expect(ProjectTaskPresentation.statusLabel('termine'), 'Terminé');
      expect(ProjectTaskPresentation.statusLabel('valide'), 'Validé');
      expect(ProjectTaskPresentation.statusLabel('annule'), 'Annulé');
    });

    test('détecte seulement les statuts de tâche terminaux', () {
      expect(ProjectTaskPresentation.isTerminal('termine'), isTrue);
      expect(ProjectTaskPresentation.isTerminal('valide'), isTrue);
      expect(ProjectTaskPresentation.isTerminal('annule'), isTrue);
      expect(ProjectTaskPresentation.isTerminal('bloque'), isFalse);
    });

    test('lit la progression uniquement dans une réponse Impact', () {
      final impact = ProjectImpactSnapshot.fromJson({
        'id': 'p1',
        'progress': 64,
      });
      expect(impact.progress, 64);
      expect(impact.projectId, 'p1');
    });

    test('la progression Impact absente reste absente', () {
      final impact = ProjectImpactSnapshot.fromJson({'id': 'p1'});
      expect(impact.progress, isNull);
    });

    test('pluralise les blocages et retards', () {
      const alerts = ProjectAlertSummary(blockedCount: 2, overdueCount: 3);
      expect(alerts.labels, ['2 tâches bloquées', '3 tâches en retard']);
    });
  });

  group('portefeuille Projets', () {
    testWidgets('affiche un portefeuille chargé', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      expect(find.text('Portefeuille Projets'), findsOneWidget);
      expect(find.text('Audit Horizon'), findsOneWidget);
    });

    testWidgets('affiche un état de chargement', (tester) async {
      final gateway = _FakeGateway.standard()..projectsCompleter = Completer();
      await tester.pumpWidget(_app(ProjectsPortfolioScreen(gateway: gateway)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('distingue erreur projets et liste vide', (tester) async {
      final gateway = _FakeGateway.standard()..projectsError = true;
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Impossible de charger les projets'), findsOneWidget);
      expect(find.text('Aucun projet'), findsNothing);
    });

    testWidgets('affiche le vrai état vide', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard()..projects = []);
      expect(find.text('Aucun projet'), findsOneWidget);
    });

    testWidgets('filtre par recherche', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      await tester.enterText(find.byType(TextField), 'Canopée');
      await tester.pump();
      expect(find.text('Audit Canopée'), findsOneWidget);
      expect(find.text('Audit Horizon'), findsNothing);
    });

    testWidgets('filtre par statut', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      await tester.tap(find.text('Tous les statuts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminé').last);
      await tester.pumpAndSettle();
      expect(find.text('Audit Solstice'), findsOneWidget);
      expect(find.text('Audit Horizon'), findsNothing);
    });

    testWidgets('filtre les projets avec blocage', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      await tester.tap(find.text('Toutes les situations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avec blocage').last);
      await tester.pumpAndSettle();
      expect(find.text('Audit Canopée'), findsOneWidget);
      expect(find.text('Audit Horizon'), findsNothing);
    });

    testWidgets('réinitialise les filtres', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pump();
      expect(find.text('Audit Horizon'), findsOneWidget);
    });

    testWidgets('affiche la progression Impact avec son nom complet', (
      tester,
    ) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      expect(find.text('Progression opérationnelle'), findsWidgets);
      expect(find.text('64 %'), findsOneWidget);
    });

    testWidgets('n’invente aucune progression depuis un statut terminé', (
      tester,
    ) async {
      final gateway = _FakeGateway.standard()..impact = {};
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Progression non disponible'), findsNWidgets(4));
      expect(find.text('100 %'), findsNothing);
    });

    testWidgets('affiche la prochaine action future et son porteur', (
      tester,
    ) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      expect(find.text('AUDIT-PROJECT-NEXT-ACTION-001'), findsOneWidget);
      expect(find.text('Awa Horizon'), findsWidgets);
    });

    testWidgets('distingue absence et indisponibilité de prochaine action', (
      tester,
    ) async {
      final gateway = _FakeGateway.standard()..taskErrors.add('p2');
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Aucune prochaine action planifiée'), findsWidgets);
      expect(find.text('Prochaine action indisponible'), findsOneWidget);
    });

    testWidgets('affiche une tâche bloquée', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      expect(find.textContaining('1 tâche bloquée'), findsOneWidget);
    });

    testWidgets('calcule une tâche réellement en retard', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      expect(find.textContaining('1 tâche en retard'), findsOneWidget);
    });

    testWidgets('reconnaît le chef et l’adjoint', (tester) async {
      final item = await _portfolioItem(_FakeGateway.standard(), 'p1');
      expect(item.lead?.displayName, 'Awa Horizon');
      expect(item.deputy?.displayName, 'Moussa Horizon');
    });

    testWidgets('affiche humainement le projet sans équipe', (tester) async {
      await _pumpPortfolio(tester, _FakeGateway.standard());
      expect(find.text('Aucune équipe affectée'), findsWidgets);
    });

    testWidgets('ouvre la fiche via l’action dédiée', (tester) async {
      ProjectPortfolioItem? opened;
      final gateway = _FakeGateway.standard();
      await _setDesktop(tester);
      await tester.pumpWidget(
        _app(
          ProjectsPortfolioScreen(
            gateway: gateway,
            onOpenProject: (item) => opened = item,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Ouvrir le projet').first,
      );
      expect(opened?.project.name, 'Audit Horizon');
    });

    testWidgets('reste lisible en largeur 390 sans overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(ProjectsPortfolioScreen(gateway: _FakeGateway.standard())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Filtres et recherche'), findsOneWidget);
      expect(find.text('Audit Horizon'), findsOneWidget);
    });

    testWidgets('une erreur équipe ne casse pas le portefeuille', (
      tester,
    ) async {
      final gateway = _FakeGateway.standard()..memberErrors.add('p1');
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Audit Horizon'), findsOneWidget);
      expect(find.text('Équipe indisponible'), findsOneWidget);
    });
  });

  group('fiche projet', () {
    testWidgets('la route /projects/:projectId charge une fiche directe', (
      tester,
    ) async {
      final gateway = _FakeGateway.standard();
      final router = GoRouter(
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:projectId',
            builder: (_, state) => ProjectDetailScreen(
              projectId: state.pathParameters['projectId']!,
              gateway: gateway,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Audit Horizon'), findsOneWidget);
      expect(find.text('Résumé'), findsWidgets);
    });

    testWidgets('le résumé affiche les informations réelles', (tester) async {
      await _pumpDetail(tester, _FakeGateway.standard(), 'p1');
      expect(find.text('Problème'), findsOneWidget);
      expect(find.text('Problème Horizon'), findsOneWidget);
      expect(find.text('Moussa Horizon'), findsOneWidget);
    });

    testWidgets('le travail humanise une tâche bloquée', (tester) async {
      await _pumpDetail(tester, _FakeGateway.standard(), 'p2');
      await tester.tap(find.text('Travail'));
      await tester.pumpAndSettle();
      expect(find.text('Bloqué'), findsWidgets);
      expect(find.text('bloque'), findsNothing);
    });

    testWidgets('l’activité affiche l’événement futur réel', (tester) async {
      await _pumpDetail(tester, _FakeGateway.standard(), 'p1');
      await tester.tap(find.text('Activité'));
      await tester.pumpAndSettle();
      expect(find.text('AUDIT-PROJECT-EVENT-FUTURE-001'), findsOneWidget);
    });

    testWidgets('les documents sont ceux du projet', (tester) async {
      final gateway = _FakeGateway.standard();
      await _pumpDetail(tester, gateway, 'p1');
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();
      expect(find.text('Document Horizon'), findsOneWidget);
      expect(gateway.documentRequests, ['p1']);
    });

    testWidgets('l’impact affiche les métriques contractuelles', (
      tester,
    ) async {
      await _pumpDetail(tester, _FakeGateway.standard(), 'p1');
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();
      expect(find.text('Bénéficiaires directs'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets(
      'des métriques avec contexte incomplet conservent les valeurs et affichent l’avertissement',
      (tester) async {
        await _pumpDetail(tester, _FakeGateway.standard(), 'p1');
        await tester.tap(find.text('Impact'));
        await tester.pumpAndSettle();
        expect(find.text('64 %'), findsOneWidget);
        expect(find.text('Bénéficiaires directs'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('Informations d’impact à compléter'), findsOneWidget);
        expect(
          find.text(
            'Certaines informations de contexte du projet ne sont pas encore renseignées.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'des métriques avec contexte complet restent visibles sans avertissement',
      (tester) async {
        final gateway = _FakeGateway.standard();
        gateway.projects[0] = _project(
          'p1',
          'Audit Horizon',
          'deploiement',
          expectedImpact: 'Impact attendu documenté',
        );
        await _pumpDetail(tester, gateway, 'p1');
        await tester.tap(find.text('Impact'));
        await tester.pumpAndSettle();
        expect(find.text('64 %'), findsOneWidget);
        expect(find.text('Bénéficiaires directs'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('Informations d’impact à compléter'), findsNothing);
      },
    );

    testWidgets('l’impact incomplet possède un état dédié', (tester) async {
      await _pumpDetail(tester, _FakeGateway.standard(), 'p3');
      await tester.tap(find.text('Impact'));
      await tester.pumpAndSettle();
      expect(find.text('Informations d’impact à compléter'), findsOneWidget);
    });

    testWidgets('une source activité en erreur ne casse pas la fiche', (
      tester,
    ) async {
      final gateway = _FakeGateway.standard()..eventsError = true;
      await _pumpDetail(tester, gateway, 'p1');
      await tester.tap(find.text('Activité'));
      await tester.pumpAndSettle();
      expect(find.text('Activité indisponible'), findsOneWidget);
      expect(find.text('Audit Horizon'), findsOneWidget);
    });

    testWidgets('la fiche projet sans équipe affiche son empty state', (
      tester,
    ) async {
      await _pumpDetail(tester, _FakeGateway.standard(), 'p3');
      await tester.tap(find.text('Équipe'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune équipe affectée'), findsOneWidget);
    });
  });
}

class _FakeGateway implements ProjectsPortfolioGateway {
  UserExperience user = _user('u-admin', {'administrateur'});
  List<ProjectModel> projects;
  List<ProjectSeasonOption> seasons = const [];
  Map<String, ProjectImpactSnapshot> impact;
  final Map<String, List<ProjectMemberModel>> members;
  final Map<String, List<TaskModel>> tasks;
  final Map<String, List<ProjectAssignee>> assignees;
  final Map<String, List<DocumentModel>> documents;
  final List<EventModel> events;
  final Set<String> memberErrors = {};
  final Set<String> taskErrors = {};
  bool projectsError = false;
  bool impactError = false;
  bool eventsError = false;
  bool documentsError = false;
  Completer<List<ProjectModel>>? projectsCompleter;
  final List<String> documentRequests = [];

  @override
  Future<UserExperience> loadCurrentUser() async => user;

  _FakeGateway({
    required this.projects,
    required this.impact,
    required this.members,
    required this.tasks,
    required this.assignees,
    required this.documents,
    required this.events,
  });

  factory _FakeGateway.standard() {
    final now = DateTime.now();
    return _FakeGateway(
      projects: [
        _project('p1', 'Audit Horizon', 'deploiement'),
        _project('p2', 'Audit Canopée', 'prototype'),
        _project('p3', 'Audit Projet Sans Équipe', 'idee'),
        _project('p4', 'Audit Solstice', 'termine'),
      ],
      impact: {
        'p1': _impact('p1', progress: 64, direct: 42),
        'p2': _impact('p2', progress: 31),
        'p3': _impact('p3'),
      },
      members: {
        'p1': [
          _member('m1', 'p1', 'u1', 'Awa Horizon', 'chef_projet'),
          _member('m2', 'p1', 'u2', 'Moussa Horizon', 'adjoint_chef_projet'),
        ],
        'p2': [_member('m3', 'p2', 'u3', 'Fatou Canopée', 'chef_projet')],
        'p3': [],
        'p4': [],
      },
      tasks: {
        'p1': [
          _task(
            't1',
            'p1',
            'AUDIT-PROJECT-NEXT-ACTION-001',
            'a_faire',
            now.add(const Duration(days: 500)),
          ),
        ],
        'p2': [
          _task(
            't2',
            'p2',
            'Tâche audit 35',
            'bloque',
            now.add(const Duration(days: 20)),
          ),
          _task(
            't3',
            'p2',
            'Tâche en retard',
            'en_cours',
            now.subtract(const Duration(days: 4)),
          ),
        ],
        'p3': [],
        'p4': [
          _task(
            't4',
            'p4',
            'Terminé',
            'termine',
            now.subtract(const Duration(days: 10)),
          ),
        ],
      },
      assignees: {
        't1': const [ProjectAssignee(userId: 'u1', displayName: 'Awa Horizon')],
      },
      documents: {
        'p1': [_document('d1', 'p1', 'Document Horizon')],
        'p2': [],
        'p3': [],
        'p4': [],
      },
      events: [_event('e1', 'p1', 'AUDIT-PROJECT-EVENT-FUTURE-001')],
    );
  }

  @override
  Future<List<ProjectModel>> loadProjects() async {
    if (projectsCompleter != null) return projectsCompleter!.future;
    if (projectsError) throw Exception('projects');
    return projects;
  }

  @override
  Future<List<ProjectSeasonOption>> loadSeasons() async => seasons;

  @override
  Future<ProjectModel> createProject(ProjectMutationDraft draft) async {
    final created = _project('created', draft.name, draft.status);
    projects = [created, ...projects];
    return created;
  }

  @override
  Future<ProjectModel> updateProject(
    String projectId,
    ProjectMutationDraft draft,
  ) async {
    final current = projects.firstWhere((item) => item.id == projectId);
    final updated = _copyProject(
      current,
      name: draft.name,
      status: current.status,
      expectedImpact: draft.expectedImpact,
    );
    projects = projects
        .map((item) => item.id == projectId ? updated : item)
        .toList();
    return updated;
  }

  @override
  Future<ProjectModel> changeProjectStatus(
    ProjectModel project,
    String targetStatus,
  ) async {
    final updated = _copyProject(project, status: targetStatus);
    projects = projects
        .map((item) => item.id == project.id ? updated : item)
        .toList();
    return updated;
  }

  @override
  Future<Map<String, ProjectImpactSnapshot>> loadImpact() async {
    if (impactError) throw Exception('impact');
    return impact;
  }

  @override
  Future<List<ProjectMemberModel>> loadMembers(String projectId) async {
    if (memberErrors.contains(projectId)) throw Exception('members');
    return members[projectId] ?? [];
  }

  @override
  Future<List<MemberModel>> loadMemberDirectory() async => const [];

  @override
  Future<ProjectMemberMutationResult> assignProjectMember({
    required String projectId,
    required String userId,
    required String position,
  }) async => ProjectMemberMutationResult(
    membership: _member(
      'assigned-$userId',
      projectId,
      userId,
      userId,
      position,
    ),
  );

  @override
  Future<ProjectMemberModel> removeProjectMember({
    required String projectId,
    required String userId,
  }) async => _member('removed-$userId', projectId, userId, userId, 'membre');

  @override
  Future<List<TaskModel>> loadTasks(String projectId) async {
    if (taskErrors.contains(projectId)) throw Exception('tasks');
    return tasks[projectId] ?? [];
  }

  @override
  Future<List<ProjectAssignee>> loadTaskAssignees(String taskId) async =>
      assignees[taskId] ?? [];

  @override
  Future<List<DocumentModel>> loadDocuments(String projectId) async {
    documentRequests.add(projectId);
    if (documentsError) throw Exception('documents');
    return documents[projectId] ?? [];
  }

  @override
  Future<List<EventModel>> loadEvents() async {
    if (eventsError) throw Exception('events');
    return events;
  }
}

Future<void> _setDesktop(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpPortfolio(WidgetTester tester, _FakeGateway gateway) async {
  await _setDesktop(tester);
  await tester.pumpWidget(_app(ProjectsPortfolioScreen(gateway: gateway)));
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeGateway gateway,
  String id,
) async {
  await _setDesktop(tester);
  await tester.pumpWidget(
    _app(ProjectDetailScreen(projectId: id, gateway: gateway)),
  );
  await tester.pumpAndSettle();
}

Widget _app(Widget child) =>
    MaterialApp(theme: ThemeData(useMaterial3: true), home: child);

Future<ProjectPortfolioItem> _portfolioItem(
  _FakeGateway gateway,
  String id,
) async {
  final project = gateway.projects.firstWhere((item) => item.id == id);
  final members = await gateway.loadMembers(id);
  final tasks = await gateway.loadTasks(id);
  return ProjectPortfolioItem(
    project: project,
    members: members,
    tasks: tasks,
    impact: gateway.impact[id],
    nextAction: null,
    teamUnavailable: false,
    tasksUnavailable: false,
    impactUnavailable: false,
  );
}

ProjectModel _project(
  String id,
  String name,
  String status, {
  String? expectedImpact,
}) => ProjectModel(
  id: id,
  seasonId: null,
  name: name,
  description: 'Description $name',
  problemStatement: 'Problème Horizon',
  solution: 'Solution Horizon',
  objectives: 'Objectifs Horizon',
  expectedImpact: expectedImpact,
  budgetEstimated: 0,
  status: status,
  startedAt: DateTime(2026, 1, 10),
  endedAt: null,
  createdAt: DateTime(2026, 1, 1),
);

ProjectModel _copyProject(
  ProjectModel project, {
  required String status,
  String? name,
  String? expectedImpact,
}) => ProjectModel(
  id: project.id,
  seasonId: project.seasonId,
  name: name ?? project.name,
  description: project.description,
  problemStatement: project.problemStatement,
  solution: project.solution,
  objectives: project.objectives,
  expectedImpact: expectedImpact ?? project.expectedImpact,
  budgetEstimated: project.budgetEstimated,
  status: status,
  startedAt: project.startedAt,
  endedAt: project.endedAt,
  createdAt: project.createdAt,
);

UserExperience _user(String id, Set<String> roles) => UserExperience(
  id: id,
  email: '$id@example.com',
  displayName: id,
  status: 'active',
  gender: null,
  profileType: 'enacteur',
  roles: roles,
  canReviewJoinRequests: false,
);

ProjectMemberModel _member(
  String id,
  String projectId,
  String userId,
  String name,
  String position,
) => ProjectMemberModel(
  id: id,
  projectId: projectId,
  userId: userId,
  position: position,
  joinedAt: DateTime(2026, 1, 1),
  leftAt: null,
  isActive: true,
  displayName: name,
  email: '$userId@example.com',
  photoUrl: null,
  status: 'active',
);

TaskModel _task(
  String id,
  String projectId,
  String title,
  String status,
  DateTime due,
) => TaskModel(
  id: id,
  title: title,
  description: null,
  priority: status == 'bloque' ? 'urgente' : 'haute',
  status: status,
  dueDate: due.toIso8601String(),
  proofRequired: false,
  proofUrl: null,
  createdAt: null,
  completedAt: null,
  validatedAt: null,
  poleId: null,
  projectId: projectId,
  canManage: false,
  currentUserAssigned: false,
);

ProjectImpactSnapshot _impact(String id, {double? progress, int? direct}) =>
    ProjectImpactSnapshot(
      projectId: id,
      progress: progress,
      directBeneficiaries: direct,
      indirectBeneficiaries: null,
      reach: null,
      jobsCreated: null,
      livesImpacted: null,
      treesPlanted: null,
      wasteReduced: null,
      waterSaved: null,
      co2Reduced: null,
      sdgs: const [],
      methodology: null,
    );

DocumentModel _document(String id, String projectId, String title) =>
    DocumentModel(
      id: id,
      title: title,
      status: 'validated',
      category: 'rapport',
      visibility: 'project_only',
      projectId: projectId,
      isTemplate: false,
      isOfficial: false,
      canManage: false,
      canValidate: false,
      isPermanent: false,
      createdAt: '2026-01-02T00:00:00Z',
    );

EventModel _event(String id, String projectId, String title) => EventModel(
  id: id,
  seasonId: null,
  title: title,
  description: null,
  eventType: 'meeting',
  location: 'Salle Projet',
  startTime: DateTime(2030, 3, 20, 14),
  endTime: null,
  poleId: null,
  projectId: projectId,
  budget: 0,
  maxParticipants: null,
  requiresRegistration: false,
  attendanceEnabled: false,
  reportUrl: null,
  createdBy: null,
  registeredCount: 0,
  currentUserRegistered: false,
  canManage: false,
  createdAt: DateTime(2026, 1, 1),
);
