// ignore_for_file: curly_braces_in_flow_control_structures

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/impact_models.dart';
import '../models/impact_record_models.dart';
import 'impact_service.dart';

abstract class ImpactGateway {
  Future<ImpactDashboardData> loadDashboard();
  Future<List<ImpactRecordModel>> getRecords();
  Future<ImpactRecordModel> getRecord(String id);
  Future<ImpactRecordModel> createRecord(Map<String, dynamic> fields);
  Future<ImpactRecordModel> updateRecord(
    String id,
    Map<String, dynamic> fields,
  );
  Future<ImpactRecordModel> validateRecord(String id);
  Future<ImpactRecordModel> rejectRecord(String id, String reason);
  Future<List<ImpactMetricModel>> getMetrics(String recordId);
  Future<ImpactMetricModel> createMetric(
    String recordId,
    Map<String, dynamic> fields,
  );
  Future<ImpactMetricModel> validateMetric(String id);
  Future<ImpactMetricModel> rejectMetric(String id, String reason);
  Future<List<ImpactEvidenceModel>> getEvidence(String recordId);
  Future<ImpactEvidenceModel> createEvidence(
    String recordId,
    Map<String, dynamic> fields,
  );
  Future<ImpactEvidenceModel> validateEvidence(String id);
  Future<ImpactEvidenceModel> rejectEvidence(String id, String reason);
}

class ApiImpactGateway implements ImpactGateway {
  final ImpactService service;
  final ApiClient apiClient;
  final AuthService authService;
  ApiImpactGateway({
    ImpactService? service,
    ApiClient? apiClient,
    AuthService? authService,
  }) : service = service ?? ImpactService(),
       apiClient = apiClient ?? ApiClient(),
       authService = authService ?? AuthService();
  Future<String> _token() async {
    final value = await authService.getToken();
    if (value == null || value.isEmpty)
      throw Exception('Utilisateur non connecté.');
    return value;
  }

  List<dynamic> _items(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['items'] is List) return value['items'] as List;
    if (value is Map && value['data'] is List) return value['data'] as List;
    throw Exception('Réponse Impact invalide.');
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw Exception('Réponse Impact invalide.');
  }

  @override
  Future<ImpactDashboardData> loadDashboard() => service.getDashboard();
  @override
  Future<List<ImpactRecordModel>> getRecords() async => _items(
    await apiClient.get('/impact/records', token: await _token()),
  ).whereType<Map<String, dynamic>>().map(ImpactRecordModel.fromJson).toList();
  @override
  Future<ImpactRecordModel> getRecord(String id) async {
    final records = await getRecords();
    return records.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Fiche Impact introuvable.'),
    );
  }

  @override
  Future<ImpactRecordModel> createRecord(Map<String, dynamic> fields) async =>
      ImpactRecordModel.fromJson(
        _map(
          await apiClient.postJson(
            '/impact/records',
            token: await _token(),
            data: fields,
          ),
        ),
      );
  @override
  Future<ImpactRecordModel> updateRecord(
    String id,
    Map<String, dynamic> fields,
  ) async => ImpactRecordModel.fromJson(
    _map(
      await apiClient.patchJson(
        '/impact/records/$id',
        token: await _token(),
        data: fields,
      ),
    ),
  );
  Future<ImpactRecordModel> _recordAction(
    String id,
    String action, [
    Map<String, dynamic> data = const {},
  ]) async => ImpactRecordModel.fromJson(
    _map(
      await apiClient.postJson(
        '/impact/records/$id/$action',
        token: await _token(),
        data: data,
      ),
    ),
  );
  @override
  Future<ImpactRecordModel> validateRecord(String id) =>
      _recordAction(id, 'validate');
  @override
  Future<ImpactRecordModel> rejectRecord(String id, String reason) =>
      _recordAction(id, 'reject', {'reason': reason.trim()});
  @override
  Future<List<ImpactMetricModel>> getMetrics(String id) async => _items(
    await apiClient.get('/impact/records/$id/metrics', token: await _token()),
  ).whereType<Map<String, dynamic>>().map(ImpactMetricModel.fromJson).toList();
  @override
  Future<ImpactMetricModel> createMetric(
    String id,
    Map<String, dynamic> fields,
  ) async => ImpactMetricModel.fromJson(
    _map(
      await apiClient.postJson(
        '/impact/records/$id/metrics',
        token: await _token(),
        data: fields,
      ),
    ),
  );
  Future<ImpactMetricModel> _metricAction(
    String id,
    String action, [
    Map<String, dynamic> data = const {},
  ]) async => ImpactMetricModel.fromJson(
    _map(
      await apiClient.postJson(
        '/impact/metrics/$id/$action',
        token: await _token(),
        data: data,
      ),
    ),
  );
  @override
  Future<ImpactMetricModel> validateMetric(String id) =>
      _metricAction(id, 'validate');
  @override
  Future<ImpactMetricModel> rejectMetric(String id, String reason) =>
      _metricAction(id, 'reject', {'reason': reason.trim()});
  @override
  Future<List<ImpactEvidenceModel>> getEvidence(String id) async =>
      _items(
            await apiClient.get(
              '/impact/records/$id/evidence',
              token: await _token(),
            ),
          )
          .whereType<Map<String, dynamic>>()
          .map(ImpactEvidenceModel.fromJson)
          .toList();
  @override
  Future<ImpactEvidenceModel> createEvidence(
    String id,
    Map<String, dynamic> fields,
  ) async => ImpactEvidenceModel.fromJson(
    _map(
      await apiClient.postJson(
        '/impact/records/$id/evidence',
        token: await _token(),
        data: fields,
      ),
    ),
  );
  Future<ImpactEvidenceModel> _evidenceAction(
    String id,
    String action, [
    Map<String, dynamic> data = const {},
  ]) async => ImpactEvidenceModel.fromJson(
    _map(
      await apiClient.postJson(
        '/impact/evidence/$id/$action',
        token: await _token(),
        data: data,
      ),
    ),
  );
  @override
  Future<ImpactEvidenceModel> validateEvidence(String id) =>
      _evidenceAction(id, 'validate');
  @override
  Future<ImpactEvidenceModel> rejectEvidence(String id, String reason) =>
      _evidenceAction(id, 'reject', {'reason': reason.trim()});
}
