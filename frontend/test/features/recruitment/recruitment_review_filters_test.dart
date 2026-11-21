import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/services/recruitment_review_filters.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_comparison_panel.dart';

Map<String, dynamic> sample(
  String id,
  double? juryMean, {
  String? decision,
  bool ready = true,
  double? spread,
}) => {
  'application_id': id,
  'anonymous_code': id,
  'score': juryMean == null ? null : juryMean * 5,
  'jury_average_20': juryMean,
  'jury_spread_20': spread,
  'ready': ready,
  'department': 'Gestion',
  'study_level': 'DIC1',
  'review_count': ready ? 3 : 2,
  'required_reviews': ready ? 3 : 4,
  'decision': decision,
};

void main() {
  test('10/20 and 15/20 boundaries are exact, without rounding', () {
    final rows = [
      sample('R1', 9.999),
      sample('R2', 10),
      sample('R3', 14.999),
      sample('R4', 15),
      sample('R5', null),
    ];
    expect(
      rows.where((r) => reviewScoreBandMatches(r, 'below', 10, 15)).length,
      1,
    );
    expect(
      rows.where((r) => reviewScoreBandMatches(r, 'middle', 10, 15)).length,
      2,
    );
    expect(
      rows.where((r) => reviewScoreBandMatches(r, 'above', 10, 15)).length,
      1,
    );
    expect(
      rows.where((r) => reviewScoreBandMatches(r, 'missing', 10, 15)).length,
      1,
    );
    expect(reviewScoreBandMatches(rows[2], 'above', 10, 15), false);
  });

  test('prepared decisions and missing grades remain distinct', () {
    final pending = sample('A', 12, ready: false, spread: 5);
    final shortlisted = sample('B', 12, decision: 'shortlisted');
    final notShortlisted = sample('C', 8, decision: 'not_shortlisted');
    expect(reviewDecisionMatches(pending, 'pending'), true);
    expect(reviewDecisionMatches(shortlisted, 'pending'), false);
    expect(reviewDecisionMatches(shortlisted, 'shortlisted'), true);
    expect(reviewDecisionMatches(notShortlisted, 'not_shortlisted'), true);
    expect(reviewDisagreementMatches(pending, 'high'), true);
    expect(reviewDisagreementMatches(pending, 'low'), false);
    expect(reviewDisagreementMatches(shortlisted, 'high'), false);
  });

  test('a future campaign can use different advisory thresholds', () {
    final caseA = sample('A', 14);
    expect(reviewScoreBandMatches(caseA, 'middle', 10, 15), true);
    expect(reviewScoreBandMatches(caseA, 'above', 12, 14), true);
    expect(reviewScoreBandMatches(caseA, 'middle', 8, 12), false);
  });

  testWidgets('priority action finds pending 10–15 regardless of readiness', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecruitmentComparisonPanel(
              screening: true,
              onOpen: opened.add,
              rows: [
                sample('R1', 9.5, decision: 'not_shortlisted'),
                sample('R2', 12, ready: false, spread: 8),
                sample('R3', 13, decision: 'shortlisted'),
                sample('R4', 14, ready: true),
                sample('R5', 15, decision: 'shortlisted'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('comparison-review-pending'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('R2'), findsOneWidget);
    expect(find.text('R4'), findsOneWidget);
    expect(find.text('R3'), findsNothing);
    expect(find.text('R1'), findsNothing);
    expect(find.text('R5'), findsNothing);
    await tester.ensureVisible(find.text('R2'));
    await tester.tap(find.text('R2'));
    expect(opened, ['R2']);
  });
}
