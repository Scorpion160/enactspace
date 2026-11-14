// Synthetic screenshots for reviewing the recruitment UI before deployment.
// No real EnactSpace candidate data, authentication or production API used.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/screens/recruitment_statistics_screen.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_comparison_panel.dart';

const _captureKey = Key('recruitment-qa-capture');

Map<String, dynamic> _syntheticCandidate(
  String code,
  double? score,
  bool ready,
  String department,
  String level,
  int completed,
  int required,
  double? spread,
) => <String, dynamic>{
  'application_id': code,
  'anonymous_code': code,
  'score': score,
  'jury_average_20': score == null ? null : score / 5,
  'jury_spread_20': spread == null ? null : spread / 5,
  'jury_score_source': 'rubric',
  'ready': ready,
  'department': department,
  'study_level': level,
  'review_count': completed,
  'required_reviews': required,
  'spread': spread,
  'decision': null,
};

final _syntheticRows = <Map<String, dynamic>>[
  _syntheticCandidate(
    'Candidat #A001',
    92,
    true,
    'Génie électrique',
    'DIC2',
    4,
    4,
    25,
  ),
  _syntheticCandidate(
    'Candidat #A002',
    86,
    true,
    'Génie civil',
    'DIC1',
    3,
    3,
    8,
  ),
  _syntheticCandidate(
    'Candidat #A003',
    79,
    true,
    'Gestion',
    'Licence2',
    3,
    3,
    12,
  ),
  _syntheticCandidate(
    'Candidat #A004',
    74,
    true,
    'Génie informatique',
    'DIC2',
    3,
    3,
    7,
  ),
  _syntheticCandidate(
    'Candidat #A005',
    88,
    false,
    'Gestion',
    'Licence1',
    2,
    3,
    15,
  ),
  _syntheticCandidate(
    'Candidat #A006',
    null,
    false,
    'GCBA',
    'DUT1',
    0,
    3,
    null,
  ),
];

class _SyntheticRecruitmentStatistics implements RecruitmentStatisticsGateway {
  @override
  Future<Map<String, dynamic>> fetch({String? campaignId}) async => {
    'campaigns': [
      {'id': 'synthetic-campaign', 'title': 'Campagne de démonstration'},
    ],
    'campaign_id': 'synthetic-campaign',
    'can_access_applications': true,
    'total': 12,
    'selection_progress': {
      'stage': 'screening',
      'ready': 5,
      'not_ready': 7,
      'not_reviewed': 2,
      'reviewed_at_least_once': 10,
      'reviews_recorded': 27,
      'high_disagreement': 3,
      'decisions_prepared': 2,
      'additional_reviews': 11,
      'minimum_reviews': 3,
      'disagreement_threshold': 20,
      'screening_published': false,
    },
    'breakdowns': {
      'department': [
        {'label': 'Génie électrique', 'count': 4, 'percentage': 33.3},
        {'label': 'Gestion', 'count': 3, 'percentage': 25.0},
        {'label': 'Génie civil', 'count': 3, 'percentage': 25.0},
        {'label': 'Génie informatique', 'count': 2, 'percentage': 16.7},
      ],
      'study_level': [
        {'label': 'DIC1', 'count': 5, 'percentage': 41.7},
        {'label': 'DIC2', 'count': 4, 'percentage': 33.3},
        {'label': 'Licence2', 'count': 3, 'percentage': 25.0},
      ],
      'study_year': [],
      'promotion': [],
      'discovery_channel': [],
    },
  };
}

Future<void> _saveScreenshot(WidgetTester tester, String filename) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  expect(boundary.debugNeedsPaint, isFalse);
  final Uint8List? bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) {
        throw StateError('Unable to encode synthetic screenshot');
      }
      return encoded.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  expect(bytes, isNotNull);
  final directory = Directory('build/recruitment-visual-review');
  directory.createSync(recursive: true);
  File('${directory.path}/$filename.png').writeAsBytesSync(bytes!);
}

Widget _comparisonFixture(ThemeMode mode) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'QaReadableSans',
    colorSchemeSeed: const Color(0xff007987),
  ),
  darkTheme: ThemeData(
    useMaterial3: true,
    fontFamily: 'QaReadableSans',
    colorSchemeSeed: const Color(0xff007987),
    brightness: Brightness.dark,
  ),
  themeMode: mode,
  home: RepaintBoundary(
    key: _captureKey,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'RECETTE VISUELLE — DONNÉES FICTIVES (AUCUN CANDIDAT RÉEL)',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RecruitmentComparisonPanel(
                  screening: true,
                  rows: _syntheticRows,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Widget _statisticsFixture(ThemeMode mode) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'QaReadableSans',
    colorSchemeSeed: const Color(0xff007987),
  ),
  darkTheme: ThemeData(
    useMaterial3: true,
    fontFamily: 'QaReadableSans',
    colorSchemeSeed: const Color(0xff007987),
    brightness: Brightness.dark,
  ),
  themeMode: mode,
  home: RepaintBoundary(
    key: _captureKey,
    child: Scaffold(
      body: RecruitmentStatisticsScreen(
        gateway: _SyntheticRecruitmentStatistics(),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The default "Ahem" font draws rectangles in Flutter test screenshots.
    // Load an open-source system font to make the images readable.
    final overriddenPath = Platform.environment['ENACTSPACE_QA_TEXT_FONT'];
    final file = File(
      overriddenPath != null && overriddenPath.isNotEmpty
          ? overriddenPath
          : '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    );
    if (!file.existsSync()) {
      throw StateError('Required CI screenshot font is unavailable');
    }
    final loader = FontLoader('QaReadableSans');
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
    await loader.load();
    final icons = Platform.environment['ENACTSPACE_QA_ICON_FONT'];
    if (icons != null) {
      final iconFile = File(icons);
      if (!iconFile.existsSync()) {
        throw StateError('Material icons file missing');
      }
      final materialIcons = FontLoader('MaterialIcons');
      materialIcons.addFont(
        Future<ByteData>.value(
          ByteData.sublistView(iconFile.readAsBytesSync()),
        ),
      );
      await materialIcons.load();
    }
  });

  testWidgets('render anonymous comparison: desktop light and phone dark', (
    tester,
  ) async {
    for (final variant in [
      (
        size: const Size(1440, 900),
        mode: ThemeMode.light,
        filename: 'comparison-desktop-light',
      ),
      (
        size: const Size(390, 844),
        mode: ThemeMode.dark,
        filename: 'comparison-phone-dark',
      ),
      (
        size: const Size(390, 844),
        mode: ThemeMode.light,
        filename: 'comparison-phone-light',
      ),
    ]) {
      await tester.binding.setSurfaceSize(variant.size);
      await tester.pumpWidget(_comparisonFixture(variant.mode));
      await tester.pumpAndSettle();
      final section = find.text('Classement indicatif des dossiers');
      await tester.ensureVisible(section);
      // The screening comparison is open by default to aid deliberation.
      await tester.pumpAndSettle();
      expect(find.text('Candidat #A001'), findsOneWidget);
      expect(find.text('Candidat #A005'), findsNothing);
      expect(tester.takeException(), isNull);
      await _saveScreenshot(tester, variant.filename);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('render manager statistics: desktop light and phone dark', (
    tester,
  ) async {
    for (final variant in [
      (
        size: const Size(1440, 900),
        mode: ThemeMode.light,
        filename: 'statistics-desktop-light',
      ),
      (
        size: const Size(390, 844),
        mode: ThemeMode.dark,
        filename: 'statistics-phone-dark',
      ),
    ]) {
      await tester.binding.setSurfaceSize(variant.size);
      await tester.pumpWidget(_statisticsFixture(variant.mode));
      await tester.pumpAndSettle();
      final progress = find.byKey(const Key('statistics-selection-progress'));
      expect(progress, findsOneWidget);
      await tester.ensureVisible(progress);
      await tester.pumpAndSettle();
      expect(find.text('Dossiers prêts'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _saveScreenshot(tester, variant.filename);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
