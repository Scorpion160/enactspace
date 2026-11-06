import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/recruitment/models/application_tracking_model.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/widgets/internal/candidate_actions.dart';
import 'package:frontend/features/recruitment/widgets/public/public_recruitment_widgets.dart';
import 'package:frontend/features/recruitment/widgets/public/recruitment_eligibility.dart';

void main() {
  testWidgets('eligibility blocks a terminal year and three clubs before the form', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecruitmentEligibilityCheck(
        onEligible: (level, count) => selected = '$level/$count',
      )),
    ));
    final level = find.byKey(const Key('eligibility-study-level'));
    final clubs = find.byKey(const Key('eligibility-clubs-count'));
    final proceed = find.byKey(const Key('eligibility-continue'));
    await tester.ensureVisible(level);
    await tester.tap(level);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DIC3').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(clubs);
    await tester.enterText(clubs, '0');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(proceed).onPressed, isNull);
    await tester.ensureVisible(level);
    await tester.tap(level);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DIC1').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(clubs);
    await tester.enterText(clubs, '3');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(proceed).onPressed, isNull);
    expect(find.textContaining('critère d’inéligibilité'), findsOneWidget);
    await tester.enterText(clubs, '2');
    await tester.pumpAndSettle();
    await tester.ensureVisible(proceed);
    await tester.tap(proceed);
    expect(selected, 'DIC1/2');
    expect(recruitmentAcademicLevels, isNot(contains('DIC3')));
    expect(recruitmentAcademicLevels, isNot(contains('DESCAF3')));
    expect(recruitmentAcademicLevels, isNot(contains('Master2')));
    expect(recruitmentAcademicLevels, isNot(contains('DIT2')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dossier rejected in screening stops before the interview', (tester) async {
    final tracking = ApplicationTrackingModel.fromJson({
      'status': 'rejected', 'screening_result': 'not_shortlisted',
      'application_id': 'selection-test', 'tracking_code': 'REC-TEST',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ApplicationTimeline(tracking: tracking)),
    )));
    expect(find.text('Candidature reçue'), findsOneWidget);
    expect(find.text('Étude du dossier'), findsOneWidget);
    expect(find.text('Dossier non retenu'), findsOneWidget);
    expect(find.text('Entretien'), findsNothing);
    expect(find.text('Décision'), findsNothing);
    expect(tracking.currentStep, 2);
    expect(tracking.presentation.title, 'Dossier non retenu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('blind dossier actions require batch publication for all outcomes', (tester) async {
    const application = ApplicationModel(
      id: 'blind-dossier', campaignId: 'blind-campaign', firstName: 'Candidat', lastName: 'ABC',
      email: 'anonymous@example.org', status: 'under_review',
      isAnonymized: true, canConvert: false,
      permissions: {'blind_selection': true, 'can_schedule': false},
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CandidateActionsSection(
        application: application, campaignTitle: 'Présélection', reviewCount: 0, reviewAverage: null,
        onStatusChange: (_) async {},
        onInterview: ({required DateTime interviewAt, String? location, String? link, String? jury, String? note}) async {},
      ),
    )));
    for (final action in ['accept', 'reject', 'waiting-list', 'close', 'interview']) {
      expect(find.byKey(Key('candidate-action-$action')), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
