import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/documents/models/document_model.dart';
import 'package:frontend/features/events/models/event_model.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/projects/models/project_management_models.dart';
import 'package:frontend/features/projects/models/project_member_model.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/models/project_portfolio_models.dart';
import 'package:frontend/features/projects/models/project_team_management_models.dart';
import 'package:frontend/features/projects/screens/project_detail_screen.dart';
import 'package:frontend/features/projects/services/projects_portfolio_gateway.dart';
import 'package:frontend/features/projects/widgets/project_team_management_widgets.dart';
import 'package:frontend/features/tasks/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('présentation et permissions équipe projet', () {
    test('les trois positions sont humanisées', () {
      expect(ProjectPositionPresentation.label('membre'), 'Membre du projet');
      expect(
        ProjectPositionPresentation.label('chef_projet'),
        'Chef de projet',
      );
      expect(
        ProjectPositionPresentation.label('adjoint_chef_projet'),
        'Adjoint chef de projet',
      );
    });

    test('un gestionnaire global gère membres et responsabilités', () {
      final value = ProjectTeamPermissions.resolve(
        _user('admin', {'administrateur'}),
        const [],
      );
      expect(value.canManageOrdinaryMembers, isTrue);
      expect(value.canManageResponsibilities, isTrue);
    });

    test('un chef local actif gère seulement les membres ordinaires', () {
      final value = ProjectTeamPermissions.resolve(
        _user('lead', {'chef_projet'}),
        [_membership('lead', 'chef_projet')],
      );
      expect(value.canManageOrdinaryMembers, isTrue);
      expect(value.canManageResponsibilities, isFalse);
      expect(value.canRemove(_membership('member', 'membre')), isTrue);
      expect(value.canRemove(_membership('lead', 'chef_projet')), isFalse);
    });

    test('un adjoint local actif gère seulement les membres ordinaires', () {
      final value = ProjectTeamPermissions.resolve(
        _user('deputy', {'adjoint_chef_projet'}),
        [_membership('deputy', 'adjoint_chef_projet')],
      );
      expect(value.canManageOrdinaryMembers, isTrue);
      expect(value.canManageResponsibilities, isFalse);
    });

    test('un non gestionnaire ne peut rien muter', () {
      final value = ProjectTeamPermissions.resolve(
        _user('member', {'enacteur'}),
        [_membership('member', 'membre')],
      );
      expect(value.canManageOrdinaryMembers, isFalse);
      expect(value.canManageResponsibilities, isFalse);
    });

    test('les erreurs réelles sont humanisées', () {
      expect(
        projectTeamErrorMessage(
          Exception("Le membre sélectionné n'est pas actif"),
        ),
        'Cette personne ne possède pas un compte actif.',
      );
      expect(
        projectTeamErrorMessage(Exception('Position projet invalide')),
        'Responsabilité dans le projet invalide.',
      );
      expect(
        projectTeamErrorMessage(Exception('Projet introuvable')),
        'Projet introuvable.',
      );
    });
  });

  group('section équipe', () {
    testWidgets('la section existante reste lisible', (tester) async {
      await _pumpTeam(tester, _globalPermissions(), _team());
      expect(find.text('Chef de projet'), findsOneWidget);
      expect(find.text('Adjoint chef de projet'), findsOneWidget);
      expect(find.text('Membres'), findsOneWidget);
      expect(find.text('Awa Lead'), findsOneWidget);
      expect(find.text('Moussa Member'), findsOneWidget);
    });

    testWidgets('le projet sans équipe affiche son état vide', (tester) async {
      await _pumpTeam(tester, _globalPermissions(), const []);
      expect(find.text('Aucune équipe affectée'), findsOneWidget);
      expect(find.text('Constituer l’équipe'), findsOneWidget);
    });

    testWidgets('Ajouter est visible pour un gestionnaire global', (
      tester,
    ) async {
      await _pumpTeam(tester, _globalPermissions(), _team());
      expect(find.text('Ajouter un membre'), findsOneWidget);
    });

    testWidgets('Ajouter est visible pour le chef local', (tester) async {
      await _pumpTeam(tester, _localPermissions(), _team());
      expect(find.text('Ajouter un membre'), findsOneWidget);
    });

    testWidgets('Ajouter est visible pour l’adjoint local', (tester) async {
      await _pumpTeam(tester, _localPermissions(), _team());
      expect(find.text('Ajouter un membre'), findsOneWidget);
    });

    testWidgets('les actions sont absentes pour un non gestionnaire', (
      tester,
    ) async {
      await _pumpTeam(
        tester,
        const ProjectTeamPermissions(
          isGlobalManager: false,
          isLocalManager: false,
        ),
        _team(),
      );
      expect(find.text('Ajouter un membre'), findsNothing);
      expect(find.text('Changer de chef de projet'), findsNothing);
      expect(find.byTooltip('Retirer Moussa Member de l’équipe'), findsNothing);
    });

    testWidgets('le chef local ne voit aucune promotion chef ou adjoint', (
      tester,
    ) async {
      await _pumpTeam(tester, _localPermissions(), _team());
      expect(find.text('Changer de chef de projet'), findsNothing);
      expect(find.text('Changer d’adjoint'), findsNothing);
    });

    testWidgets('le global peut ouvrir les changements de responsables', (
      tester,
    ) async {
      await _pumpTeam(tester, _globalPermissions(), _team());
      expect(find.text('Changer de chef de projet'), findsOneWidget);
      expect(find.text('Changer d’adjoint'), findsOneWidget);
    });

    testWidgets('aucune position brute n’est affichée', (tester) async {
      await _pumpTeam(tester, _globalPermissions(), _team());
      expect(find.text('chef_projet'), findsNothing);
      expect(find.text('adjoint_chef_projet'), findsNothing);
      expect(find.text('membre'), findsNothing);
    });

    testWidgets('la section tient en largeur 390 px sans overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpTeam(tester, _globalPermissions(), _team(), setSize: false);
      expect(tester.takeException(), isNull);
      expect(find.text('Ajouter un membre'), findsOneWidget);
    });
  });

  group('dialogue ajouter un membre', () {
    testWidgets('les alumni et comptes non actifs sont filtrés', (
      tester,
    ) async {
      await _pumpAddDialog(tester);
      expect(find.text('Aminata Active'), findsOneWidget);
      expect(find.text('Alumni Audit'), findsNothing);
      expect(find.text('Inactive Audit'), findsNothing);
    });

    testWidgets('la recherche annuaire fonctionne par nom', (tester) async {
      await _pumpAddDialog(tester);
      await tester.enterText(
        find.byKey(const Key('project-member-search')),
        'fatou',
      );
      await tester.pump();
      expect(find.text('Fatou Active'), findsOneWidget);
      expect(find.text('Aminata Active'), findsNothing);
    });

    testWidgets('la recherche annuaire fonctionne par e-mail', (tester) async {
      await _pumpAddDialog(tester);
      await tester.enterText(
        find.byKey(const Key('project-member-search')),
        'aminata@example.com',
      );
      await tester.pump();
      expect(find.text('Aminata Active'), findsOneWidget);
      expect(find.text('Fatou Active'), findsNothing);
    });

    testWidgets('un résultat vide est distinct', (tester) async {
      await _pumpAddDialog(tester);
      await tester.enterText(
        find.byKey(const Key('project-member-search')),
        'personne absente',
      );
      await tester.pump();
      expect(find.text('Aucun membre disponible'), findsOneWidget);
    });

    testWidgets('une personne déjà membre reste présentée et désactivée', (
      tester,
    ) async {
      await _pumpAddDialog(
        tester,
        memberships: [_membership('active-1', 'membre')],
      );
      expect(find.textContaining('Déjà dans l’équipe'), findsOneWidget);
    });

    testWidgets('le formulaire résume personne projet et responsabilité', (
      tester,
    ) async {
      await _pumpAddDialog(tester);
      await tester.tap(find.text('Aminata Active'));
      await tester.pump();
      expect(find.textContaining('rejoindra Audit Horizon'), findsOneWidget);
      expect(find.textContaining('Membre du projet'), findsWidgets);
    });

    testWidgets('un ajout simulé appelle une seule fois le gateway', (
      tester,
    ) async {
      var calls = 0;
      await _pumpAddDialog(
        tester,
        onSubmit: (member) async {
          calls++;
          return ProjectMemberMutationResult(
            membership: _membership(member.id, 'membre'),
          );
        },
      );
      await tester.tap(find.text('Aminata Active'));
      await tester.pump();
      await tester.tap(find.text('Ajouter à l’équipe'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('une erreur conserve la sélection et permet Réessayer', (
      tester,
    ) async {
      await _pumpAddDialog(
        tester,
        onSubmit: (_) async => throw Exception('Erreur serveur temporaire'),
      );
      await tester.tap(find.text('Aminata Active'));
      await tester.pump();
      await tester.tap(find.text('Ajouter à l’équipe'));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aminata Active rejoindra'), findsOneWidget);
    });

    testWidgets('le double clic est empêché pendant l’envoi', (tester) async {
      final completer = Completer<ProjectMemberMutationResult>();
      var calls = 0;
      await _pumpAddDialog(
        tester,
        onSubmit: (member) {
          calls++;
          return completer.future;
        },
      );
      await tester.tap(find.text('Aminata Active'));
      await tester.pump();
      await tester.tap(find.text('Ajouter à l’équipe'));
      await tester.tap(find.text('Ajouter à l’équipe'), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      completer.complete(
        ProjectMemberMutationResult(
          membership: _membership('active-1', 'membre'),
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('responsabilités', () {
    testWidgets('le dialogue chef montre le remplacement réel', (tester) async {
      await _pumpLeadDialog(tester, ProjectPositionPresentation.lead);
      await tester.tap(find.byType(DropdownButtonFormField<MemberModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      expect(find.text('Awa Lead → Aminata Active'), findsOneWidget);
      expect(
        find.text(
          'Le chef actuel quittera cette responsabilité et restera membre du projet.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('la nomination chef utilise l’action dédiée', (tester) async {
      await _pumpLeadDialog(
        tester,
        ProjectPositionPresentation.lead,
        withoutCurrent: true,
      );
      expect(find.text('Nommer un chef de projet'), findsOneWidget);
      expect(find.text('Nommer comme chef de projet'), findsOneWidget);
    });

    testWidgets('le dialogue adjoint explicite l’ancien titulaire', (
      tester,
    ) async {
      await _pumpLeadDialog(tester, ProjectPositionPresentation.deputy);
      await tester.tap(find.byType(DropdownButtonFormField<MemberModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'L’adjoint actuel quittera cette responsabilité et restera membre du projet.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('une erreur de changement conserve le candidat', (
      tester,
    ) async {
      await _pumpLeadDialog(
        tester,
        ProjectPositionPresentation.lead,
        onSubmit: (_) async => throw Exception('Permission insuffisante'),
      );
      await tester.tap(find.byType(DropdownButtonFormField<MemberModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nommer comme chef de projet'));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Awa Lead → Aminata Active'), findsOneWidget);
    });
  });

  group('retrait', () {
    testWidgets('aucun DELETE simulé avant confirmation', (tester) async {
      var calls = 0;
      await _pumpRemovalDialog(
        tester,
        onSubmit: () async {
          calls++;
          return _membership('member', 'membre');
        },
      );
      expect(calls, 0);
      expect(find.text('Retirer ce membre du projet ?'), findsOneWidget);
      expect(find.text('Retirer de l’équipe'), findsOneWidget);
    });

    testWidgets('le retrait ordinaire confirmé réussit', (tester) async {
      var calls = 0;
      await _pumpRemovalDialog(
        tester,
        onSubmit: () async {
          calls++;
          return _membership('member', 'membre');
        },
      );
      await tester.tap(find.text('Retirer de l’équipe').last);
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('une erreur de retrait garde la confirmation ouverte', (
      tester,
    ) async {
      await _pumpRemovalDialog(
        tester,
        onSubmit: () async => throw Exception('Erreur réseau'),
      );
      await tester.tap(find.text('Retirer de l’équipe'));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Retirer ce membre du projet ?'), findsOneWidget);
    });

    testWidgets('retirer un chef prévient que le projet restera sans chef', (
      tester,
    ) async {
      await _pumpRemovalDialog(
        tester,
        membership: _membership('lead', 'chef_projet'),
      );
      expect(find.textContaining('restera sans chef'), findsOneWidget);
    });

    testWidgets('une auto-action autorisée affiche la perte de gestion', (
      tester,
    ) async {
      await _pumpRemovalDialog(tester, isCurrentUser: true);
      expect(
        find.textContaining('perdrez votre capacité locale'),
        findsOneWidget,
      );
    });
  });

  group('intégration gateway simulé', () {
    testWidgets('succès ajout affiche le feedback et rafraîchit les membres', (
      tester,
    ) async {
      final gateway = _TeamGateway();
      await _pumpDetail(tester, gateway);
      await _openTeamAndAdd(tester);
      expect(gateway.assignCalls, 1);
      expect(gateway.memberLoads, greaterThan(1));
      expect(find.text('Membre ajouté à l’équipe'), findsOneWidget);
    });

    testWidgets('réactivation détectée affiche un feedback adapté', (
      tester,
    ) async {
      final gateway = _TeamGateway()..reactivated = true;
      await _pumpDetail(tester, gateway);
      await _openTeamAndAdd(tester);
      expect(find.text('Membre réintégré à l’équipe'), findsOneWidget);
    });

    testWidgets('changement chef simulé affiche le feedback', (tester) async {
      final gateway = _TeamGateway();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Équipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer de chef de projet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<MemberModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nommer comme chef de projet'));
      await tester.pumpAndSettle();
      expect(find.text('Chef de projet mis à jour'), findsOneWidget);
    });

    testWidgets('changement adjoint simulé affiche le feedback', (
      tester,
    ) async {
      final gateway = _TeamGateway();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Équipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changer d’adjoint'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<MemberModel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nommer comme adjoint'));
      await tester.pumpAndSettle();
      expect(find.text('Adjoint du projet mis à jour'), findsOneWidget);
    });

    testWidgets('retrait simulé affiche le feedback et rafraîchit', (
      tester,
    ) async {
      final gateway = _TeamGateway();
      await _pumpDetail(tester, gateway);
      await tester.tap(find.text('Équipe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Retirer Moussa Member de l’équipe'));
      await tester.pumpAndSettle();
      expect(gateway.removeCalls, 0);
      await tester.tap(find.text('Retirer de l’équipe').last);
      await tester.pumpAndSettle();
      expect(gateway.removeCalls, 1);
      expect(find.text('Membre retiré de l’équipe'), findsOneWidget);
    });
  });
}

Future<void> _pumpTeam(
  WidgetTester tester,
  ProjectTeamPermissions permissions,
  List<ProjectMemberModel> members, {
  bool setSize = true,
}) async {
  if (setSize) {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    _app(
      ProjectTeamManagementSection(
        projectName: 'Audit Horizon',
        members: members,
        unavailable: false,
        permissions: permissions,
        onAddMember: () {},
        onChangeLead: () {},
        onChangeDeputy: () {},
        onRemoveMember: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAddDialog(
  WidgetTester tester, {
  List<ProjectMemberModel> memberships = const [],
  Future<ProjectMemberMutationResult> Function(MemberModel)? onSubmit,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      ProjectMemberDialog(
        projectName: 'Audit Horizon',
        directory: _directory(),
        activeMemberships: memberships,
        onSubmit:
            onSubmit ??
            (member) async => ProjectMemberMutationResult(
              membership: _membership(member.id, 'membre'),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLeadDialog(
  WidgetTester tester,
  String position, {
  ProjectMemberModel? current,
  bool withoutCurrent = false,
  Future<ProjectMemberMutationResult> Function(MemberModel)? onSubmit,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      ProjectLeadChangeDialog(
        projectName: 'Audit Horizon',
        targetPosition: position,
        currentHolder: withoutCurrent
            ? null
            : current ??
                  _membership(
                    position == ProjectPositionPresentation.lead
                        ? 'lead'
                        : 'deputy',
                    position,
                  ),
        directory: _directory(),
        onSubmit:
            onSubmit ??
            (member) async => ProjectMemberMutationResult(
              membership: _membership(member.id, position),
              kind: ProjectMemberMutationKind.responsibilityUpdated,
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRemovalDialog(
  WidgetTester tester, {
  ProjectMemberModel? membership,
  bool isCurrentUser = false,
  Future<ProjectMemberModel> Function()? onSubmit,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 650));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final target = membership ?? _membership('member', 'membre');
  await tester.pumpWidget(
    _app(
      ProjectMemberRemovalDialog(
        projectName: 'Audit Horizon',
        membership: target,
        isCurrentUser: isCurrentUser,
        onSubmit: onSubmit ?? () async => target,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(WidgetTester tester, _TeamGateway gateway) async {
  await tester.binding.setSurfaceSize(const Size(1200, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(ProjectDetailScreen(projectId: 'p1', gateway: gateway)),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTeamAndAdd(WidgetTester tester) async {
  await tester.tap(find.text('Équipe'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajouter un membre'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aminata Active'));
  await tester.pump();
  await tester.tap(find.text('Ajouter à l’équipe'));
  await tester.pumpAndSettle();
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  home: Scaffold(body: child),
);

ProjectTeamPermissions _globalPermissions() =>
    const ProjectTeamPermissions(isGlobalManager: true, isLocalManager: false);

ProjectTeamPermissions _localPermissions() =>
    const ProjectTeamPermissions(isGlobalManager: false, isLocalManager: true);

List<ProjectMemberModel> _team() => [
  _membership('lead', 'chef_projet', name: 'Awa Lead'),
  _membership('deputy', 'adjoint_chef_projet', name: 'Ibra Deputy'),
  _membership('member', 'membre', name: 'Moussa Member'),
];

ProjectMemberModel _membership(
  String userId,
  String position, {
  String? name,
}) => ProjectMemberModel(
  id: 'membership-$userId',
  projectId: 'p1',
  userId: userId,
  position: position,
  joinedAt: DateTime(2026, 1, 15),
  leftAt: null,
  isActive: true,
  displayName:
      name ??
      switch (userId) {
        'lead' => 'Awa Lead',
        'deputy' => 'Ibra Deputy',
        'member' => 'Moussa Member',
        _ => userId,
      },
  email: '$userId@example.com',
  photoUrl: null,
  status: 'active',
);

List<MemberModel> _directory() => const [
  MemberModel(
    id: 'active-1',
    email: 'aminata@example.com',
    fullName: 'Aminata Active',
    status: 'active',
    profileType: 'enacteur',
  ),
  MemberModel(
    id: 'active-2',
    email: 'fatou@example.com',
    fullName: 'Fatou Active',
    status: 'active',
    profileType: 'enacteur',
  ),
  MemberModel(
    id: 'alumni-1',
    email: 'alumni@example.com',
    fullName: 'Alumni Audit',
    status: 'alumni',
    profileType: 'alumni',
  ),
  MemberModel(
    id: 'inactive-1',
    email: 'inactive@example.com',
    fullName: 'Inactive Audit',
    status: 'inactive',
    profileType: 'enacteur',
  ),
];

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

class _TeamGateway implements ProjectsPortfolioGateway {
  UserExperience user = _user('admin', {'administrateur'});
  List<ProjectMemberModel> members = _team();
  int memberLoads = 0;
  int assignCalls = 0;
  int removeCalls = 0;
  bool reactivated = false;

  @override
  Future<UserExperience> loadCurrentUser() async => user;

  @override
  Future<List<ProjectModel>> loadProjects() async => [_project()];

  @override
  Future<List<ProjectSeasonOption>> loadSeasons() async => const [];

  @override
  Future<Map<String, ProjectImpactSnapshot>> loadImpact() async => const {};

  @override
  Future<List<ProjectMemberModel>> loadMembers(String projectId) async {
    memberLoads++;
    return members;
  }

  @override
  Future<List<MemberModel>> loadMemberDirectory() async => _directory();

  @override
  Future<List<TaskModel>> loadTasks(String projectId) async => const [];

  @override
  Future<List<ProjectAssignee>> loadTaskAssignees(String taskId) async =>
      const [];

  @override
  Future<List<DocumentModel>> loadDocuments(String projectId) async => const [];

  @override
  Future<List<EventModel>> loadEvents() async => const [];

  @override
  Future<ProjectModel> createProject(ProjectMutationDraft draft) async =>
      _project();

  @override
  Future<ProjectModel> updateProject(
    String projectId,
    ProjectMutationDraft draft,
  ) async => _project();

  @override
  Future<ProjectModel> changeProjectStatus(
    ProjectModel project,
    String targetStatus,
  ) async => project;

  @override
  Future<ProjectMemberMutationResult> assignProjectMember({
    required String projectId,
    required String userId,
    required String position,
  }) async {
    assignCalls++;
    if (ProjectPositionPresentation.isLeadership(position)) {
      members = members
          .map(
            (item) => item.position == position
                ? _membership(item.userId, 'membre', name: item.displayName)
                : item,
          )
          .toList();
    }
    final added = _membership(
      userId,
      position,
      name: _directory().firstWhere((item) => item.id == userId).displayName,
    );
    members = [...members.where((item) => item.userId != userId), added];
    return ProjectMemberMutationResult(
      membership: added,
      kind: reactivated
          ? ProjectMemberMutationKind.reactivated
          : ProjectMemberMutationKind.assigned,
    );
  }

  @override
  Future<ProjectMemberModel> removeProjectMember({
    required String projectId,
    required String userId,
  }) async {
    removeCalls++;
    final removed = members.firstWhere((item) => item.userId == userId);
    members = members.where((item) => item.userId != userId).toList();
    return removed;
  }
}

ProjectModel _project() => ProjectModel(
  id: 'p1',
  seasonId: null,
  name: 'Audit Horizon',
  description: 'Projet audit',
  problemStatement: null,
  solution: null,
  objectives: null,
  expectedImpact: null,
  budgetEstimated: 0,
  status: 'idee',
  startedAt: null,
  endedAt: null,
  createdAt: DateTime(2026, 1, 1),
);
