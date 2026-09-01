import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../models/archive_models.dart';
import 'archives_service.dart';

abstract class ArchivesGateway {
  Future<ArchivePermissions> getPermissions();
  Future<ArchivesHomeData> loadHome();

  Future<List<ArchiveItemModel>> getItems({
    String? search,
    String? category,
    int? year,
    String? status,
    String? visibility,
  });
  Future<ArchiveItemModel> getItem(String id);
  Future<ArchiveItemModel> createItem(Map<String, dynamic> payload);
  Future<ArchiveItemModel> updateItem(String id, Map<String, dynamic> payload);
  Future<ArchiveItemModel> submitItem(String id);
  Future<ArchiveItemModel> validateItem(String id);
  Future<ArchiveItemModel> rejectItem(String id, String reason);
  Future<ArchiveItemModel> archiveItem(String id);
  Future<String> exportItemsCsv();

  Future<List<HistoricalProjectModel>> getHistoricalProjects({
    String? search,
    int? year,
    String? status,
  });
  Future<HistoricalProjectModel> getHistoricalProject(String id);
  Future<HistoricalProjectModel> createHistoricalProject(
    Map<String, dynamic> payload,
  );
  Future<HistoricalProjectModel> updateHistoricalProject(
    String id,
    Map<String, dynamic> payload,
  );

  Future<List<ArchiveAwardModel>> getAwards();
  Future<ArchiveAwardModel> createAward(Map<String, dynamic> payload);
  Future<ArchiveAwardModel> updateAward(
    String id,
    Map<String, dynamic> payload,
  );
  Future<List<ArchiveCompetitionModel>> getCompetitions();
  Future<ArchiveCompetitionModel> createCompetition(
    Map<String, dynamic> payload,
  );
  Future<ArchiveCompetitionModel> updateCompetition(
    String id,
    Map<String, dynamic> payload,
  );

  Future<List<ArchiveMediaModel>> getMedia({
    String? search,
    int? year,
    String? mediaType,
    String? projectId,
  });
  Future<ArchiveMediaModel> createMedia(Map<String, dynamic> payload);
  Future<ArchiveMediaModel> updateMedia(
    String id,
    Map<String, dynamic> payload,
  );
  Future<List<ArchiveDocumentModel>> getDocuments();
  Future<ArchiveDocumentModel> createDocument(Map<String, dynamic> payload);
  Future<ArchiveDocumentModel> updateDocument(
    String id,
    Map<String, dynamic> payload,
  );

  Future<List<HallOfFameEntryModel>> getHallOfFame({bool refresh = false});
  Future<HallOfFameEntryModel?> getHallOfFameEntry(String id);
  Future<HallOfFameEntryModel> createHallOfFameEntry(
    Map<String, dynamic> payload,
  );
  Future<HallOfFameEntryModel> updateHallOfFameEntry(
    String id,
    Map<String, dynamic> payload,
  );

  Future<List<HistoricalStatisticModel>> getHistoricalStatistics();
  Future<HistoricalStatisticModel> saveHistoricalStatistic(
    HistoricalStatisticModel current,
    Map<String, dynamic> payload,
  );
}

class ApiArchivesGateway implements ArchivesGateway {
  final ArchivesService _service;
  final AuthService _authService;
  List<HallOfFameEntryModel>? _hallCache;
  List<HistoricalStatisticModel>? _statisticsCache;

  ApiArchivesGateway({ArchivesService? service, AuthService? authService})
    : _service = service ?? ArchivesService(),
      _authService = authService ?? AuthService();

  @override
  Future<ArchivePermissions> getPermissions() async {
    final cached = await _authService.getCachedCurrentUser();
    final json = cached ?? await _authService.getCurrentUser();
    return ArchivePermissions.fromUser(UserExperience.fromJson(json));
  }

  @override
  Future<ArchivesHomeData> loadHome() async {
    final values = await Future.wait<Object>([
      getPermissions(),
      _service.getHistoricalImpactSummary(),
      getHistoricalStatistics(),
      getHistoricalProjects(),
      getAwards(),
      getCompetitions(),
      getHallOfFame(),
      getDocuments(),
      getMedia(),
    ]);
    return ArchivesHomeData(
      permissions: values[0] as ArchivePermissions,
      summary: values[1] as ArchiveImpactSummaryModel,
      statistics: values[2] as List<HistoricalStatisticModel>,
      projects: values[3] as List<HistoricalProjectModel>,
      awards: values[4] as List<ArchiveAwardModel>,
      competitions: values[5] as List<ArchiveCompetitionModel>,
      hallOfFame: values[6] as List<HallOfFameEntryModel>,
      documents: values[7] as List<ArchiveDocumentModel>,
      media: values[8] as List<ArchiveMediaModel>,
    );
  }

  @override
  Future<List<ArchiveItemModel>> getItems({
    String? search,
    String? category,
    int? year,
    String? status,
    String? visibility,
  }) => _service.getItems(
    search: search,
    category: category,
    year: year,
    status: status,
    visibility: visibility,
  );
  @override
  Future<ArchiveItemModel> getItem(String id) => _service.getItem(id);
  @override
  Future<ArchiveItemModel> createItem(Map<String, dynamic> payload) =>
      _service.createItem(payload);
  @override
  Future<ArchiveItemModel> updateItem(
    String id,
    Map<String, dynamic> payload,
  ) => _service.updateItem(id, payload);
  @override
  Future<ArchiveItemModel> submitItem(String id) => _service.submitItem(id);
  @override
  Future<ArchiveItemModel> validateItem(String id) => _service.validateItem(id);
  @override
  Future<ArchiveItemModel> rejectItem(String id, String reason) =>
      _service.rejectItem(id, reason);
  @override
  Future<ArchiveItemModel> archiveItem(String id) => _service.archiveItem(id);
  @override
  Future<String> exportItemsCsv() => _service.exportItemsCsv();

  @override
  Future<List<HistoricalProjectModel>> getHistoricalProjects({
    String? search,
    int? year,
    String? status,
  }) => _service.getHistoricalProjects(
    search: search,
    year: year,
    status: status,
  );
  @override
  Future<HistoricalProjectModel> getHistoricalProject(String id) =>
      _service.getHistoricalProject(id);
  @override
  Future<HistoricalProjectModel> createHistoricalProject(
    Map<String, dynamic> payload,
  ) => _service.createHistoricalProject(payload);
  @override
  Future<HistoricalProjectModel> updateHistoricalProject(
    String id,
    Map<String, dynamic> payload,
  ) => _service.updateHistoricalProject(id, payload);

  @override
  Future<List<ArchiveAwardModel>> getAwards() => _service.getAwards();
  @override
  Future<ArchiveAwardModel> createAward(Map<String, dynamic> payload) =>
      _service.createAward(payload);
  @override
  Future<ArchiveAwardModel> updateAward(
    String id,
    Map<String, dynamic> payload,
  ) => _service.updateAward(id, payload);
  @override
  Future<List<ArchiveCompetitionModel>> getCompetitions() =>
      _service.getCompetitions();
  @override
  Future<ArchiveCompetitionModel> createCompetition(
    Map<String, dynamic> payload,
  ) => _service.createCompetition(payload);
  @override
  Future<ArchiveCompetitionModel> updateCompetition(
    String id,
    Map<String, dynamic> payload,
  ) => _service.updateCompetition(id, payload);

  @override
  Future<List<ArchiveMediaModel>> getMedia({
    String? search,
    int? year,
    String? mediaType,
    String? projectId,
  }) => _service.getMedia(
    search: search,
    year: year,
    mediaType: mediaType,
    projectId: projectId,
  );
  @override
  Future<ArchiveMediaModel> createMedia(Map<String, dynamic> payload) =>
      _service.createMedia(payload);
  @override
  Future<ArchiveMediaModel> updateMedia(
    String id,
    Map<String, dynamic> payload,
  ) => _service.updateMedia(id, payload);
  @override
  Future<List<ArchiveDocumentModel>> getDocuments() => _service.getDocuments();
  @override
  Future<ArchiveDocumentModel> createDocument(Map<String, dynamic> payload) =>
      _service.createDocument(payload);
  @override
  Future<ArchiveDocumentModel> updateDocument(
    String id,
    Map<String, dynamic> payload,
  ) => _service.updateDocument(id, payload);

  @override
  Future<List<HallOfFameEntryModel>> getHallOfFame({
    bool refresh = false,
  }) async {
    if (!refresh && _hallCache != null) return _hallCache!;
    _hallCache = await _service.getHallOfFame();
    return _hallCache!;
  }

  @override
  Future<HallOfFameEntryModel?> getHallOfFameEntry(String id) async {
    final entries = await getHallOfFame();
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<HallOfFameEntryModel> createHallOfFameEntry(
    Map<String, dynamic> payload,
  ) async {
    final result = await _service.createHallOfFameEntry(payload);
    _hallCache = null;
    return result;
  }

  @override
  Future<HallOfFameEntryModel> updateHallOfFameEntry(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final result = await _service.updateHallOfFameEntry(id, payload);
    _hallCache = null;
    return result;
  }

  @override
  Future<List<HistoricalStatisticModel>> getHistoricalStatistics() async {
    _statisticsCache = await _service.getHistoricalStatistics();
    return _statisticsCache!;
  }

  @override
  Future<HistoricalStatisticModel> saveHistoricalStatistic(
    HistoricalStatisticModel current,
    Map<String, dynamic> payload,
  ) async {
    if (current.isPersisted) {
      final result = await _service.updateHistoricalStatistic(
        current.id,
        payload,
      );
      _statisticsCache = null;
      return result;
    }

    final known = _statisticsCache ?? await getHistoricalStatistics();
    for (final statistic in known) {
      if (statistic.metricKey == current.metricKey && statistic.isPersisted) {
        final result = await _service.updateHistoricalStatistic(
          statistic.id,
          payload,
        );
        _statisticsCache = null;
        return result;
      }
    }
    final result = await _service.createHistoricalStatistic({
      ...payload,
      'metric_key': current.metricKey,
    });
    _statisticsCache = null;
    return result;
  }
}
