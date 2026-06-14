import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/gamification_models.dart';

class GamificationService {
  final ApiClient _apiClient;
  final AuthService _authService;

  GamificationService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<EngagementPointModel>> getPoints({
    String? userId,
    String? poleId,
    String? sourceType,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      _path('/gamification/points', {
        'user_id': userId,
        'pole_id': poleId,
        'source_type': sourceType,
      }),
      token: token,
    );

    return _extractList(response)
        .whereType<Map<String, dynamic>>()
        .map(EngagementPointModel.fromJson)
        .toList();
  }

  Future<EngagementPointModel> createPoint({
    required String userId,
    String? poleId,
    required String sourceType,
    required int points,
    String? reason,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/gamification/points',
      token: token,
      data: {
        'user_id': userId,
        'pole_id': _nullable(poleId),
        'source_type': sourceType,
        'points': points,
        'reason': _nullable(reason),
      },
    );

    if (response is Map<String, dynamic>) {
      return EngagementPointModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’attribution des points.');
  }

  Future<List<UserRankingModel>> getUserRanking({
    required int month,
    required int year,
    int limit = 20,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/gamification/ranking/users?month=$month&year=$year&limit=$limit',
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(UserRankingModel.fromJson).toList();
  }

  Future<List<PoleRankingModel>> getPoleRanking({
    required int month,
    required int year,
    int limit = 20,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/gamification/ranking/poles?month=$month&year=$year&limit=$limit',
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(PoleRankingModel.fromJson).toList();
  }

  Future<MonthlyWinnerModel> getMemberOfMonth({
    required int month,
    required int year,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/gamification/winner/member-of-month?month=$month&year=$year',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return MonthlyWinnerModel.fromJson(response);
    }

    throw Exception('Réponse invalide pour le membre du mois.');
  }

  Future<MonthlyWinnerModel> getPoleOfMonth({
    required int month,
    required int year,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/gamification/winner/pole-of-month?month=$month&year=$year',
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return MonthlyWinnerModel.fromJson(response);
    }

    throw Exception('Réponse invalide pour le pôle du mois.');
  }

  Future<List<BadgeModel>> getBadges() async {
    final token = await _requireToken();
    final response = await _apiClient.get('/gamification/badges', token: token);

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(BadgeModel.fromJson).toList();
  }

  Future<List<BadgeModel>> initDefaultBadges() async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/gamification/badges/init-defaults',
      token: token,
      data: {},
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(BadgeModel.fromJson).toList();
  }

  Future<List<UserBadgeModel>> getUserBadges({String? userId}) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      _path('/gamification/user-badges', {'user_id': userId}),
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(UserBadgeModel.fromJson).toList();
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }

  String _path(String base, Map<String, String?> params) {
    final entries = params.entries.where(
      (entry) => entry.value != null && entry.value!.trim().isNotEmpty,
    );

    if (entries.isEmpty) return base;

    final query = entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value!)}',
        )
        .join('&');

    return '$base?$query';
  }

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    if (response is Map && response['items'] is List) {
      return response['items'] as List;
    }
    return [];
  }
}
