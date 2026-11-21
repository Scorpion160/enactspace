import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/help_models.dart';
import '../models/managed_help_models.dart';

abstract interface class HelpGateway {
  Future<List<SupportTicket>> loadTickets();
  Future<SupportTicket> loadTicket(String id);
  Future<SupportTicket> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String message,
    String? clientRequestId,
  });
  Future<SupportMessage> replyToTicket(
    String id,
    String message, {
    String? clientRequestId,
  });
  Future<List<ProductFeedback>> loadFeedback();
  Future<ProductFeedback> createFeedback({
    required String category,
    required String message,
    int? rating,
    String? platform,
    String? appVersion,
    int? buildNumber,
    String? clientRequestId,
  });
}

class ApiHelpGateway implements HelpGateway, HelpManagementGateway {
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
    String? clientRequestId,
  }) async {
    final response = await _api.postJson(
      '/support/tickets',
      data: {
        'subject': subject,
        'client_request_id': ?clientRequestId,
        'category': category,
        'priority': priority,
        'message': message,
      },
      token: await _token(),
    );
    return SupportTicket.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<SupportMessage> replyToTicket(
    String id,
    String message, {
    String? clientRequestId,
  }) async {
    final response = await _api.postJson(
      '/support/tickets/$id/messages',
      data: {'message': message, 'client_request_id': ?clientRequestId},
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
    String? clientRequestId,
  }) async {
    final response = await _api.postJson(
      '/feedback',
      data: {
        'category': category,
        'message': message,
        'rating': ?rating,
        'client_request_id': ?clientRequestId,
        'platform': ?platform,
        'app_version': ?appVersion,
        'build_number': ?buildNumber,
      },
      token: await _token(),
    );
    return ProductFeedback.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<SupportTicket>> loadManagedTickets() async {
    final data = await _api.get(
      '/admin/support/tickets',
      token: await _token(),
    );
    return (data as List)
        .map(
          (item) =>
              SupportTicket.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<SupportTicket> loadManagedTicket(String id) async =>
      SupportTicket.fromJson(
        Map<String, dynamic>.from(
          await _api.get('/admin/support/tickets/$id', token: await _token()),
        ),
      );
  @override
  Future<SupportTicket> manageTicket(
    String id, {
    String? status,
    String? priority,
    String? assignedToId,
    bool updateAssignment = false,
    required DateTime expectedUpdatedAt,
  }) async => SupportTicket.fromJson(
    Map<String, dynamic>.from(
      await _api.patchJson(
        '/admin/support/tickets/$id',
        token: await _token(),
        data: {
          'status': ?status,
          'priority': ?priority,
          if (updateAssignment) 'assigned_to_id': assignedToId,
          'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
        },
      ),
    ),
  );
  @override
  Future<SupportMessage> replyAsManager(
    String id,
    String message, {
    String? clientRequestId,
  }) async => SupportMessage.fromJson(
    Map<String, dynamic>.from(
      await _api.postJson(
        '/admin/support/tickets/$id/messages',
        token: await _token(),
        data: {'message': message, 'client_request_id': ?clientRequestId},
      ),
    ),
  );
  @override
  Future<List<ManagedFeedback>> loadManagedFeedback() async {
    final data = await _api.get('/admin/feedback', token: await _token());
    return (data as List)
        .map(
          (item) =>
              ManagedFeedback.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<ManagedFeedback> loadManagedFeedbackItem(String id) async =>
      ManagedFeedback.fromJson(
        Map<String, dynamic>.from(
          await _api.get('/admin/feedback/$id', token: await _token()),
        ),
      );
  @override
  Future<ManagedFeedback> manageFeedback(
    String id, {
    required String status,
    required String publicReply,
    required String adminNote,
    required DateTime expectedUpdatedAt,
  }) async => ManagedFeedback.fromJson(
    Map<String, dynamic>.from(
      await _api.patchJson(
        '/admin/feedback/$id',
        token: await _token(),
        data: {
          'status': status,
          'public_reply': publicReply,
          'admin_note': adminNote,
          'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
        },
      ),
    ),
  );
}

abstract interface class HelpManagementGateway {
  Future<List<SupportTicket>> loadManagedTickets();
  Future<SupportTicket> loadManagedTicket(String id);
  Future<SupportTicket> manageTicket(
    String id, {
    String? status,
    String? priority,
    String? assignedToId,
    bool updateAssignment = false,
    required DateTime expectedUpdatedAt,
  });
  Future<SupportMessage> replyAsManager(
    String id,
    String message, {
    String? clientRequestId,
  });
  Future<List<ManagedFeedback>> loadManagedFeedback();
  Future<ManagedFeedback> loadManagedFeedbackItem(String id);
  Future<ManagedFeedback> manageFeedback(
    String id, {
    required String status,
    required String publicReply,
    required String adminNote,
    required DateTime expectedUpdatedAt,
  });
}
