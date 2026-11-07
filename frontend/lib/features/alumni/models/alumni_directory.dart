import '../../members/models/member_model.dart';
import 'alumni_profile_model.dart';

List<AlumniProfileModel> filterAlumniDirectory({
  required List<AlumniProfileModel> profiles,
  required Map<String, MemberModel> membersById,
  required Set<String> availableMentorIds,
  required String search,
  required bool mentorsOnly,
  int? graduationYear,
  String? domain,
}) {
  final words = MemberModel.alphabeticKey(
    search,
  ).split(' ').where((word) => word.isNotEmpty);
  final visible = profiles.where((profile) {
    if (mentorsOnly && !availableMentorIds.contains(profile.userId)) {
      return false;
    }
    if (graduationYear != null && graduationYear != profile.graduationYear) {
      return false;
    }
    if (domain != null &&
        domain != MemberModel.alphabeticKey(profile.domain ?? '')) {
      return false;
    }
    if (words.isEmpty) return true;
    final fields = [
      membersById[profile.userId]?.displayName,
      profile.displayName,
      profile.currentPosition,
      profile.currentCompany,
      profile.domain,
      profile.skills,
      profile.experienceSummary,
    ].whereType<String>();
    final searchable = MemberModel.alphabeticKey(fields.join(' '));
    return words.every(searchable.contains);
  }).toList();

  final names = {
    for (final profile in visible)
      profile.id: _nameKey(profile, membersById[profile.userId]),
  };
  visible.sort((left, right) {
    final leftName = names[left.id]!;
    final rightName = names[right.id]!;
    final byLastName = leftName.$1.compareTo(rightName.$1);
    if (byLastName != 0) return byLastName;
    final byFirstName = leftName.$2.compareTo(rightName.$2);
    return byFirstName == 0 ? left.id.compareTo(right.id) : byFirstName;
  });
  return visible;
}

(String, String) _nameKey(AlumniProfileModel profile, MemberModel? member) {
  final parts = MemberModel.alphabeticKey(
    member?.displayName ?? profile.displayName,
  ).split(' ');
  final firstName = MemberModel.alphabeticKey(
    profile.firstName ?? member?.firstName ?? '',
  );
  final lastName = MemberModel.alphabeticKey(
    profile.lastName ?? member?.lastName ?? '',
  );
  return (
    lastName.isEmpty ? parts.last : lastName,
    firstName.isEmpty ? parts.take(parts.length - 1).join(' ') : firstName,
  );
}
