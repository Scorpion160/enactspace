import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/application_model.dart';

abstract interface class CampaignToolsProvider {
  RecruitmentCampaignTools get campaignTools;
}

abstract interface class RecruitmentCampaignTools {
  Future<Map<String, dynamic>> loadAccess();
  Future<Map<String, dynamic>> loadJury(String campaignId);
  Future<List<Map<String, dynamic>>> eligibleJury(
    String campaignId,
    String search,
  );
  Future<void> appointJury(String campaignId, String userId);
  Future<Map<String, dynamic>> revokeJury(String campaignId, String memberId);
  Future<Map<String, dynamic>> loadPersonality(String applicationId);
  Future<void> invitePersonality(String applicationId, DateTime? dueAt);
  Future<ApplicationModel> scheduleWithJury(
    String applicationId,
    Map<String, dynamic> appointment,
  );
}

class ApiRecruitmentCampaignTools implements RecruitmentCampaignTools {
  final ApiClient _api;
  final AuthService _auth;
  ApiRecruitmentCampaignTools({ApiClient? api, AuthService? auth})
    : _api = api ?? ApiClient(),
      _auth = auth ?? AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null) throw StateError('Connecte-toi pour poursuivre.');
    return token;
  }

  @override
  Future<Map<String, dynamic>> loadAccess() async => Map<String, dynamic>.from(
    await _api.get('/recruitment/access', token: await _token()) as Map,
  );
  @override
  Future<Map<String, dynamic>> loadJury(String campaignId) async =>
      Map<String, dynamic>.from(
        await _api.get(
              '/recruitment/campaigns/$campaignId/jury',
              token: await _token(),
            )
            as Map,
      );
  @override
  Future<List<Map<String, dynamic>>> eligibleJury(
    String campaignId,
    String search,
  ) async {
    final raw = await _api.get(
      '/recruitment/campaigns/$campaignId/jury/eligible?search=${Uri.encodeQueryComponent(search)}',
      token: await _token(),
    );
    return (raw as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  @override
  Future<void> appointJury(String campaignId, String userId) async {
    await _api.postJson(
      '/recruitment/campaigns/$campaignId/jury',
      token: await _token(),
      data: {'user_id': userId},
    );
  }

  @override
  Future<Map<String, dynamic>> revokeJury(
    String campaignId,
    String memberId,
  ) async => Map<String, dynamic>.from(
    await _api.delete(
          '/recruitment/campaigns/$campaignId/jury/$memberId',
          token: await _token(),
        )
        as Map,
  );
  @override
  Future<Map<String, dynamic>> loadPersonality(String applicationId) async =>
      Map<String, dynamic>.from(
        await _api.get(
              '/recruitment/applications/$applicationId/personality',
              token: await _token(),
            )
            as Map,
      );
  @override
  Future<void> invitePersonality(String applicationId, DateTime? dueAt) async {
    await _api.postJson(
      '/recruitment/applications/$applicationId/personality/invite',
      token: await _token(),
      data: {'due_at': dueAt?.toUtc().toIso8601String()},
    );
  }

  @override
  Future<ApplicationModel> scheduleWithJury(
    String applicationId,
    Map<String, dynamic> appointment,
  ) async => ApplicationModel.fromJson(
    Map<String, dynamic>.from(
      await _api.postJson(
            '/recruitment/applications/$applicationId/interview',
            token: await _token(),
            data: appointment,
          )
          as Map,
    ),
  );
}

abstract interface class PublicPersonalityGateway {
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> body,
  );
}

class ApiPublicPersonalityGateway implements PublicPersonalityGateway {
  final ApiClient _api;
  ApiPublicPersonalityGateway({ApiClient? api}) : _api = api ?? ApiClient();
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> body,
  ) async {
    if (!const {'load', 'save', 'submit', 'decline'}.contains(action)) {
      throw ArgumentError.value(action);
    }
    return Map<String, dynamic>.from(
      await _api.postJson('/recruitment/personality/$action', data: body)
          as Map,
    );
  }
}
