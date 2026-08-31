import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/documents/models/document_model.dart';
import 'package:frontend/features/events/models/event_model.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/poles/models/pole_management_models.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/poles/models/pole_portfolio_models.dart';
import 'package:frontend/features/poles/screens/pole_detail_screen.dart';
import 'package:frontend/features/poles/screens/poles_portfolio_screen.dart';
import 'package:frontend/features/poles/services/poles_portfolio_gateway.dart';
import 'package:frontend/features/poles/widgets/pole_management_widgets.dart';
import 'package:frontend/features/posts/models/post_model.dart';
import 'package:frontend/features/tasks/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('permissions gestion Pôles', () {
    test('les trois rôles globaux peuvent tout gérer', () {
      for (final role in [
        'administrateur',
        'team_leader',
        'secretaire_generale',
      ]) {
        final permissions = PoleManagementPermissions.resolve(
          _user('global', role),
          const [],
        );
        expect(
          PoleManagementPermissions.canCreate(_user('global', role)),
          isTrue,
        );
        expect(permissions.canEditPole, isTrue);
        expect(permissions.canManageOrdinaryMembers, isTrue);
        expect(permissions.canManageResponsibilities, isTrue);
      }
    });

    test('chef et adjoint locaux gèrent le pôle et les membres ordinaires', () {
      for (final position in ['chef_pole', 'adjoint_chef_pole']) {
        final permissions = PoleManagementPermissions.resolve(
          _user('local', 'enacteur'),
          [_member('local', 'Responsable local', position)],
        );
        expect(permissions.canEditPole, isTrue);
        expect(permissions.canManageOrdinaryMembers, isTrue);
        expect(permissions.canManageResponsibilities, isFalse);
        expect(
          permissions.canRemove(_member('lead', 'Chef', 'chef_pole')),
          isFalse,
        );
        expect(
          permissions.canRemove(_member('member', 'Membre', 'membre')),
          isTrue,
        );
      }
    });

    test('un autre membre reste en lecture seule', () {
      final permissions = PoleManagementPermissions.resolve(
        _user('viewer', 'enacteur'),
        [_member('viewer', 'Lecteur', 'membre')],
      );
      expect(
        PoleManagementPermissions.canCreate(_user('viewer', 'enacteur')),
        isFalse,
      );
      expect(permissions.canEditPole, isFalse);
      expect(permissions.canManageOrdinaryMembers, isFalse);
      expect(permissions.canManageResponsibilities, isFalse);
    });

    test('une responsabilité locale inactive ne donne aucun droit', () {
      final permissions = PoleManagementPermissions.resolve(
        _user('local', 'enacteur'),
        [
          _member(
            'local',
            'Ancien responsable',
            'chef_pole',
            status: 'inactive',
          ),
        ],
      );
      expect(permissions.canEditPole, isFalse);
      expect(permissions.canManageOrdinaryMembers, isFalse);
      expect(permissions.canManageResponsibilities, isFalse);
    });
  });

  test(
    'le payload pôle mappe les deux types et neutralise les champs vides',
    () {
      const draft = PoleMutationDraft(
        name: '  Innovation  ',
        shortName: '  ',
        type: 'support',
        description: '',
        objectives: '  Déployer  ',
      );
      expect(draft.toJson(), {
        'name': 'Innovation',
        'short_name': null,
        'type': 'support',
        'description': null,
        'objectives': 'Déployer',
      });
      expect(PolePositionPresentation.label('chef_pole'), 'Chef de pôle');
      expect(
        PolePositionPresentation.label('adjoint_chef_pole'),
        'Adjoint du pôle',
      );
      expect(PolePositionPresentation.label('legacy'), 'Membre du pôle');
    },
  );

  group('formulaire pôle', () {
    testWidgets('le nom obligatoire bloque la création', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        PoleFormDialog(
          onSubmit: (draft) async {
            calls += 1;
            return _pole();
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pole-form-submit')));
      await tester.pump();
      expect(find.text('Le nom est obligatoire.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('création réussie transmet Pôle support sans enum visible', (
      tester,
    ) async {
      PoleMutationDraft? submitted;
      await _pump(
        tester,
        PoleFormDialog(
          onSubmit: (draft) async {
            submitted = draft;
            return _pole(name: draft.name, type: draft.type);
          },
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('pole-name-field')),
        'Innovation',
      );
      await tester.tap(find.text('Pôle cœur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pôle support').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pole-form-submit')));
      await tester.pumpAndSettle();
      expect(submitted?.name, 'Innovation');
      expect(submitted?.type, 'support');
      expect(find.text('metier'), findsNothing);
      expect(find.text('support'), findsNothing);
    });

    testWidgets('erreur conserve les données et permet de réessayer', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        PoleFormDialog(
          onSubmit: (draft) async {
            calls += 1;
            if (calls == 1) throw Exception('connexion indisponible');
            return _pole(name: draft.name);
          },
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('pole-name-field')),
        'Pôle conservé',
      );
      await tester.tap(find.byKey(const ValueKey('pole-form-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Connexion impossible'), findsOneWidget);
      expect(find.text('Pôle conservé'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pole-form-submit')));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('édition est préremplie et transmet les changements', (
      tester,
    ) async {
      PoleMutationDraft? submitted;
      await _pump(
        tester,
        PoleFormDialog(
          pole: _pole(name: 'Technique'),
          onSubmit: (draft) async {
            submitted = draft;
            return _pole(name: draft.name);
          },
        ),
      );
      expect(find.text('Technique'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pole-name-field')),
        'Technique mise à jour',
      );
      await tester.tap(find.byKey(const ValueKey('pole-form-submit')));
      await tester.pumpAndSettle();
      expect(submitted?.name, 'Technique mise à jour');
    });

    testWidgets('le double submit est bloqué pendant l’envoi', (tester) async {
      final completer = Completer<PoleModel>();
      var calls = 0;
      await _pump(
        tester,
        PoleFormDialog(
          onSubmit: (draft) {
            calls += 1;
            return completer.future;
          },
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('pole-name-field')),
        'Unique',
      );
      final submit = find.byKey(const ValueKey('pole-form-submit'));
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit, warnIfMissed: false);
      expect(calls, 1);
      completer.complete(_pole());
      await tester.pumpAndSettle();
    });
  });

  group('gestion équipe', () {
    final active = _member('active', 'Aminata Active', 'membre');
    final existing = _member('existing', 'Déjà Membre', 'membre');
    final inactive = _member(
      'inactive',
      'Compte Inactif',
      'membre',
      status: 'inactive',
    );
    final alumni = _member(
      'alumni',
      'Ancien Alumni',
      'membre',
      status: 'alumni',
      profileType: 'alumni',
    );

    testWidgets('annuaire exclut inactive et alumni et désactive déjà membre', (
      tester,
    ) async {
      await _pump(
        tester,
        PoleMemberDialog(
          poleName: 'Technique',
          directory: [active, existing, inactive, alumni],
          activeMemberships: [existing],
          onSubmit: (member) async =>
              PoleMemberMutationResult(membership: member),
        ),
      );
      expect(find.text('Aminata Active'), findsOneWidget);
      expect(find.text('Déjà Membre'), findsOneWidget);
      expect(find.text('Déjà dans l’équipe'), findsOneWidget);
      expect(find.text('Compte Inactif'), findsNothing);
      expect(find.text('Ancien Alumni'), findsNothing);
    });

    testWidgets('recherche annuaire fonctionne par nom et e-mail', (
      tester,
    ) async {
      final second = _member('second', 'Fatou Candidate', 'membre');
      await _pump(
        tester,
        PoleMemberDialog(
          poleName: 'Technique',
          directory: [active, second],
          activeMemberships: const [],
          onSubmit: (member) async =>
              PoleMemberMutationResult(membership: member),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('pole-directory-search')),
        'fatou',
      );
      await tester.pump();
      expect(find.text('Fatou Candidate'), findsOneWidget);
      expect(find.text('Aminata Active'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('pole-directory-search')),
        'active@example.test',
      );
      await tester.pump();
      expect(find.text('Aminata Active'), findsOneWidget);
    });

    testWidgets('ajout membre ne soumet qu’après sélection', (tester) async {
      MemberModel? submitted;
      await _pump(
        tester,
        PoleMemberDialog(
          poleName: 'Technique',
          directory: [active],
          activeMemberships: const [],
          onSubmit: (member) async {
            submitted = member;
            return PoleMemberMutationResult(membership: member);
          },
        ),
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('pole-member-submit')),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Aminata Active'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pole-member-submit')));
      await tester.pumpAndSettle();
      expect(submitted?.id, 'active');
    });

    testWidgets('remplacement chef explique le maintien comme membre', (
      tester,
    ) async {
      String? selected;
      await _pump(
        tester,
        PoleResponsibilityDialog(
          poleName: 'Technique',
          targetPosition: PolePositionPresentation.lead,
          currentHolder: _member('old', 'Ancien Chef', 'chef_pole'),
          directory: [active],
          onSubmit: (member) async {
            selected = member.id;
            return PoleMemberMutationResult(membership: member);
          },
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('pole-responsibility-select')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('L’ancien chef redevient membre'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('pole-responsibility-submit')),
      );
      await tester.pumpAndSettle();
      expect(selected, 'active');
    });

    testWidgets('remplacement adjoint est distinct et humanisé', (
      tester,
    ) async {
      await _pump(
        tester,
        PoleResponsibilityDialog(
          poleName: 'Technique',
          targetPosition: PolePositionPresentation.deputy,
          currentHolder: _member('old', 'Ancien Adjoint', 'adjoint_chef_pole'),
          directory: [active],
          onSubmit: (member) async =>
              PoleMemberMutationResult(membership: member),
        ),
      );
      expect(find.text('Nommer l’adjoint du pôle'), findsOneWidget);
      expect(find.text('adjoint_chef_pole'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('pole-responsibility-select')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aminata Active').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('L’ancien adjoint redevient membre'),
        findsOneWidget,
      );
    });

    testWidgets('retrait membre parle uniquement de l’équipe active', (
      tester,
    ) async {
      var removed = false;
      await _pump(
        tester,
        PoleMemberRemovalDialog(
          poleName: 'Technique',
          membership: active,
          onSubmit: () async => removed = true,
        ),
      );
      expect(
        find.text('La personne quittera l’équipe active du pôle.'),
        findsOneWidget,
      );
      expect(find.textContaining('suppression définitive'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pole-removal-submit')));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('retrait responsable exige confirmation renforcée', (
      tester,
    ) async {
      await _pump(
        tester,
        PoleMemberRemovalDialog(
          poleName: 'Technique',
          membership: _member('lead', 'Chef', 'chef_pole'),
          onSubmit: () async {},
        ),
      );
      expect(
        find.text('Aucun remplacement automatique ne sera effectué.'),
        findsOneWidget,
      );
      var button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('pole-removal-submit')),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('pole-removal-submit')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('section locale masque nominations et retraits responsables', (
      tester,
    ) async {
      const permissions = PoleManagementPermissions(
        isGlobalManager: false,
        isLocalManager: true,
      );
      await _pump(
        tester,
        PoleTeamManagementSection(
          poleName: 'Technique',
          members: [
            _member('lead', 'Chef', 'chef_pole'),
            _member('ordinary', 'Membre Ordinaire', 'membre'),
          ],
          unavailable: false,
          permissions: permissions,
          onAddMember: () {},
          onRemoveMember: (_) {},
        ),
      );
      expect(find.text('Ajouter ou réintégrer'), findsOneWidget);
      expect(find.text('Remplacer'), findsNothing);
      expect(
        find.byTooltip('Retirer Membre Ordinaire de l’équipe'),
        findsOneWidget,
      );
      expect(find.byTooltip('Retirer Chef de l’équipe'), findsNothing);
    });
  });

  testWidgets('gestion Pôles reste sans overflow à 390 px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      SingleChildScrollView(
        child: PoleTeamManagementSection(
          poleName: 'Technique',
          members: [
            _member('lead', 'Chef', 'chef_pole'),
            _member('deputy', 'Adjoint', 'adjoint_chef_pole'),
            _member('member', 'Membre', 'membre'),
          ],
          unavailable: false,
          permissions: const PoleManagementPermissions(
            isGlobalManager: true,
            isLocalManager: false,
          ),
          onAddMember: () {},
          onChangeLead: () {},
          onChangeDeputy: () {},
          onRemoveMember: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('écrans intégrés utilisent uniquement le gateway mémoire', (
    tester,
  ) async {
    final gateway = _ManagementGateway();
    await _pump(tester, PolesPortfolioScreen(gateway: gateway));
    await tester.pumpAndSettle();
    expect(find.text('Créer un pôle'), findsOneWidget);
    expect(gateway.realCreateRequests, 0);
    expect(gateway.realPatchRequests, 0);
    expect(gateway.realMemberPostRequests, 0);
    expect(gateway.realMemberDeleteRequests, 0);

    await _pump(
      tester,
      PoleDetailScreen(
        poleId: 'pole',
        gateway: gateway,
        initialItem: gateway.item,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Modifier le pôle'), findsOneWidget);
    expect(find.text('chef_pole'), findsNothing);
    expect(find.text('adjoint_chef_pole'), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  ),
);

UserExperience _user(String id, String role) => UserExperience.fromJson({
  'id': id,
  'email': '$id@example.test',
  'first_name': id,
  'status': 'active',
  'roles': [role],
});

PoleModel _pole({String name = 'Technique', String type = 'metier'}) =>
    PoleModel.fromJson({
      'id': 'pole',
      'name': name,
      'short_name': 'TECH',
      'type': type,
      'description': 'Description',
      'objectives': 'Objectifs',
      'created_at': '2026-01-01T00:00:00',
    });

MemberModel _member(
  String id,
  String name,
  String position, {
  String status = 'active',
  String profileType = 'enacteur',
}) => MemberModel.fromJson({
  'id': id,
  'email': '$id@example.test',
  'full_name': name,
  'status': status,
  'profile_type': profileType,
  'is_active': status == 'active',
  'pole_position': position,
});

class _ManagementGateway implements PolesPortfolioGateway {
  final members = <MemberModel>[
    _member('global', 'Admin Global', 'chef_pole'),
    _member('deputy', 'Adjoint', 'adjoint_chef_pole'),
    _member('member', 'Membre', 'membre'),
  ];
  int realCreateRequests = 0;
  int realPatchRequests = 0;
  int realMemberPostRequests = 0;
  int realMemberDeleteRequests = 0;

  PolePortfolioItem get item => PolePortfolioItem(
    pole: _pole(),
    members: members,
    tasks: const [],
    nextAction: null,
    membersUnavailable: false,
    tasksUnavailable: false,
  );

  @override
  Future<UserExperience> loadCurrentUser() async =>
      _user('global', 'administrateur');

  @override
  Future<List<PoleModel>> loadPoles() async => [_pole()];

  @override
  Future<List<MemberModel>> loadMembers(String poleId) async => members;

  @override
  Future<List<MemberModel>> loadMemberDirectory() async => members;

  @override
  Future<List<TaskModel>> loadTasks(String poleId) async => const [];

  @override
  Future<List<PoleAssignee>> loadTaskAssignees(String taskId) async => const [];

  @override
  Future<List<DocumentModel>> loadDocuments(String poleId) async => const [];

  @override
  Future<List<PostModel>> loadPosts(String poleId) async => const [];

  @override
  Future<List<EventModel>> loadEvents() async => const [];

  @override
  Future<PoleModel> createPole(PoleMutationDraft draft) async {
    return _pole(name: draft.name, type: draft.type);
  }

  @override
  Future<PoleModel> updatePole(String poleId, PoleMutationDraft draft) async {
    return _pole(name: draft.name, type: draft.type);
  }

  @override
  Future<PoleMemberMutationResult> assignPoleMember({
    required String poleId,
    required String userId,
    required String position,
  }) async =>
      PoleMemberMutationResult(membership: _member(userId, userId, position));

  @override
  Future<void> removePoleMember({
    required String poleId,
    required String userId,
  }) async {}
}
