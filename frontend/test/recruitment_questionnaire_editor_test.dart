import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/models/recruitment_question_model.dart';
import 'package:frontend/features/recruitment/widgets/internal/questionnaire_editor.dart';

void main() {
  testWidgets(
    'questions ajoutées, reformulées, réordonnées et retirées à 390 px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var questions = <RecruitmentApplicationQuestion>[
        const RecruitmentApplicationQuestion(id: 'one', label: 'Une cause ?'),
        const RecruitmentApplicationQuestion(id: 'two', label: 'Une idée ?'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => RecruitmentQuestionnaireEditor(
                  questions: questions,
                  onChanged: (value) => setState(() => questions = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('question-label-one')),
        'Quelle cause te tient à cœur ?',
      );
      await tester.pumpAndSettle();
      expect(questions.first.label, 'Quelle cause te tient à cœur ?');
      await tester.tap(find.byTooltip('Descendre la question').first);
      await tester.pumpAndSettle();
      expect(questions.first.id, 'two');
      await tester.ensureVisible(
        find.byKey(const Key('add-application-question')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-application-question')));
      await tester.pumpAndSettle();
      expect(questions, hasLength(3));
      final added = questions.last.id;
      await tester.ensureVisible(find.byKey(ValueKey('question-label-$added')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('question-label-$added')),
        'Comment apprendrais-tu sur le terrain ?',
      );
      await tester.pumpAndSettle();
      expect(questions.last.label, 'Comment apprendrais-tu sur le terrain ?');
      await tester.ensureVisible(find.text('Retirer la question').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer la question').last);
      await tester.pumpAndSettle();
      expect(questions, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
