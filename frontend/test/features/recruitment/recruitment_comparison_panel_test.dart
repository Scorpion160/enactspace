import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_comparison_panel.dart';

Map<String, dynamic> dossier({
  required String code,
  required double score,
  required bool ready,
  required String department,
  required String level,
}) => {
  'application_id': code,
  'anonymous_code': code,
  'department': department,
  'study_level': level,
  'score': score,
  'ready': ready,
  'review_count': ready ? 3 : 2,
  'required_reviews': 3,
  'spread': 5,
  'decision': null,
};

void main() {
  testWidgets('shows only ready candidates ranked by score by default',
      (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecruitmentComparisonPanel(
            screening: true,
            onOpen: opened.add,
            rows: [
              dossier(code: 'A001', score: 50, ready: true,
                  department: 'Gestion', level: 'Licence2'),
              dossier(code: 'A002', score: 99, ready: false,
                  department: 'Gestion', level: 'Licence3'),
              dossier(code: 'A003', score: 90, ready: true,
                  department: 'Génie Civil', level: 'DIC1'),
            ],
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Classement indicatif des dossiers'));
    await tester.pumpAndSettle();

    expect(find.text('A001'), findsOneWidget);
    expect(find.text('A003'), findsOneWidget);
    expect(find.text('A002'), findsNothing);
    expect(tester.getTopLeft(find.text('A003')).dy,
        lessThan(tester.getTopLeft(find.text('A001')).dy));

    await tester.ensureVisible(find.text('A003'));
    await tester.tap(find.text('A003'));
    expect(opened, ['A003']);
  });
}
