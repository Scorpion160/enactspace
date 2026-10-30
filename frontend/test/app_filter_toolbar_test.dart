import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/academy/models/academy_models.dart';
import 'package:frontend/features/academy/screens/academy_home_screen.dart';
import 'package:frontend/features/academy/services/academy_gateway.dart';
import 'package:frontend/shared/ui/app_filter_toolbar.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() async {
    if (const String.fromEnvironment('FILTER_CAPTURE_DIR').isEmpty) return;
    for (final weight in FontWeight.values) {
      GoogleFonts.poppins(fontWeight: weight);
      GoogleFonts.poppins(fontWeight: weight, fontStyle: FontStyle.italic);
    }
    await GoogleFonts.pendingFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'toolbar $width text=$scale dark=$dark preserves every choice',
          (tester) async {
            final search = TextEditingController();
            addTearDown(search.dispose);
            String level = 'all';
            String category = 'all';
            String status = 'Tous';
            await _pump(
              tester,
              width: width,
              scale: scale,
              dark: dark,
              child: StatefulBuilder(
                builder: (context, update) => AppFilterToolbar(
                  key: const Key('catalogue-toolbar'),
                  search: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une formation…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  quickFilters: [
                    for (final label in [
                      'Tous',
                      'Obligatoires',
                      'En cours',
                      'Terminés',
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: status == label,
                        onSelected: (_) => update(() => status = label),
                      ),
                  ],
                  filters: [
                    DropdownButtonFormField<String>(
                      key: const Key('filter-level'),
                      initialValue: level,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Niveau'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Tous niveaux'),
                        ),
                        DropdownMenuItem(
                          value: 'advanced',
                          child: Text('Avancé'),
                        ),
                      ],
                      onChanged: (value) => update(() => level = value!),
                    ),
                    DropdownButtonFormField<String>(
                      key: const Key('filter-category'),
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Toutes catégories'),
                        ),
                        DropdownMenuItem(
                          value: 'field',
                          child: Text('Terrain'),
                        ),
                      ],
                      onChanged: (value) => update(() => category = value!),
                    ),
                  ],
                  activeFilterCount:
                      (level == 'all' ? 0 : 1) + (category == 'all' ? 0 : 1),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await _capture(
                tester,
                'filtres-${dark ? 'dark' : 'light'}-${width.toInt()}-compact',
              );
            }
            if (width == 1440 && scale == 1) {
              // A single compact row replaces the old two-line status block.
              expect(
                tester
                    .getSize(find.byKey(const Key('catalogue-toolbar')))
                    .height,
                lessThanOrEqualTo(64),
              );
              expect(find.byTooltip('Afficher les filtres'), findsNothing);
            } else {
              final closedHeight = tester
                  .getSize(find.byKey(const Key('catalogue-toolbar')))
                  .height;
              expect(find.byKey(const Key('filter-level')), findsNothing);
              await tester.tap(find.byTooltip('Afficher les filtres'));
              await tester.pumpAndSettle();
              expect(
                tester
                    .getSize(find.byKey(const Key('catalogue-toolbar')))
                    .height,
                greaterThan(closedHeight),
              );
            }
            if (scale == 1) {
              await _capture(
                tester,
                'filtres-${dark ? 'dark' : 'light'}-${width.toInt()}-ouverts',
              );
            }
            await tester.tap(find.byKey(const Key('filter-level')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Avancé').last);
            await tester.pumpAndSettle();
            expect(level, 'advanced');
            expect(tester.takeException(), isNull);
            final toggle = find.byTooltip('Masquer les filtres');
            if (toggle.evaluate().isNotEmpty) {
              await tester.tap(toggle);
              await tester.pumpAndSettle();
              expect(find.byKey(const Key('filter-level')), findsNothing);
              expect(find.byType(TextField), findsOneWidget);
              await tester.enterText(find.byType(TextField), 'Enactus');
              await tester.tap(find.byTooltip('Afficher les filtres'));
              await tester.pumpAndSettle();
              expect(level, 'advanced');
              expect(search.text, 'Enactus');
              expect(find.text('Avancé'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'folding preserves an unsubmitted advanced text value and removes focus',
    (tester) async {
      await _pump(
        tester,
        child: AppFilterToolbar(
          search: const TextField(key: Key('search')),
          filters: const [TextField(key: Key('advanced-text'))],
        ),
      );
      await tester.tap(find.byTooltip('Afficher les filtres'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('advanced-text')),
        'Promotion 2025-2026',
      );
      await tester.tap(find.byTooltip('Masquer les filtres'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advanced-text')), findsNothing);
      final hiddenEditable = find.descendant(
        of: find.byKey(const Key('advanced-text'), skipOffstage: false),
        matching: find.byType(EditableText, skipOffstage: false),
        skipOffstage: false,
      );
      expect(
        tester.widget<EditableText>(hiddenEditable).focusNode.hasFocus,
        isFalse,
      );
      await tester.tap(find.byTooltip('Afficher les filtres'));
      await tester.pumpAndSettle();
      expect(find.text('Promotion 2025-2026'), findsOneWidget);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'Academy search, status and advanced filters actually narrow the catalogue dark=$dark',
      (tester) async {
        await _pump(
          tester,
          width: 390,
          dark: dark,
          child: AcademyHomeScreen(gateway: _AcademyGateway()),
        );
        final outer = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(AppFilterToolbar),
          220,
          scrollable: outer,
        );
        await tester.pumpAndSettle();
        await _capture(
          tester,
          'academy-catalogue-${dark ? 'dark' : 'light'}-390',
        );
        await tester.enterText(find.byType(TextField), 'terrain');
        await tester.pumpAndSettle();
        expect(find.text('Terrain unique'), findsOneWidget);
        expect(find.text('Communication unique'), findsNothing);
        await tester.tap(find.byTooltip('Effacer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Obligatoires'));
        await tester.pumpAndSettle();
        expect(find.text('Terrain unique'), findsNothing);
        expect(find.text('Communication unique'), findsOneWidget);
        await tester.tap(find.text('Tous'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Afficher les filtres'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Tous niveaux'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Avancé').last);
        await tester.pumpAndSettle();
        expect(find.text('Terrain unique'), findsOneWidget);
        expect(find.text('Communication unique'), findsNothing);
        await tester.tap(find.byTooltip('Effacer les filtres'));
        await tester.pumpAndSettle();
        expect(find.text('Communication unique'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _AcademyGateway implements AcademyGateway {
  @override
  Future<AcademyHomeData> loadHome() async => AcademyHomeData(
    courses: [
      for (final required in [false, true])
        AcademyCourseModel(
          id: required ? 'communication' : 'terrain',
          title: required ? 'Communication unique' : 'Terrain unique',
          category: required ? 'Communication' : 'Terrain',
          level: required ? 'debutant' : 'avance',
          description: 'Une formation pour apprendre en agissant.',
          durationMinutes: 20,
          points: 0,
          isRequired: required,
          lessons: const [],
          quiz: const AcademyQuizModel(
            id: '',
            title: '',
            category: '',
            level: '',
            timeLimitMinutes: 0,
            questions: [],
          ),
        ),
    ],
    paths: const [],
    badges: const [],
    caseStudies: const [],
    progress: const AcademyProgressModel(
      completedLessons: 0,
      totalLessons: 0,
      passedQuizzes: 0,
      totalQuizzes: 0,
      points: 0,
      rank: 0,
      monthlyProgress: 0,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  double width = 390,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: RepaintBoundary(
            key: const Key('filter-capture'),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('FILTER_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('filter-capture')),
  );
  for (final element in find.byType(Image).evaluate()) {
    final image = element.widget as Image;
    await tester.runAsync(() => precacheImage(image.image, element));
  }
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Capture indisponible');
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
