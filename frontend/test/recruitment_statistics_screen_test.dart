import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/recruitment/screens/recruitment_statistics_screen.dart';

class _StatisticsFake implements RecruitmentStatisticsGateway {
  int calls = 0;
  String? lastCampaignId;

  @override
  Future<Map<String, dynamic>> fetch({String? campaignId}) async {
    calls++;
    lastCampaignId = campaignId;
    return {
      'campaigns': [
        {'id': 'campaign-1', 'title': 'Recrutement Enactus ESP 2026–2027'},
        {'id': 'campaign-2', 'title': 'Campagne précédente'},
      ],
      'campaign_id': campaignId ?? 'campaign-1',
      'can_access_applications': false,
      'total': 17,
      'breakdowns': {
        'department': [
          {'label': 'Génie électrique', 'count': 7, 'percentage': 41.2},
          {'label': 'Génie mécanique', 'count': 4, 'percentage': 23.5},
        ],
        'study_year': [
          {'label': '2e année', 'count': 9, 'percentage': 52.9},
        ],
        'study_level': [
          {'label': 'DIC2', 'count': 6, 'percentage': 35.3},
        ],
        'discovery_channel': [
          {'label': 'Réseaux sociaux', 'count': 11, 'percentage': 64.7},
        ],
        'promotion': [
          {'label': '2026-2027', 'count': 17, 'percentage': 100.0},
        ],
      },
    };
  }
}

void main() {
  testWidgets('statistics shows total and departments without dossiers', (
    tester,
  ) async {
    final gateway = _StatisticsFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentStatisticsScreen(gateway: gateway)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('La campagne en chiffres'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);
    expect(find.text('Candidatures reçues'), findsOneWidget);
    expect(find.text('Par département et filière'), findsOneWidget);
    expect(find.text('Génie électrique'), findsOneWidget);
    expect(find.text('7 · 41.2 %'), findsOneWidget);
    expect(find.byKey(const Key('statistics-open-applications')), findsNothing);
    expect(gateway.calls, 1);
  });

  testWidgets('every participant can refresh the anonymous campaign', (
    tester,
  ) async {
    final gateway = _StatisticsFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecruitmentStatisticsScreen(gateway: gateway)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actualiser les chiffres'));
    await tester.pumpAndSettle();
    expect(gateway.calls, 2);
    expect(gateway.lastCampaignId, 'campaign-1');
  });

  test(
    'all active members and alumni can see statistics without jury access',
    () {
      const enacteur = UserExperience(
        id: 'enacteur-1',
        email: 'enacteur@example.test',
        displayName: 'Enacteur Test',
        status: 'active',
        gender: null,
        profileType: 'enacteur',
        roles: {},
        canReviewJoinRequests: false,
      );
      const alumni = UserExperience(
        id: 'alumni-1',
        email: 'alumni@example.test',
        displayName: 'Alumni Test',
        status: 'alumni',
        gender: null,
        profileType: 'alumni',
        roles: {'alumni'},
        canReviewJoinRequests: false,
      );
      for (final user in [enacteur, alumni]) {
        expect(
          UserExperience.visibleRoutesFor(user),
          contains('/recruitment/statistics'),
        );
        expect(
          UserExperience.canAccessPath(user, '/recruitment/statistics'),
          isTrue,
        );
        expect(UserExperience.canAccessPath(user, '/recruitment'), isFalse);
      }
    },
  );
}
