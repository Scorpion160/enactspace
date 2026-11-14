import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/members/screens/members_screen.dart';
import 'package:frontend/features/members/services/members_service.dart';

class _AuthFixture extends AuthService {
  @override
  Future<Map<String, dynamic>> getCurrentUser() async => {
    'id': 'sample-admin',
    'email': 'admin@example.test',
    'first_name': 'Admin',
    'last_name': 'Test',
    'status': 'active',
    'roles': ['administrateur'],
  };
}

class _MembersFixture extends MembersService {
  final List<MemberModel> records;
  _MembersFixture(this.records);

  @override
  Future<List<MemberModel>> getManagedMembers() async => [...records];

  @override
  Future<List<MemberModel>> getMembers() async => [...records];
}

List<MemberModel> _syntheticMembers(int count) => List.generate(
  count,
  (i) => MemberModel(
    id: 'sample-' + i.toString(),
    email: i.isEven
        ? 'prenom.extremement.long.numero' +
              i.toString() +
              '@exemple-universitaire.test'
        : 'court' + i.toString() + '@example.test',
    firstName: i.isEven ? 'Amadou-Alexandre-Abdoulaye' : 'Awa',
    lastName: 'CANDIDAT' + i.toString().padLeft(3, '0'),
    roles: i.isEven ? ['chef_projet'] : ['enacteur'],
    department: i.isEven ? 'Génie informatique et réseaux' : 'Gestion',
    status: 'active',
    isActive: true,
  ),
);

void main() {
  testWidgets('member cards align and only show the initial page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 850));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembersScreen(
            authService: _AuthFixture(),
            membersService: _MembersFixture(_syntheticMembers(42)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('member-card-sample-0'));
    final second = find.byKey(const Key('member-card-sample-1'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(find.byKey(const Key('member-card-sample-41')), findsNothing);
    expect(
      tester.getSize(first).height,
      closeTo(tester.getSize(second).height, 0.1),
    );
    expect(tester.takeException(), isNull);
    final more = find.byKey(const Key('members-show-more'));
    await tester.scrollUntilVisible(
      more,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-card-sample-41')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('narrow cards remain uniform with long labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 830));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: MembersScreen(
                authService: _AuthFixture(),
                membersService: _MembersFixture(_syntheticMembers(2)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('member-card-sample-0'));
    final second = find.byKey(const Key('member-card-sample-1'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(
      tester.getSize(first).height,
      closeTo(tester.getSize(second).height, 0.1),
    );
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
