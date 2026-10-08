import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/settings/screens/team_years_screen.dart';
import 'package:frontend/features/settings/services/team_years_gateway.dart';
import 'package:frontend/features/members/widgets/searchable_member_picker.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/core/theme/app_theme.dart';

class FakeYears implements TeamYearsGateway {
  final bool manager;
  int activations = 0, creations = 0;
  String? expected;
  bool fail = false;
  FakeYears({this.manager = true});
  List<Map<String, dynamic>> rows = [
    {
      'id': 'new',
      'name': 'Année 2026-2027',
      'start_date': '2026-10-01',
      'end_date': '2027-09-30',
      'is_current': false,
      'archived': false,
    },
    {
      'id': 'old',
      'name': 'Année 2025-2026',
      'start_date': '2025-10-01',
      'end_date': '2026-09-30',
      'is_current': true,
      'archived': false,
    },
  ];
  @override
  Future<bool> canManage() async => manager;
  @override
  Future<List<Map<String, dynamic>>> loadYears() async => rows;
  @override
  Future<void> createYear(Map<String, dynamic> values) async {
    creations++;
  }

  @override
  Future<void> activateYear(String id, String? expectedCurrentId) async {
    activations++;
    expected = expectedCurrentId;
    if (fail) {
      throw StateError('private SQL URL');
    }
    rows = [
      for (final row in rows)
        {...row, 'is_current': row['id'] == id, 'archived': row['id'] != id},
    ];
  }
}

void main() {
  for (final width in [360.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Alumni picker separates label and hint at $width dark=$dark',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          String? selected;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: StatefulBuilder(
                    builder: (context, setState) => SearchableMemberPickerField(
                      label: 'Profil Alumni',
                      hintText: 'Choisir un Alumni',
                      value: selected,
                      members: const [
                        MemberModel(
                          id: 'alumni',
                          email: 'alumni@example.test',
                          fullName: 'Profil de test',
                          status: 'alumni',
                        ),
                      ],
                      onChanged: (value) => setState(() => selected = value),
                    ),
                  ),
                ),
              ),
            ),
          );
          final label = find.text('Profil Alumni');
          final hint = find.text('Choisir un Alumni');
          expect(
            tester.getRect(label).bottom,
            lessThan(tester.getRect(hint).top),
          );
          await tester.tap(hint);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Profil de test'));
          await tester.pumpAndSettle();
          expect(selected, 'alumni');
          expect(find.text('Choisir un Alumni'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Year opening requires confirmation and passes the previous year',
    (tester) async {
      final gateway = FakeYears();
      await tester.binding.setSurfaceSize(const Size(900, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: TeamYearsScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir cette année'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(gateway.activations, 0);
      await tester.tap(find.text('Ouvrir cette année'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir l’année'));
      await tester.pumpAndSettle();
      expect(gateway.activations, 1);
      expect(gateway.expected, 'old');
      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Année courante'), findsOneWidget);
      expect(find.text('Ouvrir cette année'), findsNothing);
    },
  );
  testWidgets('Read-only years stay usable on a narrow dark screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: TeamYearsScreen(gateway: FakeYears(manager: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-team-year')), findsNothing);
    expect(find.text('Ouvrir cette année'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Failed year opening exposes a readable error and leaves the year unchanged',
    (tester) async {
      final gateway = FakeYears()..fail = true;
      await tester.binding.setSurfaceSize(const Size(900, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: TeamYearsScreen(gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir cette année'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir l’année'));
      await tester.pumpAndSettle();
      expect(find.textContaining('L’ouverture n’a pas abouti'), findsOneWidget);
      expect(find.textContaining('private SQL'), findsNothing);
      expect(gateway.rows.last['is_current'], true);
    },
  );
  testWidgets('Empty year form validates without sending a write', (
    tester,
  ) async {
    final gateway = FakeYears();
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: TeamYearsScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-team-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer l’année'));
    await tester.pumpAndSettle();
    expect(find.text('Indiquez le nom de l’année.'), findsOneWidget);
    expect(find.text('Choisissez une date de début.'), findsOneWidget);
    expect(gateway.creations, 0);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
  });
}
