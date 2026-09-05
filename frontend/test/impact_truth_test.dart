import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/impact/models/impact_models.dart';
import 'package:frontend/features/impact/models/impact_record_models.dart'
    as records;
import 'package:frontend/features/impact/screens/impact_dashboard_screen.dart';
import 'package:frontend/features/impact/screens/impact_records_screen.dart';
import 'package:frontend/features/impact/services/impact_gateway.dart';
import 'package:frontend/features/impact/services/impact_service.dart';
import 'package:frontend/features/projects/models/project_portfolio_models.dart';

void main() {
  test('null remains unknown while explicit zero remains zero', () {
    final unknownRecord = records.ImpactRecordModel.fromJson({
      'id': 'unknown',
      'project_id': 'p1',
      'title': 'Unknown',
    });
    final zeroRecord = records.ImpactRecordModel.fromJson({
      'id': 'zero',
      'project_id': 'p1',
      'title': 'Zero',
      'direct_beneficiaries': 0,
    });
    final unknownPortfolio = ProjectImpactSnapshot.fromJson({'id': 'p1'});

    expect(unknownRecord.directBeneficiaries, isNull);
    expect(zeroRecord.directBeneficiaries, 0);
    expect(
      records.impactValueLabel(unknownRecord.directBeneficiaries),
      'Non renseigné',
    );
    expect(records.impactValueLabel(zeroRecord.directBeneficiaries), '0');
    expect(unknownPortfolio.directBeneficiaries, isNull);
    expect(unknownPortfolio.hasContractualData, isFalse);
  });

  test('claim type and validation dimensions remain visually distinct', () {
    expect(impactClaimTypeLabel('MEASURED'), 'Mesuré');
    expect(impactClaimTypeLabel('ESTIMATE'), 'Estimation');
    expect(impactClaimTypeLabel('PROJECTION'), 'Projection');
    expect(impactClaimTypeLabel('HISTORICAL_CLAIM'), 'Historique déclaré');
    expect(impactValidationLabel('VERIFIED'), 'Vérifié');
    expect(impactValidationLabel('UNDER_REVIEW'), 'En vérification');
    expect(impactValidationLabel('EVIDENCE_ATTACHED'), contains('à vérifier'));
  });

  test('only a verified measured claim identifies itself as realized', () {
    final claims = [
      _claim('MEASURED', 'VERIFIED', 4),
      _claim('MEASURED', 'UNDER_REVIEW', 5),
      _claim('ESTIMATE', 'VERIFIED', 6),
      _claim('PROJECTION', 'VERIFIED', 7),
      _claim('HISTORICAL_CLAIM', 'VERIFIED', 8),
    ];

    expect(
      claims.where((claim) => claim.isRealized).map((claim) => claim.value),
      [4],
    );
  });

  test('impact and operational scores do not treat missing values as zero', () {
    final project = _project(directImpact: null);
    final organization = _organization(directImpactTotal: null);

    expect(project.projectImpactScore, isNull);
    expect(project.totalBeneficiaries, isNull);
    expect(organization.organizationHealthScore, isNull);
  });

  test('dashboard API parser preserves nullable compatibility fields', () {
    final service = ImpactService();
    final unknown = service.projectFromJson({
      'id': 'p1',
      'project_name': 'Unknown',
      'evidence_count': 0,
    });
    final zero = service.projectFromJson({
      'id': 'p2',
      'project_name': 'Zero',
      'direct_impact': 0,
      'evidence_count': 0,
    });
    final summary = service.organizationFromJson({}, [unknown, zero]);

    expect(unknown.directImpact, isNull);
    expect(zero.directImpact, 0);
    expect(summary.directImpactTotal, isNull);
  });

  testWidgets('dashboard tolerates nulls and labels typed claims truthfully', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ImpactDashboardScreen(gateway: _TruthGateway())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Non renseigné'), findsWidgets);
    expect(find.textContaining('Estimation · Vérifié'), findsOneWidget);
    expect(find.textContaining('Projection · En vérification'), findsOneWidget);
    expect(find.textContaining('Historique déclaré'), findsWidgets);
    expect(find.textContaining('Score indicatif /100'), findsNothing);
  });

  test('project name never creates client-side impact fallback', () {
    for (final name in ['TERRASEN', 'Terrasen', 'terrasen']) {
      final project = _project(projectName: name, directImpact: null);
      expect(project.directImpact, isNull);
      expect(project.evidenceCount, 0);
      expect(project.sdgs, isEmpty);
      expect(project.methodology, isNull);
      expect(project.competitionReadinessScore, isNull);
    }
  });

  test('validated-evidence warning ignores draft or rejected evidence', () {
    final project = _project(evidenceCount: 2, verifiedEvidenceCount: 0);

    expect(project.evidenceCount, 2);
    expect(project.verifiedEvidenceCount, 0);
    expect(project.needsEvidence, isTrue);
  });

  testWidgets(
    'verified parent record does not make legacy aggregate realized or verified',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImpactRecordDetailScreen(
              recordId: 'legacy-record',
              gateway: _LegacyImpactGateway(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fiche vérifiée'), findsOneWidget);
      expect(
        find.text('Données historiques / compatibilité — non vérifiées'),
        findsOneWidget,
      );
      expect(find.text('17'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Indicateurs'), 400);
      await tester.tap(find.text('Charger').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Historique déclaré · Brouillon'),
        findsOneWidget,
      );
      expect(
        find.textContaining('17.0 personnes · Historique déclaré · Vérifié'),
        findsNothing,
      );
    },
  );
}

ImpactClaimModel _claim(String type, String validation, double value) =>
    ImpactClaimModel(
      id: '$type-$validation',
      semanticKey: 'direct_beneficiaries',
      title: 'Bénéficiaires',
      value: value,
      unit: 'personnes',
      claimType: type,
      validationStatus: validation,
      periodStart: null,
      periodEnd: null,
      populationScope: null,
      source: null,
      sourceReference: null,
      methodology: null,
      notesLimitations: null,
      evidenceCount: 0,
    );

ProjectImpactMetricModel _project({
  String projectName = 'Projet sans données',
  int? directImpact,
  int evidenceCount = 0,
  int verifiedEvidenceCount = 0,
}) => ProjectImpactMetricModel(
  id: 'p1',
  projectName: projectName,
  status: 'active',
  poleName: 'Projet',
  projectLead: 'Non assigné',
  deputyLead: 'Non assigné',
  sdgs: const [],
  problem: 'À documenter',
  solution: 'À documenter',
  targetBeneficiaries: 'À préciser',
  directImpact: directImpact,
  indirectImpact: null,
  reach: null,
  revenue: null,
  surplus: null,
  jobsCreated: null,
  livesImpacted: null,
  treesPlanted: null,
  wasteReduced: null,
  waterSaved: null,
  co2Reduced: null,
  planetImpact: null,
  evidenceCount: evidenceCount,
  verifiedEvidenceCount: verifiedEvidenceCount,
  methodology: null,
  assumptions: null,
  budgetUsed: 0,
  progress: 0,
  completedTasks: 0,
  lateTasks: 0,
  documentsCount: 0,
  innovationScore: null,
  businessViabilityScore: null,
  scalabilityScore: null,
  competitionReadinessScore: null,
  claims: [
    _claim('ESTIMATE', 'VERIFIED', 100),
    _claim('PROJECTION', 'UNDER_REVIEW', 500),
    _claim('HISTORICAL_CLAIM', 'DRAFT', 15000),
  ],
);

OrganizationPerformanceModel _organization({int? directImpactTotal}) =>
    OrganizationPerformanceModel(
      activeMembers: 0,
      attendanceRate: null,
      retentionRate: null,
      completedTasks: 0,
      lateTasks: 0,
      activeProjects: 1,
      directImpactTotal: directImpactTotal,
      indirectImpactTotal: null,
      reachTotal: null,
      jobsCreatedTotal: null,
      livesImpactedTotal: null,
      treesPlantedTotal: null,
      validatedEvidenceCount: 0,
      touchedSdgs: null,
      revenueTotal: null,
      surplusTotal: null,
      officialDocuments: 0,
      competitionReadiness: null,
      academyParticipation: null,
      communicationEngagement: null,
      financialHealth: null,
    );

class _TruthGateway implements ImpactGateway {
  @override
  Future<ImpactDashboardData> loadDashboard() async => ImpactDashboardData(
    organization: _organization(),
    historicalImpact: null,
    projects: [_project()],
    enacteurs: const [],
    poles: const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LegacyImpactGateway implements ImpactGateway {
  @override
  Future<records.ImpactRecordModel> getRecord(String id) async =>
      records.ImpactRecordModel.fromJson({
        'id': id,
        'project_id': 'project-1',
        'title': 'Legacy record',
        'validation_status': 'VERIFIED',
        'status': 'validated',
        'direct_beneficiaries': 17,
      });

  @override
  Future<List<records.ImpactMetricModel>> getMetrics(String recordId) async => [
    records.ImpactMetricModel.fromJson({
      'id': 'legacy-claim',
      'semantic_key': 'direct_beneficiaries',
      'title': 'Legacy beneficiaries',
      'category': 'social',
      'unit': 'personnes',
      'value': 17,
      'claim_type': 'HISTORICAL_CLAIM',
      'validation_status': 'DRAFT',
      'status': 'draft',
    }),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
