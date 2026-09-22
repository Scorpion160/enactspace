import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/alumni_profile_model.dart';
import '../models/mentorship_model.dart';
import 'alumni_service.dart';

class AlumniCenterData {
  final UserExperience user;
  final List<AlumniProfileModel> profiles;
  final List<MentorshipModel> mentorships;
  final List<MemberModel> members;
  final List<ProjectModel> projects;
  final List<PoleModel> poles;

  const AlumniCenterData({
    required this.user,
    required this.profiles,
    required this.mentorships,
    required this.members,
    required this.projects,
    required this.poles,
  });
}

abstract class AlumniGateway {
  Future<AlumniCenterData> loadCenter({
    String? search,
    bool mentorsOnly = false,
    String mentorshipStatus = 'all',
  });
  Future<AlumniProfileModel> getProfile(String profileId);
  Future<AlumniProfileModel> createProfile({
    required String userId,
    int? graduationYear,
    required String currentCompany,
    required String currentPosition,
    required String domain,
    required String skills,
    required String experienceSummary,
    required bool availableForMentoring,
    required String linkedinUrl,
    required String portfolioUrl,
    required String visibility,
  });
  Future<AlumniProfileModel> updateProfile(
    String profileId, {
    int? graduationYear,
    String? currentCompany,
    String? currentPosition,
    String? domain,
    String? skills,
    String? experienceSummary,
    bool? availableForMentoring,
    String? linkedinUrl,
    String? portfolioUrl,
    String? visibility,
  });
  Future<void> deleteProfile(String profileId);
  Future<MentorshipModel> createMentorship({
    required String alumniId,
    String? projectId,
    String? poleId,
    required String title,
    required String objective,
    required String status,
  });
  Future<MentorshipModel> updateMentorship(
    String mentorshipId, {
    String? projectId,
    String? poleId,
    String? title,
    String? objective,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
  });
  Future<MentorshipModel> completeMentorship(String mentorshipId);
  Future<void> deleteMentorship(String mentorshipId);
}

class ApiAlumniGateway implements AlumniGateway {
  final AlumniService alumniService;
  final AuthService authService;
  final MembersService membersService;
  final ProjectsService projectsService;
  final PolesService polesService;

  ApiAlumniGateway({
    AlumniService? alumniService,
    AuthService? authService,
    MembersService? membersService,
    ProjectsService? projectsService,
    PolesService? polesService,
  }) : alumniService = alumniService ?? AlumniService(),
       authService = authService ?? AuthService(),
       membersService = membersService ?? MembersService(),
       projectsService = projectsService ?? ProjectsService(),
       polesService = polesService ?? PolesService();

  @override
  Future<AlumniCenterData> loadCenter({
    String? search,
    bool mentorsOnly = false,
    String mentorshipStatus = 'all',
  }) async {
    final user = UserExperience.fromJson(await authService.getCurrentUser());
    final core = await Future.wait<dynamic>([
      alumniService.getProfiles(
        search: search,
        availableForMentoring: mentorsOnly ? true : null,
      ),
      alumniService.getMentorships(status: mentorshipStatus),
    ]);
    final references = await Future.wait<dynamic>([
      if (user.canViewMembersDirectory)
        _safe(membersService.getMembers)
      else
        Future.value(<MemberModel>[]),
      if (user.canViewOperations)
        _safe(projectsService.getProjects)
      else
        Future.value(<ProjectModel>[]),
      if (user.canViewOperations)
        _safe(polesService.getPoles)
      else
        Future.value(<PoleModel>[]),
    ]);
    return AlumniCenterData(
      user: user,
      profiles: core[0] as List<AlumniProfileModel>,
      mentorships: core[1] as List<MentorshipModel>,
      members: references[0] as List<MemberModel>,
      projects: references[1] as List<ProjectModel>,
      poles: references[2] as List<PoleModel>,
    );
  }

  Future<List<T>> _safe<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return <T>[];
    }
  }

  @override
  Future<AlumniProfileModel> getProfile(String profileId) =>
      alumniService.getProfile(profileId);
  @override
  Future<AlumniProfileModel> createProfile({
    required String userId,
    int? graduationYear,
    required String currentCompany,
    required String currentPosition,
    required String domain,
    required String skills,
    required String experienceSummary,
    required bool availableForMentoring,
    required String linkedinUrl,
    required String portfolioUrl,
    required String visibility,
  }) => alumniService.createProfile(
    userId: userId,
    graduationYear: graduationYear,
    currentCompany: currentCompany,
    currentPosition: currentPosition,
    domain: domain,
    skills: skills,
    experienceSummary: experienceSummary,
    availableForMentoring: availableForMentoring,
    linkedinUrl: linkedinUrl,
    portfolioUrl: portfolioUrl,
    visibility: visibility,
  );
  @override
  Future<AlumniProfileModel> updateProfile(
    String profileId, {
    int? graduationYear,
    String? currentCompany,
    String? currentPosition,
    String? domain,
    String? skills,
    String? experienceSummary,
    bool? availableForMentoring,
    String? linkedinUrl,
    String? portfolioUrl,
    String? visibility,
  }) => alumniService.updateProfile(
    profileId,
    graduationYear: graduationYear,
    currentCompany: currentCompany,
    currentPosition: currentPosition,
    domain: domain,
    skills: skills,
    experienceSummary: experienceSummary,
    availableForMentoring: availableForMentoring,
    linkedinUrl: linkedinUrl,
    portfolioUrl: portfolioUrl,
    visibility: visibility,
  );
  @override
  Future<void> deleteProfile(String profileId) =>
      alumniService.deleteProfile(profileId);
  @override
  Future<MentorshipModel> createMentorship({
    required String alumniId,
    String? projectId,
    String? poleId,
    required String title,
    required String objective,
    required String status,
  }) => alumniService.createMentorship(
    alumniId: alumniId,
    projectId: projectId,
    poleId: poleId,
    title: title,
    objective: objective,
    status: status,
  );
  @override
  Future<MentorshipModel> updateMentorship(
    String mentorshipId, {
    String? projectId,
    String? poleId,
    String? title,
    String? objective,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
  }) => alumniService.updateMentorship(
    mentorshipId,
    projectId: projectId,
    poleId: poleId,
    title: title,
    objective: objective,
    status: status,
    startedAt: startedAt,
    endedAt: endedAt,
  );
  @override
  Future<MentorshipModel> completeMentorship(String mentorshipId) =>
      alumniService.completeMentorship(mentorshipId);
  @override
  Future<void> deleteMentorship(String mentorshipId) =>
      alumniService.deleteMentorship(mentorshipId);
}
