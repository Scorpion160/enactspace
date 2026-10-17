import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/widgets/internal/human_assessment_editor.dart';
import 'package:frontend/features/recruitment/models/application_model.dart';
import 'package:frontend/features/recruitment/models/application_review_model.dart';
import 'package:frontend/features/recruitment/models/recruitment_question_model.dart';

void main() {
  final rubric =
      jsonDecode(
            File(
              '../backend/app/services/recruitment_rubric.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  Map<String, dynamic> ratings([int? level = 3]) => {
    'rubric_version': rubric['version'],
    'ratings': [
      for (final criterion in rubric['criteria'])
        {
          'criterion_id': criterion['id'],
          'rating': level,
          'evidence':
              'Une contribution précise et un apprentissage discutés avec le jury.',
        },
    ],
  };
  test('unknown criteria never turn into a zero or a default rating', () {
    expect(isCompleteHumanAssessment(null, rubric), isFalse);
    expect(isCompleteHumanAssessment(ratings(null), rubric), isFalse);
    expect(isCompleteHumanAssessment(ratings(0), rubric), isTrue);
    final duplicate = ratings();
    (duplicate['ratings'] as List)[4] = (duplicate['ratings'] as List)[0];
    expect(isCompleteHumanAssessment(duplicate, rubric), isFalse);
    final missingEvidence = ratings();
    missingEvidence['ratings'][0]['evidence'] = '  ';
    expect(isCompleteHumanAssessment(missingEvidence, rubric), isFalse);
    expect(
      isCompleteHumanAssessment({
        ...ratings(),
        'rubric_version': 'other',
      }, rubric),
      isFalse,
    );
  });
  test('identity, studies and text length never generate an index', () {
    for (final level in ['DIC1', 'DIC3', 'DUT2']) {
      final item = ApplicationModel.fromJson({
        'id': 'one',
        'first_name': 'Nom',
        'last_name': 'Test',
        'email': 'test@example.org',
        'status': 'submitted',
        'study_level': level,
        'motivation': 'Un texte très long. ' * 80,
        'availability': '10',
        'final_score': 19,
      });
      expect(item.screeningScore, isNull);
      expect(item.scoreLabel, startsWith('Note antérieure'));
      expect(item.screeningLabel, 'Évaluation à réaliser');
    }
    final scored = ApplicationModel.fromJson({
      'id': 'one',
      'screening_score': 75,
      'screening_review_count': 2,
      'screening_spread': 10,
    });
    expect(scored.screeningScore, 75);
    expect(scored.scoreLabel, '15.0/20');
  });
  test('stored human observations survive API parsing', () {
    final review = ApplicationReviewModel.fromJson({
      'id': 'review',
      'criteria_assessment': ratings(),
    });
    expect(review.criteriaAssessment, ratings());
    expect(
      ApplicationReviewModel.fromJson({'score': 18}).criteriaAssessment,
      isNull,
    );
  });
  test(
    'default public questionnaire mirrors the server and includes concrete teamwork and learning',
    () {
      final code = File(
        '../backend/app/services/recruitment_questionnaire.py',
      ).readAsStringSync();
      final start =
          code.indexOf('DEFAULT_QUESTIONS = ') + 'DEFAULT_QUESTIONS = '.length;
      final end = code.indexOf('\nLEGACY_FIELDS', start);
      final server = jsonDecode(
        code
            .substring(start, end)
            .replaceAll(': True', ': true')
            .replaceAll(': False', ': false'),
      );
      expect(
        defaultRecruitmentQuestions.map((q) => q.toJson()).toList(),
        server,
      );
      expect(
        defaultRecruitmentQuestions
            .where((q) => q.id == 'teamwork-example')
            .single
            .required,
        isTrue,
      );
      expect(
        defaultRecruitmentQuestions
            .where((q) => q.id == 'learning-example')
            .single
            .required,
        isTrue,
      );
      expect(
        defaultRecruitmentQuestions.any((q) => q.id.contains('preferred')),
        isFalse,
      );
    },
  );
  testWidgets('an evaluator reopens the existing levels and observations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HumanAssessmentEditor(
              rubric: rubric,
              initialAssessment: ratings(2),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Ton évaluation : 50/100'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('rubric-evidence-mission')),
    );
    expect(field.initialValue, contains('Une contribution précise'));
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    for (final width in [360.0, 1440.0]) {
      testWidgets(
        'unscored rubric remains readable dark=$dark width=$width with large text',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Map<String, dynamic>? current;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 900),
                  textScaler: TextScaler.linear(1.8),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: HumanAssessmentEditor(
                        rubric: rubric,
                        onChanged: (value) => current = value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('0/5 critères renseignés'), findsOneWidget);
          expect(current, isNull);
          expect(tester.takeException(), isNull);
          final ids = (rubric['criteria'] as List)
              .map((c) => c['id'].toString())
              .toList();
          for (final id in ids) {
            final dropdown = find.byKey(ValueKey('rubric-rating-$id'));
            await tester.ensureVisible(dropdown);
            await tester.pumpAndSettle();
            await tester.tap(dropdown);
            await tester.pumpAndSettle();
            await tester.tap(find.text('3/4').last);
            await tester.pumpAndSettle();
            final evidence = find.byKey(ValueKey('rubric-evidence-$id'));
            await tester.ensureVisible(evidence);
            await tester.pumpAndSettle();
            await tester.enterText(
              evidence,
              'Un exemple précis, discuté et justifié.',
            );
            await tester.pumpAndSettle();
          }
          expect(isCompleteHumanAssessment(current, rubric), isTrue);
          expect(find.text('Ton évaluation : 75/100'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
