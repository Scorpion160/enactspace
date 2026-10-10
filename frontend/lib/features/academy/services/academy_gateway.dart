// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage_options.dart';
import '../../../core/auth/auth_service.dart';
import '../models/academy_models.dart';

class AcademyQuizQueuedException implements Exception {
  const AcademyQuizQueuedException();

  @override
  String toString() =>
      'Réponses conservées sur cet appareil. Le serveur n’a pas pu confirmer le résultat ; la validation sera retentée à la prochaine synchronisation.';
}

abstract class AcademyGateway {
  Future<AcademyHomeData> loadHome();
  Future<AcademyCourseModel> getCourse(String courseId);
  Future<void> startLesson(String lessonId);
  Future<AcademyRewardResult> completeLesson(String lessonId);
  Future<AcademyQuizModel> getQuiz(String quizId);
  Future<AcademyQuizResult> submitQuiz(String quizId, List<int> answers);
  Future<List<AcademyCourseModel>> getAdminCourses();
  Future<AcademyAdminSummary> getAdminSummary();
  Future<AcademyCourseModel> createCourse(Map<String, dynamic> fields);
  Future<AcademyCourseModel> updateCourse(
    String courseId,
    Map<String, dynamic> fields,
  );
  Future<void> publishCourse(String courseId);
  Future<void> unpublishCourse(String courseId);
  Future<void> archiveCourse(String courseId);
  Future<void> restoreCourse(String courseId);
  Future<List<AcademyLessonModel>> getAdminLessons(String courseId);
  Future<AcademyLessonModel> createLesson(
    String courseId,
    Map<String, dynamic> fields,
  );
  Future<AcademyLessonModel> updateLesson(
    String lessonId,
    Map<String, dynamic> fields,
  );
  Future<void> deleteLesson(String lessonId);
}

class ApiAcademyGateway implements AcademyGateway {
  final ApiClient apiClient;
  final AuthService authService;
  final FlutterSecureStorage secureStorage;
  ApiAcademyGateway({
    ApiClient? apiClient,
    AuthService? authService,
    FlutterSecureStorage? secureStorage,
  }) : apiClient = apiClient ?? ApiClient(),
       authService = authService ?? AuthService(),
       secureStorage = secureStorage ?? enactSpaceSecureStorage;

  Future<String> _token() async {
    final value = await authService.getToken();
    if (value == null || value.isEmpty)
      throw Exception('Utilisateur non connecté.');
    return value;
  }

  Future<String?> _cacheKey() async {
    try {
      final user = await authService.getCachedCurrentUser();
      final id = user?['id']?.toString();
      if (id == null || id.isEmpty) return null;
      return 'academy-home-v2-$id';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _userId() async {
    try {
      return (await authService.getCachedCurrentUser())?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  String _outboxKey(String userId) => 'enactspace.academy.outbox.v1.$userId';
  String _quizKey(String userId, String quizId) =>
      'enactspace.academy.quiz.v2.$userId.$quizId';

  Future<List<Map<String, dynamic>>> _readOutbox(String userId) async {
    try {
      final raw = await secureStorage.read(key: _outboxKey(userId));
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeOutbox(
    String userId,
    List<Map<String, dynamic>> actions,
  ) async {
    if (actions.isEmpty) {
      await secureStorage.delete(key: _outboxKey(userId));
    } else {
      await secureStorage.write(
        key: _outboxKey(userId),
        value: jsonEncode(actions),
      );
    }
  }

  Future<void> _queueAction(Map<String, dynamic> action) async {
    final userId = await _userId();
    if (userId == null || userId.isEmpty) return;
    final actions = List<Map<String, dynamic>>.of(await _readOutbox(userId));
    actions.removeWhere((item) => item['id'] == action['id']);
    actions.add(action);
    await _writeOutbox(userId, actions);
  }

  String _actionId(String type, String target) =>
      '$type-$target-${DateTime.now().microsecondsSinceEpoch}';

  bool _retryable(Object error) =>
      error is TimeoutException ||
      error is http.ClientException ||
      error is ApiException &&
          (error.statusCode == 408 ||
              error.statusCode == 429 ||
              error.statusCode >= 500);

  bool _permanent(Object error) =>
      error is ApiException &&
      error.statusCode >= 400 &&
      error.statusCode < 500 &&
      error.statusCode != 401 &&
      error.statusCode != 408 &&
      error.statusCode != 429;

  Future<void> _syncPending(String token) async {
    final userId = await _userId();
    if (userId == null || userId.isEmpty) return;
    final actions = await _readOutbox(userId);
    if (actions.isEmpty) return;
    final remaining = List<Map<String, dynamic>>.of(actions);
    for (final action in actions) {
      try {
        final type = action['type']?.toString();
        final target = action['target']?.toString() ?? '';
        if (type == 'quiz') {
          await apiClient.postJson(
            '/academy/quizzes/$target/submit',
            token: token,
            data: {
              'answers': action['answers'] ?? const <int>[],
              'client_submission_id': action['id'],
            },
          );
        } else if (type == 'start' || type == 'complete') {
          await apiClient.postJson(
            '/academy/lessons/$target/$type',
            token: token,
            data: {},
          );
        } else {
          remaining.remove(action);
          continue;
        }
        remaining.remove(action);
      } catch (error) {
        if (_permanent(error)) {
          remaining.remove(action);
          continue;
        }
        break;
      }
    }
    await _writeOutbox(userId, remaining);
  }

  AcademyHomeData _homeFromResponses(
    List<dynamic> results, {
    bool offline = false,
    int pendingActions = 0,
  }) {
    final courses = _items(
      results[0],
    ).whereType<Map<String, dynamic>>().map(_course).toList();
    if (results[1] is! Map<String, dynamic>) {
      throw Exception('Progression Academy indisponible.');
    }
    return AcademyHomeData(
      courses: courses,
      paths: _items(
        results[2],
      ).whereType<Map<String, dynamic>>().map(_path).toList(),
      badges: const [],
      caseStudies: const [],
      progress: _progress(results[1] as Map<String, dynamic>, courses),
      offline: offline,
      pendingActions: pendingActions,
    );
  }

  Future<AcademyHomeData> _homeWithPending(
    List<dynamic> raw, {
    bool offline = false,
  }) async {
    final userId = await _userId();
    final actions = userId == null
        ? <Map<String, dynamic>>[]
        : await _readOutbox(userId);
    final results = jsonDecode(jsonEncode(raw)) as List<dynamic>;
    for (final course in _items(results[0]).whereType<Map>()) {
      for (final lesson in _items(course['lessons']).whereType<Map>()) {
        for (final action in actions) {
          if (action['target'] != lesson['id']) continue;
          if (action['type'] == 'start' && lesson['completed'] != true) {
            lesson['started'] = true;
            lesson['status'] = 'in_progress';
          } else if (action['type'] == 'complete') {
            lesson['started'] = true;
            lesson['completed'] = true;
            lesson['status'] = 'completed';
          }
        }
      }
    }
    if (actions.isNotEmpty && results[1] is Map) {
      (results[1] as Map)['completed_lessons'] = _items(results[0])
          .whereType<Map>()
          .expand((c) => _items(c['lessons']).whereType<Map>())
          .where((l) => l['completed'] == true)
          .length;
    }
    return _homeFromResponses(
      results,
      offline: offline,
      pendingActions: actions.length,
    );
  }

  @override
  Future<AcademyHomeData> loadHome() async {
    final token = await _token();
    final key = await _cacheKey();
    try {
      await _syncPending(token);
      final results = await Future.wait<dynamic>([
        apiClient.get('/academy/courses', token: token),
        apiClient.get('/academy/me/progress', token: token),
        apiClient.get('/academy/me/paths', token: token),
      ]);
      final home = await _homeWithPending(results);
      if (key != null) {
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(key, jsonEncode(results));
        } catch (_) {
          // Local storage failure must not block online learning.
        }
      }
      return home;
    } catch (error) {
      if (!_retryable(error)) rethrow;
      if (key == null) rethrow;
      try {
        final cached = (await SharedPreferences.getInstance()).getString(key);
        if (cached == null) rethrow;
        final results = jsonDecode(cached);
        if (results is! List) rethrow;
        return await _homeWithPending(results, offline: error is! ApiException);
      } catch (_) {
        rethrow;
      }
    }
  }

  @override
  Future<AcademyCourseModel> getCourse(String courseId) async {
    final courses = (await loadHome()).courses;
    return courses.firstWhere(
      (course) =>
          course.id == courseId ||
          course.title ==
              const {
                'discover-enactus': 'Découvrir Enactus',
                'sdgs-impact': 'Comprendre les ODD',
              }[courseId],
      orElse: () => throw Exception('Formation introuvable.'),
    );
  }

  @override
  Future<void> startLesson(String lessonId) async {
    final action = {
      'id': _actionId('start', lessonId),
      'type': 'start',
      'target': lessonId,
    };
    try {
      await apiClient.postJson(
        '/academy/lessons/$lessonId/start',
        token: await _token(),
        data: {},
      );
    } catch (error) {
      if (!_retryable(error)) rethrow;
      await _queueAction(action);
    }
  }

  @override
  Future<AcademyRewardResult> completeLesson(String lessonId) async {
    final action = {
      'id': _actionId('complete', lessonId),
      'type': 'complete',
      'target': lessonId,
    };
    try {
      final response = await apiClient.postJson(
        '/academy/lessons/$lessonId/complete',
        token: await _token(),
        data: {},
      );
      final json = response is Map<String, dynamic>
          ? response
          : <String, dynamic>{};
      return AcademyRewardResult(
        points: _int(json['points']),
        label: _text(json['message'], 'Leçon terminée'),
        syncedWithGamification: json['gamification_synced'] != false,
      );
    } catch (error) {
      if (!_retryable(error)) rethrow;
      await _queueAction(action);
      return AcademyRewardResult(
        points: 0,
        label: error is ApiException
            ? 'Progression conservée sur cet appareil. Le serveur est temporairement indisponible ; nouvelle tentative au prochain chargement.'
            : 'Progression conservée sur cet appareil : connexion au serveur impossible, synchronisation en attente',
        syncedWithGamification: false,
      );
    }
  }

  @override
  Future<AcademyQuizModel> getQuiz(String quizId) async {
    final userId = await _userId();
    try {
      final response = await apiClient.get(
        '/academy/quizzes/$quizId',
        token: await _token(),
      );
      if (response is! Map<String, dynamic>)
        throw Exception('Quiz indisponible.');
      if (userId != null && userId.isNotEmpty) {
        try {
          await secureStorage.write(
            key: _quizKey(userId, quizId),
            value: jsonEncode(response),
          );
        } catch (_) {
          /* An available online quiz stays usable without local storage. */
        }
      }
      return _quiz(response);
    } catch (error) {
      if (!_retryable(error) || userId == null || userId.isEmpty) rethrow;
      final cached = await secureStorage.read(key: _quizKey(userId, quizId));
      final decoded = cached == null ? null : jsonDecode(cached);
      if (decoded is! Map) rethrow;
      return _quiz(Map<String, dynamic>.from(decoded));
    }
  }

  @override
  Future<AcademyQuizResult> submitQuiz(String quizId, List<int> answers) async {
    final submissionId = _actionId('quiz', quizId);
    dynamic response;
    try {
      response = await apiClient.postJson(
        '/academy/quizzes/$quizId/submit',
        token: await _token(),
        data: {'answers': answers, 'client_submission_id': submissionId},
      );
    } catch (error) {
      if (!_retryable(error)) rethrow;
      await _queueAction({
        'id': submissionId,
        'type': 'quiz',
        'target': quizId,
        'answers': answers,
      });
      throw const AcademyQuizQueuedException();
    }
    if (response is! Map<String, dynamic>)
      throw Exception('Résultat du quiz indisponible.');
    return AcademyQuizResult(
      score: _double(response['score']),
      passed: response['passed'] == true,
      correctAnswers: response['correct_answers'] == null
          ? null
          : _int(response['correct_answers']),
      total: _int(response['total_questions'] ?? response['total']),
      points: _int(response['points']),
      feedback: _itemsOrEmpty(response['feedback'])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      attemptNumber: response['attempt_number'] == null
          ? null
          : _int(response['attempt_number']),
    );
  }

  @override
  Future<List<AcademyCourseModel>> getAdminCourses() async => _items(
    await apiClient.get('/academy/admin/courses', token: await _token()),
  ).whereType<Map<String, dynamic>>().map(_course).toList();
  @override
  Future<AcademyAdminSummary> getAdminSummary() async {
    final response = await apiClient.get(
      '/academy/admin/summary',
      token: await _token(),
    );
    final json = response is Map<String, dynamic>
        ? response
        : <String, dynamic>{};
    return AcademyAdminSummary(
      courses: _int(json['courses'] ?? json['total_courses']),
      publishedCourses: _int(json['published_courses']),
      learners: _int(json['learners'] ?? json['active_learners']),
      completions: _int(json['completions']),
    );
  }

  @override
  Future<AcademyCourseModel> createCourse(Map<String, dynamic> fields) async =>
      _course(
        _map(
          await apiClient.postJson(
            '/academy/admin/courses',
            token: await _token(),
            data: fields,
          ),
          'création du cours',
        ),
      );
  @override
  Future<AcademyCourseModel> updateCourse(
    String courseId,
    Map<String, dynamic> fields,
  ) async => _course(
    _map(
      await apiClient.patchJson(
        '/academy/admin/courses/$courseId',
        token: await _token(),
        data: fields,
      ),
      'modification du cours',
    ),
  );
  Future<void> _courseAction(String id, String action) async {
    await apiClient.postJson(
      '/academy/admin/courses/$id/$action',
      token: await _token(),
      data: {},
    );
  }

  @override
  Future<void> publishCourse(String id) => _courseAction(id, 'publish');
  @override
  Future<void> unpublishCourse(String id) => _courseAction(id, 'unpublish');
  @override
  Future<void> archiveCourse(String id) => _courseAction(id, 'archive');
  @override
  Future<void> restoreCourse(String id) => _courseAction(id, 'restore');
  @override
  Future<List<AcademyLessonModel>> getAdminLessons(String courseId) async =>
      _items(
        await apiClient.get(
          '/academy/admin/courses/$courseId/lessons',
          token: await _token(),
        ),
      ).whereType<Map<String, dynamic>>().map(_lesson).toList();
  @override
  Future<AcademyLessonModel> createLesson(
    String courseId,
    Map<String, dynamic> fields,
  ) async => _lesson(
    _map(
      await apiClient.postJson(
        '/academy/admin/courses/$courseId/lessons',
        token: await _token(),
        data: fields,
      ),
      'création de la leçon',
    ),
  );
  @override
  Future<AcademyLessonModel> updateLesson(
    String lessonId,
    Map<String, dynamic> fields,
  ) async => _lesson(
    _map(
      await apiClient.patchJson(
        '/academy/admin/lessons/$lessonId',
        token: await _token(),
        data: fields,
      ),
      'modification de la leçon',
    ),
  );
  @override
  Future<void> deleteLesson(String lessonId) async {
    await apiClient.delete(
      '/academy/admin/lessons/$lessonId',
      token: await _token(),
    );
  }

  Map<String, dynamic> _map(dynamic value, String operation) {
    if (value is Map<String, dynamic>) return value;
    throw Exception('Réponse invalide lors de la $operation.');
  }

  List<dynamic> _items(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['items'] is List) return value['items'] as List;
    if (value is Map && value['data'] is List) return value['data'] as List;
    throw Exception('Réponse Academy invalide.');
  }

  AcademyCourseModel _course(Map<String, dynamic> json) {
    final lessons =
        _itemsOrEmpty(
            json['lessons'],
          ).whereType<Map<String, dynamic>>().map(_lesson).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return AcademyCourseModel(
      id: _text(json['id'], ''),
      title: _text(json['title'], 'Formation'),
      category: _text(json['category'], 'Non classée'),
      level: _text(json['level'], 'debutant'),
      description: _text(json['description'], ''),
      durationMinutes: _int(
        json['estimated_duration_minutes'] ?? json['duration_minutes'],
      ),
      points: _int(json['points']),
      isRequired: json['is_required'] == true,
      quizPassed: json['quiz_passed'] == true,
      isLocked: json['is_locked'] == true,
      lockReason: _text(json['lock_reason'], ''),
      serverMastered: json['is_mastered'] is bool
          ? json['is_mastered'] as bool
          : null,
      prerequisiteCourseIds: _strings(json['prerequisite_course_ids']),
      prerequisites: _itemsOrEmpty(json['prerequisites'])
          .whereType<Map>()
          .map(
            (p) => AcademyPrerequisiteModel(
              id: _text(p['id'], ''),
              title: _text(p['title'], 'Formation'),
              completed: p['completed'] == true,
              available: p['available'] != false,
            ),
          )
          .toList(),
      targetRoles: _strings(json['target_roles']),
      isPublished: json['is_published'] != false,
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      lessons: lessons,
      quiz: _quiz(
        json['quiz'] is Map<String, dynamic>
            ? json['quiz'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
    );
  }

  AcademyLessonModel _lesson(Map<String, dynamic> json) => AcademyLessonModel(
    id: _text(json['id'], ''),
    title: _text(json['title'], 'Leçon'),
    summary: _text(json['summary'], ''),
    durationMinutes: _int(json['duration_minutes']),
    completed: json['completed'] == true || json['status'] == 'completed',
    lessonType: _text(json['lesson_type'], 'texte'),
    content: json['content']?.toString(),
    resourceFileId: json['resource_file_id']?.toString(),
    externalUrl: json['external_url']?.toString(),
    started: json['started'] == true || json['status'] == 'in_progress',
    orderIndex: _int(json['order_index']),
    isPublished: json['is_published'] != false,
  );
  AcademyQuizModel _quiz(Map<String, dynamic> json) => AcademyQuizModel(
    id: _text(json['id'], ''),
    title: _text(json['title'], 'Quiz'),
    category: _text(json['category'], 'Academy'),
    level: _text(json['level'], 'debutant'),
    timeLimitMinutes: _int(json['time_limit_minutes']),
    questions: _itemsOrEmpty(json['questions'])
        .whereType<Map<String, dynamic>>()
        .map(
          (q) => AcademyQuestionModel(
            question: _text(q['question'] ?? q['text'], 'Question'),
            choices: _strings(q['choices'] ?? q['options']),
            correctIndex: -1,
            explanation: '',
          ),
        )
        .toList(),
  );
  AcademyPathModel _path(Map<String, dynamic> json) => AcademyPathModel(
    id: _text(json['id'], ''),
    title: _text(json['title'], 'Parcours'),
    description: _text(json['description'], ''),
    courseIds: _strings(json['course_ids']),
    progress: _double(json['progress']),
  );
  AcademyProgressModel _progress(
    Map<String, dynamic> json,
    List<AcademyCourseModel> courses,
  ) => AcademyProgressModel(
    completedLessons: _int(json['completed_lessons']),
    totalLessons: _int(json['total_lessons']),
    passedQuizzes: _int(json['passed_quizzes']),
    totalQuizzes: _int(json['total_quizzes']),
    points: _int(json['points']),
    rank: _int(json['rank']),
    monthlyProgress: _double(json['monthly_progress']),
  );
  List<dynamic> _itemsOrEmpty(dynamic value) =>
      value is List ? value : const [];
  List<String> _strings(dynamic value) => value is List
      ? value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
      : const [];
  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  double _double(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
}
