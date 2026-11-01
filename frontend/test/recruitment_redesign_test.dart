import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/screens/internal/campaign_management_screen.dart';
import 'package:frontend/features/recruitment/screens/internal/internal_recruitment_screen.dart';
import 'package:frontend/features/recruitment/screens/internal/recruitment_jury_screen.dart';
import 'package:frontend/features/recruitment/widgets/internal/campaign_management_widgets.dart';
import 'support/recruitment_redesign_fixture.dart';

Future<void> pumpRedesign(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapRedesign(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final dark in [false, true]) {
    for (final size in [(320.0, 1.0), (390.0, 2.0), (1440.0, 1.0)]) {
      testWidgets('redesign responsive ${size.$1} text=${size.$2} dark=$dark', (
        tester,
      ) async {
        final gateway = RedesignGateway();
        for (final page in <Widget>[
          InternalRecruitmentScreen(gateway: gateway),
          CampaignManagementScreen(
            gateway: gateway,
            now: DateTime.utc(2026, 11, 1),
          ),
          RecruitmentJuryScreen(
            tools: gateway.campaignTools,
            campaigns: gateway.campaigns,
          ),
        ]) {
          await pumpRedesign(
            tester,
            page,
            width: size.$1,
            dark: dark,
            scale: size.$2,
          );
          expect(tester.takeException(), isNull);
          expect(gateway.writes, 0);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
  testWidgets(
    'campaign card expands the entire description without a fixed height',
    (tester) async {
      await pumpRedesign(
        tester,
        CampaignManagementScreen(
          gateway: RedesignGateway(),
          now: DateTime.utc(2026, 11, 1),
        ),
        width: 1440,
      );
      final card = find.byType(CampaignManagementCard);
      final before = tester.getSize(card).height;
      await tapRedesign(tester, find.text('Lire la suite'));
      expect(
        find.widgetWithText(SelectableText, redesignDescription),
        findsOneWidget,
      );
      expect(tester.getSize(card).height, greaterThan(before));
      await tapRedesign(tester, find.text('Réduire'));
      expect(tester.getSize(card).height, closeTo(before, 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('anonymity hides names and prevents hidden-name searches', (
    tester,
  ) async {
    await pumpRedesign(
      tester,
      InternalRecruitmentScreen(gateway: RedesignGateway()),
    );
    await tapRedesign(tester, find.byKey(const Key('internal-anonymized')));
    expect(find.text('Awa Diop'), findsNothing);
    await tester.enterText(find.byKey(const Key('internal-search')), 'Awa');
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('internal-search')),
      'REC-FIXTURE-1',
    );
    await tester.pumpAndSettle();
    expect(find.text('1–1 sur 1 candidatures'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('visible candidates sort by surname then first name', (
    tester,
  ) async {
    await pumpRedesign(
      tester,
      InternalRecruitmentScreen(gateway: RedesignGateway()),
    );
    expect(
      tester.getTopLeft(find.text('Moussa Ba')).dy,
      lessThan(tester.getTopLeft(find.text('Awa Diop')).dy),
    );
  });
  testWidgets(
    'workspace navigation opens the actual campaign screen and returns to interviews',
    (tester) async {
      final gateway = RedesignGateway();
      await pumpRedesign(tester, InternalRecruitmentScreen(gateway: gateway));
      await tapRedesign(
        tester,
        find.byKey(const ValueKey('recruitment-nav-campaigns')),
      );
      expect(find.byType(CampaignManagementScreen), findsOneWidget);
      await tapRedesign(
        tester,
        find.byKey(const ValueKey('recruitment-nav-interviews')),
      );
      expect(find.text('Planning des entretiens'), findsOneWidget);
      expect(gateway.writes, 0);
    },
  );
  testWidgets('a selected reviewer has no campaign-management entry', (
    tester,
  ) async {
    await pumpRedesign(
      tester,
      InternalRecruitmentScreen(gateway: RedesignGateway(canManage: false)),
    );
    expect(
      find.byKey(const ValueKey('recruitment-nav-campaigns')),
      findsNothing,
    );
    expect(find.byKey(const Key('manage-campaigns')), findsNothing);
  });
  testWidgets(
    'campaign tabs preserve draft and preview the actual custom questions',
    (tester) async {
      final gateway = RedesignGateway();
      await pumpRedesign(tester, CampaignManagementScreen(gateway: gateway));
      await tapRedesign(tester, find.byKey(const Key('create-campaign')));
      await tester.enterText(
        find.byKey(const Key('campaign-title')),
        'Une nouvelle génération',
      );
      await tapRedesign(
        tester,
        find.widgetWithText(ChoiceChip, 'Questionnaire'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('question-label-personality')),
        'Raconte un apprentissage concret.',
      );
      await tapRedesign(
        tester,
        find.widgetWithText(ChoiceChip, 'Aperçu candidat'),
      );
      expect(find.text('Une nouvelle génération'), findsOneWidget);
      expect(
        find.textContaining('Raconte un apprentissage concret.'),
        findsOneWidget,
      );
      await tapRedesign(
        tester,
        find.widgetWithText(ChoiceChip, 'Informations'),
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('campaign-title')))
            .controller!
            .text,
        'Une nouvelle génération',
      );
      expect(gateway.writes, 0);
      await tapRedesign(tester, find.byKey(const Key('campaign-form-submit')));
      expect(gateway.writes, 1);
      expect(
        gateway.savedQuestions!.first['label'],
        'Raconte un apprentissage concret.',
      );
    },
  );
}
