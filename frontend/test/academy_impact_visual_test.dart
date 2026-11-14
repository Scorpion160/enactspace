import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/academy/widgets/academy_illustration.dart';
import 'package:frontend/features/impact/models/impact_models.dart';
import 'package:frontend/features/impact/screens/impact_dashboard_screen.dart';
import 'package:frontend/features/impact/services/impact_gateway.dart';
import 'package:frontend/features/impact/services/impact_service.dart';
import 'package:frontend/shared/ui/heritage_photo.dart';

class _ImpactVisualGateway implements ImpactGateway {
  @override
  Future<ImpactDashboardData> loadDashboard() async => ImpactDashboardData(
    organization: ImpactService().organizationFromJson({}, []),
    historicalImpact: const HistoricalImpactModel(
      sourceLabel: 'Fixture',
      developedProducts: 39,
      touchedSdgs: 11,
      createdJobs: 200,
      createdJobsIsMinimum: true,
      peopleTrained: 1597,
      workHours: 36640,
      plantedTrees: 1425,
      fieldKilometers: 8949,
      revenueUsd2021To2022: 173193,
      dimbaliRevenueUsd2021To2022: 125521,
      menNanRevenueUsd2021To2022: 47672,
      beneficiaryIncomeIncreasePct: 77,
      malnutritionBeforePct: 15,
      malnutritionAfterPct: 0,
      impactedLives: 150000,
      impactedLivesIsMinimum: true,
      emblematicProjects: [
        'Dimbali',
        'Mën Nañ',
        'SHERY',
        'Terrasen',
        'Aquatus',
        'Deconaane',
        'Javelisel',
      ],
      distinctions: [
        'Champion national 2017',
        'Champion national 2018',
        'Demi-finaliste Enactus World Cup 2018',
      ],
    ),
    projects: [],
    enacteurs: [],
    poles: [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['ENACTSPACE_VISUAL_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  for (final item in find.byType(Image).evaluate()) {
    final widget = item.widget as Image;
    await tester.runAsync(() => precacheImage(widget.image, item));
  }
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final weight in FontWeight.values) {
      GoogleFonts.poppins(fontWeight: weight);
      GoogleFonts.poppins(fontWeight: weight, fontStyle: FontStyle.italic);
    }
    await GoogleFonts.pendingFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test(
    'each of the 16 concept drawings produces visible pixels without an icon font',
    () async {
      for (final drawing in AcademyDrawing.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        AcademyConceptPainter(
          drawing,
          Colors.white,
        ).paint(canvas, const Size(88, 70));
        final picture = recorder.endRecording();
        final image = await picture.toImage(88, 70);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var pixels = 0;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) > 0) {
            pixels++;
          }
        }
        expect(pixels, greaterThan(250), reason: drawing.name);
        image.dispose();
        picture.dispose();
      }
    },
  );
  for (final scenario in [
    (360.0, 1.6, true),
    (768.0, 1.0, false),
    (1440.0, 1.0, true),
  ]) {
    for (final course in [
      'Social business avec Muhammad Yunus',
      'Mesurer les résultats',
      'Étude de cas : Aquatus',
      "Travail d'équipe et transmission",
      'Brainstorming et idéation',
    ]) {
      testWidgets(
        'all illustrations and photos: $course ${scenario.$1} scale ${scenario.$2}',
        (tester) async {
          tester.view.physicalSize = Size(scenario.$1, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: scenario.$3 ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!,
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: AcademyIllustration(
                          courseTitle: course,
                          lessonTitle: 'Les concepts essentiels',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find
                .byType(CustomPaint)
                .evaluate()
                .where(
                  (e) =>
                      (e.widget as CustomPaint).painter
                          is AcademyConceptPainter,
                ),
            hasLength(4),
          );
          expect(find.byType(HeritagePhoto), findsOneWidget);
          expect(
            find.text('La photo est momentanément indisponible.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          if (course.startsWith('Social business')) {
            await _capture(tester, key, 'academy-${scenario.$1.toInt()}');
          }
        },
      );
    }
    testWidgets(
      'Impact stories readable, illustrated and navigable ${scenario.$1}',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$1, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: scenario.$3 ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: ImpactDashboardScreen(gateway: _ImpactVisualGateway()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Ce que nous avons construit ensemble'),
          180,
        );
        expect(
          find.text('Ce que nous avons construit ensemble'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Mémoire institutionnelle validée'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await _capture(tester, key, 'impact-top-${scenario.$1.toInt()}');
        for (final asset in [
          'dimbali-gie-favec',
          'haffe-2025-parcelles',
          'niaguiss-2025-produits',
          'mobigel-prototypes',
        ]) {
          final button = find.byKey(ValueKey('impact-story-$asset'));
          await tester.scrollUntilVisible(button, 200);
          await tester.pumpAndSettle();
          if (asset == 'dimbali-gie-favec') {
            await _capture(
              tester,
              key,
              'impact-stories-${scenario.$1.toInt()}',
            );
          }
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.byType(HeritagePhoto), findsWidgets);
          expect(
            find.text('La photo est momentanément indisponible.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
