import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/member_model.dart';

class MembersService {
  final ApiClient _apiClient;
  final AuthService _authService;

  MembersService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<MemberModel>> getMembers() {
    return _getMembersFrom('/users/directory');
  }

  Future<List<MemberModel>> getManagedMembers() {
    return _getMembersFrom('/users/');
  }

  Future<List<MemberModel>> getPendingMembers() {
    return _getMembersFrom('/users/pending');
  }

  Future<List<MemberModel>> _getMembersFrom(String path) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.get(path, token: token);

    final List<dynamic> rawList;

    if (response is List) {
      rawList = response;
    } else if (response is Map && response['data'] is List) {
      rawList = response['data'] as List;
    } else if (response is Map && response['items'] is List) {
      rawList = response['items'] as List;
    } else {
      rawList = [];
    }

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(MemberModel.fromJson)
        .toList();
  }

  Future<MemberModel> createMember({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/users/',
      token: token,
      data: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'password': password.trim(),
        'status': 'pending',
      },
    );

    if (response is Map<String, dynamic>) {
      return MemberModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du membre.');
  }

  Future<MemberModel> approveMember(String userId) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/users/$userId/approve',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return MemberModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’approbation du membre.');
  }

  Future<MemberModel> rejectMember(String userId) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/users/$userId/reject',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return MemberModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du rejet de la demande.');
  }

  Future<MemberModel> suspendMember(String userId) {
    return _postMemberAction(userId, 'suspend');
  }

  Future<MemberModel> reactivateMember(String userId) {
    return _postMemberAction(userId, 'reactivate');
  }

  Future<MemberModel> makeAlumni(String userId) {
    return _postMemberAction(userId, 'make-alumni');
  }

  Future<MemberModel> _postMemberAction(String userId, String action) async {
    final token = await _authService.getToken();
    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/users/$userId/$action',
      token: token,
      data: {},
    );
    if (response is Map<String, dynamic>) {
      return MemberModel.fromJson(response);
    }
    throw Exception('Réponse invalide lors de la mise à jour du membre.');
  }

  Future<MemberModel> assignRoles({
    required String userId,
    required List<String> roleNames,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _apiClient.postJson(
      '/users/$userId/roles',
      token: token,
      data: {'role_names': roleNames},
    );

    if (response is Map<String, dynamic>) {
      return MemberModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’assignation du rôle.');
  }

  Future<MemberModel> updateMemberAdmin({
    required String userId,
    String? status,
    bool? emailVerified,
    bool? isActive,
    String? department,
    String? studyLevel,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final Map<String, dynamic> data = {};

    if (status != null) data['status'] = status;
    if (emailVerified != null) data['email_verified'] = emailVerified;
    if (isActive != null) data['is_active'] = isActive;
    if (department != null) data['department'] = department;
    if (studyLevel != null) data['study_level'] = studyLevel;

    final response = await _apiClient.patchJson(
      '/users/$userId/admin',
      token: token,
      data: data,
    );

    if (response is Map<String, dynamic>) {
      return MemberModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la mise à jour du membre.');
  }
}
