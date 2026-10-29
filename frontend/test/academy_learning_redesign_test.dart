import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/academy/models/academy_lesson_sections.dart';
import 'package:frontend/features/academy/models/academy_models.dart';
import 'package:frontend/features/academy/screens/academy_course_screen.dart';
import 'package:frontend/features/academy/screens/academy_home_screen.dart';
import 'package:frontend/features/academy/screens/academy_path_screen.dart';
import 'package:frontend/features/academy/services/academy_gateway.dart';
import 'package:frontend/features/academy/widgets/academy_lesson_reader.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _learner = UserExperience(
  id: 'learner',
  email: 'learner@example.test',
  displayName: 'Apprenante',
  status: 'active',
  gender: 'female',
  profileType: 'enacteur',
  roles: {},
  canReviewJoinRequests: false,
);
const _title =
    'Design thinking : du terrain au prototype et aux retours des personnes concernées';
const _firstBody =
    'Objectif\nÉcouter avant de proposer.\n\nComprendre\nPremier paragraphe conservé.\n\nDeuxième paragraphe conservé.\n\nÀ toi de jouer\nPrépare deux questions ouvertes.';

class _Gateway implements AcademyGateway {
  final started = <String>{};
  final completed = <String>{};
  final startCalls = <String>[];
  final completionCalls = <String>[];
  Completer<AcademyRewardResult>? pending;
  bool locked = false;
  AcademyCourseModel get course => AcademyCourseModel(
    id: 'course',
    title: _title,
    category: 'Créativité',
    level: 'intermediaire',
    description:
        'Écoute les personnes concernées, mets une idée à l’épreuve et apprends de leurs retours.',
    durationMinutes: 28,
    points: 17,
    isRequired: true,
    isLocked: locked,
    lockReason: locked ? 'Termine d’abord les bases.' : '',
    lessons: [
      for (final id in ['lesson-a', 'lesson-b'])
        AcademyLessonModel(
          id: id,
          title: id == 'lesson-a'
              ? 'Comprendre avant de proposer une solution'
              : 'Apprendre des retours, puis recommencer',
          summary: 'Une leçon utile sur le terrain.',
          durationMinutes: 14,
          completed: completed.contains(id),
          started: started.contains(id),
          content: id == 'lesson-a'
              ? _firstBody
              : 'Objectif\nTester une hypothèse.\n\nSur le terrain\nRecueille les retours sans orienter les réponses.',
        ),
    ],
    quiz: const AcademyQuizModel(
      id: 'quiz',
      title: 'Les repères',
      category: 'Créativité',
      level: 'intermediaire',
      timeLimitMinutes: 3,
      questions: [],
    ),
  );
  @override
  Future<AcademyHomeData> loadHome() async => AcademyHomeData(
    courses: [course],
    paths: const [
      AcademyPathModel(
        id: 'path',
        title: 'Apprendre en agissant',
        description: 'De la rencontre au premier essai.',
        courseIds: ['course'],
        progress: 0,
      ),
    ],
    badges: const [],
    caseStudies: const [],
    progress: AcademyProgressModel(
      completedLessons: completed.length,
      totalLessons: 2,
      passedQuizzes: 0,
      totalQuizzes: 1,
      points: 0,
      rank: 0,
      monthlyProgress: 0,
    ),
  );
  @override
  Future<AcademyCourseModel> getCourse(String courseId) async => course;
  @override
  Future<void> startLesson(String id) async {
    startCalls.add(id);
    started.add(id);
  }

  @override
  Future<AcademyRewardResult> completeLesson(String id) async {
    completionCalls.add(id);
    if (pending != null) return pending!.future;
    completed.add(id);
    return const AcademyRewardResult(
      points: 0,
      label: 'Leçon terminée',
      syncedWithGamification: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    const directory = String.fromEnvironment('ACADEMY_CAPTURE_DIR');
    if (directory.isEmpty) return;
    for (final weight in FontWeight.values) {
      GoogleFonts.poppins(fontWeight: weight);
      GoogleFonts.poppins(fontWeight: weight, fontStyle: FontStyle.italic);
    }
    await GoogleFonts.pendingFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test('reading sections preserve paragraphs and support separate headings', () {
    final sections = AcademyLessonSection.parse(_firstBody);
    expect(sections.map((s) => s.heading), [
      'Objectif',
      'Comprendre',
      'À toi de jouer',
    ]);
    expect(sections[1].paragraphs, [
      'Premier paragraphe conservé.',
      'Deuxième paragraphe conservé.',
    ]);
    final separate = AcademyLessonSection.parse(
      'Préambule.\n\n## Comprendre\n\nUn texte.\n\nAutre texte.\n\n### Sujet libre\nUne explication.',
    );
    expect(separate.first.heading, isNull);
    expect(separate.first.body, 'Préambule.');
    expect(separate[1].body, 'Un texte.\n\nAutre texte.');
    expect(separate.last.heading, 'Sujet libre');
    expect(separate.last.body, 'Une explication.');
    expect(AcademyLessonSection.parse(' \n\n '), isEmpty);
  });

  for (final width in [320.0, 390.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'formation and reader fit width=$width dark=$dark text=$scale',
          (tester) async {
            final gateway = _Gateway();
            await _pump(
              tester,
              AcademyCourseScreen(
                courseId: 'course',
                gateway: gateway,
                currentUser: _learner,
              ),
              width: width,
              dark: dark,
              scale: scale,
            );
            expect(find.text(_title), findsOneWidget);
            expect(find.text('Gestion Academy'), findsNothing);
            expect(gateway.completionCalls, isEmpty);
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await _capture(
                tester,
                'formation-${dark ? 'dark' : 'light'}-${width.toInt()}',
              );
            }

            await _tapVisible(
              tester,
              find.byKey(const Key('academy-course-continue')),
            );
            expect(find.byType(AcademyLessonReader), findsOneWidget);
            expect(gateway.startCalls, ['lesson-a']);
            expect(gateway.completionCalls, isEmpty);
            expect(
              find.byKey(const Key('complete-reading-lesson')).hitTestable(),
              findsOneWidget,
            );
            final scroller = find
                .descendant(
                  of: find.byKey(const Key('academy-reader-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.text('Écouter avant de proposer.'),
              180,
              scrollable: scroller,
            );
            expect(
              find.text(
                'Premier paragraphe conservé.\n\nDeuxième paragraphe conservé.',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              await _capture(
                tester,
                'lecture-${dark ? 'dark' : 'light'}-${width.toInt()}',
              );
            }

            await tester.tap(find.byTooltip('Fermer la leçon'));
            await tester.pumpAndSettle();
            expect(gateway.completionCalls, isEmpty);
            expect(find.byType(AcademyLessonReader), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'reader navigation starts a lesson once and failed completion stays readable',
    (tester) async {
      final gateway = _Gateway();
      await _pump(
        tester,
        AcademyCourseScreen(
          courseId: 'course',
          gateway: gateway,
          currentUser: _learner,
        ),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('academy-course-continue')),
      );
      await tester.tap(find.byTooltip('Leçon suivante'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('academy-reader-scroll')),
          matching: find.text('Apprendre des retours, puis recommencer'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Leçon précédente'));
      await tester.pumpAndSettle();
      expect(gateway.startCalls, ['lesson-a', 'lesson-b']);
      expect(gateway.completed, isEmpty);

      gateway.pending = Completer<AcademyRewardResult>();
      final action = find.byKey(const Key('complete-reading-lesson'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      expect(gateway.completionCalls, ['lesson-a']);
      gateway.pending!.completeError(Exception('synthetic failure'));
      await tester.pumpAndSettle();
      expect(find.byType(AcademyLessonReader), findsOneWidget);
      expect(find.textContaining('Ta lecture reste ouverte'), findsOneWidget);
      expect(gateway.completed, isEmpty);
      gateway.pending = null;
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(gateway.completed, {'lesson-a'});
      expect(find.byType(AcademyLessonReader), findsNothing);
      expect(gateway.course.canTakeQuiz, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home to path to reader preserves the supplied gateway', (
    tester,
  ) async {
    final gateway = _Gateway();
    final router = GoRouter(
      initialLocation: '/academy',
      routes: [
        GoRoute(
          path: '/academy',
          builder: (_, _) =>
              Scaffold(body: AcademyHomeScreen(gateway: gateway)),
        ),
        GoRoute(
          path: '/academy/paths/:id',
          builder: (_, state) {
            expect(identical(state.extra, gateway), isTrue);
            return Scaffold(
              body: AcademyPathScreen(
                pathId: state.pathParameters['id']!,
                gateway: state.extra! as AcademyGateway,
              ),
            );
          },
        ),
        GoRoute(
          path: '/academy/courses/:id',
          builder: (_, state) {
            expect(identical(state.extra, gateway), isTrue);
            return Scaffold(
              body: AcademyCourseScreen(
                courseId: state.pathParameters['id']!,
                gateway: state.extra! as AcademyGateway,
                currentUser: _learner,
                resume: true,
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pump(tester, const SizedBox.shrink(), router: router);
    await _tapVisible(tester, find.text('Explorer le parcours'));
    expect(find.byType(AcademyPathScreen), findsOneWidget);
    expect(gateway.startCalls, isEmpty);
    await _tapVisible(tester, find.text('Continuer cette formation'));
    expect(find.byType(AcademyLessonReader), findsOneWidget);
    expect(gateway.startCalls, ['lesson-a']);
    expect(gateway.completionCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('path keeps long titles visible width=$width dark=$dark', (
        tester,
      ) async {
        await _pump(
          tester,
          AcademyPathScreen(pathId: 'path', gateway: _Gateway()),
          width: width,
          dark: dark,
        );
        expect(find.text('1. $_title'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          'parcours-${dark ? 'dark' : 'light'}-${width.toInt()}',
        );
        await _pump(
          tester,
          AcademyHomeScreen(gateway: _Gateway()),
          width: width,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          'accueil-${dark ? 'dark' : 'light'}-${width.toInt()}',
        );
      });
    }
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // A jump schedules a frame; wait for layout before using screen coordinates.
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  bool dark = false,
  double scale = 1,
  GoRouter? router,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget media(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
  final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('academy-redesign-capture'),
      child: router == null
          ? MaterialApp(
              theme: theme,
              builder: media,
              home: Scaffold(body: child),
            )
          : MaterialApp.router(
              theme: theme,
              builder: media,
              routerConfig: router,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('ACADEMY_CAPTURE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('academy-redesign-capture')),
  );
  for (final element in find.byType(Image).evaluate()) {
    final widget = element.widget as Image;
    await tester.runAsync(() => precacheImage(widget.image, element));
  }
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Screenshot unavailable');
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
