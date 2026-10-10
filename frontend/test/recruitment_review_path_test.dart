import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/screens/internal/application_detail_panel.dart';
import 'package:frontend/features/recruitment/services/internal_recruitment_gateway.dart';

final _rubric =
    jsonDecode(
          File(
            '../backend/app/services/recruitment_rubric.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
Map<String, dynamic> _assessment() => {
  'rubric_version': _rubric['version'],
  'ratings': [
    for (final c in _rubric['criteria'])
      {
        'criterion_id': c['id'],
        'rating': 3,
        'evidence': 'Un exemple concret de coopération et de responsabilité.',
      },
  ],
};
Map<String, dynamic> _data({bool own = false}) => {
  'id': 'candidate-one',
  'campaign_id': 'campaign-one',
  'first_name': 'Candidate',
  'last_name': 'Test',
  'email': 'candidate@example.org',
  'status': 'under_review',
  'screening_rubric': _rubric,
  if (own)
    'my_review': {
      'id': 'review-one',
      'application_id': 'candidate-one',
      'score': 15,
      'recommendation': 'favorable',
      'comment': 'Mon observation conservée',
      'criteria_assessment': _assessment(),
    },
};

class _ReviewGateway implements InternalRecruitmentGateway {
  final bool failSave;
  Map<String, dynamic> data;
  int saves = 0;
  Map<String, dynamic>? savedAssessment;
  _ReviewGateway({bool own = false, this.failSave = false})
    : data = _data(own: own);
  @override
  Future<ApplicationModel> loadApplication(
    String id, {
    bool anonymized = false,
  }) async => ApplicationModel.fromJson(data);
  @override
  Future<List<ApplicationReviewModel>> loadReviews(String id) async =>
      data['my_review'] == null
      ? []
      : [ApplicationReviewModel.fromJson(data['my_review'])];
  @override
  Future<ApplicationReviewModel> createReview({
    required String applicationId,
    required Map<String, dynamic> criteriaAssessment,
    String? comment,
    String recommendation = 'reserve',
  }) async {
    saves++;
    if (failSave) {
      throw ApiException(
        statusCode: 500,
        message: 'SQL private server diagnostic',
      );
    }
    savedAssessment = criteriaAssessment;
    final review = {
      'id': 'review-one',
      'application_id': applicationId,
      'score': 15,
      'comment': comment,
      'recommendation': recommendation,
      'criteria_assessment': criteriaAssessment,
    };
    data = {
      ...data,
      'my_review': review,
      'screening_score': 75,
      'screening_review_count': 1,
    };
    return ApplicationReviewModel.fromJson(review);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(
  WidgetTester tester,
  _ReviewGateway gateway, {
  ValueChanged<ApplicationModel>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ApplicationDetailPanel(
          summary: ApplicationModel.fromJson(gateway.data),
          campaignTitle: 'Recrutement',
          anonymized: false,
          gateway: gateway,
          onClose: () {},
          onApplicationChanged: onChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final button = find.byKey(const Key('candidate-review-action'));
  await tester.scrollUntilVisible(
    button,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'active candidate detail opens the grid and rejects incomplete reviews',
    (tester) async {
      final gateway = _ReviewGateway();
      await _open(tester, gateway);
      expect(find.text('Évaluer la candidature'), findsOneWidget);
      await tester.tap(find.text('Enregistrer mon avis'));
      await tester.pumpAndSettle();
      expect(gateway.saves, 0);
      expect(find.textContaining('Renseignez un niveau'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Évaluer la candidature'), findsNothing);
      expect(find.byKey(const Key('candidate-review-action')), findsOneWidget);
    },
  );
  testWidgets(
    'own restored review saves through the active gateway and refreshes the detail without changing status',
    (tester) async {
      final gateway = _ReviewGateway(own: true);
      ApplicationModel? updated;
      await _open(tester, gateway, onChanged: (value) => updated = value);
      expect(find.text('Ton évaluation : 75/100'), findsOneWidget);
      await tester.tap(find.text('Enregistrer mon avis'));
      await tester.pumpAndSettle();
      expect(gateway.saves, 1);
      expect(gateway.savedAssessment, _assessment());
      expect(updated?.screeningScore, 75);
      expect(updated?.screeningReviewCount, 1);
      expect(updated?.status, 'under_review');
      expect(updated?.myReview?.comment, 'Mon observation conservée');
      expect(find.text('Évaluer la candidature'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed save keeps the draft and displays a human message', (
    tester,
  ) async {
    final gateway = _ReviewGateway(own: true, failSave: true);
    await _open(tester, gateway);
    await tester.tap(find.text('Enregistrer mon avis'));
    await tester.pumpAndSettle();
    expect(find.text('Évaluer la candidature'), findsOneWidget);
    expect(find.textContaining('SQL'), findsNothing);
    expect(find.text('Ton évaluation : 75/100'), findsOneWidget);
    expect(gateway.data['status'], 'under_review');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
