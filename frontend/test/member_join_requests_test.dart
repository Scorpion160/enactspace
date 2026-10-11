import 'package:flutter_test/flutter_test.dart';
import '../lib/features/members/models/member_model.dart';

void main() {
  MemberModel member(String profile, String status) => MemberModel(
    id: 'request',
    email: 'request@example.org',
    profileType: profile,
    status: status,
    isActive: true,
  );

  test('reviewers see alumni requests but never approved alumni as members', () {
    for (final reviewer in [true, false]) {
      expect(member('alumni', 'pending').visibleInMemberManagement(
        canReviewJoinRequests: reviewer,
      ), reviewer);
      for (final status in ['alumni', 'inactive', 'rejected']) {
        expect(member('alumni', status).visibleInMemberManagement(
          canReviewJoinRequests: reviewer,
        ), isFalse);
      }
    }
  });

  test('enacteur and enactrice requests remain available in membership management', () {
    for (final profile in ['enacteur', 'enactrice']) {
      for (final status in ['pending', 'active']) {
        expect(member(profile, status).visibleInMemberManagement(
          canReviewJoinRequests: true,
        ), isTrue);
      }
    }
  });

  test('an alumni request leaves the members view after approval', () {
    final pending = member('alumni', 'pending');
    final approved = member('alumni', 'alumni');
    expect(pending.visibleInMemberManagement(canReviewJoinRequests: true), isTrue);
    expect(approved.visibleInMemberManagement(canReviewJoinRequests: true), isFalse);
    expect([pending, approved].where((m) => !m.isAlumni), isEmpty);
  });
}
