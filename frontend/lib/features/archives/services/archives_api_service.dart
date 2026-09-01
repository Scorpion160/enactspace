import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/archive_models.dart';

/// Transport HTTP du domaine Archives. Il ne contient ni politique d'UX,
/// ni données historiques locales.
class ArchivesService {
  final ApiClient _apiClient;
  final AuthService _authService;

  ArchivesService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<String> _token() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Utilisateur non connecté.');
    }
    return token;
  }

  String _path(String path, Map<String, Object?> query) {
    final filtered = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && '${entry.value}'.trim().isNotEmpty)
          entry.key: '${entry.value}',
    };
    return Uri(path: path, queryParameters: filtered).toString();
  }

  List<Map<String, dynamic>> _items(dynamic response) {
    final raw = response is List
        ? response
        : response is Map
        ? response['items'] ?? response['data'] ?? const []
        : const [];
    return raw is List
        ? raw.whereType<Map>().map(archiveMap).toList(growable: false)
        : const [];
  }

  Map<String, dynamic> _object(dynamic response) {
    if (response is! Map) throw const FormatException('Réponse API invalide.');
    return archiveMap(response);
  }

  Future<List<ArchiveItemModel>> getItems({
    String? search,
    String? category,
    int? year,
    String? status,
    String? visibility,
  }) async {
    final response = await _apiClient.get(
      _path('/archives/items', {
        'search': search,
        'category': category,
        'year': year,
        'status': status,
        'visibility': visibility,
      }),
      token: await _token(),
    );
    return _items(response).map(ArchiveItemModel.fromJson).toList();
  }

  Future<ArchiveItemModel> getItem(String id) async =>
      ArchiveItemModel.fromJson(
        _object(
          await _apiClient.get('/archives/items/$id', token: await _token()),
        ),
      );

  Future<ArchiveItemModel> createItem(Map<String, dynamic> payload) async =>
      ArchiveItemModel.fromJson(
        _object(
          await _apiClient.postJson(
            '/archives/items',
            data: archivePayload(payload),
            token: await _token(),
          ),
        ),
      );

  Future<ArchiveItemModel> updateItem(
    String id,
    Map<String, dynamic> payload,
  ) async => ArchiveItemModel.fromJson(
    _object(
      await _apiClient.patchJson(
        '/archives/items/$id',
        data: archivePayload(payload),
        token: await _token(),
      ),
    ),
  );

  Future<ArchiveItemModel> submitItem(String id) => _itemAction(id, 'submit');
  Future<ArchiveItemModel> validateItem(String id) =>
      _itemAction(id, 'validate');
  Future<ArchiveItemModel> archiveItem(String id) => _itemAction(id, 'archive');

  Future<ArchiveItemModel> rejectItem(String id, String reason) =>
      _itemAction(id, 'reject', {'reason': reason});

  Future<ArchiveItemModel> _itemAction(
    String id,
    String action, [
    Map<String, dynamic> data = const {},
  ]) async => ArchiveItemModel.fromJson(
    _object(
      await _apiClient.postJson(
        '/archives/items/$id/$action',
        data: data,
        token: await _token(),
      ),
    ),
  );

  Future<String> exportItemsCsv() => _token().then(
    (token) => _apiClient.getText('/archives/export/items.csv', token: token),
  );

  Future<List<HistoricalProjectModel>> getHistoricalProjects({
    String? search,
    int? year,
    String? status,
    bool includeStatic = true,
  }) async {
    final response = await _apiClient.get(
      _path('/archives/historical-projects', {
        'search': search,
        'year': year,
        'status': status,
        'include_static': includeStatic,
      }),
      token: await _token(),
    );
    return _items(response).map(HistoricalProjectModel.fromJson).toList();
  }

  Future<HistoricalProjectModel> getHistoricalProject(String id) async =>
      HistoricalProjectModel.fromJson(
        _object(
          await _apiClient.get(
            '/archives/historical-projects/$id',
            token: await _token(),
          ),
        ),
      );

  Future<HistoricalProjectModel> createHistoricalProject(
    Map<String, dynamic> payload,
  ) => _create(
    '/archives/historical-projects',
    payload,
    HistoricalProjectModel.fromJson,
  );

  Future<HistoricalProjectModel> updateHistoricalProject(
    String id,
    Map<String, dynamic> payload,
  ) => _update(
    '/archives/historical-projects/$id',
    payload,
    HistoricalProjectModel.fromJson,
  );

  Future<List<ArchiveAwardModel>> getAwards() =>
      _list('/archives/awards', ArchiveAwardModel.fromJson);
  Future<ArchiveAwardModel> getAward(String id) =>
      _get('/archives/awards/$id', ArchiveAwardModel.fromJson);
  Future<ArchiveAwardModel> createAward(Map<String, dynamic> payload) =>
      _create('/archives/awards', payload, ArchiveAwardModel.fromJson);
  Future<ArchiveAwardModel> updateAward(
    String id,
    Map<String, dynamic> payload,
  ) => _update('/archives/awards/$id', payload, ArchiveAwardModel.fromJson);

  Future<List<ArchiveCompetitionModel>> getCompetitions() =>
      _list('/archives/competitions', ArchiveCompetitionModel.fromJson);
  Future<ArchiveCompetitionModel> getCompetition(String id) =>
      _get('/archives/competitions/$id', ArchiveCompetitionModel.fromJson);
  Future<ArchiveCompetitionModel> createCompetition(
    Map<String, dynamic> payload,
  ) => _create(
    '/archives/competitions',
    payload,
    ArchiveCompetitionModel.fromJson,
  );
  Future<ArchiveCompetitionModel> updateCompetition(
    String id,
    Map<String, dynamic> payload,
  ) => _update(
    '/archives/competitions/$id',
    payload,
    ArchiveCompetitionModel.fromJson,
  );

  Future<List<ArchiveMediaModel>> getMedia({
    String? search,
    int? year,
    String? mediaType,
    String? projectId,
  }) async {
    final response = await _apiClient.get(
      _path('/archives/media', {
        'search': search,
        'year': year,
        'media_type': mediaType,
        'project_id': projectId,
      }),
      token: await _token(),
    );
    return _items(response).map(ArchiveMediaModel.fromJson).toList();
  }

  Future<ArchiveMediaModel> createMedia(Map<String, dynamic> payload) =>
      _create('/archives/media', payload, ArchiveMediaModel.fromJson);
  Future<ArchiveMediaModel> updateMedia(
    String id,
    Map<String, dynamic> payload,
  ) => _update('/archives/media/$id', payload, ArchiveMediaModel.fromJson);

  Future<List<ArchiveDocumentModel>> getDocuments() =>
      _list('/archives/documents', ArchiveDocumentModel.fromJson);
  Future<ArchiveDocumentModel> createDocument(Map<String, dynamic> payload) =>
      _create('/archives/documents', payload, ArchiveDocumentModel.fromJson);
  Future<ArchiveDocumentModel> updateDocument(
    String id,
    Map<String, dynamic> payload,
  ) => _update(
    '/archives/documents/$id',
    payload,
    ArchiveDocumentModel.fromJson,
  );

  Future<List<HallOfFameEntryModel>> getHallOfFame() async {
    final values = await _list(
      '/archives/hall-of-fame',
      HallOfFameEntryModel.fromJson,
    );
    values.sort((a, b) {
      final order = a.orderIndex.compareTo(b.orderIndex);
      if (order != 0) return order;
      return (b.year ?? 0).compareTo(a.year ?? 0);
    });
    return values;
  }

  Future<HallOfFameEntryModel> createHallOfFameEntry(
    Map<String, dynamic> payload,
  ) =>
      _create('/archives/hall-of-fame', payload, HallOfFameEntryModel.fromJson);
  Future<HallOfFameEntryModel> updateHallOfFameEntry(
    String id,
    Map<String, dynamic> payload,
  ) => _update(
    '/archives/hall-of-fame/$id',
    payload,
    HallOfFameEntryModel.fromJson,
  );

  Future<ArchiveImpactSummaryModel> getHistoricalImpactSummary() async =>
      ArchiveImpactSummaryModel.fromJson(
        _object(
          await _apiClient.get(
            '/archives/historical-impact/summary',
            token: await _token(),
          ),
        ),
      );

  Future<List<HistoricalStatisticModel>> getHistoricalStatistics() => _list(
    '/archives/historical-impact/statistics',
    HistoricalStatisticModel.fromJson,
  );
  Future<HistoricalStatisticModel> createHistoricalStatistic(
    Map<String, dynamic> payload,
  ) => _create(
    '/archives/historical-impact/statistics',
    payload,
    HistoricalStatisticModel.fromJson,
  );
  Future<HistoricalStatisticModel> updateHistoricalStatistic(
    String id,
    Map<String, dynamic> payload,
  ) => _update(
    '/archives/historical-impact/statistics/$id',
    payload,
    HistoricalStatisticModel.fromJson,
  );

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async => _items(
    await _apiClient.get(path, token: await _token()),
  ).map(parse).toList();

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async => parse(_object(await _apiClient.get(path, token: await _token())));

  Future<T> _create<T>(
    String path,
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) parse,
  ) async => parse(
    _object(
      await _apiClient.postJson(
        path,
        data: archivePayload(payload),
        token: await _token(),
      ),
    ),
  );

  Future<T> _update<T>(
    String path,
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) parse,
  ) async => parse(
    _object(
      await _apiClient.patchJson(
        path,
        data: archivePayload(payload),
        token: await _token(),
      ),
    ),
  );
}
