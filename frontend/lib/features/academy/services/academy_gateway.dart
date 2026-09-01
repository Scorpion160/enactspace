// ignore_for_file: curly_braces_in_flow_control_structures

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/academy_models.dart';

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
  ApiAcademyGateway({ApiClient? apiClient, AuthService? authService})
    : apiClient = apiClient ?? ApiClient(),
      authService = authService ?? AuthService();

  Future<String> _token() async {
    final value = await authService.getToken();
    if (value == null || value.isEmpty)
      throw Exception('Utilisateur non connecté.');
    return value;
  }

  @override
  Future<AcademyHomeData> loadHome() async {
    final token = await _token();
    final results = await Future.wait<dynamic>([
      apiClient.get('/academy/courses', token: token),
      apiClient.get('/academy/me/progress', token: token),
      apiClient.get('/academy/me/paths', token: token),
    ]);
    final courses = _items(
      results[0],
    ).whereType<Map<String, dynamic>>().map(_course).toList();
    if (results[1] is! Map<String, dynamic>)
      throw Exception('Progression Academy indisponible.');
    return AcademyHomeData(
      courses: courses,
      paths: _items(
        results[2],
      ).whereType<Map<String, dynamic>>().map(_path).toList(),
      badges: const [],
      caseStudies: const [],
      progress: _progress(results[1] as Map<String, dynamic>, courses),
    );
  }

  @override
  Future<AcademyCourseModel> getCourse(String courseId) async {
    final courses = (await loadHome()).courses;
    return courses.firstWhere(
      (course) => course.id == courseId,
      orElse: () => throw Exception('Formation introuvable.'),
    );
  }

  @override
  Future<void> startLesson(String lessonId) async {
    await apiClient.postJson(
      '/academy/lessons/$lessonId/start',
      token: await _token(),
      data: {},
    );
  }

  @override
  Future<AcademyRewardResult> completeLesson(String lessonId) async {
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
  }

  @override
  Future<AcademyQuizModel> getQuiz(String quizId) async {
    final response = await apiClient.get(
      '/academy/quizzes/$quizId',
      token: await _token(),
    );
    if (response is! Map<String, dynamic>)
      throw Exception('Quiz indisponible.');
    return _quiz(response);
  }

  @override
  Future<AcademyQuizResult> submitQuiz(String quizId, List<int> answers) async {
    final response = await apiClient.postJson(
      '/academy/quizzes/$quizId/submit',
      token: await _token(),
      data: {'answers': answers},
    );
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
