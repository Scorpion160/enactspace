import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/models/recruitment_schedule_model.dart';
import 'package:frontend/features/recruitment/widgets/recruitment_schedule.dart';

const plan = RecruitmentScheduleModel({
  'applications_open': '2026-11-06', 'applications_close': '2026-11-09',
  'screening_start': '2026-11-09', 'screening_end': '2026-11-14',
  'screening_results': '2026-11-15', 'interviews_start': '2026-11-16',
  'interviews_end': '2026-11-21', 'final_results': '2026-11-24',
});

void main() {
  testWidgets('the team can load the November plan and correct invalid dates before saving', (tester) async {
    RecruitmentScheduleModel? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RecruitmentScheduleEditor(
        template: plan, enabled: true, onSave: (value) async { saved = value; },
      ),
    ))));
    await tester.tap(find.text('Calendrier de la campagne'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('load-november-schedule')));
    await tester.tap(find.byKey(const Key('load-november-schedule')));
    await tester.pumpAndSettle();
    final firstResult = find.byKey(const Key('schedule-screening_results'));
    expect(tester.widget<TextFormField>(firstResult).controller!.text, '15/11/2026');
    final save = find.byKey(const Key('save-recruitment-schedule'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved?.dates['applications_open'], '2026-11-06');
    expect(saved?.dates['applications_close'], '2026-11-09');
    expect(saved?.dates['final_results'], '2026-11-24');

    saved = null;
    final finalResult = find.byKey(const Key('schedule-final_results'));
    await tester.ensureVisible(finalResult);
    await tester.enterText(finalResult, '31/11/2026');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.textContaining('Renseigne une date valide'), findsWidgets);
    await tester.ensureVisible(finalResult);
    await tester.enterText(finalResult, '20/11/2026');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.textContaining('Les dates doivent suivre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar dates stay readable on a narrow screen in light and dark modes at 200 percent', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!,
        ),
        home: const Scaffold(body: SingleChildScrollView(child: Padding(
          padding: EdgeInsets.all(12), child: RecruitmentScheduleCard(schedule: plan),
        ))),
      ));
      await tester.pump();
      expect(find.textContaining('15/11/2026', findRichText: true), findsOneWidget);
      expect(find.textContaining('24/11/2026', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the calendar editor remains usable on a narrow screen at 200 percent', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(18),
        child: RecruitmentScheduleEditor(template: plan, enabled: true, onSave: (_) async {}),
      ))),
    ));
    await tester.tap(find.text('Calendrier de la campagne'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('load-november-schedule')));
    await tester.tap(find.byKey(const Key('load-november-schedule')));
    await tester.pumpAndSettle();
    final last = find.byKey(const Key('schedule-final_results'));
    await tester.ensureVisible(last);
    expect(tester.widget<TextFormField>(last).controller!.text, '24/11/2026');
    expect(tester.takeException(), isNull);
  });
}
