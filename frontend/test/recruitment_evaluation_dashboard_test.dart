import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/screens/recruitment_statistics_screen.dart';

class _StatsFake implements RecruitmentStatisticsGateway {
  _StatsFake({required this.maySeeDetails});

  final bool maySeeDetails;
  String? lastRequestedCampaign;

  @override
  Future<Map<String, dynamic>> fetch({String? campaignId}) async {
    lastRequestedCampaign = campaignId;
    return {
      'campaigns': [
        {'id': 'campaign-a', 'title': 'Campagne A'},
        {'id': 'campaign-b', 'title': 'Campagne B'},
      ],
      'campaign_id': campaignId ?? 'campaign-a',
      'can_access_applications': maySeeDetails,
      'total': campaignId == 'campaign-b' ? 0 : 95,
      'breakdowns': {
        'department': [
          {'label': 'Gestion', 'count': 25, 'percentage': 26.3},
        ],
      },
      'evaluation': {
        'minimum_reviews': 3,
        'overview': {
          'applications': campaignId == 'campaign-b' ? 0 : 95,
          'reviews': campaignId == 'campaign-b' ? 0 : 301,
          'scored_reviews': campaignId == 'campaign-b' ? 0 : 301,
          'completed': campaignId == 'campaign-b' ? 0 : 95,
          'completed_percentage': campaignId == 'campaign-b' ? 0.0 : 100.0,
          'missing_reviews': 0,
          'beyond_minimum': 16,
          'average_reviews': 3.17,
          'reviewers': 14,
          'distribution': [
            {'label': '3', 'count': 81},
          ],
        },
        'scoring': {
          'candidate_average': campaignId == 'campaign-b' ? null : 13.02,
          'review_average': 13.01,
          'median': 13.75,
          'lowest': 0.0,
          'highest': 18.33,
          'lower_quarter': 10.83,
          'upper_quarter': 16.0,
          'top_tenth_threshold': 16.67,
          'at_least_14': 47,
          'at_least_16': 27,
          'below_10': 17,
          'score_bands': [
            {'label': 'De 16 à moins de 18', 'count': 24},
          ],
        },
        'disagreements': {
          'sensitive_total': 31,
          'spread_ge_5': 29,
          'opposite_opinions': 9,
          'mixed_recommendations': 71,
          'max_spread': 14.0,
          'spread_ge_3': 65,
          'spread_ge_4': 43,
          'spread_ge_6': 20,
        },
        'recommendations': {
          'votes': {'favorable': 141, 'reserve': 118, 'defavorable': 42},
          'majority': {
            'favorable': 46,
            'reserve': 31,
            'defavorable': 10,
            'egalite': 8,
          },
        },
        'groups': {
          'department': [
            {
              'label': 'Gestion',
              'count': 25,
              'completed': 25,
              'average': 13.08,
              'at_least_14': 13,
              'high_disagreement': 7,
            },
          ],
          'study_level': <Map<String, dynamic>>[],
          'gender': <Map<String, dynamic>>[],
        },
        'statuses': {'under_review': 95},
        'missing_fields': {'phone': 0},
        'daily': [
          {'date': '2026-11-12', 'applications': 0, 'reviews': 3},
        ],
        'reviewer_workload': {
          'average': 21.5,
          'highest': 54,
          'lowest': 2,
          'top_three_percentage': 44.9,
        },
        'interviews_scheduled': 0,
        'converted_users': 0,
      },
    };
  }
}

void main() {
  testWidgets('recruitment staff see the report with comprehensible labels', (
    tester,
  ) async {
    final fake = _StatsFake(maySeeDetails: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentStatisticsScreen(gateway: fake)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Étude des dossiers'), findsOneWidget);
    expect(find.text('95 / 95'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
    expect(find.text('13,02/20'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('Note au milieu du classement'), findsOneWidget);
    expect(find.text('Dossiers ayant au moins 3 notes'), findsOneWidget);
  });

  testWidgets('detailed assessment is not rendered to other members', (
    tester,
  ) async {
    final fake = _StatsFake(maySeeDetails: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentStatisticsScreen(gateway: fake)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('95'), findsOneWidget);
    expect(find.text('Étude des dossiers'), findsNothing);
    expect(find.text('13,02/20'), findsNothing);
    expect(find.text('31'), findsNothing);
  });

  testWidgets('a future empty campaign does not show historical averages', (
    tester,
  ) async {
    final fake = _StatsFake(maySeeDetails: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentStatisticsScreen(gateway: fake)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Campagne B').last);
    await tester.pumpAndSettle();
    expect(fake.lastRequestedCampaign, 'campaign-b');
    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.text('13,02/20'), findsNothing);
  });

  testWidgets('dashboard fits a narrow mobile width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = _StatsFake(maySeeDetails: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentStatisticsScreen(gateway: fake)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('95 / 95'), findsOneWidget);
  });
}
