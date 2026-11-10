// Synthetic visual acceptance of the entire selection workspace.
// No real application or production API is used.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/services/recruitment_selection_api.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_selection_panel.dart';
import 'package:frontend/features/recruitment/widgets/recruitment_style.dart';

const _boundaryKey = Key('synthetic-selection-screenshot');

class _SyntheticSelectionApi extends RecruitmentSelectionApi {
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (body != null) {
      throw StateError('The visual fixture must never write or publish data');
    }
    if (!path.endsWith('/selection')) {
      throw StateError('Unexpected synthetic request $path');
    }
    const dates = {
      'applications_open': '2028-05-02',
      'applications_close': '2028-05-05',
      'screening_start': '2028-05-02',
      'screening_end': '2028-05-10',
      'screening_results': '2028-05-11',
      'interviews_start': '2028-05-12',
      'interviews_end': '2028-05-17',
      'final_results': '2028-05-20',
    };
    return {
      'stage': 'screening',
      'rows': [
        {
          'application_id': 'fictive-a001',
          'anonymous_code': 'Candidat #A001',
          'department': 'Génie électrique',
          'study_level': 'DIC2',
          'ready': true,
          'review_count': 3,
          'required_reviews': 3,
          'score': 90.0,
          'spread': 9.0,
          'decision': null,
        },
        {
          'application_id': 'fictive-a002',
          'anonymous_code': 'Candidat #A002',
          'department': 'Gestion',
          'study_level': 'Licence1',
          'ready': false,
          'review_count': 2,
          'required_reviews': 3,
          'score': 96.0,
          'spread': 8.0,
          'decision': null,
        },
        {
          'application_id': 'fictive-a003',
          'anonymous_code': 'Candidat #A003',
          'department': 'Génie civil',
          'study_level': 'DIC1',
          'ready': true,
          'review_count': 4,
          'required_reviews': 4,
          'score': 84.0,
          'spread': 24.0,
          'decision': 'shortlisted',
        },
      ],
      'revision': 'fictive-only',
      'selection_schedule': dates,
      'schedule_template': dates,
      'minimum_reviews': 3,
      'disagreement_threshold': 20,
      'eligible_jurors': 27,
      'result_available_from': '2028-05-11',
      'can_publish_on_date': false,
      'screening_published_at': null,
      'final_published_at': null,
      'identities_revealed_at': null,
      'result_emails': <String, dynamic>{},
    };
  }
}

Widget _fixture(ThemeMode mode) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'QaReadableSans',
  ),
  darkTheme: ThemeData(
    useMaterial3: true,
    fontFamily: 'QaReadableSans',
    brightness: Brightness.dark,
  ),
  themeMode: mode,
  home: RepaintBoundary(
    key: _boundaryKey,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'RECETTE VISUELLE — CAMPAGNE FICTIVE 2028',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RecruitmentStyle(
                  child: RecruitmentSelectionPanel(
                    campaignId: 'synthetic-campaign-2028',
                    refreshToken: 0,
                    onChanged: () {},
                    api: _SyntheticSelectionApi(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  expect(boundary.debugNeedsPaint, isFalse);
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Screenshot encoding failed');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  expect(png, isNotNull);
  final directory = Directory('build/recruitment-visual-review');
  directory.createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(png!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final file = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (!file.existsSync()) throw StateError('Readable screenshot font missing');
    final loader = FontLoader('QaReadableSans');
    loader.addFont(Future<ByteData>.value(
      ByteData.sublistView(file.readAsBytesSync()),
    ));
    await loader.load();
  });

  testWidgets('selection workspace screenshots for desktop and phone',
      (tester) async {
    for (final scene in [
      (size: const Size(1440, 900), mode: ThemeMode.light,
       file:'selection-workspace-desktop-light'),
      (size: const Size(390, 844), mode: ThemeMode.dark,
       file:'selection-workspace-phone-dark'),
    ]) {
      await tester.binding.setSurfaceSize(scene.size);
      await tester.pumpWidget(_fixture(scene.mode));
      await tester.pumpAndSettle();
      expect(find.text('Présélection des dossiers'), findsOneWidget);
      expect(find.text('2/3 dossiers prêts · 1 décisions préparées'), findsOneWidget);
      expect(find.text('Publier les résultats et préparer les mails'), findsOneWidget);
      await _capture(tester, scene.file);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('calendar, evaluation settings and publication remain separate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(_fixture(ThemeMode.light));
    await tester.pumpAndSettle();
    final calendar = find.text('Calendrier de la campagne');
    await tester.ensureVisible(calendar);
    await tester.tap(calendar);
    await tester.pumpAndSettle();
    expect(find.text('Charger un calendrier indicatif'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('schedule-screening_results')));
    await _capture(tester, 'selection-calendar-desktop-light');
    final settings = find.text('Paramètres des évaluations');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Répartir ou compléter les attributions'));
    await _capture(tester, 'selection-settings-desktop-light');
    await tester.ensureVisible(find.text('Publication des décisions'));
    await _capture(tester, 'selection-publication-desktop-light');
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
