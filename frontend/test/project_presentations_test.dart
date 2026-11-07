import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/models/project_portfolio_models.dart';
import 'package:frontend/features/archives/screens/archive_detail_screens.dart';
import 'package:frontend/features/archives/services/archives_gateway.dart';
import 'package:frontend/features/projects/widgets/project_detail_widgets.dart';
import 'package:frontend/features/archives/models/archive_models.dart';
import 'package:frontend/shared/models/project_presentation.dart';
import 'package:frontend/shared/ui/project_reference_documents.dart';

const _reference = ProjectReferenceDocument(
  title: 'Mën Nañ — présentation et bilan',
  asset: 'assets/documents/men-nan-presentation.pdf',
  description:
      'Les territoires, les formations et les perspectives de développement.',
  filename: 'Men-Nan-presentation-et-bilan.pdf',
  pages: 9,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the four bundled files are PDF documents', () async {
    for (final asset in [
      'assets/documents/aquatus-synthese.pdf',
      'assets/documents/shery-presentation.pdf',
      'assets/documents/men-nan-presentation.pdf',
      'assets/documents/terrasen-world-cup.pdf',
    ]) {
      final data = await rootBundle.load(asset);
      expect(
        ascii.decode(data.buffer.asUint8List(data.offsetInBytes, 5)),
        '%PDF-',
      );
      expect(data.lengthInBytes, greaterThan(300000));
    }
  });

  test('the parser rejects paths outside the bundled project files', () {
    expect(
      ProjectReferenceDocument.parse([
        {'asset': '../secret.pdf'},
        {'asset': 'https://example.test/a.pdf'},
        {'asset': _reference.asset, 'title': _reference.title, 'pages': 9},
      ]).single.asset,
      _reference.asset,
    );
  });

  test('archives and current projects read the same presentation contract', () {
    final presentation = {
      'id': 'aquatus',
      'name': 'Aquatus',
      'description': 'Le projet associe poissons et cultures.',
      'impact_summary': 'Un pilote à préparer.',
      'sections': [
        {
          'title': 'Le terrain',
          'body': 'Les participantes prennent part à la conception.',
        },
      ],
      'documents': [
        {'title': _reference.title, 'asset': _reference.asset, 'pages': 9},
      ],
    };
    final current = ProjectModel.fromJson({
      'id': 'current',
      'name': 'Aquatus',
      'presentation': presentation,
    });
    final archive = HistoricalProjectModel.fromJson({
      'id': 'aquatus',
      'name': 'Aquatus',
      'presentation': presentation,
      'reference_documents': presentation['documents'],
    });
    expect(current.presentation!.sections.single.title, 'Le terrain');
    expect(
      archive.presentation!.sections.single.body,
      current.presentation!.sections.single.body,
    );
    expect(archive.referenceDocuments.single.asset, _reference.asset);
    expect(ProjectModel.fromJson({'name': 'Nouveau'}).presentation, isNull);
  });

  final catalog =
      (jsonDecode(
                File(
                  '../backend/app/services/project_presentations.json',
                ).readAsStringSync(),
              )
              as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
  for (final row in catalog) {
    for (final dark in [false, true]) {
      testWidgets("complete narrative for ${row['name']} dark=$dark", (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(360, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final project = ProjectModel.fromJson({
          'id': 'current-project',
          'name': row['name'],
          'presentation': row,
          'problem_statement': 'Besoin de l’équipe actuelle',
          'solution': 'Travail en cours',
        });
        final item = ProjectPortfolioItem(
          project: project,
          members: const [],
          tasks: const [],
          impact: null,
          nextAction: null,
          teamUnavailable: false,
          tasksUnavailable: false,
          impactUnavailable: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(body: ProjectOverviewSection(item: item)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('L’aventure du projet'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('L’aventure du projet'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Résultats et perspectives'),
          240,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Résultats et perspectives'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final archive = HistoricalProjectModel.fromJson({
          'id': row['id'],
          'name': row['name'],
          'description': row['description'],
          'problem': row['problem'],
          'solution': row['solution'],
          'impact_summary': row['impact_summary'],
          'story_sections': row['sections'],
          'reference_documents': row['documents'],
          'presentation': row,
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: HistoricalProjectDetailScreen(
                projectId: row['id'].toString(),
                gateway: _ArchiveGateway(archive),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if ((row['documents'] as List).isNotEmpty) {
          await tester.scrollUntilVisible(
            find.text('Les dossiers du projet'),
            240,
            maxScrolls: 120,
          );
          expect(find.text('Lire le dossier'), findsOneWidget);
        } else {
          expect(find.text('Lire le dossier'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Impact et héritage'),
            240,
            maxScrolls: 120,
          );
          expect(find.text('Impact et héritage'), findsWidgets);
        }

        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final width in [360.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'project files remain usable at $width $brightness text $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 1000));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(
                    child: ProjectReferenceDocuments(documents: [_reference]),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('PDF · 9 pages'), findsOneWidget);
            expect(find.text('Lire le dossier'), findsOneWidget);
            expect(tester.takeException(), isNull);
            // Open/close the full screen shell without relying on a mocked PDF renderer.
            await tester.tap(find.text('Lire le dossier'));
            await tester.pump();
            expect(find.byTooltip('Fermer le dossier'), findsOneWidget);
            await tester.tap(find.byTooltip('Fermer le dossier'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Lire le dossier'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'bundled documents remain available if the other documents fail to load',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProjectDocumentsSection(
              documents: null,
              unavailable: true,
              referenceDocuments: [_reference],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lire le dossier'), findsOneWidget);
      expect(find.text('Documents indisponibles'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a missing bundled file has a readable error and a close button',
    (tester) async {
      const missing = ProjectReferenceDocument(
        title: 'Dossier',
        asset: 'assets/documents/missing.pdf',
        description: '',
        filename: 'dossier.pdf',
        pages: 1,
      );
      await tester.pumpWidget(
        const MaterialApp(home: ProjectReferencePdfViewer(document: missing)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Le dossier n’a pas pu être ouvert.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.byTooltip('Fermer le dossier'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ArchiveGateway extends ApiArchivesGateway {
  final HistoricalProjectModel project;
  _ArchiveGateway(this.project);
  @override
  Future<HistoricalProjectModel> getHistoricalProject(String id) async =>
      project;
}
