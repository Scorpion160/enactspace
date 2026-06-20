import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/pole_model.dart';
import '../../members/models/member_model.dart';

class PolesService {
  final ApiClient _apiClient;
  final AuthService _authService;

  PolesService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<PoleModel>> getPoles() async {
    final token = await _requireToken();
    final response = await _apiClient.get('/poles/', token: token);

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(PoleModel.fromJson).toList();
  }

  Future<List<MemberModel>> getPoleMembers(String poleId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/poles/$poleId/members',
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(MemberModel.fromJson).toList();
  }

  Future<PoleModel> createPole({
    required String name,
    required String shortName,
    required String type,
    required String description,
    required String objectives,
  }) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/poles/',
      token: token,
      data: {
        'name': name.trim(),
        'short_name': shortName.trim().isEmpty ? null : shortName.trim(),
        'type': type,
        'description': description.trim().isEmpty ? null : description.trim(),
        'objectives': objectives.trim().isEmpty ? null : objectives.trim(),
      },
    );

    if (response is Map<String, dynamic>) {
      return PoleModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du pôle.');
  }

  Future<void> assignMember({
    required String poleId,
    required String userId,
    required String position,
  }) async {
    final token = await _requireToken();
    await _apiClient.postJson(
      '/poles/$poleId/members',
      token: token,
      data: {'user_id': userId, 'position': position},
    );
  }

  Future<void> removeMember({
    required String poleId,
    required String userId,
  }) async {
    final token = await _requireToken();
    await _apiClient.delete('/poles/$poleId/members/$userId', token: token);
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
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
