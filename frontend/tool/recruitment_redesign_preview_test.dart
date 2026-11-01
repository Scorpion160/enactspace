// Actual Flutter widget captures, using local fonts and fictitious gateways.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/recruitment/screens/internal/internal_recruitment_screen.dart';
import 'package:frontend/features/recruitment/screens/internal/campaign_management_screen.dart';
import 'package:frontend/features/recruitment/screens/internal/recruitment_jury_screen.dart';
import 'package:frontend/features/recruitment/screens/internal/application_detail_panel.dart';
import 'package:frontend/features/recruitment/screens/application_tracking_screen.dart';
import 'package:frontend/features/recruitment/screens/public/public_application_flow_screen.dart';
import 'package:frontend/features/recruitment/widgets/internal/candidate_review_dialog.dart';
import 'package:frontend/features/recruitment/widgets/internal/interview_planning_dialog.dart';
import 'package:frontend/features/recruitment/widgets/recruitment_style.dart';

import '../test/support/recruitment_redesign_fixture.dart';

final _capture = GlobalKey();
Future<void> _pump(WidgetTester tester, Widget page, bool dark) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _capture,
      child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: name);
  final boundary =
      _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final path = File('.dart_tool/recruitment_redesign_previews/$name.png');
      await path.parent.create(recursive: true);
      await path.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    } finally {
      image.dispose();
    }
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [
      ('regular', 'Regular'),
      ('medium', 'Medium'),
      ('semibold', 'SemiBold'),
      ('bold', 'Bold'),
      ('extrabold', 'ExtraBold'),
    ]) {
      await (FontLoader('Poppins_${font.$1}')..addFont(
            rootBundle.load('assets/fonts/poppins/Poppins-${font.$2}.ttf'),
          ))
          .load();
    }
    await (FontLoader(
          'Poppins',
        )..addFont(rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf')))
        .load();
  });
  for (final dark in [false, true]) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('capture real recruitment widgets dark=$dark width=$width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final suffix = '${dark ? 'sombre' : 'clair'}-${width.toInt()}';
        final gateway = RedesignGateway();
        await _pump(tester, InternalRecruitmentScreen(gateway: gateway), dark);
        await _shot(tester, '01-candidatures-$suffix');
        await _pump(
          tester,
          CampaignManagementScreen(
            gateway: gateway,
            now: DateTime.utc(2026, 11, 1),
          ),
          dark,
        );
        await _shot(tester, '02-campagnes-$suffix');
        await _tap(tester, find.text('Lire la suite'));
        await _shot(tester, '03-description-complete-$suffix');
        await _tap(tester, find.byKey(const Key('create-campaign')));
        await tester.enterText(
          find.byKey(const Key('campaign-title')),
          redesignCampaign.title,
        );
        await tester.enterText(
          find.byKey(const Key('campaign-description')),
          redesignDescription,
        );
        await tester.enterText(
          find.byKey(const Key('campaign-start-date')),
          '04/11/2026',
        );
        await tester.enterText(
          find.byKey(const Key('campaign-end-date')),
          '08/11/2026',
        );
        // Scroll back to the top of the actual form after keyboard focus moves.
        await tester.ensureVisible(find.byKey(const Key('campaign-title')));
        await tester.pumpAndSettle();
        await _shot(tester, '04-informations-$suffix');
        await _tap(tester, find.widgetWithText(ChoiceChip, 'Questionnaire'));
        await _shot(tester, '05-questionnaire-$suffix');
        await _tap(tester, find.widgetWithText(ChoiceChip, 'Aperçu candidat'));
        await _shot(tester, '06-apercu-candidat-$suffix');
        await _pump(
          tester,
          RecruitmentJuryScreen(
            tools: gateway.campaignTools,
            campaigns: gateway.campaigns,
          ),
          dark,
        );
        await _shot(tester, '07-jury-equipes-$suffix');
        await _tap(tester, find.text('Réunir tout le jury'));
        await _shot(tester, '08-jury-unique-$suffix');
        await _pump(
          tester,
          ApplicationDetailPanel(
            summary: gateway.applications.first,
            campaignTitle: redesignCampaign.title,
            anonymized: false,
            gateway: gateway,
            onClose: () {},
          ),
          dark,
        );
        await _shot(tester, '09-dossier-$suffix');
        await _pump(
          tester,
          RecruitmentStyle(
            child: CandidateReviewDialog(
              application: gateway.applications.first,
              gateway: gateway,
            ),
          ),
          dark,
        );
        await _shot(tester, '10-evaluation-$suffix');
        await _pump(
          tester,
          RecruitmentStyle(
            child: InterviewPlanningDialog(
              application: gateway.applications.first,
              tools: gateway.campaignTools,
              onSaved: (_) {},
            ),
          ),
          dark,
        );
        await _shot(tester, '11-entretien-$suffix');
        await _pump(
          tester,
          ApplicationTrackingScreen(gateway: RedesignPublicGateway()),
          dark,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'REC-FIXTURE-1');
        await tester.enterText(fields.at(1), 'candidate@example.test');
        await _tap(
          tester,
          find.widgetWithText(FilledButton, 'Consulter ma candidature'),
        );
        await _shot(tester, '12-suivi-$suffix');
        await _pump(
          tester,
          PublicApplicationFlowScreen(
            campaignId: redesignCampaign.id,
            campaign: redesignCampaign.copyWith(
              startDate: '2026-10-01',
              endDate: '2026-12-01',
            ),
            gateway: RedesignPublicGateway(),
          ),
          dark,
        );
        await _shot(tester, '13-formulaire-public-$suffix');
        expect(gateway.writes, 0);
      });
    }
  }
}
