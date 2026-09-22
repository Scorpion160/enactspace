import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/help_models.dart';

abstract interface class HelpGateway {
  Future<List<SupportTicket>> loadTickets();
  Future<SupportTicket> loadTicket(String id);
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String message,
  });
  Future<SupportMessage> replyToTicket(String id, String message);
  Future<List<ProductFeedback>> loadFeedback();
  Future<ProductFeedback> createFeedback({
    required String category,
    required String message,
    int? rating,
    String? platform,
    String? appVersion,
    int? buildNumber,
  });
}

class ApiHelpGateway implements HelpGateway {
  final ApiClient _api;
  final AuthService _auth;

  ApiHelpGateway({ApiClient? apiClient, AuthService? authService})
    : _api = apiClient ?? ApiClient(),
      _auth = authService ?? AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException(statusCode: 401, message: 'Session expirée.');
    }
    return token;
  }

  @override
  Future<List<SupportTicket>> loadTickets() async {
    final response = await _api.get('/support/tickets', token: await _token());
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }

  @override
  Future<SupportTicket> loadTicket(String id) async {
    final response = await _api.get(
      '/support/tickets/$id',
      token: await _token(),
    );
    return SupportTicket.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String message,
  }) async {
    final response = await _api.postJson(
      '/support/tickets',
      data: {
        'subject': subject,
        'category': category,
        'priority': priority,
        'message': message,
      },
      token: await _token(),
    );
    return SupportTicket.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<SupportMessage> replyToTicket(String id, String message) async {
    final response = await _api.postJson(
      '/support/tickets/$id/messages',
      data: {'message': message},
      token: await _token(),
    );
    return SupportMessage.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<ProductFeedback>> loadFeedback() async {
    final response = await _api.get('/feedback', token: await _token());
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ProductFeedback.fromJson)
        .toList();
  }

  @override
  Future<ProductFeedback> createFeedback({
    required String category,
    required String message,
    int? rating,
    String? platform,
    String? appVersion,
    int? buildNumber,
  }) async {
    final response = await _api.postJson(
      '/feedback',
      data: {
        'category': category,
        'message': message,
        'rating': ?rating,
        'platform': ?platform,
        'app_version': ?appVersion,
        'build_number': ?buildNumber,
      },
      token: await _token(),
    );
    return ProductFeedback.fromJson(response as Map<String, dynamic>);
  }
}
