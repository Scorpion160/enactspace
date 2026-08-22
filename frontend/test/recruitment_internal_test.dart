import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/models/application_status_presentation.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/screens/internal/internal_recruitment_screen.dart';
import 'package:frontend/features/recruitment/services/internal_recruitment_gateway.dart';

const _campaign = RecruitmentCampaignModel(
  id: 'campaign-1',
  title: 'Campagne Audit 2026',
  isActive: true,
);

ApplicationModel _application({
  int index = 1,
  String status = 'under_review',
  DateTime? interviewAt,
  String? interviewLocation,
  double? finalScore = 15,
}) => ApplicationModel(
  id: 'application-$index',
  campaignId: _campaign.id,
  firstName: 'Awa',
  lastName: 'Candidate $index',
  gender: 'female',
  email: 'awa$index@example.com',
  phone: '+22177000000$index',
  department: 'Génie informatique',
  studyLevel: 'DIC 2',
  className: 'Classe $index',
  motivation: 'Je souhaite contribuer durablement aux projets Enactus.',
  knownEnactusFrom: 'Forum associatif',
  enactusKnowledge: 'Entrepreneuriat social et impact mesurable.',
  otherClubs: 'Club innovation',
  contribution: 'Développement produit et animation d’équipe.',
  projectIdeas: 'Une plateforme de réemploi locale.',
  leadershipProfile: 'Écoute, initiative et collaboration.',
  preferredPole: 'Innovation',
  projectInterest: 'Projet Alpha',
  associativeExperience: 'Deux années de bénévolat.',
  availability: 'Soirs et week-ends',
  publicComment: 'Disponible immédiatement.',
  interviewAt: interviewAt,
  interviewLocation: interviewLocation,
  interviewJury: 'Jury Audit',
  interviewNote: interviewAt == null ? null : 'Préparer un cas pratique.',
  cvUrl: '/uploads/cv.pdf',
  motivationLetterUrl: '/uploads/letter.pdf',
  attachmentUrl: '/uploads/attachment.png',
  status: status,
  trackingCode: 'AUDIT-REC-${index.toString().padLeft(3, '0')}',
  finalScore: finalScore,
  createdAt: '2026-08-01T10:00:00',
  updatedAt: '2026-08-02T10:00:00',
  isAnonymized: false,
  canConvert: status == 'accepted',
);

const _reviews = [
  ApplicationReviewModel(
    id: 'review-1',
    applicationId: 'application-1',
    reviewerId: 'Évaluateur A',
    score: 16,
    comment: 'Dossier solide.',
    recommendation: 'favorable',
  ),
  ApplicationReviewModel(
    id: 'review-2',
    applicationId: 'application-1',
    reviewerId: 'Évaluateur B',
    score: 14,
    comment: 'Motivation à approfondir.',
    recommendation: 'reserve',
  ),
];

class _FakeGateway implements InternalRecruitmentGateway {
  final Future<List<ApplicationModel>> Function()? applications;
  final ApplicationModel? detail;

  _FakeGateway({this.applications, this.detail});

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      Future.value(const [_campaign]);

  @override
  Future<List<ApplicationModel>> loadApplications() =>
      applications?.call() ?? Future.value([_application()]);

  @override
  Future<ApplicationModel> loadApplication(String applicationId) async =>
      detail ?? _application();

  @override
  Future<List<ApplicationReviewModel>> loadReviews(
    String applicationId,
  ) async => _reviews;
}

Widget _app(InternalRecruitmentGateway gateway) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: InternalRecruitmentScreen(gateway: gateway)),
);

Future<void> _pump(
  WidgetTester tester,
  InternalRecruitmentGateway gateway, {
  Size size = const Size(1366, 768),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(gateway));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('écran interne autorisé avec liste dense', (tester) async {
    await _pump(tester, _FakeGateway());
    expect(find.text('Recrutement'), findsOneWidget);
    expect(find.text('Candidat / référence'), findsOneWidget);
    expect(find.text('Ouvrir le dossier'), findsOneWidget);
    expect(find.text('1–1 sur 1 candidatures'), findsOneWidget);
  });

  testWidgets('chargement initial dédié', (tester) async {
    final completer = Completer<List<ApplicationModel>>();
    await tester.pumpWidget(
      _app(_FakeGateway(applications: () => completer.future)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete([_application()]);
    await tester.pumpAndSettle();
  });

  testWidgets('erreur API distincte de la liste vide', (tester) async {
    await _pump(
      tester,
      _FakeGateway(
        applications: () async => throw Exception('API indisponible'),
      ),
    );
    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Aucun dossier'), findsNothing);
  });

  testWidgets('état aucun dossier dédié', (tester) async {
    await _pump(tester, _FakeGateway(applications: () async => []));
    expect(find.text('Aucun dossier'), findsOneWidget);
    expect(find.text('Erreur de chargement'), findsNothing);
  });

  testWidgets('recherche locale et zéro résultat filtré', (tester) async {
    await _pump(tester, _FakeGateway());
    await tester.enterText(
      find.byKey(const Key('internal-search')),
      'introuvable',
    );
    await tester.pump();
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('Réinitialiser les filtres'), findsOneWidget);
  });

  testWidgets('filtre statut puis réinitialisation', (tester) async {
    await _pump(tester, _FakeGateway());
    await tester.tap(find.byKey(const Key('internal-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Candidature retenue').last);
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser les filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir le dossier'), findsOneWidget);
  });

  testWidgets('pagination client par quinze dossiers', (tester) async {
    final items = List.generate(37, (index) => _application(index: index + 1));
    await _pump(tester, _FakeGateway(applications: () async => items));
    expect(find.text('1–15 sur 37 candidatures'), findsOneWidget);
    await tester.tap(find.byKey(const Key('internal-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('16–30 sur 37 candidatures'), findsOneWidget);
  });

  testWidgets('fiche candidat affiche résumé réponses et documents', (
    tester,
  ) async {
    await _pump(tester, _FakeGateway());
    await tester.tap(find.text('Ouvrir le dossier'));
    await tester.pumpAndSettle();
    expect(find.text('Fiche candidat'), findsOneWidget);
    expect(find.text('Résumé'), findsOneWidget);
    expect(find.text('Réponses'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('application-detail-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Lettre de motivation'), findsOneWidget);
    expect(find.text('Consulter'), findsNWidgets(3));
  });

  testWidgets('évaluations humanisées et moyenne officielle sur 20', (
    tester,
  ) async {
    await _pump(tester, _FakeGateway());
    await tester.tap(find.text('Ouvrir le dossier'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('application-detail-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Moyenne officielle : 15.0/20'), findsOneWidget);
    expect(find.textContaining('Favorable'), findsOneWidget);
    expect(find.textContaining('Avec réserves'), findsOneWidget);
    expect(find.text('favorable'), findsNothing);
    expect(find.text('reserve'), findsNothing);
  });

  testWidgets('entretien affiche date et lieu', (tester) async {
    final interview = _application(
      status: 'interview_scheduled',
      interviewAt: DateTime(2026, 8, 10, 14, 30),
      interviewLocation: 'Salle Audit A1',
    );
    await _pump(tester, _FakeGateway(detail: interview));
    await tester.tap(find.text('Ouvrir le dossier'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('application-detail-scroll')),
      const Offset(0, -1900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Salle Audit A1'), findsOneWidget);
    expect(find.textContaining('10/08/2026 14:30'), findsOneWidget);
  });

  testWidgets('sept statuts sont humanisés sans enum brut', (tester) async {
    final items = <ApplicationModel>[];
    for (var i = 0; i < internalStatuses.length; i++) {
      items.add(_application(index: i + 1, status: internalStatuses[i]));
    }
    await _pump(tester, _FakeGateway(applications: () async => items));
    for (final status in internalStatuses) {
      expect(
        find.text(ApplicationStatusPresentation.fromStatus(status).title),
        findsWidgets,
      );
      expect(find.text(status), findsNothing);
    }
  });

  testWidgets('mobile 390 px sans overflow et scores distingués', (
    tester,
  ) async {
    await _pump(tester, _FakeGateway(), size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    final openButton = find
        .widgetWithText(TextButton, 'Ouvrir le dossier')
        .first;
    await tester.scrollUntilVisible(
      openButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Indice de présélection'), findsOneWidget);
    expect(find.textContaining('/100'), findsOneWidget);
  });
}

const internalStatuses = [
  'submitted',
  'under_review',
  'interview_scheduled',
  'accepted',
  'rejected',
  'waiting_list',
  'cancelled',
];
