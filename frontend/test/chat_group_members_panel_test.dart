import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/models/chat_models.dart';
import 'package:frontend/features/chat/services/chat_gateway.dart';
import 'package:frontend/features/chat/widgets/chat_group_members_panel.dart';

ChatThreadMemberModel _member(int number, {String role = 'member'}) =>
    ChatThreadMemberModel.fromJson({
      'user_id': 'user-$number',
      'first_name': 'Membre',
      'last_name': '$number',
      'email': 'member$number@example.test',
      'participant_role': role,
    });

ChatThreadModel _thread({String role = 'owner'}) => ChatThreadModel.fromJson({
  'id': 'group-1',
  'title': 'Groupe de projet',
  'thread_type': 'group',
  'current_user_role': role,
  'participants_count': 9,
  // Real thread endpoint exposes at most six preview entries.
  'participants_preview': [
    for (var number = 0; number < 6; number++)
      _member(number, role: number == 0 ? 'owner' : 'member').toJson(),
  ],
});

class _GroupGateway implements ChatGateway {
  final List<ChatThreadMemberModel> members = [
    for (var i = 0; i < 9; i++) _member(i, role: i == 0 ? 'owner' : 'member'),
  ];
  String? removedId;

  @override
  Future<List<ChatThreadMemberModel>> getParticipants(String threadId) async =>
      [...members];

  @override
  Future<void> removeParticipant({
    required String threadId,
    required String userId,
  }) async {
    removedId = userId;
    members.removeWhere((member) => member.userId == userId);
  }

  @override
  Future<void> updateParticipantRole({
    required String threadId,
    required String userId,
    required String participantRole,
  }) async {
    final index = members.indexWhere((member) => member.userId == userId);
    final member = members[index];
    members[index] = ChatThreadMemberModel.fromJson({
      ...member.toJson(),
      'participant_role': participantRole,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('group lists every member, adds new ones and confirms removal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(680, 1050));
    final gateway = _GroupGateway();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatGroupMembersPanel(
              thread: _thread(),
              gateway: gateway,
              currentUserId: 'user-0',
              onAddMembers: () async => gateway.members.add(_member(9)),
              onChanged: () async => changes++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Participants (9)'), findsOneWidget);
    expect(find.byKey(const Key('chat-group-member-user-8')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-group-add-members')));
    await tester.pumpAndSettle();
    expect(find.text('Participants (10)'), findsOneWidget);
    expect(find.byKey(const Key('chat-group-member-user-9')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('chat-group-manage-user-1')),
    );
    await tester.tap(find.byKey(const Key('chat-group-manage-user-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer du groupe').last);
    await tester.pumpAndSettle();
    expect(find.text('Retirer ce membre ?'), findsOneWidget);
    expect(gateway.removedId, isNull);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(gateway.removedId, isNull);

    await tester.tap(find.byKey(const Key('chat-group-manage-user-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer du groupe').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer du groupe').last);
    await tester.pumpAndSettle();
    expect(gateway.removedId, 'user-1');
    expect(changes, 1);
    expect(find.text('Participants (9)'), findsOneWidget);
    expect(find.byKey(const Key('chat-group-member-user-1')), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an owner confirms the promotion and demotion of an admin', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(680, 1050));
    final gateway = _GroupGateway();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatGroupMembersPanel(
              thread: _thread(),
              gateway: gateway,
              currentUserId: 'user-0',
              onChanged: () async => changes++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-group-manage-user-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nommer administrateur').last);
    await tester.pumpAndSettle();
    expect(find.text('Nommer administrateur ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(gateway.members[1].participantRole, 'member');
    await tester.tap(find.byKey(const Key('chat-group-manage-user-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nommer administrateur').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nommer administrateur').last);
    await tester.pumpAndSettle();
    expect(gateway.members[1].participantRole, 'admin');
    expect(changes, 1);
    await tester.tap(find.byKey(const Key('chat-group-manage-user-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer le rôle admin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(gateway.members[1].participantRole, 'member');
    expect(changes, 2);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('ordinary members cannot manage other group members', (
    tester,
  ) async {
    final gateway = _GroupGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChatGroupMembersPanel(
              thread: _thread(role: 'member'),
              gateway: gateway,
              currentUserId: 'user-2',
              onChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-group-add-members')), findsNothing);
    expect(find.byKey(const Key('chat-group-manage-user-1')), findsNothing);
    expect(find.byKey(const Key('chat-group-manage-user-0')), findsNothing);
  });
}
