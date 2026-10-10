import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/archives/models/archive_models.dart';
import 'package:frontend/features/archives/screens/archive_detail_screens.dart';
import 'package:frontend/features/archives/screens/archives_center_sections.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';

const _body =
    'Le concours réunit dix projets sélectionnés dans le cadre du soixantenaire de l’ESP. Terrasen remporte le premier prix et Aquatus le deuxième prix. Ces deux solutions abordent la production alimentaire par des approches complémentaires, le micro-jardinage et l’aquaponie.';
final _home = ArchivesHomeData(
  projects: const [
    HistoricalProjectModel(
      id: 'aquatus',
      name: 'AQUATUS',
      description: 'Le projet associe élevage de poissons et culture hors-sol.',
    ),
  ],
  competitions: const [
    ArchiveCompetitionModel(
      id: 'polytech',
      name: 'Polytech’Innovation 2025',
      year: 2025,
      result: 'Premier et deuxième prix',
      projectIds: ['aquatus'],
      storySections: [
        ArchiveStorySection(title: 'Le cadre du concours', body: _body),
      ],
    ),
  ],
  statistics: const [
    HistoricalStatisticModel(
      id: 'lives',
      metricKey: 'lives',
      label: 'Vies impactées',
      value: 150000,
      status: 'validated',
    ),
  ],
);

class _Gateway extends ApiArchivesGateway {
  @override
  Future<ArchivesHomeData> loadHome() async => _home;
}

void main() {
  for (final width in [360.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'competition explains its context and linked projects at $width text $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: ArchiveCollectionDetailScreen(
                  recordId: 'polytech',
                  competition: true,
                  gateway: _Gateway(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(_body), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Les projets à découvrir'),
            200,
          );
          expect(find.text('AQUATUS'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'overview keeps history and figures without repeated validation labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchivesOverview(home: _home, gateway: _Gateway()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('L’aventure Enactus ESP'), findsOneWidget);
      expect(find.textContaining('validé'), findsNothing);
      expect(find.text('Historique validé'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
