import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/attendance/models/attendance_session_model.dart';
import 'package:frontend/features/attendance/screens/attendance_nfc_enrollment_screen.dart';
import 'package:frontend/features/attendance/screens/attendance_screen.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/recruitment/screens/application_tracking_screen.dart';

void main() {
  testWidgets('login screen renders expected actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    expect(find.text('Connexion des comptes validés'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('candidate tracking fits a compact mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: ApplicationTrackingScreen()),
    );
    await tester.pump();

    expect(find.text('Suivre ma candidature'), findsOneWidget);
    expect(find.text('Afficher mon suivi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a simple member only sees their personal attendance follow-up', (
    tester,
  ) async {
    final member = UserExperience(
      id: 'audit-member',
      email: 'audit.member@enactspace.local',
      displayName: 'Audit Member',
      status: 'active',
      gender: null,
      profileType: 'enacteur',
      roles: const {'enacteur'},
      canReviewJoinRequests: false,
    );

    expect(UserExperience.visibleRoutesFor(member), contains('/attendance'));

    await tester.pumpWidget(
      MaterialApp(home: AttendanceScreen(testUser: member)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mon suivi de présence'), findsOneWidget);
    expect(find.text('Scanner QR'), findsOneWidget);
    expect(find.text('Créer session'), findsNothing);
    expect(find.text('Gestion'), findsNothing);
    expect(find.text('Statistiques du mois'), findsNothing);
  });

  test('human labels keep API identifiers out of the interface', () {
    const member = MemberModel(
      id: 'member-1',
      email: 'member@example.test',
      roles: ['administrateur', 'chef_pole', 'enacteur'],
    );
    const session = AttendanceSessionModel(
      id: 'session-1',
      title: 'Réunion du bureau',
      sessionType: 'general_meeting',
      status: 'planned',
      canManage: false,
    );

    expect(
      member.rolesLabel,
      'Administrateur, Chef de pôle, Enacteur/Enactrice',
    );
    expect(session.typeLabel, 'Réunion générale');
    expect(session.statusLabel, 'Planifiée');
  });

  test(
    'NFC member loading distinguishes an API failure from an empty list',
    () {
      const member = MemberModel(id: 'member-1', email: 'member@example.test');

      expect(
        nfcMemberLoadState(members: const [], error: 'HTTP 403'),
        NfcMemberLoadState.failed,
      );
      expect(nfcMemberLoadState(members: const []), NfcMemberLoadState.empty);
      expect(
        nfcMemberLoadState(members: const [member]),
        NfcMemberLoadState.ready,
      );
    },
  );

  test(
    'attendance path permissions do not expose NFC enrollment to members',
    () {
      UserExperience user({
        required String status,
        required Set<String> roles,
      }) {
        return UserExperience(
          id: '$status-${roles.join('-')}',
          email: 'audit@example.test',
          displayName: 'Audit User',
          status: status,
          gender: null,
          profileType: status == 'alumni' ? 'alumni' : 'enacteur',
          roles: roles,
          canReviewJoinRequests: false,
        );
      }

      final member = user(status: 'active', roles: const {'enacteur'});
      final secretary = user(
        status: 'active',
        roles: const {'secretaire_generale', 'enacteur'},
      );
      final admin = user(
        status: 'active',
        roles: const {'administrateur', 'enacteur'},
      );
      final alumni = user(status: 'alumni', roles: const {'alumni'});

      expect(UserExperience.canAccessPath(member, '/attendance'), isTrue);
      expect(UserExperience.canAccessPath(member, '/attendance/scan'), isTrue);
      expect(UserExperience.canAccessPath(member, '/attendance/nfc'), isFalse);
      expect(
        UserExperience.canAccessPath(secretary, '/attendance/nfc'),
        isTrue,
      );
      expect(UserExperience.canAccessPath(admin, '/attendance/nfc'), isTrue);
      expect(UserExperience.canAccessPath(alumni, '/attendance'), isFalse);
      expect(UserExperience.canAccessPath(null, '/attendance/nfc'), isFalse);
    },
  );
}
