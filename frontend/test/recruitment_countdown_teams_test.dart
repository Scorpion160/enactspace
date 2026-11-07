import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/services/recruitment_campaign_tools.dart';
import 'package:frontend/features/recruitment/widgets/public/recruitment_countdown.dart';
import 'package:frontend/features/recruitment/widgets/public/public_recruitment_widgets.dart';
import 'package:frontend/features/recruitment/widgets/internal/jury_teams_section.dart';
import 'package:frontend/features/recruitment/widgets/internal/interview_planning_dialog.dart';

const campaign = RecruitmentCampaignModel(
  id: 'campaign',
  title: 'Rejoindre Enactus ESP',
  startDate: '2026-11-04',
  endDate: '2026-11-08',
  isActive: true,
);
const candidate = ApplicationModel(
  id: 'candidate',
  campaignId: 'campaign',
  firstName: 'Awa',
  lastName: 'Test',
  email: 'fixture@example.org',
  status: 'under_review',
  isAnonymized: false,
  canConvert: false,
);

class _TeamTools implements RecruitmentCampaignTools {
  final members = <Map<String, dynamic>>[
    {'id': 'm1', 'name': 'Enacteur Test', 'active': true},
    {'id': 'm2', 'name': 'Alumni Test', 'active': true},
  ];
  final teams = <Map<String, dynamic>>[];
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>> loadJury(String campaignId) async => {
    'members': members,
    'teams': teams,
  };
  @override
  Future<Map<String, dynamic>> saveJuryTeam(
    String campaignId,
    Map<String, dynamic> body, {
    String? teamId,
  }) async {
    saved = body;
    final team = <String, dynamic>{
      ...body,
      'id': teamId ?? 'team-1',
      'revision': 1,
      'available': true,
      'members': members
          .where((row) => (body['member_ids'] as List).contains(row['id']))
          .toList(),
      'interviews': <Map<String, dynamic>>[],
    };
    teams.add(team);
    return team;
  }

  @override
  Future<ApplicationModel> scheduleWithJury(
    String id,
    Map<String, dynamic> body,
  ) async {
    saved = body;
    return candidate;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected fixture call: ${invocation.memberName}');
}

void main() {
  test('Dakar opening and inclusive last day use explicit UTC instants', () {
    expect(campaign.openingInstant, DateTime.utc(2026, 11, 4));
    expect(campaign.closingInstant, DateTime.utc(2026, 11, 9));
    expect(campaign.isOpenAt(DateTime.utc(2026, 11, 3, 23, 59, 59)), isFalse);
    expect(campaign.isOpenAt(DateTime.utc(2026, 11, 4)), isTrue);
    expect(campaign.isOpenAt(DateTime.utc(2026, 11, 8, 23, 59, 59)), isTrue);
    expect(campaign.isOpenAt(DateTime.utc(2026, 11, 9)), isFalse);
  });
  test('server time anchors the display even when the local date differs', () {
    final value = RecruitmentCampaignModel.fromJson({
      'id': 'c',
      'title': 'Fixture',
      'is_active': true,
      'start_date': '2026-11-04',
      'server_time': '2026-10-31T18:00:00Z',
    });
    expect(
      value.currentTime.difference(DateTime.utc(2026, 10, 31, 18)).inSeconds,
      lessThan(5),
    );
    expect(value.isOpenAt(value.currentTime), isFalse);
  });
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('countdown fits width=$width text=$scale dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RecruitmentCountdown(
                      campaign: campaign,
                      now: DateTime.utc(2026, 10, 31, 18, 2, 3),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Jours'), findsOneWidget);
          expect(find.text('Heures'), findsOneWidget);
          expect(find.text('Minutes'), findsOneWidget);
          expect(find.text('Secondes'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'card switches at opening and closure without early access and cancels its timer',
    (tester) async {
      var now = DateTime.utc(2026, 11, 3, 23, 59, 59);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CampaignPublicCard(
                campaign: campaign,
                actionKey: const ValueKey('apply'),
                now: () => now,
                onStart: () => starts++,
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply')))
            .onPressed,
        isNull,
      );
      now = DateTime.utc(2026, 11, 4);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('apply')));
      expect(starts, 1);
      now = DateTime.utc(2026, 11, 9);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply')))
            .onPressed,
        isNull,
      );
      expect(find.text('Inscriptions clôturées'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unique jury preselects every available juror and read-only view hides editing',
    (tester) async {
      final tools = _TeamTools();
      Widget page(bool manager) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JuryTeamsSection(
              campaignId: 'campaign',
              teams: tools.teams,
              members: tools.members,
              canManage: manager,
              tools: tools,
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.tap(find.text('Réunir tout le jury'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((row) => row.value == true),
        isTrue,
      );
      await tester.tap(find.text('Enregistrer l’équipe'));
      await tester.pumpAndSettle();
      expect(tools.saved!['member_ids'], containsAll(['m1', 'm2']));
      expect(tools.saved!['name'], 'Jury unique');
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(find.text('Créer une équipe'), findsNothing);
      expect(find.text('Réunir tout le jury'), findsNothing);
      expect(find.text('Jury unique'), findsOneWidget);
    },
  );
  testWidgets(
    'planning chooses a saved team with its revision instead of a custom list',
    (tester) async {
      final tools = _TeamTools();
      tools.teams.add({
        'id': 't1',
        'name': 'Équipe A',
        'active': true,
        'available': true,
        'revision': 3,
        'members': tools.members,
        'interviews': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InterviewPlanningDialog(
              application: candidate,
              tools: tools,
              onSaved: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '20/11/2026');
      await tester.enterText(find.byType(TextFormField).at(3), 'Salle fictive');
      final dropdown = find.byKey(const ValueKey('interview-team-'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Équipe A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer l’entretien'));
      await tester.pumpAndSettle();
      expect(tools.saved!['jury_team_id'], 't1');
      expect(tools.saved!['jury_team_revision'], 3);
      expect(tools.saved!.containsKey('jury_member_ids'), isFalse);
    },
  );
}
