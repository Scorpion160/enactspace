// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/academy/screens/academy_home_screen.dart';
import 'package:frontend/features/academy/screens/academy_path_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/features/academy/services/academy_gateway.dart';
import 'package:frontend/features/academy/screens/academy_course_screen.dart';
import 'package:frontend/features/academy/widgets/academy_quiz_dialog.dart';
import 'package:frontend/features/academy/models/academy_models.dart';
import 'package:frontend/core/theme/app_theme.dart';

class _Auth extends AuthService {
  @override
  Future<String?> getToken() async => 'synthetic-token';
  @override
  Future<Map<String, dynamic>?> getCachedCurrentUser() async => {
    'id': 'test-academy-user',
  };
}

class _Api extends ApiClient {
  bool online = true;
  bool serverError = false;
  bool started = false;
  bool completed = false;
  bool locked = false;
  final posted = <String>[];
  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (!online) throw http.ClientException('offline');
    if (path == '/academy/quizzes/real-quiz')
      return {
        'id': 'real-quiz',
        'title': 'Quiz',
        'questions': [
          {
            'id': 'question-1',
            'question': 'Que faut-il observer ?',
            'choices': ['Le changement', 'Les logos'],
            'correct_index': -1,
            'explanation': '',
          },
        ],
      };
    if (path == '/academy/courses')
      return [
        {
          'id': 'real-course',
          'title': 'Cours pédagogique',
          'category': 'Méthode projet',
          'level': 'debutant',
          'description': 'Apprendre en pratiquant',
          'is_locked': locked,
          'lock_reason': locked
              ? 'Termine les leçons et réussis le quiz de : Les bases'
              : '',
          'prerequisite_course_ids': locked ? ['previous-course'] : [],
          'prerequisites': locked
              ? [
                  {
                    'id': 'previous-course',
                    'title': 'Les bases',
                    'completed': false,
                    'available': true,
                  },
                ]
              : [],
          'lessons': [
            {
              'id': 'real-lesson',
              'title': 'Écouter le terrain',
              'summary': 'Comprendre avant de proposer',
              'duration_minutes': 10,
              'started': started,
              'completed': completed,
              'content':
                  'Objectif\nÉcouter avant de proposer.\n\nÀ toi de jouer\nPrépare deux questions ouvertes.',
            },
          ],
          'quiz': {'id': 'real-quiz', 'title': 'Quiz', 'questions': []},
        },
      ];
    if (path == '/academy/me/paths')
      return [
        {
          'id': 'new-enacteur',
          'title': 'Nouveau Enacteur',
          'description':
              'Trouve tes repères et organise ta première contribution.',
          'course_ids': ['real-course'],
          'progress': 0,
        },
      ];
    if (path == '/academy/me/progress')
      return {'completed_lessons': completed ? 1 : 0, 'total_lessons': 1};
    return [];
  }

  @override
  Future<dynamic> postJson(
    String path, {
    required Map<String, dynamic> data,
    String? token,
  }) async {
    if (!online) throw http.ClientException('offline');
    if (serverError)
      throw ApiException(statusCode: 500, message: 'synthetic server failure');
    posted.add(path);
    if (path.endsWith('/start')) started = true;
    if (path.endsWith('/complete')) {
      started = true;
      completed = true;
    }
    if (path.endsWith('/submit'))
      return {
        'score': 100,
        'passed': true,
        'correct_answers': 1,
        'total': 1,
        'feedback': [
          {'explanation': 'Le changement doit être situé et mesuré.'},
        ],
      };
    return {'points': 0, 'message': 'Leçon terminée'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('un cours bloqué ne lance ni lecteur ni quiz même avec resume', (
    tester,
  ) async {
    final api = _Api()..locked = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AcademyCourseScreen(
            courseId: 'real-course',
            resume: true,
            gateway: ApiAcademyGateway(apiClient: api, authService: _Auth()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Cette formation se débloque à la prochaine étape'),
      findsOneWidget,
    );
    expect(find.text('Les bases'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(api.posted, isEmpty);
    await tester.scrollUntilVisible(find.text('À débloquer'), 220);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('À débloquer'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    await tester.scrollUntilVisible(find.text('Ouvrir le quiz'), 220);
    final quizButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Ouvrir le quiz'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(quizButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'le quiz attend les leçons et Continuer ignore les cours bloqués',
    (tester) async {
      final api = _Api()..locked = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademyHomeScreen(
              gateway: ApiAcademyGateway(apiClient: api, authService: _Auth()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Continuer'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(api.posted, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'première progression hors ligne puis synchronisation sans liste constante',
    () async {
      final api = _Api();
      final gateway = ApiAcademyGateway(apiClient: api, authService: _Auth());
      await gateway.loadHome();
      api.online = false;
      await gateway.startLesson('real-lesson');
      await gateway.completeLesson('real-lesson');
      final offline = await gateway.loadHome();
      expect(offline.offline, isTrue);
      expect(offline.courses.single.lessons.single.completed, isTrue);
      final queue = await const FlutterSecureStorage().read(
        key: 'enactspace.academy.outbox.v1.test-academy-user',
      );
      expect(jsonDecode(queue!), hasLength(2));
      api.online = true;
      final fresh = await gateway.loadHome();
      expect(fresh.courses.single.lessons.single.completed, isTrue);
      expect(api.posted, [
        '/academy/lessons/real-lesson/start',
        '/academy/lessons/real-lesson/complete',
      ]);
      expect(
        await const FlutterSecureStorage().read(
          key: 'enactspace.academy.outbox.v1.test-academy-user',
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'Commencer ouvre le contenu, puis terminer met à jour la progression à 360 px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      final gateway = ApiAcademyGateway(apiClient: api, authService: _Auth());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcademyCourseScreen(
              courseId: 'real-course',
              gateway: gateway,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Commencer'));
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Écouter avant de proposer.'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Écouter avant de proposer.'), findsOneWidget);
      expect(api.completed, isFalse);
      await tester.scrollUntilVisible(
        find.byKey(const Key('complete-reading-lesson')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('complete-reading-lesson')));
      await tester.pumpAndSettle();
      expect(api.completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'après les leçons, ouvrir et valider le quiz du cours reste opérationnel',
    (tester) async {
      final api = _Api()..completed = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AcademyCourseScreen(
              courseId: 'real-course',
              gateway: ApiAcademyGateway(apiClient: api, authService: _Auth()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Ouvrir le quiz'), 220);
      await tester.tap(find.text('Ouvrir le quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Le changement'), findsOneWidget);
      await tester.tap(find.text('Le changement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz réussi'), findsOneWidget);
      expect(api.posted, contains('/academy/quizzes/real-quiz/submit'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Continuer reprend la leçon et le parcours accueille réellement le nouveau membre',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      final gateway = ApiAcademyGateway(apiClient: api, authService: _Auth());
      final router = GoRouter(
        initialLocation: '/academy',
        routes: [
          GoRoute(
            path: '/academy',
            builder: (_, _) =>
                Scaffold(body: AcademyHomeScreen(gateway: gateway)),
          ),
          GoRoute(
            path: '/academy/courses/:id',
            builder: (_, state) => Scaffold(
              body: AcademyCourseScreen(
                courseId: state.pathParameters['id']!,
                gateway: gateway,
                resume: state.uri.queryParameters['resume'] == 'true',
              ),
            ),
          ),
          GoRoute(
            path: '/academy/paths/:id',
            builder: (_, state) => Scaffold(
              body: AcademyPathScreen(
                pathId: state.pathParameters['id']!,
                gateway: gateway,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Écouter avant de proposer.'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Écouter avant de proposer.'), findsOneWidget);
      expect(api.started, isTrue);
      expect(api.completed, isFalse);
      await tester.tap(find.byTooltip('Fermer la leçon'));
      await tester.pumpAndSettle();
      router.go('/academy/paths/new-enacteur');
      await tester.pumpAndSettle();
      expect(find.text('1. Cours pédagogique'), findsOneWidget);
      await tester.tap(find.text('Continuer cette formation'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Écouter avant de proposer.'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Écouter avant de proposer.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'une erreur serveur ne devient pas une fausse perte de connexion',
    () async {
      final api = _Api();
      final gateway = ApiAcademyGateway(apiClient: api, authService: _Auth());
      api.serverError = true;
      final result = await gateway.completeLesson('real-lesson');
      expect(result.label, contains('serveur'));
      expect(result.label, isNot(contains('hors ligne')));
      final pending = await gateway.loadHome();
      expect(pending.offline, isFalse);
      expect(pending.pendingActions, 1);
      api.serverError = false;
      final synced = await gateway.loadHome();
      expect(synced.pendingActions, 0);
      expect(synced.courses.single.lessons.single.completed, isTrue);
    },
  );
  for (final scenario in [
    (false, 390.0, 1.25),
    (true, 390.0, 2.0),
    (true, 1440.0, 1.0),
  ]) {
    final dark = scenario.$1;
    testWidgets(
      'quiz affichable et soumission avec correction, sombre=$dark, largeur=${scenario.$2}, texte=${scenario.$3}',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$2, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var sends = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.$3)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<AcademyQuizResult>(
                    context: context,
                    builder: (_) => AcademyQuizDialog(
                      quiz: const AcademyQuizModel(
                        id: 'quiz',
                        title: 'Quiz de test',
                        category: 'Impact',
                        level: 'debutant',
                        timeLimitMinutes: 3,
                        questions: [
                          AcademyQuestionModel(
                            question: 'Que faut-il observer ?',
                            choices: ['Le changement', 'Le nombre de logos'],
                            correctIndex: -1,
                            explanation: '',
                          ),
                        ],
                      ),
                      submit: (answers) async {
                        sends++;
                        expect(answers, [0]);
                        if (sends == 1) throw Exception('temporary failure');
                        return const AcademyQuizResult(
                          score: 100,
                          passed: true,
                          correctAnswers: 1,
                          total: 1,
                          points: 0,
                          attemptNumber: 1,
                          feedback: [
                            {
                              'explanation':
                                  'Le changement doit être situé et mesuré.',
                            },
                          ],
                        );
                      },
                    ),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        expect(find.text('Le changement'), findsOneWidget);
        final text = tester.widget<Text>(find.text('Le changement'));
        final context = tester.element(find.text('Le changement'));
        expect(text.style!.color, Theme.of(context).colorScheme.onSurface);
        await tester.ensureVisible(find.text('Le changement'));
        await tester.tap(find.text('Le changement'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Tes réponses sont conservées'),
          findsOneWidget,
        );
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        expect(find.text('Quiz réussi'), findsOneWidget);
        expect(
          find.text('Le changement doit être situé et mesuré.'),
          findsOneWidget,
        );
        expect(sends, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
