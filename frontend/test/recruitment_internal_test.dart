import 'package:frontend/features/recruitment/models/application_history_model.dart';
import 'package:frontend/features/recruitment/screens/internal/application_detail_panel.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_internal_widgets.dart';
import 'package:frontend/features/recruitment/services/recruitment_message.dart';
import 'package:frontend/core/api/api_client.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/models/application_status_presentation.dart';
import 'package:frontend/features/recruitment/models/candidate_conversion_model.dart';
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
  List<ApplicationHistoryModel> history = const [],
}) => ApplicationModel(
  history: history,
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
  final Future<ApplicationModel> Function(String status)? statusMutation;
  final Future<ApplicationModel> Function(DateTime interviewAt)?
  interviewMutation;
  ApplicationModel? _current;
  final anonymousDetailRequests = <bool>[];
  int statusMutationCount = 0;
  int interviewMutationCount = 0;

  _FakeGateway({
    this.applications,
    ApplicationModel? detail,
    this.statusMutation,
    this.interviewMutation,
  }) : _current = detail;

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      Future.value(const [_campaign]);

  @override
  Future<RecruitmentCampaignModel> createCampaign({
    List<Map<String, dynamic>>? applicationQuestions,
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async => _campaign.copyWith(
    title: title,
    description: description,
    startDate: startDate?.toIso8601String(),
    endDate: endDate?.toIso8601String(),
    isActive: isActive,
  );

  @override
  Future<RecruitmentCampaignModel> updateCampaign({
    List<Map<String, dynamic>>? applicationQuestions,
    required String campaignId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async => _campaign.copyWith(
    title: title,
    description: description,
    startDate: startDate?.toIso8601String(),
    endDate: endDate?.toIso8601String(),
    isActive: isActive,
  );

  @override
  Future<void> deleteCampaign(String campaignId) async {}

  @override
  Future<List<ApplicationModel>> loadApplications() =>
      applications?.call() ?? Future.value([_application()]);

  @override
  Future<ApplicationModel> loadApplication(
    String applicationId, {
    bool anonymized = false,
  }) async {
    anonymousDetailRequests.add(anonymized);
    return _current ?? _application();
  }

  @override
  Future<ApplicationReviewModel> createReview({
    required String applicationId,
    required Map<String, dynamic> criteriaAssessment,
    String? comment,
    String recommendation = 'reserve',
  }) async =>
      throw UnimplementedError('Review mutation unused in this fixture');

  @override
  Future<List<ApplicationReviewModel>> loadReviews(
    String applicationId,
  ) async => _reviews;

  @override
  Future<ApplicationModel> changeStatus({
    required String applicationId,
    required String status,
  }) async {
    statusMutationCount++;
    final result =
        await (statusMutation?.call(status) ??
            Future.value(_application(status: status)));
    _current = result;
    return result;
  }

  @override
  Future<ApplicationModel> scheduleInterview({
    required String applicationId,
    required DateTime interviewAt,
    String? location,
    String? link,
    String? jury,
    String? note,
  }) async {
    interviewMutationCount++;
    final result =
        await (interviewMutation?.call(interviewAt) ??
            Future.value(
              _application(
                status: 'interview_scheduled',
                interviewAt: interviewAt,
                interviewLocation: location,
              ),
            ));
    _current = result;
    return result;
  }

  @override
  Future<CandidateConversionCatalog> loadConversionCatalog() async =>
      const CandidateConversionCatalog(poles: [], projects: []);

  @override
  Future<CandidateConversionResult> convertCandidate(
    CandidateConversionRequest request,
  ) => throw UnsupportedError('unused');
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
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_app(gateway));
  await tester.pumpAndSettle();
}

Future<void> _openActions(
  WidgetTester tester,
  InternalRecruitmentGateway gateway,
) async {
  await _pump(tester, gateway);
  await tester.tap(find.text('Ouvrir le dossier'));
  await tester.pumpAndSettle();
  await tester.drag(
    find.byKey(const Key('application-detail-scroll')),
    const Offset(0, -3000),
  );
  await tester.pumpAndSettle();
  expect(find.text('Actions sur la candidature'), findsOneWidget);
}

void main() {
  test('technical error details are replaced with a useful message', () {
    expect(
      recruitmentMessage(
        ApiException(
          statusCode: 500,
          message: 'SQLAlchemy traceback https://private.invalid',
        ),
        fallback: 'Réessaie dans un instant.',
      ),
      'Réessaie dans un instant.',
    );
    expect(
      recruitmentMessage(
        Exception('Le backend ne fournit pas de journal'),
        fallback: 'Réessaie.',
      ),
      'Réessaie.',
    );
    expect(
      recruitmentMessage(
        Exception('Agenda indisponible.'),
        fallback: 'Réessaie.',
      ),
      'Agenda indisponible.',
    );
  });

  for (final dark in [false, true]) {
    testWidgets('status contrast remains readable dark=$dark', (tester) async {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      for (final status in ApplicationStatusPresentation.supportedStatuses) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(child: InternalStatusBadge(status: status)),
            ),
          ),
        );
        final badge = find.byType(InternalStatusBadge);
        final container = tester.widget<Container>(
          find.descendant(of: badge, matching: find.byType(Container)),
        );
        final decoration = container.decoration! as BoxDecoration;
        final text = tester.widget<Text>(
          find.descendant(of: badge, matching: find.byType(Text)),
        );
        final background = Color.alphaBlend(
          decoration.color!,
          theme.colorScheme.surface,
        );
        final a = text.style!.color!.computeLuminance(),
            b = background.computeLuminance();
        final contrast = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
        expect(contrast, greaterThanOrEqualTo(4.5), reason: status);
      }
    });
    for (final width in [360.0, 768.0, 1366.0, 1600.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('candidate list width=$width scale=$scale dark=$dark', (
          tester,
        ) async {
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
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ApplicationWorkbench(
                      applications: [
                        for (var i = 0; i < internalStatuses.length; i++)
                          _application(
                            index: i + 1,
                            status: internalStatuses[i],
                          ),
                      ],
                      campaignTitle: (_) => 'Rejoindre Enactus ESP cette année',
                      anonymized: false,
                      rangeStart: 1,
                      rangeEnd: 7,
                      total: 7,
                      currentPage: 1,
                      pageCount: 1,
                      onOpen: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (width >= 1366 && scale == 1) {
            final evaluation = tester.getRect(find.text('Évaluation'));
            final documents = tester.getRect(find.text('Documents'));
            expect(documents.left - evaluation.right, greaterThanOrEqualTo(16));
          }
        });
      }
    }
  }

  testWidgets('detail displays dated history and requests anonymous data', (
    tester,
  ) async {
    final detail = _application(
      history: [
        ApplicationHistoryModel(
          id: 'history-1',
          kind: 'status',
          title: 'Statut mis à jour',
          occurredAt: DateTime(2026, 10, 5, 12, 30),
          actorName: 'Aïta DIA',
          fromStatus: 'submitted',
          toStatus: 'under_review',
        ),
      ],
    );
    final gateway = _FakeGateway(detail: detail);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ApplicationDetailPanel(
          summary: detail,
          campaignTitle: _campaign.title,
          anonymized: true,
          gateway: gateway,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Statut mis à jour'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reçue → En cours d’étude'), findsOneWidget);
    expect(find.textContaining('Aïta DIA'), findsOneWidget);
    expect(find.textContaining('12:30'), findsOneWidget);
    expect(find.textContaining('backend'), findsNothing);
    expect(find.textContaining('Évaluateur A'), findsNothing);
    expect(gateway.anonymousDetailRequests, [true]);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Lettre de motivation'), findsOneWidget);
    expect(find.text('Consulter la pièce jointe'), findsNWidgets(3));
  });

  testWidgets(
    'évaluations antérieures conservées sans moyenne de la nouvelle grille',
    (tester) async {
      await _pump(tester, _FakeGateway());
      await tester.tap(find.text('Ouvrir le dossier'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('application-detail-scroll')),
        const Offset(0, -1400),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Note antérieure · Hors de la nouvelle grille'),
        findsNWidgets(2),
      );
      expect(find.textContaining('Indice du jury :'), findsNothing);
      expect(find.textContaining('Favorable'), findsOneWidget);
      expect(find.textContaining('Avec réserves'), findsOneWidget);
      expect(find.text('favorable'), findsNothing);
      expect(find.text('reserve'), findsNothing);
    },
  );

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
    expect(find.text('Évaluation selon la grille'), findsOneWidget);
    expect(find.text('À réaliser'), findsOneWidget);
  });

  testWidgets(
    'les actions ne mutent rien à la sélection et masquent le statut actuel',
    (tester) async {
      final gateway = _FakeGateway();
      await _openActions(tester, gateway);
      expect(find.text('Passer en étude'), findsNothing);
      expect(find.text('Planifier un entretien'), findsOneWidget);
      expect(gateway.statusMutationCount, 0);
      expect(gateway.interviewMutationCount, 0);
    },
  );

  testWidgets('le dialogue standard résume le changement de statut', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Placer en liste d’attente'));
    await tester.pumpAndSettle();
    expect(find.text('Placer en liste d’attente ?'), findsOneWidget);
    expect(find.text('En cours d’étude'), findsWidgets);
    expect(find.text('Liste d’attente'), findsWidgets);
    expect(gateway.statusMutationCount, 0);
  });

  testWidgets('acceptation dédiée confirme sans convertir en utilisateur', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Accepter la candidature'));
    await tester.pumpAndSettle();
    expect(find.text('Retenir cette candidature ?'), findsOneWidget);
    expect(find.text('Évaluation par critères'), findsOneWidget);
    expect(find.text('Non disponible'), findsWidgets);
    expect(
      find.textContaining('sans convertir automatiquement'),
      findsOneWidget,
    );
    expect(find.text('Retenir la candidature'), findsOneWidget);
    expect(gateway.statusMutationCount, 0);
  });

  testWidgets('rejet exige une confirmation renforcée sans faux motif', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Ne pas retenir la candidature'));
    await tester.pumpAndSettle();
    expect(find.text('Ne pas retenir cette candidature ?'), findsOneWidget);
    expect(find.textContaining('Motif'), findsNothing);
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('candidate-decision-submit')),
    );
    expect(submit.onPressed, isNull);
    await tester.tap(find.byKey(const Key('candidate-decision-confirmation')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('candidate-decision-submit')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('clôture reste distincte du rejet et exige confirmation', (
    tester,
  ) async {
    await _openActions(tester, _FakeGateway());
    await tester.tap(find.text('Clôturer la candidature'));
    await tester.pumpAndSettle();
    expect(find.text('Clôturer cette candidature ?'), findsOneWidget);
    expect(find.textContaining('distincte d’un rejet'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('candidate-decision-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('liste d’attente est appliquée seulement après confirmation', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Placer en liste d’attente'));
    await tester.pumpAndSettle();
    expect(gateway.statusMutationCount, 0);
    await tester.tap(find.byKey(const Key('candidate-decision-submit')));
    await tester.pumpAndSettle();
    expect(gateway.statusMutationCount, 1);
    expect(
      find.textContaining('Statut mis à jour : Liste d’attente'),
      findsOneWidget,
    );
    expect(find.text('Placer en liste d’attente'), findsNothing);
  });

  testWidgets('succès de décision rafraîchit un statut humanisé', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Accepter la candidature'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('candidate-decision-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Candidature retenue'), findsWidgets);
    expect(find.text('accepted'), findsNothing);
    expect(
      find.textContaining('La création du compte membre vient après'),
      findsOneWidget,
    );
  });

  testWidgets(
    'erreur de décision garde le dialogue ouvert et permet réessayer',
    (tester) async {
      var attempts = 0;
      final gateway = _FakeGateway(
        statusMutation: (status) async {
          attempts++;
          if (attempts == 1) {
            throw Exception('Service temporairement indisponible.');
          }
          return _application(status: status);
        },
      );
      await _openActions(tester, gateway);
      await tester.tap(find.text('Placer en liste d’attente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('candidate-decision-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Placer en liste d’attente ?'), findsOneWidget);
      expect(find.text('Service temporairement indisponible.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('candidate-decision-submit')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.textContaining('Liste d’attente'), findsWidgets);
    },
  );

  testWidgets('double clic de décision est empêché pendant envoi', (
    tester,
  ) async {
    final completer = Completer<ApplicationModel>();
    final gateway = _FakeGateway(statusMutation: (_) => completer.future);
    await _openActions(tester, gateway);
    await tester.tap(find.text('Placer en liste d’attente'));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('candidate-decision-submit'));
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(gateway.statusMutationCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(_application(status: 'waiting_list'));
    await tester.pumpAndSettle();
  });

  testWidgets('formulaire entretien expose seulement les champs backend', (
    tester,
  ) async {
    await _openActions(tester, _FakeGateway());
    await tester.tap(find.text('Planifier un entretien'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('candidate-interview-date')), findsOneWidget);
    expect(find.byKey(const Key('candidate-interview-time')), findsOneWidget);
    expect(
      find.byKey(const Key('candidate-interview-location')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('candidate-interview-link')), findsOneWidget);
    expect(find.byKey(const Key('candidate-interview-jury')), findsOneWidget);
    expect(find.byKey(const Key('candidate-interview-note')), findsOneWidget);
    expect(find.textContaining('Motif'), findsNothing);
  });

  testWidgets('validation entretien bloque date et heure invalides', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Planifier un entretien'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('candidate-interview-date')),
      '31/02/2026',
    );
    await tester.enterText(
      find.byKey(const Key('candidate-interview-time')),
      '27:90',
    );
    await tester.tap(find.byKey(const Key('candidate-interview-submit')));
    await tester.pump();
    expect(find.text('Saisissez une date et une heure valides.'), findsWidgets);
    expect(gateway.interviewMutationCount, 0);
  });

  testWidgets('succès entretien rafraîchit statut date et lieu', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await _openActions(tester, gateway);
    await tester.tap(find.text('Planifier un entretien'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('candidate-interview-date')),
      '10/09/2026',
    );
    await tester.enterText(
      find.byKey(const Key('candidate-interview-time')),
      '14:30',
    );
    await tester.enterText(
      find.byKey(const Key('candidate-interview-location')),
      'Salle Horizon',
    );
    await tester.tap(find.byKey(const Key('candidate-interview-submit')));
    await tester.pumpAndSettle();
    expect(gateway.interviewMutationCount, 1);
    expect(find.textContaining('Entretien enregistré'), findsOneWidget);
    expect(find.text('Entretien programmé'), findsWidgets);
    expect(find.text('Salle Horizon'), findsOneWidget);
  });

  testWidgets('erreur entretien conserve le formulaire et les données', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      interviewMutation: (_) async => throw Exception('Agenda indisponible.'),
    );
    await _openActions(tester, gateway);
    await tester.tap(find.text('Planifier un entretien'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('candidate-interview-date')),
      '10/09/2026',
    );
    await tester.enterText(
      find.byKey(const Key('candidate-interview-time')),
      '14:30',
    );
    await tester.enterText(
      find.byKey(const Key('candidate-interview-location')),
      'Salle conservée',
    );
    await tester.tap(find.byKey(const Key('candidate-interview-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Agenda indisponible.'), findsOneWidget);
    expect(find.text('Salle conservée'), findsOneWidget);
    expect(find.text('Planifier l’entretien'), findsWidgets);
  });

  testWidgets('entretien existant propose une modification préremplie', (
    tester,
  ) async {
    final existing = _application(
      status: 'interview_scheduled',
      interviewAt: DateTime(2026, 8, 10, 14, 30),
      interviewLocation: 'Salle Audit A1',
    );
    await _openActions(tester, _FakeGateway(detail: existing));
    await tester.tap(find.text('Modifier l’entretien'));
    await tester.pumpAndSettle();
    expect(find.text('10/08/2026'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('Salle Audit A1'), findsWidgets);
    expect(find.text('Modifier l’entretien'), findsWidgets);
  });

  testWidgets('actions terminales déjà actives sont absentes', (tester) async {
    await _openActions(
      tester,
      _FakeGateway(detail: _application(status: 'accepted')),
    );
    expect(find.text('Accepter la candidature'), findsNothing);
    expect(find.text('Candidature retenue'), findsWidgets);
    expect(find.text('accepted'), findsNothing);
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
