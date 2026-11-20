import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/models/recruitment_question_model.dart';
import 'package:frontend/features/recruitment/widgets/public/public_application_field.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'questions and help remain complete at $width scale=$scale dark=$dark',
          (tester) async {
            tester.view.physicalSize = Size(width, 564);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 564),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (final question in defaultRecruitmentQuestions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: PublicApplicationField(
                                label: question.label,
                                help: question.hint,
                                child: TextFormField(
                                  key: ValueKey(question.id),
                                  minLines: 4,
                                  maxLines: 7,
                                  maxLength: 1200,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            void verifyCopy() {
              for (final question in defaultRecruitmentQuestions) {
                for (final copy in [
                  question.label,
                  if (question.hint.isNotEmpty) question.hint,
                ]) {
                  final finder = find.text(copy);
                  expect(finder, findsOneWidget);
                  final paragraph = tester.renderObject<RenderParagraph>(
                    finder,
                  );
                  expect(paragraph.didExceedMaxLines, isFalse, reason: copy);
                  final rect = tester.getRect(finder);
                  expect(rect.left, greaterThanOrEqualTo(0));
                  expect(rect.right, lessThanOrEqualTo(width + 0.1));
                }
              }
            }

            verifyCopy();
            await tester.enterText(
              find.byKey(ValueKey(defaultRecruitmentQuestions.first.id)),
              'Ma réponse conservée.',
            );
            await tester.pumpAndSettle();
            verifyCopy();
            expect(find.text('Ma réponse conservée.'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('a long selected value can be swiped horizontally', (
    tester,
  ) async {
    const label =
        'Une longue valeur de département ou de formation qui reste entièrement accessible';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: PublicApplicationChoiceText(label),
            ),
          ),
        ),
      ),
    );
    final scrollable = find.byType(Scrollable);
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.drag(
      find.byType(PublicApplicationChoiceText),
      const Offset(-140, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(find.text(label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
