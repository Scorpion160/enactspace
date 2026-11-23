import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/meetings/models/meeting_model.dart';

void main() {
  test('external invitation is visible only for explicitly authorized meetings', () {
    final ordinary = MeetingModel.fromJson({
      'id': 'meeting-1',
      'title': 'Rencontre avec un partenaire',
      'status': 'scheduled',
      'can_manage': true,
      'can_invite_external': true,
    });
    expect(ordinary.canInviteExternal, isTrue);
    final interview = MeetingModel.fromJson({
      'id': 'meeting-2',
      'title': 'Entretien interne',
      'status': 'live',
      'can_manage': true,
      'is_recruitment_interview': true,
      'can_invite_external': false,
    });
    expect(interview.canInviteExternal, isFalse);
    expect(MeetingModel.fromJson({'id': 'meeting-3'}).canInviteExternal, isFalse);
  });

  test('guest status is separate from EnactSpace membership', () {
    final guest = MeetingExternalGuestModel.fromJson({
      'id': 'invitation-1',
      'email': 'partner@example.org',
      'display_name': 'Partenaire externe',
      'active': true,
      'email_status': 'sent',
      'expires_at': '2026-11-25T13:00:00Z',
    });
    expect(guest.email, 'partner@example.org');
    expect(guest.active, isTrue);
    expect(guest.emailStatus, 'sent');
    expect(guest.expiresAt, isNotNull);
  });
}
