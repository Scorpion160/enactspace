import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/fee_model.dart';
import '../models/financial_account_model.dart';
import '../models/payment_model.dart';

class FinanceService {
  final ApiClient _apiClient;
  final AuthService _authService;

  FinanceService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<FinancialAccountModel>> getAccounts() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/finance/accounts', token: token);

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(FinancialAccountModel.fromJson)
        .toList();
  }

  Future<List<FeeModel>> getFees() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/finance/fees', token: token);

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(FeeModel.fromJson)
        .toList();
  }

  Future<List<PaymentModel>> getPayments() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/finance/payments', token: token);

    final rawList = _extractList(response);

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(PaymentModel.fromJson)
        .toList();
  }

  Future<PaymentModel> createPayment({
    required String userId,
    required double amount,
    required String method,
    String? reference,
    String? proofUrl,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/finance/payments',
      token: token,
      data: {
        'user_id': userId,
        'amount': amount,
        'method': method,
        'reference': reference,
        'proof_url': proofUrl,
      },
    );

    if (response is Map<String, dynamic>) {
      return PaymentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du paiement.');
  }

  Future<PaymentModel> validatePayment(String paymentId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/finance/payments/$paymentId/validate',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return PaymentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la validation du paiement.');
  }

  Future<PaymentModel> cancelPayment(String paymentId) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.postJson(
      '/finance/payments/$paymentId/cancel',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return PaymentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’annulation du paiement.');
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
