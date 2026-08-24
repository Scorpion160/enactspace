import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/documents/models/document_model.dart';
import 'package:frontend/features/events/models/event_model.dart';
import 'package:frontend/features/projects/models/project_management_models.dart';
import 'package:frontend/features/projects/models/project_member_model.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/models/project_portfolio_models.dart';
import 'package:frontend/features/projects/screens/project_detail_screen.dart';
import 'package:frontend/features/projects/screens/projects_portfolio_screen.dart';
import 'package:frontend/features/projects/services/projects_portfolio_gateway.dart';
import 'package:frontend/features/projects/widgets/project_management_widgets.dart';
import 'package:frontend/features/tasks/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('permissions de gestion projet', () {
    testWidgets('Nouveau projet est visible pour un rôle global', (
      tester,
    ) async {
      await _pumpPortfolio(tester, _ManagementGateway.admin());
      expect(find.text('Nouveau projet'), findsOneWidget);
    });

    testWidgets('Nouveau projet est absent pour un rôle non autorisé', (
      tester,
    ) async {
      final gateway = _ManagementGateway.admin()
        ..user = _user('member', {'enacteur'});
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Nouveau projet'), findsNothing);
    });

    testWidgets('la fiche autorisée expose la zone Gestion du projet', (
      tester,
    ) async {
      await _pumpDetail(tester, _ManagementGateway.admin());
      expect(find.text('Gestion du projet'), findsOneWidget);
      expect(find.text('Modifier le projet'), findsOneWidget);
      expect(find.text('Changer le statut'), findsOneWidget);
    });

    testWidgets('le chef actif gère uniquement son projet', (tester) async {
      final gateway = _ManagementGateway.admin()
        ..user = _user('lead', {'chef_projet'});
      await _pumpDetail(tester, gateway);
      expect(find.text('Gestion du projet'), findsOneWidget);
    });

    testWidgets('l’adjoint actif gère son projet', (tester) async {
      final gateway = _ManagementGateway.admin()
        ..user = _user('deputy', {'adjoint_chef_projet'});
      await _pumpDetail(tester, gateway);
      expect(find.text('Gestion du projet'), findsOneWidget);
    });

    testWidgets('un membre sans responsabilité ne voit aucune action', (
      tester,
    ) async {
      final gateway = _ManagementGateway.admin()
        ..user = _user('member', {'enacteur'});
      await _pumpDetail(tester, gateway);
      expect(find.text('Gestion du projet'), findsNothing);
      expect(find.text('Modifier le projet'), findsNothing);
    });
  });

  group('création projet', () {
    testWidgets('le formulaire présente les champs du contrat POST', (
      tester,
    ) async {
      await _openForm(tester);
      for (final label in [
        'Nom *',
        'Description',
        'Problème',
        'Solution',
        'Objectifs',
        'Impact attendu',
        'Budget estimé',
        'Saison',
        'Statut initial',
      ]) {
        if (find.text(label).evaluate().isEmpty) {
          await _scrollTo(tester, find.text(label));
        }
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('le nom requis bloque la création', (tester) async {
      await _openForm(tester);
      await tester.tap(find.text('Créer le projet'));
      await tester.pump();
      expect(find.text('Le nom est requis.'), findsOneWidget);
    });

    testWidgets('une fin antérieure au début est refusée', (tester) async {
      await _openForm(tester);
      await tester.enterText(_field('Nom *'), 'Projet dates');
      await _enterDate(tester, 'Date de début', '20/08/2026');
      await _enterDate(tester, 'Date de fin', '19/08/2026');
      await tester.tap(find.text('Créer le projet'));
      await tester.pump();
      expect(
        find.text('La fin doit être postérieure ou égale au début.'),
        findsOneWidget,
      );
    });

    testWidgets('un budget non numérique est refusé', (tester) async {
      await _openForm(tester);
      await tester.enterText(_field('Nom *'), 'Projet budget');
      await _scrollTo(tester, _field('Budget estimé'));
      await tester.enterText(_field('Budget estimé'), 'douze');
      await tester.tap(find.text('Créer le projet'));
      await tester.pump();
      expect(
        find.text('Saisissez un budget numérique valide.'),
        findsOneWidget,
      );
    });

    testWidgets('le statut initial propose les sept valeurs canoniques', (
      tester,
    ) async {
      await _openForm(tester);
      await _scrollTo(tester, find.text('Statut initial'));
      final dropdown = tester
          .widgetList<DropdownButton<String>>(
            find.byType(DropdownButton<String>),
          )
          .firstWhere(
            (widget) => widget.items!.any((item) => item.value == 'idee'),
          );
      final values = dropdown.items!.map((item) => item.value).toList();
      expect(values, ProjectStatusPresentation.values);
    });

    testWidgets('aucun statut legacy n’est proposé', (tester) async {
      await _openForm(tester);
      expect(find.text('active'), findsNothing);
      expect(find.text('suspended'), findsNothing);
      expect(find.text('completed'), findsNothing);
    });

    testWidgets('la création simulée réussit puis rafraîchit', (tester) async {
      final gateway = _ManagementGateway.admin();
      await _pumpPortfolio(tester, gateway);
      await tester.tap(find.text('Nouveau projet'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nom *'), 'Projet créé');
      await tester.tap(find.text('Créer le projet'));
      await tester.pumpAndSettle();
      expect(gateway.createCalls, 1);
      expect(gateway.projectLoads, greaterThan(1));
      expect(find.text('Projet mis à jour'), findsOneWidget);
    });

    testWidgets('une erreur de création conserve toutes les valeurs', (
      tester,
    ) async {
      final gateway = _ManagementGateway.admin()..createError = true;
      await _pumpPortfolio(tester, gateway);
      await tester.tap(find.text('Nouveau projet'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nom *'), 'Projet conservé');
      await tester.tap(find.text('Créer le projet'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('La demande n’a pas abouti'));
      expect(find.text('La demande n’a pas abouti'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      await _scrollTo(tester, _field('Nom *'), delta: -240);
      expect(
        tester.widget<TextFormField>(_field('Nom *')).controller!.text,
        'Projet conservé',
      );
    });

    testWidgets('le double clic de création ne produit qu’un envoi', (
      tester,
    ) async {
      final completer = Completer<ProjectModel>();
      var calls = 0;
      await _openForm(
        tester,
        onSubmit: (draft) {
          calls++;
          return completer.future;
        },
      );
      await tester.enterText(_field('Nom *'), 'Projet unique');
      final submit = find.text('Créer le projet');
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(calls, 1);
      completer.complete(_project(name: 'Projet unique'));
      await tester.pumpAndSettle();
    });
  });

  group('édition projet', () {
    testWidgets('le formulaire est réellement prérempli', (tester) async {
      await _pumpDetail(tester, _ManagementGateway.admin());
      await tester.tap(find.text('Modifier le projet'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_field('Nom *')).controller!.text,
        'Audit Horizon',
      );
      await _scrollTo(tester, _field('Problème'));
      expect(
        tester.widget<TextFormField>(_field('Problème')).controller!.text,
        'Problème Horizon',
      );
      expect(find.text('Enregistrer les modifications'), findsOneWidget);
      expect(find.text('Statut initial'), findsNothing);
    });

    testWidgets('l’édition simulée réussit', (tester) async {
      final gateway = _ManagementGateway.admin();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Modifier le projet'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nom *'), 'Horizon modifié');
      await tester.tap(find.text('Enregistrer les modifications'));
      await tester.pumpAndSettle();
      expect(gateway.updateCalls, 1);
      expect(find.text('Projet mis à jour'), findsOneWidget);
      expect(find.text('Horizon modifié'), findsOneWidget);
    });

    testWidgets('une erreur d’édition conserve le formulaire', (tester) async {
      final gateway = _ManagementGateway.admin()..updateError = true;
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Modifier le projet'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Nom *'), 'Valeur préservée');
      await tester.tap(find.text('Enregistrer les modifications'));
      await tester.pumpAndSettle();
      expect(find.text('Valeur préservée'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(gateway.updateCalls, 1);
    });
  });

  group('transitions de statut', () {
    testWidgets('le dialogue est dédié et résume la transition', (
      tester,
    ) async {
      await _openStatus(tester);
      expect(find.text('Mettre à jour le statut du projet'), findsOneWidget);
      await _selectStatus(tester, 'Test');
      expect(find.text('Déploiement → Test'), findsOneWidget);
    });

    testWidgets('le statut actuel est absent des choix', (tester) async {
      await _openStatus(tester);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('project-status-target')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        dropdown.items!.map((item) => item.value),
        isNot(contains('deploiement')),
      );
    });

    testWidgets('le choix seul ne déclenche aucune mutation', (tester) async {
      final gateway = _ManagementGateway.admin();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Changer le statut'));
      await tester.pumpAndSettle();
      await _selectStatus(tester, 'Test');
      expect(gateway.statusCalls, 0);
    });

    testWidgets('Terminé affiche l’avertissement sur les tâches', (
      tester,
    ) async {
      await _openStatus(tester);
      await _selectStatus(tester, 'Terminé');
      expect(find.text('Marquer ce projet comme terminé ?'), findsOneWidget);
      expect(find.text('1 tâche(s) encore non terminale(s).'), findsOneWidget);
      expect(find.textContaining('informatifs'), findsOneWidget);
    });

    testWidgets('Suspendu possède une confirmation distincte', (tester) async {
      await _openStatus(tester);
      await _selectStatus(tester, 'Suspendu');
      expect(find.text('Suspendre ce projet ?'), findsOneWidget);
      expect(find.text('Suspendre le projet'), findsOneWidget);
      expect(find.textContaining('restera consultable'), findsOneWidget);
    });

    testWidgets('aucun faux motif de suspension n’est demandé', (tester) async {
      await _openStatus(tester);
      await _selectStatus(tester, 'Suspendu');
      expect(find.textContaining('Motif'), findsNothing);
    });

    testWidgets('la confirmation réussie rafraîchit le statut', (tester) async {
      final gateway = _ManagementGateway.admin();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Changer le statut'));
      await tester.pumpAndSettle();
      await _selectStatus(tester, 'Test');
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(gateway.statusCalls, 1);
      expect(gateway.projectLoads, greaterThan(1));
      expect(find.text('Test'), findsWidgets);
      expect(find.text('Projet mis à jour'), findsOneWidget);
    });

    testWidgets('une erreur garde le dialogue ouvert et réessayable', (
      tester,
    ) async {
      final gateway = _ManagementGateway.admin()..statusError = true;
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Changer le statut'));
      await tester.pumpAndSettle();
      await _selectStatus(tester, 'Test');
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      expect(find.text('Déploiement → Test'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('le double clic de statut est empêché', (tester) async {
      final gateway = _ManagementGateway.admin()
        ..statusCompleter = Completer<ProjectModel>();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Changer le statut'));
      await tester.pumpAndSettle();
      await _selectStatus(tester, 'Test');
      final confirm = find.text('Confirmer');
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(gateway.statusCalls, 1);
      gateway.statusCompleter!.complete(
        _copy(gateway.projects.first, status: 'test'),
      );
      await tester.pumpAndSettle();
    });

    test('Terminé centralise ended_at à la date du jour', () {
      final payload = ProjectStatusMutationPayload.build(
        _project(),
        'termine',
        now: () => DateTime(2026, 8, 23),
      );
      expect(payload, {'status': 'termine', 'ended_at': '2026-08-23'});
    });

    test(
      'quitter Terminé efface ended_at selon la compatibilité historique',
      () {
        final payload = ProjectStatusMutationPayload.build(
          _project(status: 'termine', endedAt: DateTime(2026, 8, 20)),
          'deploiement',
        );
        expect(payload, {'status': 'deploiement', 'ended_at': null});
      },
    );
  });

  group('résilience et responsive', () {
    testWidgets('aucun pourcentage n’est inventé depuis le statut', (
      tester,
    ) async {
      final gateway = _ManagementGateway.admin()..impact = {};
      await _pumpPortfolio(tester, gateway);
      expect(find.text('Progression non disponible'), findsOneWidget);
      expect(find.text('100 %'), findsNothing);
    });

    testWidgets('la gestion reste sans overflow à 390 px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(ProjectsPortfolioScreen(gateway: _ManagementGateway.admin())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouveau projet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpPortfolio(
  WidgetTester tester,
  _ManagementGateway gateway,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(ProjectsPortfolioScreen(gateway: gateway)));
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _ManagementGateway gateway,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(ProjectDetailScreen(projectId: 'p1', gateway: gateway)),
  );
  await tester.pumpAndSettle();
}

Future<void> _openForm(
  WidgetTester tester, {
  ProjectModel? project,
  Future<ProjectModel> Function(ProjectMutationDraft)? onSubmit,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<ProjectModel>(
              context: context,
              builder: (_) => ProjectFormDialog(
                project: project,
                seasons: const [
                  ProjectSeasonOption(
                    id: 's1',
                    name: '2026-2027',
                    isCurrent: true,
                  ),
                ],
                onSubmit:
                    onSubmit ?? (draft) async => _project(name: draft.name),
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

Future<void> _openStatus(WidgetTester tester) async {
  final gateway = _ManagementGateway.admin();
  await _pumpDetail(tester, gateway);
  await tester.tap(find.text('Changer le statut'));
  await tester.pumpAndSettle();
}

Future<void> _selectStatus(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('project-status-target')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _enterDate(WidgetTester tester, String label, String value) async {
  final field = _field(label);
  await _scrollTo(tester, field);
  await tester.enterText(field, value);
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  double delta = 240,
}) async {
  final formScrollable = find.descendant(
    of: find.byKey(const Key('project-form-scroll')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: formScrollable.first,
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Widget _app(Widget child) =>
    MaterialApp(theme: ThemeData(useMaterial3: true), home: child);

class _ManagementGateway implements ProjectsPortfolioGateway {
  UserExperience user;
  List<ProjectModel> projects;
  Map<String, ProjectImpactSnapshot> impact;
  int projectLoads = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int statusCalls = 0;
  bool createError = false;
  bool updateError = false;
  bool statusError = false;
  Completer<ProjectModel>? statusCompleter;

  _ManagementGateway({
    required this.user,
    required this.projects,
    required this.impact,
  });

  factory _ManagementGateway.admin() => _ManagementGateway(
    user: _user('admin', {'administrateur'}),
    projects: [_project()],
    impact: {
      'p1': const ProjectImpactSnapshot(
        projectId: 'p1',
        progress: 40,
        directBeneficiaries: 80,
        indirectBeneficiaries: 320,
        reach: 475,
        jobsCreated: 0,
        livesImpacted: 80,
        treesPlanted: 0,
        wasteReduced: 0,
        waterSaved: 0,
        co2Reduced: 0,
        sdgs: [],
        methodology: null,
      ),
    },
  );

  @override
  Future<UserExperience> loadCurrentUser() async => user;

  @override
  Future<List<ProjectModel>> loadProjects() async {
    projectLoads++;
    return projects;
  }

  @override
  Future<List<ProjectSeasonOption>> loadSeasons() async => const [
    ProjectSeasonOption(id: 's1', name: '2026-2027', isCurrent: true),
  ];

  @override
  Future<Map<String, ProjectImpactSnapshot>> loadImpact() async => impact;

  @override
  Future<List<ProjectMemberModel>> loadMembers(String projectId) async => [
    _membership('lead', 'chef_projet'),
    _membership('deputy', 'adjoint_chef_projet'),
  ];

  @override
  Future<List<TaskModel>> loadTasks(String projectId) async => [_task()];

  @override
  Future<List<ProjectAssignee>> loadTaskAssignees(String taskId) async =>
      const [];

  @override
  Future<List<DocumentModel>> loadDocuments(String projectId) async => const [];

  @override
  Future<List<EventModel>> loadEvents() async => const [];

  @override
  Future<ProjectModel> createProject(ProjectMutationDraft draft) async {
    createCalls++;
    if (createError) throw Exception('Création impossible');
    final created = _project(
      id: 'created',
      name: draft.name,
      status: draft.status,
    );
    projects = [created, ...projects];
    return created;
  }

  @override
  Future<ProjectModel> updateProject(
    String projectId,
    ProjectMutationDraft draft,
  ) async {
    updateCalls++;
    if (updateError) throw Exception('Modification impossible');
    final current = projects.firstWhere((project) => project.id == projectId);
    final updated = _copy(current, name: draft.name);
    projects = [updated];
    return updated;
  }

  @override
  Future<ProjectModel> changeProjectStatus(
    ProjectModel project,
    String targetStatus,
  ) async {
    statusCalls++;
    if (statusCompleter != null) return statusCompleter!.future;
    if (statusError) throw Exception('Transition impossible');
    final updated = _copy(project, status: targetStatus);
    projects = [updated];
    return updated;
  }
}

ProjectModel _project({
  String id = 'p1',
  String name = 'Audit Horizon',
  String status = 'deploiement',
  DateTime? endedAt,
}) => ProjectModel(
  id: id,
  seasonId: 's1',
  name: name,
  description: 'Description Horizon',
  problemStatement: 'Problème Horizon',
  solution: 'Solution Horizon',
  objectives: 'Objectifs Horizon',
  expectedImpact: 'Impact Horizon',
  budgetEstimated: 12000,
  status: status,
  startedAt: DateTime(2026, 1, 10),
  endedAt: endedAt,
  createdAt: DateTime(2026, 1, 1),
);

ProjectModel _copy(ProjectModel project, {String? name, String? status}) =>
    ProjectModel(
      id: project.id,
      seasonId: project.seasonId,
      name: name ?? project.name,
      description: project.description,
      problemStatement: project.problemStatement,
      solution: project.solution,
      objectives: project.objectives,
      expectedImpact: project.expectedImpact,
      budgetEstimated: project.budgetEstimated,
      status: status ?? project.status,
      startedAt: project.startedAt,
      endedAt: project.endedAt,
      createdAt: project.createdAt,
    );

ProjectMemberModel _membership(String userId, String position) =>
    ProjectMemberModel(
      id: 'm-$userId',
      projectId: 'p1',
      userId: userId,
      position: position,
      joinedAt: DateTime(2026, 1, 1),
      leftAt: null,
      isActive: true,
      displayName: userId,
      email: '$userId@example.com',
      photoUrl: null,
      status: 'active',
    );

TaskModel _task() => TaskModel(
  id: 't1',
  title: 'Tâche active',
  description: null,
  priority: 'urgente',
  status: 'bloque',
  dueDate: DateTime(2026, 8, 20).toIso8601String(),
  proofRequired: false,
  proofUrl: null,
  createdAt: null,
  completedAt: null,
  validatedAt: null,
  poleId: null,
  projectId: 'p1',
  canManage: false,
  currentUserAssigned: false,
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
