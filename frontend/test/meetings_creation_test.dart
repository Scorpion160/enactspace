import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/features/meetings/models/meeting_model.dart';
import 'package:frontend/features/meetings/services/meetings_service.dart';
import 'package:frontend/features/meetings/screens/meetings_screen.dart';
import 'package:frontend/features/members/models/member_model.dart';
import 'package:frontend/features/members/services/members_service.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/poles/services/poles_service.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/services/projects_service.dart';

class _Auth extends AuthService {
  @override
  Future<Map<String, dynamic>?> getCachedCurrentUser() async =>
    {'id': 'host', 'status': 'active', 'roles': ['administrateur'], 'first_name': 'Host'};
}
class _Members extends MembersService {
  @override
  Future<List<MemberModel>> getMembers() async => throw Exception('Annuaire indisponible');
}
class _Poles extends PolesService {
  @override
  Future<List<PoleModel>> getPoles() async => [];
}
class _Projects extends ProjectsService {
  @override
  Future<List<ProjectModel>> getProjects() async => throw Exception('Projets indisponibles');
}
class _Meetings extends MeetingsService {
  int created = 0;
  @override
  Future<List<MeetingModel>> listMeetings() async => [];
  @override
  Future<MeetingModel> createMeeting({required String title, String? description,
    String scopeType = 'custom', String? scopeId, DateTime? scheduledStart, DateTime? scheduledEnd,
    List<String> inviteUserIds = const [], bool startWithAudioMuted = true,
    bool startWithVideoMuted = true, bool lobbyEnabled = true}) async {
    created++;
    return MeetingModel.fromJson({'id': 'created', 'title': title, 'scope_type': scopeType});
  }
}

void main() {
  testWidgets('unavailable invitation lists do not prevent creating a meeting', (tester) async {
    final service = _Meetings();
    final router = GoRouter(initialLocation: '/meetings', routes: [
      GoRoute(path: '/meetings', builder: (_, state) => MeetingsScreen(
        service: service, authService: _Auth(), membersService: _Members(),
        polesService: _Poles(), projectsService: _Projects())),
      GoRoute(path: '/meetings/:id', builder: (_, state) => const Scaffold(body: Text('Réunion créée'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle réunion'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle réunion EnactMeet'), findsOneWidget);
    expect(find.textContaining('Certaines listes d’invitation'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Titre de la réunion'), 'Réunion de préparation');
    final save = find.text('Créer la réunion');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(service.created, 1);
    expect(find.text('Réunion créée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
