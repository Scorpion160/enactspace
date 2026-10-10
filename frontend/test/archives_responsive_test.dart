import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/archives/models/archive_models.dart';
import 'package:frontend/features/archives/models/memory_timeline_models.dart';
import 'package:frontend/features/archives/screens/archives_center_screen.dart';
import 'package:frontend/features/archives/screens/archives_center_sections.dart';
import 'package:frontend/features/archives/screens/archive_visuals.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';

final _home = ArchivesHomeData(
  media: const [
    ArchiveMediaModel(
      id: 'trophy-2016',
      title: 'Trophées Enactus Sénégal 2016',
      mediaType: 'photo',
      year: 2016,
      description: 'Vice Champion National et Premier Prix Fondation Sonatel.',
      imageAsset: 'assets/img/prix_enactus_national_2016.png',
      sourceLabel: 'Photothèque Enactus ESP',
    ),
    ArchiveMediaModel(
      id: 'uhodari',
      title: 'Trophée UHODARI 2016',
      mediaType: 'photo',
      year: 2016,
      imageAsset: 'assets/img/prix_uhodari_2016.png',
      sourceLabel: 'Photothèque Enactus ESP',
    ),
    ArchiveMediaModel(
      id: 'polytech',
      title: 'Double victoire à Polytech’Innovation 2025',
      mediaType: 'photo',
      year: 2025,
      description: 'Terrasen, premier prix, et Aquatus, deuxième prix.',
      imageAsset: 'assets/heritage/polytech-innovation-2025.jpg',
      sourceLabel: 'Site officiel Enactus ESP',
      sourceUrl:
          'https://www.enactusesp.com/stories/concours-polytech-innovation-2025',
    ),
  ],
);

class _Gateway extends ApiArchivesGateway {
  @override
  Future<ArchivePermissions> getPermissions() async =>
      const ArchivePermissions();
  @override
  Future<MemoryTimelinePage> getTimeline({
    MemoryTimelineFilters filters = const MemoryTimelineFilters(),
    String? cursor,
    int limit = 25,
  }) async => const MemoryTimelinePage(items: []);
  @override
  Future<ArchivesHomeData> loadHome() async => _home;
}

Widget _app(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: widget!,
  ),
  home: Scaffold(
    body: RepaintBoundary(key: const Key('heritage_scene'), child: child),
  ),
);

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'gallery ${size.width.toInt()} ${dark ? "dark" : "light"} stays inside viewport',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            _app(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ArchivesCollectionCenter(
                  sectionLabel: 'Médias',
                  home: _home,
                  gateway: _Gateway(),
                ),
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(HeritageImage), findsNWidgets(3));
          expect(tester.takeException(), isNull);
          for (final image in tester.widgetList<HeritageImage>(
            find.byType(HeritageImage),
          )) {
            expect(image.asset, startsWith('assets/'));
          }
        },
      );
    }
  }
  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('gallery ${size.width.toInt()} text 200 percent', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ArchivesCollectionCenter(
              sectionLabel: 'Médias',
              home: _home,
              gateway: _Gateway(),
            ),
          ),
          dark: true,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('trophy opens full photo and closes without changing data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const HeritageImage(
          asset: 'assets/img/prix_enactus_national_2016.png',
          title: 'Trophées 2016',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HeritageImage));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer la photo'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'member sees approved heritage when unfiltered timeline is empty',
    (tester) async {
      await tester.pumpWidget(_app(ArchivesScreen(gateway: _Gateway())));
      await tester.pumpAndSettle();
      expect(find.text('Mémoire historique Enactus ESP'), findsWidgets);
      expect(find.text('Vue d’ensemble'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mobile section selector reaches illustrated gallery', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HistoricalMemoryContents(home: _home, gateway: _Gateway()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historical_section_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Médias').last);
    await tester.pumpAndSettle();
    expect(find.byType(HeritageImage), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
