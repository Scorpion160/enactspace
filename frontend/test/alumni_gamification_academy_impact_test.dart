import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/features/academy/models/academy_models.dart';
import 'package:frontend/features/academy/screens/academy_course_screen.dart';
import 'package:frontend/features/academy/screens/academy_home_screen.dart';
import 'package:frontend/features/academy/services/academy_gateway.dart';
import 'package:frontend/features/alumni/models/alumni_profile_model.dart';
import 'package:frontend/features/alumni/models/mentorship_model.dart';
import 'package:frontend/features/alumni/screens/alumni_screen.dart';
import 'package:frontend/features/alumni/services/alumni_gateway.dart';
import 'package:frontend/features/gamification/models/gamification_models.dart';
import 'package:frontend/features/gamification/screens/gamification_screen.dart';
import 'package:frontend/features/gamification/services/gamification_gateway.dart';
import 'package:frontend/features/impact/models/impact_models.dart';
import 'package:frontend/features/impact/models/impact_record_models.dart';
import 'package:frontend/features/impact/screens/impact_dashboard_screen.dart';
import 'package:frontend/features/impact/screens/impact_records_screen.dart';
import 'package:frontend/features/impact/services/impact_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Alumni humanise toutes les visibilités', () {
    expect(_profile('internal').visibilityLabel, 'Membres');
    expect(_profile('alumni_only').visibilityLabel, 'Alumni');
    expect(_profile('enacchef_only').visibilityLabel, 'Responsables');
    expect(_profile('private').visibilityLabel, 'Privé');
  });

  test('Mentorat humanise tous les statuts', () {
    expect(_mentorship('active').statusLabel, 'Actif');
    expect(_mentorship('paused').statusLabel, 'En pause');
    expect(_mentorship('completed').statusLabel, 'Terminé');
    expect(_mentorship('cancelled').statusLabel, 'Annulé');
  });

  testWidgets('annuaire Alumni utilise le gateway mémoire', (tester) async {
    await tester.pumpWidget(_app(AlumniScreen(gateway: _AlumniFake())));
    await tester.pumpAndSettle();
    expect(find.text('Awa Alumni'), findsOneWidget);
    expect(find.text('Mentorat'), findsWidgets);
    expect(_AlumniFake.networkRequests, 0);
  });

  test('Gamification humanise toutes les sources confirmées', () {
    const expected = {
      'task_validated': 'Tâche validée',
      'attendance_present': 'Présence',
      'attendance_late': 'Retard',
      'event_participation': 'Participation événement',
      'training_completed': 'Formation terminée',
      'document_shared': 'Document partagé',
      'project_progress': 'Progression projet',
      'mentorship': 'Mentorat',
      'leader_rating': 'Évaluation leadership',
      'manual': 'Attribution manuelle',
    };
    for (final entry in expected.entries) {
      expect(_point(entry.key).sourceLabel, entry.value);
    }
  });

  testWidgets('Gamification distingue la vue manager', (tester) async {
    await tester.pumpWidget(
      _app(GamificationScreen(gateway: _GamificationFake())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Engagement et reconnaissance'), findsOneWidget);
    expect(find.text('Attribuer points'), findsOneWidget);
    expect(find.text('Gérer les badges'), findsOneWidget);
  });

  test('Academy humanise niveaux, types et statuts réels', () {
    expect(_course().levelLabel, 'Débutant');
    expect(_lesson().typeLabel, 'Vidéo');
    expect(_lesson().statusLabel, 'En cours');
  });

  testWidgets('erreur Academy ne montre aucune donnée de démonstration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(AcademyHomeScreen(gateway: _AcademyErrorFake())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Academy indisponible'), findsWidgets);
    expect(find.text('Découvrir Enactus'), findsNothing);
  });

  testWidgets('fiche cours expose progression, leçons et quiz', (tester) async {
    await tester.pumpWidget(
      _app(AcademyCourseScreen(courseId: 'course-1', gateway: _AcademyFake())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mesurer l’impact'), findsOneWidget);
    expect(find.textContaining('En cours'), findsOneWidget);
    expect(find.text('Ouvrir le quiz'), findsOneWidget);
  });

  test('Impact humanise statuts, catégories et unités', () {
    expect(impactStatusLabel('under_review'), 'En vérification');
    expect(impactStatusLabel('validated'), 'Validé');
    expect(impactCategoryLabel('environmental'), 'Environnemental');
    expect(impactCategoryLabel('economique'), 'Économique');
    expect(impactUnitLabel('personnes'), 'Personnes');
    expect(impactUnitLabel('pourcentage'), 'Pourcentage');
  });

  testWidgets('erreur Impact ne montre aucune statistique de démonstration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(ImpactDashboardScreen(gateway: _ImpactErrorFake())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Impact indisponible'), findsWidgets);
    expect(find.text('Green Campus ESP'), findsNothing);
  });

  testWidgets('fiches Impact utilisent les permissions serveur', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ImpactRecordsScreen(gateway: _ImpactFake())));
    await tester.pumpAndSettle();
    expect(find.text('Fiche solaire'), findsOneWidget);
    expect(find.text('Validation autorisée'), findsOneWidget);
  });

  testWidgets('métriques et preuves restent lazy sur la fiche Impact', (
    tester,
  ) async {
    final fake = _ImpactFake();
    await tester.pumpWidget(
      _app(ImpactRecordDetailScreen(recordId: 'impact-1', gateway: fake)),
    );
    await tester.pumpAndSettle();
    expect(fake.metricsLoads, 0);
    expect(fake.evidenceLoads, 0);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Charger'), findsNWidgets(2));
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

UserExperience _manager() => UserExperience.fromJson({
  'id': 'user-1',
  'first_name': 'Awa',
  'last_name': 'Ndiaye',
  'roles': ['admin'],
  'status': 'active',
});
AlumniProfileModel _profile(String visibility) => AlumniProfileModel(
  id: 'alumni-1',
  userId: 'user-1',
  graduationYear: 2024,
  currentCompany: 'SunuTech',
  currentPosition: 'Impact lead',
  domain: 'Énergie',
  skills: 'Mesure, Mentorat',
  experienceSummary: 'Accompagne les équipes projet.',
  availableForMentoring: true,
  linkedinUrl: 'https://linkedin.com',
  portfolioUrl: 'https://portfolio.test',
  visibility: visibility,
  displayName: 'Awa Alumni',
  photoUrl: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
MentorshipModel _mentorship(String status) => MentorshipModel(
  id: 'mentorship-1',
  alumniId: 'user-1',
  projectId: 'project-1',
  poleId: null,
  assignedBy: 'manager',
  title: 'Mentorat SunuTech',
  objective: 'Structurer la mesure.',
  status: status,
  startedAt: DateTime(2026),
  endedAt: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
EngagementPointModel _point(String source) => EngagementPointModel(
  id: 'point-1',
  userId: 'user-1',
  seasonId: 'season-1',
  poleId: 'pole-1',
  projectId: 'project-1',
  sourceType: source,
  sourceId: 'source-1',
  points: 10,
  reason: 'Contribution',
  awardedBy: 'manager',
  createdAt: DateTime(2026),
);
AcademyLessonModel _lesson() => const AcademyLessonModel(
  id: 'lesson-1',
  title: 'Construire un indicateur',
  summary: 'Source et méthode.',
  durationMinutes: 12,
  completed: false,
  started: true,
  lessonType: 'video',
  orderIndex: 1,
);
AcademyCourseModel _course() => AcademyCourseModel(
  id: 'course-1',
  title: 'Mesurer l’impact',
  category: 'Impact',
  level: 'debutant',
  description: 'Mesurer sans inventer.',
  durationMinutes: 30,
  points: 50,
  isRequired: true,
  targetRoles: const ['member'],
  lessons: [_lesson()],
  quiz: const AcademyQuizModel(
    id: 'quiz-1',
    title: 'Quiz Impact',
    category: 'Impact',
    level: 'debutant',
    timeLimitMinutes: 8,
    questions: [],
  ),
);
AcademyProgressModel _progress() => const AcademyProgressModel(
  completedLessons: 0,
  totalLessons: 1,
  passedQuizzes: 0,
  totalQuizzes: 1,
  points: 0,
  rank: 0,
  monthlyProgress: 0,
);

class _AlumniFake implements AlumniGateway {
  static int networkRequests = 0;
  @override
  Future<AlumniCenterData> loadCenter({
    String? search,
    bool mentorsOnly = false,
    String mentorshipStatus = 'all',
  }) async => AlumniCenterData(
    user: _manager(),
    profiles: [_profile('internal')],
    mentorships: [_mentorship('active')],
    members: const [],
    projects: const [],
    poles: const [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GamificationFake implements GamificationGateway {
  @override
  Future<GamificationCenterData> load({
    required int month,
    required int year,
  }) async => GamificationCenterData(
    user: _manager(),
    members: const [],
    poles: const [],
    points: [_point('mentorship')],
    badges: const [],
    userBadges: const [],
    userRanking: const [],
    poleRanking: const [],
    memberOfMonth: MonthlyWinnerModel(
      month: month,
      year: year,
      userId: null,
      poleId: null,
      totalPoints: 0,
    ),
    poleOfMonth: MonthlyWinnerModel(
      month: month,
      year: year,
      userId: null,
      poleId: null,
      totalPoints: 0,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AcademyFake implements AcademyGateway {
  @override
  Future<AcademyHomeData> loadHome() async => AcademyHomeData(
    courses: [_course()],
    paths: const [],
    badges: const [],
    caseStudies: const [],
    progress: _progress(),
  );
  @override
  Future<AcademyCourseModel> getCourse(String id) async => _course();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AcademyErrorFake extends _AcademyFake {
  @override
  Future<AcademyHomeData> loadHome() =>
      Future.error(Exception('Academy indisponible'));
}

class _ImpactErrorFake implements ImpactGateway {
  @override
  Future<ImpactDashboardData> loadDashboard() =>
      Future.error(Exception('Impact indisponible'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImpactFake implements ImpactGateway {
  int metricsLoads = 0, evidenceLoads = 0;
  ImpactRecordModel get record => ImpactRecordModel(
    id: 'impact-1',
    projectId: 'project-1',
    seasonId: 'season-1',
    title: 'Fiche solaire',
    summary: 'Donnée consolidée',
    problemStatement: 'Accès énergie',
    solutionSummary: 'Ateliers',
    targetPopulation: 'Étudiants',
    directBeneficiaries: 20,
    indirectBeneficiaries: 50,
    reach: 70,
    jobsCreated: 2,
    revenueGenerated: 1000,
    profitOrSurplus: 100,
    costSavings: 50,
    livesImpacted: 20,
    treesPlanted: 0,
    wasteReduced: 0,
    waterSaved: 0,
    co2Reduced: 10,
    sdgs: const ['ODD 7'],
    evidenceNotes: 'Registre',
    methodology: 'Comptage',
    projectionNext12Months: 'Étendre',
    status: 'under_review',
    canManage: true,
    canValidate: true,
  );
  @override
  Future<List<ImpactRecordModel>> getRecords() async => [record];
  @override
  Future<ImpactRecordModel> getRecord(String id) async => record;
  @override
  Future<List<ImpactMetricModel>> getMetrics(String id) async {
    metricsLoads++;
    return const [];
  }

  @override
  Future<List<ImpactEvidenceModel>> getEvidence(String id) async {
    evidenceLoads++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
