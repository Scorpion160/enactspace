import 'dart:async';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/models/campaign_state_presentation.dart';
import 'package:frontend/features/recruitment/models/candidate_conversion_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/screens/internal/campaign_management_screen.dart';
import 'package:frontend/features/recruitment/services/internal_recruitment_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _open = RecruitmentCampaignModel(
  id: 'open',
  title: 'Campagne ouverte',
  description: 'Recrutement en cours.',
  startDate: '2026-08-01',
  endDate: '2026-08-31',
  isActive: true,
);
const _planned = RecruitmentCampaignModel(
  id: 'planned',
  title: 'Campagne planifiée',
  startDate: '2026-09-01',
  endDate: '2026-09-30',
  isActive: true,
);
const _ended = RecruitmentCampaignModel(
  id: 'ended',
  title: 'Campagne terminée',
  startDate: '2026-06-01',
  endDate: '2026-06-30',
  isActive: true,
);
const _inactive = RecruitmentCampaignModel(
  id: 'inactive',
  title: 'Campagne inactive',
  startDate: '2026-08-01',
  endDate: '2026-08-31',
  isActive: false,
);

final _now = DateTime(2026, 8, 23);

class _CampaignGateway implements InternalRecruitmentGateway {
  final Future<List<RecruitmentCampaignModel>> Function()? campaignsLoader;
  final Future<RecruitmentCampaignModel> Function({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    required bool isActive,
  })?
  createMutation;
  final Future<RecruitmentCampaignModel> Function({
    required String campaignId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  })?
  updateMutation;
  final Future<void> Function(String campaignId)? deleteMutation;
  List<RecruitmentCampaignModel> items;
  int createCount = 0;
  int updateCount = 0;
  int deleteCount = 0;

  _CampaignGateway({
    List<RecruitmentCampaignModel> campaigns = const [_open],
    this.campaignsLoader,
    this.createMutation,
    this.updateMutation,
    this.deleteMutation,
  }) : items = List.of(campaigns);

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() =>
      campaignsLoader?.call() ?? Future.value(List.of(items));

  @override
  Future<List<ApplicationModel>> loadApplications() async => const [];

  @override
  Future<RecruitmentCampaignModel> createCampaign({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    createCount++;
    final created =
        await (createMutation?.call(
              title: title,
              description: description,
              startDate: startDate,
              endDate: endDate,
              isActive: isActive,
            ) ??
            Future.value(
              RecruitmentCampaignModel(
                id: 'created',
                title: title,
                description: description,
                startDate: startDate?.toIso8601String(),
                endDate: endDate?.toIso8601String(),
                isActive: isActive,
              ),
            ));
    items = [created, ...items];
    return created;
  }

  @override
  Future<RecruitmentCampaignModel> updateCampaign({
    required String campaignId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) async {
    updateCount++;
    final current = items.firstWhere((item) => item.id == campaignId);
    final updated =
        await (updateMutation?.call(
              campaignId: campaignId,
              title: title,
              description: description,
              startDate: startDate,
              endDate: endDate,
              isActive: isActive,
            ) ??
            Future.value(
              current.copyWith(
                title: title,
                description: description,
                startDate: startDate?.toIso8601String(),
                endDate: endDate?.toIso8601String(),
                isActive: isActive,
              ),
            ));
    items = items
        .map((item) => item.id == campaignId ? updated : item)
        .toList();
    return updated;
  }

  @override
  Future<void> deleteCampaign(String campaignId) async {
    deleteCount++;
    await deleteMutation?.call(campaignId);
    items = items.where((item) => item.id != campaignId).toList();
  }

  @override
  Future<ApplicationModel> loadApplication(String applicationId) =>
      throw UnsupportedError('unused');

  @override
  Future<List<ApplicationReviewModel>> loadReviews(String applicationId) =>
      throw UnsupportedError('unused');

  @override
  Future<ApplicationModel> changeStatus({
    required String applicationId,
    required String status,
  }) => throw UnsupportedError('unused');

  @override
  Future<ApplicationModel> scheduleInterview({
    required String applicationId,
    required DateTime interviewAt,
    String? location,
    String? link,
    String? jury,
    String? note,
  }) => throw UnsupportedError('unused');

  @override
  Future<CandidateConversionCatalog> loadConversionCatalog() async =>
      const CandidateConversionCatalog(poles: [], projects: []);

  @override
  Future<CandidateConversionResult> convertCandidate(
    CandidateConversionRequest request,
  ) => throw UnsupportedError('unused');
}

Widget _app(_CampaignGateway gateway) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: CampaignManagementScreen(gateway: gateway, now: _now),
);

Future<void> _pump(
  WidgetTester tester,
  _CampaignGateway gateway, {
  Size size = const Size(1366, 768),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_app(gateway));
  await tester.pumpAndSettle();
}

Future<void> _openCreate(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-campaign')));
  await tester.pumpAndSettle();
}

void main() {
  test('état Planifiée dérivé d’une campagne active future', () {
    expect(
      CampaignStatePresentation.fromCampaign(_planned, now: _now).label,
      'Planifiée',
    );
  });

  test('état Ouverte dérivé de la période courante', () {
    expect(
      CampaignStatePresentation.fromCampaign(_open, now: _now).label,
      'Ouverte',
    );
  });

  test('état Terminée prioritaire même si la campagne reste active', () {
    expect(
      CampaignStatePresentation.fromCampaign(_ended, now: _now).label,
      'Terminée',
    );
  });

  test('état Inactive dérivé sans exposer le booléen technique', () {
    expect(
      CampaignStatePresentation.fromCampaign(_inactive, now: _now).label,
      'Inactive',
    );
  });

  testWidgets('liste affiche les quatre états humains sans valeur brute', (
    tester,
  ) async {
    await _pump(
      tester,
      _CampaignGateway(campaigns: const [_open, _planned, _ended, _inactive]),
    );
    for (final label in ['Ouverte', 'Planifiée', 'Terminée', 'Inactive']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('is_active=true'), findsNothing);
    expect(find.text('is_active=false'), findsNothing);
  });

  testWidgets('liste campagnes disponible avec période et actions', (
    tester,
  ) async {
    await _pump(tester, _CampaignGateway());
    expect(find.text('Campagne ouverte'), findsOneWidget);
    expect(find.text('Du 01/08/2026 au 31/08/2026'), findsOneWidget);
    expect(find.text('Consulter'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Fermer'), findsWidgets);
  });

  testWidgets('état vide dédié', (tester) async {
    await _pump(tester, _CampaignGateway(campaigns: const []));
    expect(find.text('Aucune campagne'), findsOneWidget);
    expect(find.text('Erreur de chargement'), findsNothing);
  });

  testWidgets('erreur API distincte de la liste vide', (tester) async {
    await _pump(
      tester,
      _CampaignGateway(
        campaignsLoader: () async => throw Exception('API indisponible'),
      ),
    );
    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Aucune campagne'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('ouverture du formulaire de création', (tester) async {
    await _pump(tester, _CampaignGateway());
    await _openCreate(tester);
    expect(find.text('Créer une campagne'), findsWidgets);
    expect(find.byKey(const Key('campaign-title')), findsOneWidget);
    expect(find.byKey(const Key('campaign-description')), findsOneWidget);
    expect(find.byKey(const Key('campaign-start-date')), findsOneWidget);
    expect(find.byKey(const Key('campaign-end-date')), findsOneWidget);
  });

  testWidgets('titre requis bloque la création', (tester) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await _openCreate(tester);
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pump();
    expect(find.text('Le titre est requis.'), findsOneWidget);
    expect(gateway.createCount, 0);
  });

  testWidgets('validation bloque une fin antérieure au début', (tester) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await _openCreate(tester);
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Nouvelle campagne',
    );
    await tester.enterText(
      find.byKey(const Key('campaign-start-date')),
      '20/09/2026',
    );
    await tester.enterText(
      find.byKey(const Key('campaign-end-date')),
      '10/09/2026',
    );
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pump();
    expect(
      find.text('La date de fin doit suivre la date de début.'),
      findsOneWidget,
    );
    expect(gateway.createCount, 0);
  });

  testWidgets('création simulée réussie', (tester) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await _openCreate(tester);
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Campagne créée',
    );
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pumpAndSettle();
    expect(gateway.createCount, 1);
    expect(find.text('Campagne créée'), findsWidgets);
  });

  testWidgets('erreur de création conserve le formulaire', (tester) async {
    final gateway = _CampaignGateway(
      createMutation:
          ({
            required title,
            description,
            startDate,
            endDate,
            required isActive,
          }) async => throw Exception('Création indisponible.'),
    );
    await _pump(tester, gateway);
    await _openCreate(tester);
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Saisie conservée',
    );
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Création indisponible.'), findsOneWidget);
    expect(find.text('Saisie conservée'), findsOneWidget);
  });

  testWidgets('formulaire édition prérempli sans contrôle d’activation', (
    tester,
  ) async {
    await _pump(tester, _CampaignGateway());
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier la campagne'), findsOneWidget);
    expect(find.text('Campagne ouverte'), findsWidgets);
    expect(find.text('01/08/2026'), findsOneWidget);
    expect(find.byKey(const Key('campaign-active')), findsNothing);
  });

  testWidgets('modification simulée réussie', (tester) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Titre modifié',
    );
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pumpAndSettle();
    expect(gateway.updateCount, 1);
    expect(find.text('Titre modifié'), findsWidgets);
  });

  testWidgets('erreur de modification conserve le formulaire', (tester) async {
    final gateway = _CampaignGateway(
      updateMutation:
          ({
            required campaignId,
            title,
            description,
            startDate,
            endDate,
            isActive,
          }) async => throw Exception('Modification indisponible.'),
    );
    await _pump(tester, gateway);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Valeur conservée',
    );
    await tester.tap(find.byKey(const Key('campaign-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Modification indisponible.'), findsOneWidget);
    expect(find.text('Valeur conservée'), findsOneWidget);
  });

  testWidgets('dialogue ouverture résume état actuel et nouvel état', (
    tester,
  ) async {
    final gateway = _CampaignGateway(campaigns: const [_inactive]);
    await _pump(tester, gateway);
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir cette campagne ?'), findsOneWidget);
    expect(find.text('État actuel : Inactive'), findsOneWidget);
    expect(find.text('Nouvel état attendu : Ouverte'), findsOneWidget);
    expect(gateway.updateCount, 0);
  });

  testWidgets('campagne future activée reste Planifiée', (tester) async {
    final gateway = _CampaignGateway(
      campaigns: [_planned.copyWith(isActive: false)],
    );
    await _pump(tester, gateway);
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvel état attendu : Planifiée'), findsOneWidget);
    expect(find.textContaining('restera planifiée'), findsOneWidget);
  });

  testWidgets('ouverture bloquée lorsque les dates sont incohérentes', (
    tester,
  ) async {
    final gateway = _CampaignGateway(
      campaigns: const [
        RecruitmentCampaignModel(
          id: 'invalid-dates',
          title: 'Période incohérente',
          startDate: '2026-10-20',
          endDate: '2026-09-20',
          isActive: false,
        ),
      ],
    );
    await _pump(tester, gateway);
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Corrigez la période avant d’activer cette campagne.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('campaign-toggle-submit')))
          .onPressed,
      isNull,
    );
    expect(gateway.updateCount, 0);
  });

  testWidgets('dialogue fermeture explique la conservation des dossiers', (
    tester,
  ) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Fermer cette campagne ?'), findsOneWidget);
    expect(
      find.textContaining('candidatures existantes resteront consultables'),
      findsOneWidget,
    );
    expect(gateway.updateCount, 0);
  });

  testWidgets('suppression avertit explicitement de la cascade', (
    tester,
  ) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await tester.tap(find.byKey(const Key('delete-campaign-open')));
    await tester.pumpAndSettle();
    expect(
      find.text('Supprimer définitivement cette campagne ?'),
      findsOneWidget,
    );
    expect(find.textContaining('également en cascade'), findsOneWidget);
    expect(find.textContaining('irréversible'), findsWidgets);
  });

  testWidgets('suppression exige confirmation et ne mute pas avant', (
    tester,
  ) async {
    final gateway = _CampaignGateway();
    await _pump(tester, gateway);
    await tester.tap(find.byKey(const Key('delete-campaign-open')));
    await tester.pumpAndSettle();
    expect(gateway.deleteCount, 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('campaign-delete-submit')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('campaign-delete-confirmation')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('campaign-delete-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('erreur de suppression garde la confirmation ouverte', (
    tester,
  ) async {
    final gateway = _CampaignGateway(
      deleteMutation: (_) async => throw Exception('Suppression indisponible.'),
    );
    await _pump(tester, gateway);
    await tester.tap(find.byKey(const Key('delete-campaign-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-delete-confirmation')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('campaign-delete-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Suppression indisponible.'), findsOneWidget);
    expect(
      find.text('Supprimer définitivement cette campagne ?'),
      findsOneWidget,
    );
  });

  testWidgets('double soumission de création empêchée', (tester) async {
    final completer = Completer<RecruitmentCampaignModel>();
    final gateway = _CampaignGateway(
      createMutation:
          ({
            required title,
            description,
            startDate,
            endDate,
            required isActive,
          }) => completer.future,
    );
    await _pump(tester, gateway);
    await _openCreate(tester);
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Double clic',
    );
    final submit = find.byKey(const Key('campaign-form-submit'));
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();
    expect(gateway.createCount, 1);
    completer.complete(
      const RecruitmentCampaignModel(
        id: 'double',
        title: 'Double clic',
        isActive: false,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('mobile 390 px sans overflow horizontal', (tester) async {
    await _pump(
      tester,
      _CampaignGateway(campaigns: const [_open, _planned]),
      size: const Size(390, 844),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Campagne ouverte'), findsOneWidget);
    await tester.tap(find.text('Modifier').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('campaign-form-submit')), findsOneWidget);
  });
}
