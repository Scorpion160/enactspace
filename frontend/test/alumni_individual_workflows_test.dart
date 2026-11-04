import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/alumni/models/alumni_profile_model.dart';
import 'package:frontend/features/alumni/models/individual_mentorship.dart';
import 'package:frontend/features/alumni/screens/alumni_screen.dart';
import 'package:frontend/features/alumni/services/alumni_gateway.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/members/services/members_service.dart';
import 'package:frontend/features/members/widgets/alumni_transition_dialog.dart';

void main() {
  for (final size in [const Size(360, 900), const Size(1280, 900)]) {
    for (final dark in [false, true]) {
      testWidgets('Individual mentoring form at ${size.width}, dark=$dark', (
        tester,
      ) async {
        _setViewport(tester, size);
        final gateway = _MentoringGateway();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: Scaffold(body: AlumniScreen(gateway: gateway)),
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'Mentorat');
        await _tap(tester, 'Demander un mentorat');
        expect(
          find.text('Vous créez cette demande pour vous-même.'),
          findsOneWidget,
        );
        await _tap(tester, 'Envoyer la demande');
        expect(find.text('Décrivez votre objectif.'), findsOneWidget);
        final mentor = find.byType(DropdownButtonFormField<String>).last;
        await tester.ensureVisible(mentor);
        await tester.tap(mentor);
        await tester.pumpAndSettle();
        await _tap(tester, 'Awa Ndiaye');
        final objective = find.byType(TextFormField);
        await tester.ensureVisible(objective);
        await tester.enterText(objective, '  Préparer un entretien.  ');
        await _tap(tester, 'Envoyer la demande');
        expect(gateway.submission, (
          'mentor',
          'member',
          'Préparer un entretien.',
        ));
        expect(find.text('À valider'), findsOneWidget);
        expect(find.text('Valider'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Transition repair refreshes the linked profile and visibility', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 780));
    final service = _TransitionService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AlumniTransitionDialog(
            service: service,
            members: const [
              MemberModel(
                id: 'member',
                email: 'member@example.test',
                fullName: 'Membre Test',
              ),
            ],
          ),
        ),
      ),
    );
    await _tap(tester, 'Compte à contrôler');
    await _tap(tester, 'Membre Test');
    expect(find.text('Fiche Alumni manquante'), findsOneWidget);
    await _tap(tester, 'Créer et lier la fiche');
    expect(service.repairs, 1);
    expect(find.text('Fiche liée et visible'), findsOneWidget);
    expect(find.text('Visibilité de la fiche · Membres'), findsOneWidget);
    expect(find.text('Ouvrir la fiche Alumni'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _MentoringGateway implements AlumniGateway, IndividualMentorshipGateway {
  (String, String, String)? submission;

  @override
  Future<AlumniCenterData> loadCenter({
    String? search,
    bool mentorsOnly = false,
    String mentorshipStatus = 'all',
  }) async => AlumniCenterData(
    user: UserExperience.fromJson({'id': 'member', 'status': 'active'}),
    profiles: [
      AlumniProfileModel.fromJson({
        'id': 'profile',
        'user_id': 'mentor',
        'display_name': 'Awa Ndiaye',
        'visibility': 'internal',
        'available_for_mentoring': true,
      }),
    ],
    mentorships: const [],
    members: const [],
    projects: const [],
    poles: const [],
  );

  @override
  Future<List<IndividualMentorship>> listIndividualRequests() async {
    final request = submission;
    return [
      if (request != null)
        IndividualMentorship(
          id: 'request',
          mentorName: 'Awa Ndiaye',
          menteeName: 'Membre Test',
          objective: request.$3,
          status: IndividualMentorshipStatus.pending,
        ),
    ];
  }

  @override
  Future<void> createIndividualRequest({
    required String mentorId,
    required String menteeId,
    required String objective,
  }) async {
    submission = (mentorId, menteeId, objective);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TransitionService extends MembersService {
  int repairs = 0;

  @override
  Future<Map<String, dynamic>> previewAlumni(String memberId) async => {
    'status': 'alumni',
    'roles': ['alumni'],
    'control': {'state': 'missing_profile', 'can_repair': true},
  };

  @override
  Future<Map<String, dynamic>> repairAlumniTransition(String memberId) async {
    repairs++;
    return {
      'state': 'linked_visible',
      'can_repair': false,
      'profile_id': 'linked-profile',
      'visibility': 'internal',
    };
  }
}
