import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../models/gamification_models.dart';
import 'gamification_service.dart';

class GamificationCenterData {
  final UserExperience user;
  final List<MemberModel> members;
  final List<PoleModel> poles;
  final List<EngagementPointModel> points;
  final List<BadgeModel> badges;
  final List<UserBadgeModel> userBadges;
  final List<UserRankingModel> userRanking;
  final List<PoleRankingModel> poleRanking;
  final MonthlyWinnerModel memberOfMonth;
  final MonthlyWinnerModel poleOfMonth;
  const GamificationCenterData({
    required this.user,
    required this.members,
    required this.poles,
    required this.points,
    required this.badges,
    required this.userBadges,
    required this.userRanking,
    required this.poleRanking,
    required this.memberOfMonth,
    required this.poleOfMonth,
  });
}

abstract class GamificationGateway {
  Future<GamificationCenterData> load({required int month, required int year});
  Future<EngagementPointModel> createPoint({
    required String userId,
    String? seasonId,
    String? poleId,
    String? projectId,
    required String sourceType,
    String? sourceId,
    required int points,
    String? reason,
  });
  Future<List<BadgeModel>> initDefaultBadges();
  Future<BadgeModel> createBadge({
    required String name,
    required String label,
    String? description,
    String? iconUrl,
  });
  Future<BadgeModel> updateBadge(
    String badgeId, {
    String? name,
    String? label,
    String? description,
    String? iconUrl,
  });
  Future<void> deleteBadge(String badgeId);
  Future<UserBadgeModel> awardBadge({
    required String userId,
    required String badgeId,
    String? seasonId,
  });
  Future<void> removeUserBadge(String userBadgeId);
}

class ApiGamificationGateway implements GamificationGateway {
  final GamificationService service;
  final AuthService authService;
  final MembersService membersService;
  final PolesService polesService;
  ApiGamificationGateway({
    GamificationService? service,
    AuthService? authService,
    MembersService? membersService,
    PolesService? polesService,
  }) : service = service ?? GamificationService(),
       authService = authService ?? AuthService(),
       membersService = membersService ?? MembersService(),
       polesService = polesService ?? PolesService();

  @override
  Future<GamificationCenterData> load({
    required int month,
    required int year,
  }) async {
    final user = UserExperience.fromJson(await authService.getCurrentUser());
    final results = await Future.wait<dynamic>([
      polesService.getPoles(),
      service.getPoints(userId: user.canManageGamification ? null : user.id),
      service.getBadges(),
      service.getUserBadges(
        userId: user.canManageGamification ? null : user.id,
      ),
      service.getUserRanking(month: month, year: year),
      service.getPoleRanking(month: month, year: year),
      service.getMemberOfMonth(month: month, year: year),
      service.getPoleOfMonth(month: month, year: year),
      user.canManageGamification
          ? membersService.getMembers()
          : Future.value(<MemberModel>[]),
    ]);
    return GamificationCenterData(
      user: user,
      poles: results[0] as List<PoleModel>,
      points: results[1] as List<EngagementPointModel>,
      badges: results[2] as List<BadgeModel>,
      userBadges: results[3] as List<UserBadgeModel>,
      userRanking: results[4] as List<UserRankingModel>,
      poleRanking: results[5] as List<PoleRankingModel>,
      memberOfMonth: results[6] as MonthlyWinnerModel,
      poleOfMonth: results[7] as MonthlyWinnerModel,
      members: results[8] as List<MemberModel>,
    );
  }

  @override
  Future<EngagementPointModel> createPoint({
    required String userId,
    String? seasonId,
    String? poleId,
    String? projectId,
    required String sourceType,
    String? sourceId,
    required int points,
    String? reason,
  }) => service.createPoint(
    userId: userId,
    seasonId: seasonId,
    poleId: poleId,
    projectId: projectId,
    sourceType: sourceType,
    sourceId: sourceId,
    points: points,
    reason: reason,
  );
  @override
  Future<List<BadgeModel>> initDefaultBadges() => service.initDefaultBadges();
  @override
  Future<BadgeModel> createBadge({
    required String name,
    required String label,
    String? description,
    String? iconUrl,
  }) => service.createBadge(
    name: name,
    label: label,
    description: description,
    iconUrl: iconUrl,
  );
  @override
  Future<BadgeModel> updateBadge(
    String badgeId, {
    String? name,
    String? label,
    String? description,
    String? iconUrl,
  }) => service.updateBadge(
    badgeId,
    name: name,
    label: label,
    description: description,
    iconUrl: iconUrl,
  );
  @override
  Future<void> deleteBadge(String badgeId) => service.deleteBadge(badgeId);
  @override
  Future<UserBadgeModel> awardBadge({
    required String userId,
    required String badgeId,
    String? seasonId,
  }) =>
      service.awardBadge(userId: userId, badgeId: badgeId, seasonId: seasonId);
  @override
  Future<void> removeUserBadge(String userBadgeId) =>
      service.removeUserBadge(userBadgeId);
}
