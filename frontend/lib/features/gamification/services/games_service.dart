import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

class GamesService {
  final ApiClient _api;
  final AuthService _auth;
  GamesService({ApiClient? api, AuthService? auth})
      : _api = api ?? ApiClient(),
        _auth = auth ?? AuthService();

  Future<String> _token() async {
    final value = await _auth.getToken();
    if (value == null || value.isEmpty) throw StateError('Connexion requise.');
    return value;
  }

  Future<Map<String, dynamic>> create(String game, String mode, String theme,
      int rounds) async =>
      Map<String, dynamic>.from(await _api.postJson('/games/rooms',
          data: {'game': game, 'mode': mode, 'theme': theme, 'rounds': rounds},
          token: await _token()));

  Future<Map<String, dynamic>> join(String code, {String? team}) async =>
      Map<String, dynamic>.from(await _api.postJson('/games/rooms/join',
          data: {'code': code, 'team': team}, token: await _token()));

  Future<Map<String, dynamic>> room(String id) async =>
      Map<String, dynamic>.from(
          await _api.get('/games/rooms/$id', token: await _token()));

  Future<List<Map<String, dynamic>>> mine() async =>
      (await _api.get('/games/rooms/mine', token: await _token()) as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map)).toList();

  Future<Map<String, dynamic>> profile(String userId) async =>
      Map<String, dynamic>.from(await _api.get(
          '/games/profiles/$userId', token: await _token()));

  Future<List<Map<String, dynamic>>> leaderboard({String? game}) async =>
      (await _api.get('/games/leaderboard${game == null ? '' : '?game=$game'}',
          token: await _token()) as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map)).toList();

  Future<Map<String, dynamic>> action(String id, String verb,
      [String? answer]) async =>
      Map<String, dynamic>.from(await _api.postJson('/games/rooms/$id/$verb',
          data: answer == null ? {} : {'answer': answer},
          token: await _token()));
}
