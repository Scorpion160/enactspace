import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/academy/models/academy_models.dart';
import 'package:frontend/features/academy/screens/academy_home_screen.dart';
import 'package:frontend/features/academy/services/academy_gateway.dart';

class _Gateway implements AcademyGateway {
  @override
  Future<AcademyHomeData> loadHome() async => const AcademyHomeData(
    courses: [
      AcademyCourseModel(id: 'intro', title: 'Découvrir Enactus', category: 'Culture Enactus',
        level: 'debutant', description: 'Comprendre et agir ensemble.', durationMinutes: 29,
        points: 10, isRequired: true,
        lessons: [AcademyLessonModel(id: 'intro-1', title: 'Notre démarche', summary: 'Écouter.',
          durationMinutes: 10, completed: false)],
        quiz: AcademyQuizModel(id: '', title: '', category: '', level: '', timeLimitMinutes: 0, questions: [])),
      AcademyCourseModel(id: 'locked', title: 'Immersion : écouter avant de proposer une solution',
        category: 'Méthode de projet', level: 'intermediaire', description: 'Une formation avec prérequis.',
        durationMinutes: 28, points: 10, isRequired: false, isLocked: true,
        lessons: [AcademyLessonModel(id: 'locked-1', title: 'Le terrain', summary: 'Observer.',
          durationMinutes: 10, completed: false)],
        quiz: AcademyQuizModel(id: '', title: '', category: '', level: '', timeLimitMinutes: 0, questions: [])),
    ], paths: [], badges: [], caseStudies: [],
    progress: AcademyProgressModel(completedLessons: 7, totalLessons: 20,
      passedQuizzes: 2, totalQuizzes: 5, points: 42, rank: 3, monthlyProgress: 0),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('all local academy illustrations are bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final variant in ['mobile', 'web']) {
      for (final name in ['hero_learning', 'recommended_path', 'course_enactus',
          'course_design_thinking', 'course_immersion']) {
        final bytes = await rootBundle.load('assets/img/academy_${variant}_$name.webp');
        expect(bytes.lengthInBytes, greaterThan(100));
      }
    }
  });
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('academy home fits $width scale=$scale dark=$dark', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(useMaterial3: true,
              brightness: dark ? Brightness.dark : Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
            home: Scaffold(body: AcademyHomeScreen(gateway: _Gateway())),
          ));
          await tester.pumpAndSettle();
          expect(find.textContaining(RegExp(r'Apprendre pour agir\.|Fais grandir ton impact\.')), findsOneWidget);
          final button = tester.widget<ElevatedButton>(find.ancestor(
            of: find.text('Continuer mon apprentissage'), matching: find.byType(ElevatedButton)));
          expect(button.onPressed, isNotNull);
          await tester.scrollUntilVisible(find.text('Ma progression'), 180,
            scrollable: find.descendant(of: find.byType(ListView).first,
              matching: find.byType(Scrollable)).first);
          await tester.scrollUntilVisible(find.text('7/20'), 100,
            scrollable: find.descendant(of: find.byType(ListView).first,
              matching: find.byType(Scrollable)).first);
          expect(find.text('7/20'), findsOneWidget);
          expect(find.text('42'), findsOneWidget);
          final scroller = find.descendant(of: find.byType(ListView).first,
            matching: find.byType(Scrollable)).first;
          await tester.scrollUntilVisible(find.text('Commencer'), 220, scrollable: scroller);
          expect(find.text('Commencer'), findsOneWidget);
          expect(find.text('Ouvrir la formation'), findsNothing);
          await tester.scrollUntilVisible(find.text('Voir les prérequis'), 180, scrollable: scroller);
          expect(find.text('Voir les prérequis'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
