import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/models/candidate_conversion_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_campaign_model.dart';
import 'package:frontend/features/recruitment/screens/internal/application_detail_panel.dart';
import 'package:frontend/features/recruitment/services/internal_recruitment_gateway.dart';
import 'package:frontend/features/recruitment/widgets/internal/candidate_actions.dart';
import 'package:frontend/features/recruitment/widgets/internal/candidate_conversion.dart';

final _corePole = PoleModel(
  id: 'pole-core',
  seasonId: null,
  name: 'Innovation',
  shortName: 'INNO',
  type: 'core',
  description: null,
  objectives: null,
  createdAt: DateTime(2026),
);

final _supportPole = PoleModel(
  id: 'pole-support',
  seasonId: null,
  name: 'Communication',
  shortName: 'COM',
  type: 'support',
  description: null,
  objectives: null,
  createdAt: DateTime(2026),
);

final _project = ProjectModel(
  id: 'project-1',
  seasonId: null,
  name: 'Projet Alpha',
  description: null,
  problemStatement: null,
  solution: null,
  objectives: null,
  expectedImpact: null,
  budgetEstimated: 0,
  status: 'deploiement',
  startedAt: null,
  endedAt: null,
  createdAt: DateTime(2026),
);

final _catalog = CandidateConversionCatalog(
  poles: [_corePole, _supportPole],
  projects: [_project],
);

ApplicationModel _candidate({
  String status = 'accepted',
  bool canConvert = true,
  String? convertedUserId,
}) => ApplicationModel(
  id: 'application-accepted',
  campaignId: 'campaign-1',
  firstName: 'Awa',
  lastName: 'Candidate',
  gender: 'female',
  email: 'awa.candidate@example.com',
  phone: '+221770000000',
  department: 'Génie informatique',
  studyLevel: 'DIC 2',
  className: 'Promotion 2027',
  motivation: 'Contribuer à un projet à impact.',
  preferredPole: 'Innovation',
  projectInterest: 'Projet Alpha',
  availability: 'Soirs et week-ends',
  status: status,
  trackingCode: 'AUDIT-REC-ACCEPTED-001',
  convertedUserId: convertedUserId,
  createdAt: '2026-08-01T10:00:00',
  updatedAt: '2026-08-02T10:00:00',
  isAnonymized: false,
  canConvert: canConvert,
);

class _ConversionGateway implements InternalRecruitmentGateway {
  final ApplicationModel application;
  final Future<CandidateConversionCatalog> Function()? catalogLoader;
  final Future<CandidateConversionResult> Function(
    CandidateConversionRequest request,
  )?
  conversion;
  int conversionCount = 0;
  CandidateConversionRequest? lastRequest;

  _ConversionGateway({
    ApplicationModel? application,
    this.catalogLoader,
    this.conversion,
  }) : application = application ?? _candidate();

  @override
  Future<CandidateConversionCatalog> loadConversionCatalog() =>
      catalogLoader?.call() ?? Future.value(_catalog);

  @override
  Future<CandidateConversionResult> convertCandidate(
    CandidateConversionRequest request,
  ) async {
    conversionCount++;
    lastRequest = request;
    return conversion?.call(request) ??
        const CandidateConversionResult(
          userId: 'user-1',
          profileType: 'enactrice',
          corePoleId: 'pole-core',
          projectId: 'project-1',
          operation: CandidateConversionOperation.created,
          message: 'Compte membre créé avec succès.',
        );
  }

  @override
  Future<List<RecruitmentCampaignModel>> loadCampaigns() async => const [
    RecruitmentCampaignModel(
      id: 'campaign-1',
      title: 'Campagne Audit 2026',
      isActive: true,
    ),
  ];

  @override
  Future<List<ApplicationModel>> loadApplications() async => [application];

  @override
  Future<ApplicationModel> loadApplication(String applicationId) async =>
      application;

  @override
  Future<List<ApplicationReviewModel>> loadReviews(
    String applicationId,
  ) async => const [];

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
  Future<RecruitmentCampaignModel> createCampaign({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) => throw UnsupportedError('unused');

  @override
  Future<RecruitmentCampaignModel> updateCampaign({
    required String campaignId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
  }) => throw UnsupportedError('unused');

  @override
  Future<void> deleteCampaign(String campaignId) =>
      throw UnsupportedError('unused');
}

Widget _section(_ConversionGateway gateway) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: CandidateIntegrationSection(
        application: gateway.application,
        campaignTitle: 'Campagne Audit 2026',
        gateway: gateway,
      ),
    ),
  ),
);

Future<void> _pumpSection(
  WidgetTester tester,
  _ConversionGateway gateway, {
  Size size = const Size(900, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_section(gateway));
  await tester.pumpAndSettle();
}

Future<void> _openConversion(
  WidgetTester tester,
  _ConversionGateway gateway,
) async {
  await _pumpSection(tester, gateway);
  await tester.tap(find.byKey(const Key('candidate-integration-prepare')));
  await tester.pumpAndSettle();
}

Future<void> _reachAssignments(
  WidgetTester tester,
  _ConversionGateway gateway,
) async {
  await _openConversion(tester, gateway);
  await tester.tap(find.byKey(const Key('candidate-conversion-next')));
  await tester.pumpAndSettle();
}

Future<void> _reachReview(
  WidgetTester tester,
  _ConversionGateway gateway, {
  String password = 'Factice-2026',
}) async {
  await _reachAssignments(tester, gateway);
  await tester.enterText(
    find.byKey(const Key('candidate-conversion-password')),
    password,
  );
  await tester.tap(find.byKey(const Key('candidate-conversion-next')));
  await tester.pumpAndSettle();
}

Future<void> _confirmAndSubmit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('candidate-conversion-confirmation')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('candidate-conversion-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('action absente pour une candidature non retenue', (
    tester,
  ) async {
    final gateway = _ConversionGateway(
      application: _candidate(status: 'under_review'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ApplicationDetailPanel(
          summary: gateway.application,
          campaignTitle: 'Campagne Audit 2026',
          anonymized: false,
          gateway: gateway,
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('candidate-integration-section')),
      findsNothing,
    );
  });

  testWidgets('action visible pour une candidature retenue autorisée', (
    tester,
  ) async {
    await _pumpSection(tester, _ConversionGateway());
    expect(find.text('Intégration dans EnactSpace'), findsOneWidget);
    expect(
      find.byKey(const Key('candidate-integration-prepare')),
      findsOneWidget,
    );
  });

  testWidgets('action absente lorsque can_convert serveur est faux', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      _ConversionGateway(application: _candidate(canConvert: false)),
    );
    expect(
      find.byKey(const Key('candidate-integration-prepare')),
      findsNothing,
    );
    expect(find.textContaining('responsables autorisés'), findsOneWidget);
  });

  for (final role in ['Secrétaire générale', 'Team Leader', 'Administrateur']) {
    testWidgets('$role autorisé via can_convert serveur', (tester) async {
      await _pumpSection(tester, _ConversionGateway());
      expect(
        find.byKey(const Key('candidate-integration-prepare')),
        findsOneWidget,
      );
    });
  }

  testWidgets('résumé candidat affiche les données utiles', (tester) async {
    await _openConversion(tester, _ConversionGateway());
    expect(find.text('Résumé du candidat'), findsOneWidget);
    expect(find.text('Awa Candidate'), findsOneWidget);
    expect(find.text('awa.candidate@example.com'), findsOneWidget);
    expect(find.text('Campagne Audit 2026'), findsOneWidget);
    expect(find.text('Candidature retenue'), findsWidgets);
    expect(find.text('Innovation'), findsOneWidget);
    expect(find.text('Projet Alpha'), findsOneWidget);
  });

  testWidgets('catalogue charge pôles et projets depuis le gateway', (
    tester,
  ) async {
    await _reachAssignments(tester, _ConversionGateway());
    expect(find.text('Affectations et accès initial'), findsOneWidget);
    await tester.tap(find.byKey(const Key('candidate-conversion-core-pole')));
    await tester.pumpAndSettle();
    expect(find.text('Innovation'), findsOneWidget);
    await tester.tap(find.text('Innovation'));
    await tester.pumpAndSettle();
    expect(find.text('Communication'), findsOneWidget);
    await tester.tap(find.byKey(const Key('candidate-conversion-project')));
    await tester.pumpAndSettle();
    expect(find.text('Projet Alpha'), findsOneWidget);
  });

  testWidgets('erreur de catalogue est distincte et réessayable', (
    tester,
  ) async {
    final gateway = _ConversionGateway(
      catalogLoader: () => throw Exception('réseau'),
    );
    await _reachAssignments(tester, gateway);
    expect(
      find.text('Impossible de charger les pôles et projets.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('mot de passe trop court bloque la vérification', (tester) async {
    await _reachAssignments(tester, _ConversionGateway());
    await tester.enterText(
      find.byKey(const Key('candidate-conversion-password')),
      'court',
    );
    await tester.tap(find.byKey(const Key('candidate-conversion-next')));
    await tester.pump();
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
  });

  testWidgets('mot de passe initial est masqué', (tester) async {
    await _reachAssignments(tester, _ConversionGateway());
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('candidate-conversion-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.obscureText, isTrue);
  });

  testWidgets('mot de passe peut être affiché puis masqué', (tester) async {
    await _reachAssignments(tester, _ConversionGateway());
    await tester.tap(
      find.byKey(const Key('candidate-conversion-password-visibility')),
    );
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('candidate-conversion-password')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );
  });

  testWidgets('vérification finale humanise toutes les affectations', (
    tester,
  ) async {
    await _reachReview(tester, _ConversionGateway());
    expect(find.text('Vérification finale'), findsOneWidget);
    expect(
      find.text('Cette opération est distincte de la décision de recrutement.'),
      findsOneWidget,
    );
    expect(find.text('Membre EnactSpace'), findsOneWidget);
    expect(find.text('Enactrice'), findsOneWidget);
    expect(
      find.text('Création ou activation d’un compte existant'),
      findsOneWidget,
    );
  });

  testWidgets('confirmation renforcée est obligatoire', (tester) async {
    await _reachReview(tester, _ConversionGateway());
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('candidate-conversion-submit')),
    );
    expect(submit.onPressed, isNull);
    expect(
      find.text(
        'Je confirme les affectations et l’ouverture de l’accès EnactSpace.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('aucune conversion automatique après acceptation', (
    tester,
  ) async {
    final gateway = _ConversionGateway();
    await _openConversion(tester, gateway);
    expect(gateway.conversionCount, 0);
    await tester.tap(find.byKey(const Key('candidate-conversion-next')));
    await tester.pumpAndSettle();
    expect(gateway.conversionCount, 0);
  });

  testWidgets('double clic final ne déclenche qu’un envoi', (tester) async {
    final completer = Completer<CandidateConversionResult>();
    final gateway = _ConversionGateway(conversion: (_) => completer.future);
    await _reachReview(tester, gateway);
    await tester.tap(
      find.byKey(const Key('candidate-conversion-confirmation')),
    );
    await tester.pump();
    final submit = find.byKey(const Key('candidate-conversion-submit'));
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(gateway.conversionCount, 1);
    completer.complete(
      const CandidateConversionResult(
        userId: 'user-1',
        profileType: 'enactrice',
        operation: CandidateConversionOperation.created,
        message: 'Compte créé.',
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('création simulée affiche un résultat humain', (tester) async {
    await _reachReview(tester, _ConversionGateway());
    await _confirmAndSubmit(tester);
    expect(find.text('Intégration terminée'), findsOneWidget);
    expect(find.text('Compte membre créé'), findsOneWidget);
    expect(find.text('Awa Candidate'), findsOneWidget);
  });

  testWidgets('réactivation simulée affiche un résultat distinct', (
    tester,
  ) async {
    final gateway = _ConversionGateway(
      conversion: (_) async => const CandidateConversionResult(
        userId: 'user-existing',
        profileType: 'enacteur',
        operation: CandidateConversionOperation.existingAccountActivated,
        message: 'Un compte existait déjà avec cet email',
      ),
    );
    await _reachReview(tester, gateway);
    await _confirmAndSubmit(tester);
    expect(find.text('Compte existant activé et lié'), findsOneWidget);
  });

  testWidgets('erreur utilisateur actif est humanisée', (tester) async {
    final gateway = _ConversionGateway(
      conversion: (_) => throw Exception('Utilisateur déjà actif'),
    );
    await _reachReview(tester, gateway);
    await _confirmAndSubmit(tester);
    expect(
      find.text('Un membre actif utilise déjà cette adresse e-mail.'),
      findsOneWidget,
    );
  });

  testWidgets('erreur permission est humanisée', (tester) async {
    final gateway = _ConversionGateway(
      conversion: (_) => throw Exception('Permission insuffisante'),
    );
    await _reachReview(tester, gateway);
    await _confirmAndSubmit(tester);
    expect(
      find.text(
        'Vous n’avez pas la permission de finaliser cette intégration.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('erreur réseau est humanisée', (tester) async {
    final gateway = _ConversionGateway(
      conversion: (_) => throw Exception('Network socket unavailable'),
    );
    await _reachReview(tester, gateway);
    await _confirmAndSubmit(tester);
    expect(
      find.text(
        'Le réseau est indisponible. Vérifiez la connexion puis réessayez.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('formulaire et mot de passe restent conservés après erreur', (
    tester,
  ) async {
    final gateway = _ConversionGateway(
      conversion: (_) => throw Exception('Erreur serveur'),
    );
    await _reachReview(tester, gateway, password: 'Memoire-2026');
    await _confirmAndSubmit(tester);
    await tester.tap(find.text('Précédent'));
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('candidate-conversion-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text, 'Memoire-2026');
    expect(editable.obscureText, isTrue);
  });

  testWidgets('candidature déjà liée ne propose aucune nouvelle conversion', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      _ConversionGateway(
        application: _candidate(convertedUserId: 'member-existing'),
      ),
    );
    expect(find.text('Déjà membre'), findsOneWidget);
    expect(
      find.byKey(const Key('candidate-integration-prepare')),
      findsNothing,
    );
  });

  testWidgets('dialogue d’acceptation ne contient aucune conversion', (
    tester,
  ) async {
    var decisions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CandidateDecisionDialog(
            application: _candidate(status: 'under_review'),
            campaignTitle: 'Campagne Audit 2026',
            reviewCount: 0,
            reviewAverage: null,
            targetStatus: 'accepted',
            kind: CandidateDecisionKind.acceptance,
            onConfirm: () async => decisions++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('convertir automatiquement'), findsOneWidget);
    expect(find.text('Préparer l’intégration'), findsNothing);
    expect(decisions, 0);
  });

  testWidgets('résultat ne contient aucune donnée sensible', (tester) async {
    const password = 'Secret-Factice-2026';
    await _reachReview(tester, _ConversionGateway(), password: password);
    await _confirmAndSubmit(tester);
    expect(find.textContaining(password), findsNothing);
    expect(find.textContaining('mot de passe'), findsOneWidget);
  });

  testWidgets('parcours mobile 390 px reste sans overflow', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    await _reachAssignments(tester, _ConversionGateway());
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      errors.where((error) => error.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
    expect(find.text('Affectations et accès initial'), findsOneWidget);
  });

  testWidgets('aucun enum technique brut n’est affiché', (tester) async {
    await _reachReview(tester, _ConversionGateway());
    for (final raw in [
      'accepted',
      'enacteur',
      'existingAccountActivated',
      'core_pole_id',
      'project_id',
    ]) {
      expect(find.text(raw), findsNothing);
    }
  });
}
