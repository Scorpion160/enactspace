import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/archives/models/archive_models.dart';
import 'package:frontend/features/archives/screens/archive_minutes_screen.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';

const _first = ArchiveMediaModel(
  id: 'minute-one',
  title: 'Oser essayer',
  mediaType: 'minute_enacteur',
  speaker: 'Aïta Ndir DIA',
  theme: 'Curiosité',
  year: 2020,
  description: 'Une réflexion sur les possibilités d’apprendre.',
  challenge: 'Essaie une petite chose cette semaine.',
  originalText: 'Le maître mot : PROFITER !',
  sourceLabel: 'Thread Enactus ESP',
);
const _second = ArchiveMediaModel(
  id: 'minute-two',
  title: 'Se faire confiance',
  mediaType: 'minute_enacteur',
  speaker: 'Ibrahima CISSE',
  theme: 'Confiance',
  description: 'Avancer sans se comparer.',
  sourceLabel: 'Photothèque Enactus ESP',
);

class _Gateway extends ApiArchivesGateway {
  @override
  Future<ArchivesHomeData> loadHome() async =>
      const ArchivesHomeData(media: [_first, _second]);
}

void main() {
  for (final width in [360.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Minute lisible à $width px et texte $scale', (tester) async {
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
            home: ArchiveMinutesScreen(
              minuteId: 'minute-one',
              gateway: _Gateway(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Aïta Ndir DIA'), findsOneWidget);
        expect(find.byTooltip('Retour'), findsOneWidget);
        await tester.ensureVisible(find.text('Lire les extraits conservés'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lire les extraits conservés'));
        await tester.pumpAndSettle();
        expect(find.text('Le maître mot : PROFITER !'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('recherche une voix par son nom et filtre par thème', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ArchiveMinutesScreen(gateway: _Gateway())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Oser essayer'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('minute_search')), 'Ibrahima');
    await tester.pumpAndSettle();
    expect(find.text('Oser essayer'), findsNothing);
    expect(find.text('Se faire confiance'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Curiosité'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune Minute'), findsOneWidget);
  });
}
