import '../models/dashboard_summary_model.dart';
import 'dashboard_service.dart';

abstract interface class DashboardGateway {
  Future<DashboardSummaryModel> loadSummary();
}

class ApiDashboardGateway implements DashboardGateway {
  final DashboardService _service;

  ApiDashboardGateway({DashboardService? service})
    : _service = service ?? DashboardService();

  @override
  Future<DashboardSummaryModel> loadSummary() => _service.getSummary();
}
