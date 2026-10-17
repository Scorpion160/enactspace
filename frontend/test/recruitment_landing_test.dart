import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/services/public_recruitment_gateway.dart';
import 'package:frontend/features/recruitment/screens/public/public_recruitment_campaigns_screen.dart';

const _campaign = RecruitmentCampaignModel(id: 'landing-test', title: 'Une campagne de test',
  startDate: '2026-10-16', endDate: '2026-10-29', isActive: true);

class _LandingGateway implements PublicRecruitmentGateway {
  final List<RecruitmentCampaignModel> campaigns;
  _LandingGateway(this.campaigns);
  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() async => campaigns;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('landing fits $width scale=$scale dark=$dark and finds campaigns before stories', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
              child: child!),
            home: PublicRecruitmentCampaignsScreen(gateway: _LandingGateway([_campaign])),
          ));
          await tester.pumpAndSettle();
          final discover = find.byKey(const ValueKey('discover-campaigns'));
          await tester.ensureVisible(discover);
          await tester.tap(discover);
          await tester.pumpAndSettle();
          final heading = find.text('Les candidatures ouvertes');
          expect(tester.getTopLeft(heading).dy, greaterThanOrEqualTo(0));
          expect(tester.getTopLeft(heading).dy, lessThan(300));
          expect(tester.getTopLeft(find.text(_campaign.title)).dy,
            lessThan(tester.getTopLeft(find.text('Une équipe, des idées, des actions.')).dy));
          expect(find.textContaining('29 octobre 2026'), findsWidgets);
          expect(find.text('Retour à la connexion'), findsNothing);
          final faq = find.widgetWithText(ExpansionTile, 'Comment mon dossier est-il étudié ?');
          await tester.ensureVisible(faq);
          await tester.tap(faq);
          await tester.pumpAndSettle();
          expect(find.textContaining('Le jury regarde cinq critères'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('closed recruitment never offers a start action and retains tracking', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PublicRecruitmentCampaignsScreen(gateway: _LandingGateway([]))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('discover-campaigns')), findsNothing);
    expect(find.text('Commencer ma candidature'), findsNothing);
    expect(find.text('Suivre ma candidature'), findsOneWidget);
    expect(find.text('Aucune campagne n’est ouverte pour le moment'), findsOneWidget);
  });
  testWidgets('start and tracking keep their actual public routes', (tester) async {
    final router = GoRouter(initialLocation: '/recruitment/apply', routes: [
      GoRoute(path: '/recruitment/apply', builder: (context, state) => PublicRecruitmentCampaignsScreen(gateway: _LandingGateway([_campaign]))),
      GoRoute(path: '/recruitment/apply/landing-test', builder: (context, state) => const Scaffold(body: Text('Formulaire ouvert'))),
      GoRoute(path: '/application-tracking', builder: (context, state) => const Scaffold(body: Text('Suivi ouvert'))),
      GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('Connexion'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final start = find.widgetWithText(FilledButton, 'Commencer ma candidature');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Formulaire ouvert'), findsOneWidget);
    router.go('/recruitment/apply');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivre ma candidature'));
    await tester.pumpAndSettle();
    expect(find.text('Suivi ouvert'), findsOneWidget);
  });
}
