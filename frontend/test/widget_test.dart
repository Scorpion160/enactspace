import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/attendance/models/attendance_session_model.dart';
import 'package:frontend/features/attendance/screens/attendance_nfc_enrollment_screen.dart';
import 'package:frontend/features/attendance/screens/attendance_screen.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/finance/models/payment_model.dart';
import 'package:frontend/features/finance/screens/finance_screen.dart';
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

  test('finance payment statuses keep API values humanized', () {
    const pending = PaymentModel(
      id: 'payment-1',
      userId: 'member-1',
      amount: 2500,
      method: 'wave',
      status: 'pending',
      canValidate: false,
      canReject: false,
      canCancel: false,
    );
    const rejected = PaymentModel(
      id: 'payment-2',
      userId: 'member-1',
      amount: 2500,
      method: 'wave',
      status: 'rejected',
      canValidate: false,
      canReject: false,
      canCancel: false,
    );

    expect(pending.statusLabel, 'En attente');
    expect(rejected.statusLabel, 'Rejeté');
    expect(pending.canValidate, isFalse);
  });

  testWidgets('finance proof dialog distinguishes no proof from a document', (
    tester,
  ) async {
    const withoutProof = PaymentModel(
      id: 'payment-1',
      userId: 'member-1',
      amount: 2500,
      method: 'wave',
      status: 'pending',
      canValidate: false,
      canReject: false,
      canCancel: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PaymentProofDialog(payment: withoutProof)),
    );
    expect(
      find.text('Aucune preuve fournie pour ce paiement.'),
      findsOneWidget,
    );

    const withProof = PaymentModel(
      id: 'payment-2',
      userId: 'member-1',
      amount: 2500,
      method: 'wave',
      status: 'pending',
      proofUrl: '/uploads/proof.pdf',
      canValidate: false,
      canReject: false,
      canCancel: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PaymentProofDialog(payment: withProof)),
    );
    expect(find.text('proof.pdf'), findsOneWidget);
    expect(find.text('Ouvrir la preuve'), findsOneWidget);
  });

  testWidgets(
    'finance rejection requires a reason and validation is explicit',
    (tester) async {
      const payment = PaymentModel(
        id: 'payment-1',
        userId: 'member-1',
        amount: 2500,
        method: 'wave',
        status: 'pending',
        reference: 'AUDIT-PAY-000',
        canValidate: true,
        canReject: true,
        canCancel: false,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentDecisionDialog(
            payment: payment,
            memberName: 'Audit Member',
            approve: false,
          ),
        ),
      );
      expect(find.text('Motif du rejet'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Rejeter le paiement'),
            )
            .onPressed,
        isNull,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentDecisionDialog(
            payment: payment,
            memberName: 'Audit Member',
            approve: true,
          ),
        ),
      );
      expect(find.text('Valider le paiement'), findsOneWidget);
    },
  );

  test(
    'finance proof URLs resolve relative paths and reject unsafe schemes',
    () {
      final relative = PaymentProofUriResolver.resolve(
        '/uploads/proof.pdf',
        baseUrl: Uri.parse('http://127.0.0.1:18002/'),
      );

      expect(relative, Uri.parse('http://127.0.0.1:18002/uploads/proof.pdf'));
      expect(PaymentProofUriResolver.resolve('javascript:alert(1)'), isNull);
      expect(
        PaymentProofUriResolver.resolve('//untrusted.example/proof.pdf'),
        isNull,
      );
    },
  );

  testWidgets('finance proof dialog renders an image preview', (tester) async {
    const payment = PaymentModel(
      id: 'payment-image',
      userId: 'member-1',
      amount: 2500,
      method: 'wave',
      status: 'pending',
      proofUrl: '/uploads/proof.png',
      canValidate: false,
      canReject: false,
      canCancel: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PaymentProofDialog(payment: payment)),
    );

    expect(find.text('Image de preuve'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('finance proof opening failure offers retry', (tester) async {
    const payment = PaymentModel(
      id: 'payment-proof',
      userId: 'member-1',
      amount: 2500,
      method: 'wave',
      status: 'pending',
      proofUrl: '/uploads/proof.pdf',
      canValidate: false,
      canReject: false,
      canCancel: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentProofDialog(payment: payment, openUri: (_) async => false),
      ),
    );

    await tester.tap(find.text('Ouvrir la preuve'));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
  });

  test(
    'finance permissions remain data-driven for member and finance roles',
    () {
      const memberPayment = PaymentModel(
        id: 'member-payment',
        userId: 'member-1',
        amount: 2500,
        method: 'wave',
        status: 'pending',
        canValidate: false,
        canReject: false,
        canCancel: false,
      );
      const financePayment = PaymentModel(
        id: 'finance-payment',
        userId: 'member-1',
        amount: 2500,
        method: 'wave',
        status: 'pending',
        canValidate: true,
        canReject: true,
        canCancel: false,
      );

      expect(memberPayment.canValidate, isFalse);
      expect(memberPayment.canReject, isFalse);
      expect(financePayment.canValidate, isTrue);
      expect(financePayment.canReject, isTrue);
    },
  );

  test(
    'active members can open personal finance without management access',
    () {
      UserExperience user({
        required String status,
        required Set<String> roles,
      }) {
        return UserExperience(
          id: 'finance-$status',
          email: 'finance@example.test',
          displayName: 'Finance Test',
          status: status,
          gender: null,
          profileType: status == 'alumni' ? 'alumni' : 'enacteur',
          roles: roles,
          canReviewJoinRequests: false,
        );
      }

      final member = user(status: 'active', roles: const {'enacteur'});
      final admin = user(status: 'active', roles: const {'administrateur'});
      final finance = user(status: 'active', roles: const {'financier'});
      final alumni = user(status: 'alumni', roles: const {'alumni'});
      final candidate = user(status: 'candidate', roles: const {'enacteur'});

      expect(member.canAccessPersonalFinance, isTrue);
      expect(member.canManageFinance, isFalse);
      expect(UserExperience.canAccessPath(member, '/finance'), isTrue);
      expect(UserExperience.visibleRoutesFor(member), contains('/finance'));
      expect(UserExperience.canAccessPath(admin, '/finance'), isTrue);
      expect(UserExperience.canAccessPath(finance, '/finance'), isTrue);
      expect(UserExperience.canAccessPath(alumni, '/finance'), isFalse);
      expect(UserExperience.canAccessPath(candidate, '/finance'), isFalse);
      expect(UserExperience.canAccessPath(null, '/finance'), isFalse);
    },
  );
}
