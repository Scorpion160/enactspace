import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/dashboard_summary_model.dart';

class DashboardService {
  final ApiClient _apiClient;
  final AuthService _authService;

  DashboardService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<DashboardSummaryModel> getSummary() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');

    final response = await _apiClient.get('/dashboard/summary', token: token);
    if (response is Map<String, dynamic>) {
      return DashboardSummaryModel.fromJson(response);
    }

    throw Exception('Réponse dashboard invalide.');
  }
}
