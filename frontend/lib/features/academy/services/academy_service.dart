// ignore_for_file: curly_braces_in_flow_control_structures

import '../models/academy_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';

class AcademyService {
  final ApiClient _apiClient;
  final AuthService _authService;

  AcademyService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<AcademyHomeData> getHome() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }

    final responses = await Future.wait([
      _apiClient.get('/academy/courses', token: token),
      _apiClient.get('/academy/me/progress', token: token),
      _apiClient.get('/academy/me/paths', token: token),
    ]);

    final coursesResponse = responses[0];
    final progressResponse = responses[1];
    final pathsResponse = responses[2];
    if (coursesResponse is! List || progressResponse is! Map<String, dynamic>) {
      throw Exception('Données Academy indisponibles.');
    }

    final courses = coursesResponse
        .whereType<Map<String, dynamic>>()
        .map(_courseFromJson)
        .toList();
    final paths = pathsResponse is List
        ? pathsResponse
              .whereType<Map<String, dynamic>>()
              .map(_pathFromJson)
              .toList()
        : <AcademyPathModel>[];
    return AcademyHomeData(
      courses: courses,
      paths: paths,
      badges: const [],
      caseStudies: const [],
      progress: _progressFromJson(progressResponse, courses),
    );
  }

  Future<AcademyRewardResult> completeLesson({
    required AcademyCourseModel course,
    required AcademyLessonModel lesson,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty)
      throw Exception('Utilisateur non connecté.');
    final response = await _apiClient.postJson(
      '/academy/lessons/${lesson.id}/complete',
      token: token,
      data: {},
    );
    final json = response is Map<String, dynamic>
        ? response
        : <String, dynamic>{};
    return AcademyRewardResult(
      points: _int(json['points']),
      label: _string(json['message'], fallback: 'Leçon terminée'),
      syncedWithGamification: json['gamification_synced'] != false,
    );
  }

  Future<AcademyRewardResult> passQuiz({
    required AcademyCourseModel course,
    List<int>? answers,
  }) async {
    if (answers == null) throw Exception('Réponses du quiz manquantes.');
    final backendResult = await _submitQuiz(
      quizId: course.quiz.id,
      answers: answers,
    );
    if (backendResult == null)
      throw Exception('Résultat du quiz indisponible.');
    if (!backendResult.passed) {
      return AcademyRewardResult(
        points: 0,
        label:
            'Quiz non validé côté Academy (${backendResult.score.toStringAsFixed(0)}%)',
        syncedWithGamification: false,
      );
    }

    return AcademyRewardResult(
      points: backendResult.points,
      label: 'Quiz réussi',
      syncedWithGamification: true,
    );
  }

  AcademyCourseModel _courseFromJson(Map<String, dynamic> json) {
    final lessons = _list(
      json['lessons'],
    ).whereType<Map<String, dynamic>>().map(_lessonFromJson).toList();

    return AcademyCourseModel(
      id: _string(json['id'], fallback: 'course'),
      title: _string(json['title'], fallback: 'Cours Academy'),
      category: _string(json['category'], fallback: 'Academy'),
      level: _string(json['level'], fallback: 'Débutant'),
      description: _string(
        json['description'],
        fallback: 'Parcours de formation Enactus ESP.',
      ),
      durationMinutes: _int(
        json['duration_minutes'],
        fallback: lessons.fold(
          0,
          (sum, lesson) => sum + lesson.durationMinutes,
        ),
      ),
      points: _int(json['points'], fallback: lessons.length * 40),
      isRequired: json['is_required'] == true,
      lessons: lessons,
      quiz: _quizFromJson(json['quiz']),
    );
  }

  AcademyLessonModel _lessonFromJson(Map<String, dynamic> json) {
    return AcademyLessonModel(
      id: _string(json['id'], fallback: 'lesson'),
      title: _string(json['title'], fallback: 'Leçon Academy'),
      summary: _string(json['summary'], fallback: 'Résumé à compléter'),
      durationMinutes: _int(json['duration_minutes'], fallback: 8),
      completed: json['completed'] == true || json['status'] == 'completed',
    );
  }

  AcademyQuizModel _quizFromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final questions = _list(
      json['questions'],
    ).whereType<Map<String, dynamic>>().map(_questionFromJson).toList();

    return AcademyQuizModel(
      id: _string(json['id'], fallback: 'academy-quiz'),
      title: _string(json['title'], fallback: 'Quiz Academy'),
      category: _string(json['category'], fallback: 'Academy'),
      level: _string(json['level'], fallback: 'Débutant'),
      timeLimitMinutes: _int(json['time_limit_minutes'], fallback: 8),
      questions: questions,
    );
  }

  AcademyQuestionModel _questionFromJson(Map<String, dynamic> json) {
    return AcademyQuestionModel(
      question: _string(json['question'], fallback: 'Question Academy'),
      choices: _list(json['choices'])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      correctIndex: -1,
      explanation: _string(
        json['explanation'],
        fallback: 'Explication à compléter.',
      ),
    );
  }

  AcademyProgressModel _progressFromJson(
    Map<String, dynamic> json,
    List<AcademyCourseModel> courses,
  ) {
    final totalLessons = courses.fold(
      0,
      (sum, course) => sum + course.lessonCount,
    );
    return AcademyProgressModel(
      completedLessons: _int(json['completed_lessons']),
      totalLessons: _int(json['total_lessons'], fallback: totalLessons),
      passedQuizzes: _int(json['passed_quizzes']),
      totalQuizzes: _int(json['total_quizzes'], fallback: courses.length),
      points: _int(json['points']),
      rank: _int(json['rank']),
      monthlyProgress: _double(json['monthly_progress']),
    );
  }

  AcademyPathModel _pathFromJson(Map<String, dynamic> json) {
    return AcademyPathModel(
      id: _string(json['id'], fallback: 'path'),
      title: _string(json['title'], fallback: 'Parcours Academy'),
      description: _string(
        json['description'],
        fallback: 'Parcours recommande selon ton role.',
      ),
      courseIds: _stringList(json['course_ids']),
      progress: _double(json['progress']),
    );
  }

  List<dynamic> _list(dynamic value) {
    return value is List ? value : const [];
  }

  String _string(dynamic value, {required String fallback}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _int(dynamic value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(dynamic value, {double fallback = 0}) {
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<({bool passed, int points, double score})?> _submitQuiz({
    required String quizId,
    required List<int> answers,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;

      final response = await _apiClient.postJson(
        '/academy/quizzes/$quizId/submit',
        token: token,
        data: {'answers': answers},
      );

      if (response is! Map<String, dynamic>) return null;

      return (
        passed: response['passed'] == true,
        points: _int(response['points'], fallback: 60),
        score: _double(response['score']),
      );
    } catch (_) {
      return null;
    }
  }
}
