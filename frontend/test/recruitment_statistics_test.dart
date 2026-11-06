import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/screens/recruitment_statistics_screen.dart';

Map<String, dynamic> figures({bool jury = false, String id = 'campaign-a'}) => {
  'campaign_id': id,
  'campaigns': [
    {'id': 'campaign-a', 'title': 'Recrutement Enactus ESP 2026–2027'},
    {'id': 'campaign-b', 'title': 'Campagne précédente'},
  ],
  'can_access_applications': jury,
  'total': id == 'campaign-a' ? 500 : 100,
  'breakdowns': {
    for (final key in ['department', 'study_level', 'study_year', 'promotion', 'discovery_channel'])
      key: [
        {'label': key == 'department' ? 'Génie électrique' : 'Réseaux sociaux', 'count': 250, 'percentage': 50.0},
      ],
  },
};

void main() {
  testWidgets('members see totals and can switch campaigns without a dossier action', (tester) async {
    final requested = <String?>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RecruitmentStatisticsScreen(
      loader: (id) async { requested.add(id); return figures(id: id ?? 'campaign-a'); },
    ))));
    await tester.pumpAndSettle();
    expect(find.text('500'), findsOneWidget);
    expect(find.text('Ouvrir les candidatures'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Campagne précédente').last);
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(requested, [null, 'campaign-b']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jurors retain an entry to their dossiers', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RecruitmentStatisticsScreen(
      loader: (_) async => figures(jury: true),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir les candidatures'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('campaign figures remain readable at 200 percent in ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
        home: Scaffold(body: RecruitmentStatisticsScreen(loader: (_) async => figures())),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Par département'), 180);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Comment ont-ils connu Enactus ESP ?'), 200);
      expect(tester.takeException(), isNull);
    });
  }
}
