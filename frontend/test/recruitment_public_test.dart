import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/app_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_status_presentation.dart';
import 'package:frontend/features/recruitment/models/application_tracking_model.dart';
import 'package:frontend/features/recruitment/models/public_application_draft.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/screens/application_tracking_screen.dart';
import 'package:frontend/features/recruitment/screens/public/public_application_flow_screen.dart';
import 'package:frontend/features/recruitment/screens/public/public_recruitment_campaigns_screen.dart';
import 'package:frontend/features/recruitment/services/public_recruitment_gateway.dart';

const _campaign = RecruitmentCampaignModel(
  id: 'campaign-open',
  title: 'Campagne publique synthétique',
  description: 'Une campagne destinée uniquement aux tests widgets.',
  startDate: '2026-08-01',
  endDate: '2026-09-30',
  isActive: true,
);

class _FakeGateway implements PublicRecruitmentGateway {
  final Future<List<RecruitmentCampaignModel>> Function()? campaigns;
  final Future<ApplicationModel> Function(PublicApplicationDraft)? submit;
  final Future<ApplicationTrackingModel> Function(String, String)? track;
  PublicApplicationDraft? lastDraft;

  _FakeGateway({this.campaigns, this.submit, this.track});

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      campaigns?.call() ?? Future.value(const [_campaign]);

  @override
  Future<ApplicationModel> submitApplication(PublicApplicationDraft draft) {
    lastDraft = draft;
    return submit?.call(draft) ?? Future.value(_application());
  }

  @override
  Future<ApplicationTrackingModel> trackApplication({
    required String code,
    required String email,
  }) {
    return track?.call(code, email) ?? Future.value(_tracking());
  }
}

ApplicationModel _application() => const ApplicationModel(
  id: 'application-1',
  campaignId: 'campaign-open',
  firstName: 'Awa',
  lastName: 'Audit',
  email: 'awa.audit@example.com',
  status: 'submitted',
  trackingCode: 'AUDIT-REC-SUCCESS-001',
  isAnonymized: false,
  canConvert: false,
);

ApplicationTrackingModel _tracking({
  String status = 'submitted',
  String? interviewDetails,
}) => ApplicationTrackingModel(
  applicationId: 'application-1',
  trackingCode: 'AUDIT-REC-TRACK-001',
  campaignTitle: _campaign.title,
  firstName: 'Awa',
  lastName: 'Audit',
  email: 'awa.audit@example.com',
  department: 'Génie informatique',
  studyLevel: 'Master 1',
  preferredPole: 'Technique',
  projectInterest: 'Impact',
  status: status,
  submittedAt: DateTime(2026, 8, 1, 10),
  updatedAt: DateTime(2026, 8, 10, 14, 30),
  nextStep: 'Consulte les prochaines informations.',
  candidateMessage: null,
  interviewDetails: interviewDetails,
  finalResult: null,
  accountCreated: false,
);

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: child);

Future<void> _fillIdentity(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('field-firstName')), 'Awa');
  await tester.enterText(find.byKey(const ValueKey('field-lastName')), 'Audit');
  await tester.enterText(
    find.byKey(const ValueKey('field-email')),
    'awa.audit@example.com',
  );
  await tester.tap(find.byKey(const ValueKey('application-next')));
  await tester.pump();
}

Future<void> _reachReview(WidgetTester tester) async {
  await _fillIdentity(tester);
  await tester.enterText(
    find.byKey(const ValueKey('field-studyLevel')),
    'Master 1',
  );
  await tester.enterText(
    find.byKey(const ValueKey('field-department')),
    'Génie informatique',
  );
  await tester.tap(find.byKey(const ValueKey('application-next')));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey('field-motivation')),
    'Je souhaite contribuer à des projets utiles et apprendre en équipe.',
  );
  await tester.tap(find.byKey(const ValueKey('application-next')));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey('field-availability')),
    'Disponible les mardi et jeudi après les cours.',
  );
  await tester.tap(find.byKey(const ValueKey('application-next')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('application-next')));
  await tester.pump();
}

void main() {
  test('public recruitment routes bypass authentication redirects', () {
    expect(AppRouter.isPublicPath('/recruitment/apply'), isTrue);
    expect(AppRouter.isPublicPath('/recruitment/apply/campaign-open'), isTrue);
    expect(AppRouter.isPublicPath('/application-tracking'), isTrue);
    expect(AppRouter.isPublicPath('/recruitment'), isFalse);
  });

  testWidgets('campaign discovery distinguishes loading and an open campaign', (
    tester,
  ) async {
    final completer = Completer<List<RecruitmentCampaignModel>>();
    final gateway = _FakeGateway(campaigns: () => completer.future);
    await tester.pumpWidget(
      _app(PublicRecruitmentCampaignsScreen(gateway: gateway)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(const [_campaign]);
    await tester.pumpAndSettle();

    expect(find.text(_campaign.title), findsOneWidget);
    expect(find.text('Commencer ma candidature'), findsOneWidget);
  });

  testWidgets('campaign discovery has a dedicated empty state', (tester) async {
    await tester.pumpWidget(
      _app(
        PublicRecruitmentCampaignsScreen(
          gateway: _FakeGateway(campaigns: () async => const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Aucune campagne n’est ouverte pour le moment'),
      findsOneWidget,
    );
    expect(find.text('Suivre une candidature'), findsWidgets);
  });

  testWidgets('campaign discovery has a distinct loading error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        PublicRecruitmentCampaignsScreen(
          gateway: _FakeGateway(campaigns: () async => throw Exception()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger les campagnes'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(
      find.text('Aucune campagne n’est ouverte pour le moment'),
      findsNothing,
    );
  });

  testWidgets('step validation blocks navigation until identity is valid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        PublicApplicationFlowScreen(
          campaignId: _campaign.id,
          campaign: _campaign,
          gateway: _FakeGateway(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('application-next')));
    await tester.pump();

    expect(find.text('Étape 1 sur 6'), findsOneWidget);
    expect(
      find.text('Ce champ est nécessaire pour continuer.'),
      findsNWidgets(2),
    );
  });

  testWidgets('six steps preserve entered values after returning', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        PublicApplicationFlowScreen(
          campaignId: _campaign.id,
          campaign: _campaign,
          gateway: _FakeGateway(),
        ),
      ),
    );
    await _fillIdentity(tester);

    expect(find.text('Étape 2 sur 6'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retour'));
    await tester.pump();

    expect(find.text('Étape 1 sur 6'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('field-firstName')))
          .controller
          ?.text,
      'Awa',
    );
  });

  testWidgets('completed flow reaches the review page without submitting', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      _app(
        PublicApplicationFlowScreen(
          campaignId: _campaign.id,
          campaign: _campaign,
          gateway: gateway,
        ),
      ),
    );
    await _reachReview(tester);

    expect(find.text('Étape 6 sur 6'), findsOneWidget);
    expect(find.text('Vérification'), findsOneWidget);
    expect(find.text('Envoyer ma candidature'), findsOneWidget);
    expect(gateway.lastDraft, isNull);
  });

  testWidgets('simulated submission displays a selectable tracking code', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      _app(
        PublicApplicationFlowScreen(
          campaignId: _campaign.id,
          campaign: _campaign,
          gateway: gateway,
        ),
      ),
    );
    await _reachReview(tester);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('application-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Candidature envoyée'), findsOneWidget);
    expect(find.text('AUDIT-REC-SUCCESS-001'), findsOneWidget);
    expect(find.text('Copier le code'), findsOneWidget);
    expect(gateway.lastDraft?.email, 'awa.audit@example.com');
  });

  testWidgets('failed submission keeps all data and allows retry', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      submit: (_) async => throw const PublicRecruitmentFailure(
        PublicRecruitmentFailureKind.server,
      ),
    );
    await tester.pumpWidget(
      _app(
        PublicApplicationFlowScreen(
          campaignId: _campaign.id,
          campaign: _campaign,
          gateway: gateway,
        ),
      ),
    );
    await _reachReview(tester);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('application-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('n’a pas pu être envoyée'), findsOneWidget);
    expect(find.text('Envoyer ma candidature'), findsOneWidget);
    final editIdentity = find.widgetWithText(TextButton, 'Modifier').at(1);
    await tester.ensureVisible(editIdentity);
    await tester.tap(editIdentity);
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('field-email')))
          .controller
          ?.text,
      'awa.audit@example.com',
    );
  });

  testWidgets('public tracking remains responsive at 390 pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(ApplicationTrackingScreen(gateway: _FakeGateway())),
    );
    await tester.pump();

    expect(find.text('Consulter ma candidature'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('all seven public statuses are humanized without raw enums', () {
    const expected = {
      'submitted': 'Reçue',
      'under_review': 'En cours d’étude',
      'interview_scheduled': 'Entretien programmé',
      'accepted': 'Candidature retenue',
      'rejected': 'Candidature non retenue',
      'waiting_list': 'Liste d’attente',
      'cancelled': 'Candidature clôturée',
    };

    for (final entry in expected.entries) {
      final presentation = ApplicationStatusPresentation.fromStatus(entry.key);
      expect(presentation.title, entry.value);
      expect(presentation.title, isNot(entry.key));
      expect(presentation.explanation, isNotEmpty);
      expect(presentation.nextAction, isNotEmpty);
    }
  });

  testWidgets('interview tracking shows human status, date and place', (
    tester,
  ) async {
    const details = '10/08/2026 à 14:30 · Salle Audit A1';
    final gateway = _FakeGateway(
      track: (_, _) async =>
          _tracking(status: 'interview_scheduled', interviewDetails: details),
    );
    await tester.pumpWidget(_app(ApplicationTrackingScreen(gateway: gateway)));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'AUDIT-REC-INTERVIEW-001',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'audit.rec.interview001@example.com',
    );
    await tester.tap(find.text('Consulter ma candidature'));
    await tester.pumpAndSettle();

    expect(find.text('Entretien programmé'), findsOneWidget);
    expect(find.text(details), findsOneWidget);
    expect(find.text('interview_scheduled'), findsNothing);
    expect(find.text('Chronologie de la candidature'), findsNothing);
  });
}
