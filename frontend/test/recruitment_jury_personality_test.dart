import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/screens/internal/recruitment_jury_screen.dart';
import 'package:frontend/features/recruitment/screens/public/personality_questionnaire_screen.dart';
import 'package:frontend/features/recruitment/services/recruitment_campaign_tools.dart';
import 'package:frontend/features/recruitment/widgets/internal/interview_planning_dialog.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_internal_widgets.dart';

class _Questionnaire implements PublicPersonalityGateway {
  bool failSave = false;
  final List<Map<String, dynamic>> writes = [];
  Map<String, dynamic> state = {
    'status': 'invited',
    'version': 'fixture-v1',
    'revision': 0,
    'answers': <String, int>{},
    'scenario_answers': <String, String>{},
    'instrument': {
      'notice':
          'Questionnaire de préparation : réponses privées jusqu’à leur confirmation.',
      'items': [
        for (var index = 1; index <= 20; index++)
          {'id': 'q$index', 'label': 'Affirmation $index'},
      ],
      'scale': ['Pas du tout', 'Peu', 'Un peu', 'Assez', 'Tout à fait'],
      'scenarios': [
        for (var index = 1; index <= 5; index++)
          {
            'id': 's$index',
            'title': 'Situation $index',
            'question': 'Comment réagirais-tu dans cette situation ?',
          },
      ],
    },
  };
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> body,
  ) async {
    if (action == 'load') return Map<String, dynamic>.from(state);
    if (failSave) {
      throw ApiException(
        statusCode: 503,
        message: 'La connexion a été interrompue. Réessaie.',
      );
    }
    writes.add(Map<String, dynamic>.from(body));
    state = {
      ...state,
      'revision': (state['revision'] as int) + 1,
      'answers': Map<String, int>.from(body['answers'] as Map? ?? const {}),
      'scenario_answers': Map<String, String>.from(
        body['scenario_answers'] as Map? ?? const {},
      ),
    };
    return Map<String, dynamic>.from(state);
  }
}

class _Tools implements RecruitmentCampaignTools {
  bool appointed = true;
  Map<String, dynamic>? saved;
  final List<Map<String, dynamic>> teams = [];
  @override
  Future<Map<String, dynamic>> saveJuryTeam(
    String campaignId,
    Map<String, dynamic> body, {
    String? teamId,
  }) async {
    final team = {
      'id': teamId ?? 'team-${teams.length}',
      'name': body['name'],
      'revision': 1,
      'active': body['active'],
      'available': true,
      'members': [
        {'id': 'member-1', 'name': 'Alumni Test', 'active': true},
      ],
      'interviews': <Map<String, dynamic>>[],
    };
    teams.add(team);
    return team;
  }

  @override
  Future<Map<String, dynamic>> loadAccess() async => {'can_manage_jury': true};
  @override
  Future<Map<String, dynamic>> loadJury(String campaignId) async => {
    'can_manage': true,
    'teams': teams,
    'members': [
      {
        'id': 'member-1',
        'user_id': 'alumni-1',
        'name': 'Alumni Test',
        'status': 'alumni',
        'appointed': appointed,
        'active': appointed,
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> eligibleJury(
    String campaignId,
    String search,
  ) async => [
    {'id': 'alumni-1', 'name': 'Alumni Test', 'status': 'alumni'},
  ];
  @override
  Future<void> appointJury(String campaignId, String userId) async {
    appointed = true;
  }

  @override
  Future<Map<String, dynamic>> revokeJury(
    String campaignId,
    String memberId,
  ) async {
    appointed = false;
    return {
      'interviews_to_reassign': ['application-1'],
    };
  }

  @override
  Future<Map<String, dynamic>> loadPersonality(String applicationId) async => {
    'status': 'not_invited',
  };
  @override
  Future<void> invitePersonality(String applicationId, DateTime? dueAt) async {}
  @override
  Future<ApplicationModel> scheduleWithJury(
    String applicationId,
    Map<String, dynamic> appointment,
  ) async {
    saved = appointment;
    return _application;
  }
}

const _application = ApplicationModel(
  id: 'application-1',
  campaignId: 'campaign-1',
  firstName: 'Awa',
  lastName: 'Test',
  email: 'fixture@example.org',
  status: 'under_review',
  isAnonymized: false,
  canConvert: false,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'campus false remains distinct from missing data and interview uses Dakar UTC',
    () {
      final model = ApplicationModel.fromJson({
        'id': 'application-1',
        'campaign_id': 'campaign-1',
        'campus_resident': false,
        'interview_at': '2026-11-16T19:00:00',
        'interview_end_at': '2026-11-16T19:30:00Z',
        'interview_preferences': ['online'],
      });
      expect(model.campusResident, isFalse);
      expect(model.interviewAt, DateTime.utc(2026, 11, 16, 19));
      expect(model.interviewEndAt, DateTime.utc(2026, 11, 16, 19, 30));
      expect(model.interviewLabel, contains('19:00 · Dakar'));
    },
  );

  test(
    'alumni jury route depends on server permission and grants no management role',
    () {
      UserExperience user(bool allowed) => UserExperience(
        id: 'alumni-1',
        email: 'fixture@example.org',
        displayName: 'Alumni Test',
        status: 'alumni',
        gender: null,
        profileType: 'alumni',
        roles: const {'alumni'},
        canReviewJoinRequests: false,
        canAccessRecruitment: allowed,
      );
      expect(
        UserExperience.visibleRoutesFor(user(true)),
        contains('/recruitment'),
      );
      expect(
        UserExperience.visibleRoutesFor(user(false)),
        isNot(contains('/recruitment')),
      );
      expect(user(true).canManageMembers, isFalse);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'questionnaire remains readable at 320 pixels, text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = _Questionnaire();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: scale == 2 ? Brightness.dark : Brightness.light,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: PersonalityQuestionnaireScreen(
              code: 'fixture-code',
              email: 'fixture@example.org',
              gateway: gateway,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Tout à fait').first);
        expect(tester.takeException(), isNull);
        await _tap(tester, find.text('Enregistrer pour plus tard'));
        expect(
          gateway.writes,
          isEmpty,
        ); // Consent is required before persisting.
        expect(
          find.text(
            'Prends connaissance de l’utilisation des réponses avant de continuer.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'failed save keeps selection and a successful retry persists credentials in body',
    (tester) async {
      final gateway = _Questionnaire()..failSave = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalityQuestionnaireScreen(
            code: 'fixture-code',
            email: 'fixture@example.org',
            gateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byType(CheckboxListTile));
      await _tap(tester, find.text('Tout à fait').first);
      await _tap(tester, find.text('Enregistrer pour plus tard'));
      expect(gateway.writes, isEmpty);
      final selected = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((chip) => chip.selected);
      expect(selected, hasLength(1));
      gateway.failSave = false;
      await _tap(tester, find.text('Enregistrer pour plus tard'));
      expect(gateway.writes.single['application_id'], 'fixture-code');
      expect(gateway.writes.single['answers'], {'q1': 5});
      expect(gateway.writes.single['email'], 'fixture@example.org');
    },
  );

  testWidgets('saved answers reappear on reopening without a new submission', (
    tester,
  ) async {
    final gateway = _Questionnaire();
    gateway.state['answers'] = {'q1': 4};
    gateway.state['revision'] = 2;
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalityQuestionnaireScreen(
          code: 'fixture-code',
          email: 'fixture@example.org',
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .where((chip) => chip.selected),
      hasLength(1),
    );
    expect(gateway.writes, isEmpty);
  });

  testWidgets(
    'jury removal needs confirmation and reports interviews to reassign',
    (tester) async {
      final tools = _Tools();
      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentJuryScreen(
            tools: tools,
            campaigns: const [
              RecruitmentCampaignModel(
                id: 'campaign-1',
                title: 'Campagne Test',
                isActive: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Retirer du jury'));
      expect(tools.appointed, isTrue);
      await _tap(tester, find.text('Retirer du jury').last);
      expect(tools.appointed, isFalse);
      expect(
        find.textContaining('1 entretien(s) à réattribuer'),
        findsOneWidget,
      );
      await _tap(tester, find.byTooltip('Ajouter au jury'));
      expect(tools.appointed, isTrue);
    },
  );

  testWidgets(
    'an evening online appointment includes an actual jury and UTC interval',
    (tester) async {
      final tools = _Tools();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => InterviewPlanningDialog(
                    application: _application,
                    tools: tools,
                    onSaved: (_) {},
                  ),
                ),
                child: const Text('Planifier'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Planifier'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Date *'),
        '16/11/2026',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Heure de Dakar *'),
        '19:00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Durée en minutes *'),
        '30',
      );
      await _tap(tester, find.byType(DropdownButtonFormField<String>));
      await _tap(tester, find.text('En ligne').last);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lien de l’entretien *'),
        'https://example.org/meeting',
      );
      await _tap(tester, find.text('Alumni Test'));
      await _tap(tester, find.text('Confirmer l’entretien'));
      expect(tools.saved?['interview_at'], '2026-11-16T19:00:00.000Z');
      expect(tools.saved?['interview_end_at'], '2026-11-16T19:30:00.000Z');
      expect(tools.saved?['jury_member_ids'], ['member-1']);
      expect(tools.saved?['interview_location'], isNull);
    },
  );

  testWidgets('jury view hides campaign management controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InternalRecruitmentHeader(
            campaignLabel: 'Campagne Test',
            visibleCount: 1,
            totalCount: 1,
            activeFilterCount: 0,
            onRefresh: () {},
            onToggleFilters: () {},
            onManageCampaigns: () {},
            canManageCampaigns: false,
          ),
        ),
      ),
    );
    expect(find.text('Gérer les campagnes'), findsNothing);
  });
}
