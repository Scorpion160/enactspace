import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/screens/internal/recruitment_team_guide_screen.dart';

void main() {
  testWidgets('the team can find the guide and read the proposed admission mail', (tester) async {
    final raw = await tester.runAsync(() => rootBundle.loadString('assets/documents/recruitment_team_guide.json'));
    final content = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
    await tester.pumpWidget(MaterialApp(home: RecruitmentTeamGuideScreen(content: content)));
    await tester.pumpAndSettle();
    expect(find.text('Le guide de l’équipe de recrutement'), findsOneWidget);
    await tester.tap(find.text('Les mails'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Admission finale');
    await tester.pumpAndSettle();
    final admission = find.widgetWithText(ExpansionTile, 'Admission finale');
    await tester.ensureVisible(admission);
    await tester.tap(admission);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is SelectableText &&
      (widget.data ?? '').contains('Bonne nouvelle : ta candidature est retenue')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the guide remains readable on a narrow screen with large text', (tester) async {
    final raw = await tester.runAsync(() => rootBundle.loadString('assets/documents/recruitment_team_guide.json'));
    final content = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
        home: RecruitmentTeamGuideScreen(content: content)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Les mails'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
