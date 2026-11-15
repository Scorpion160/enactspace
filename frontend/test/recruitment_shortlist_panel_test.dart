import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/services/recruitment_selection_api.dart';
import 'package:frontend/features/recruitment/widgets/internal/recruitment_shortlist_panel.dart';

class _ShortlistFixture extends RecruitmentSelectionApi {
  final bool reveal;
  _ShortlistFixture({this.reveal = false});

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!path.endsWith('/selection/shortlist') || body != null) {
      throw StateError('Only a read-only shortlist is allowed');
    }
    return {
      'identities_revealed': reveal,
      'rows': [
        for (var i = 0; i < 3; i++)
          {
            'application_id': 'candidate-$i',
            'anonymous_code': 'Candidat #$i',
            'candidate_name': reveal ? 'Candidat public $i' : null,
            'department': i == 2 ? 'GC' : 'GE',
            'study_level': i == 2 ? 'DIC1' : 'DIC2',
            'jury_average_20': 19.0 - i,
            'review_count': 3,
            'rank': i + 1,
            'interview_scheduled': false,
          },
      ],
    };
  }
}

Widget _fixture(_ShortlistFixture fake, {ValueChanged<String>? open}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecruitmentShortlistPanel(
            campaignId: 'synthetic-campaign',
            refreshToken: 0,
            onOpen: open,
            api: fake,
          ),
        ),
      ),
    );

void main() {
  testWidgets('all shortlisted dossiers are accessible by rank and filter', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(_fixture(_ShortlistFixture(), open: opened.add));
    await tester.pumpAndSettle();
    expect(find.text('Retenus pour entretien (3)'), findsOneWidget);
    await tester.tap(find.text('Retenus pour entretien (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Candidat #0'), findsOneWidget);
    expect(find.text('Candidat #1'), findsOneWidget);
    expect(find.text('Candidat #2'), findsOneWidget);
    expect(find.text('Candidat public 0'), findsNothing);
    await tester.ensureVisible(find.text('Candidat #0'));
    await tester.tap(find.text('Candidat #0'));
    expect(opened, ['candidate-0']);
    await tester.enterText(find.byKey(const Key('shortlist-search')), '#2');
    await tester.pumpAndSettle();
    expect(find.text('Candidat #0'), findsNothing);
    expect(find.text('Candidat #2'), findsOneWidget);
  });

  testWidgets('names appear only if backend confirms identity reveal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_fixture(_ShortlistFixture(reveal: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retenus pour entretien (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Candidat public 0'), findsOneWidget);
    expect(find.text('Candidat #0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
