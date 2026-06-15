import '../models/academy_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../gamification/services/gamification_service.dart';

class AcademyService {
  final AuthService _authService;
  final GamificationService _gamificationService;

  final Set<String> _completedLessonIds = {'l1', 'l2', 'l4', 'l11'};
  final Set<String> _passedQuizIds = {
    'discover-enactus-quiz',
    'leadership-collaboration-quiz',
  };
  int _academyPoints = 340;

  AcademyService({
    AuthService? authService,
    GamificationService? gamificationService,
  }) : _authService = authService ?? AuthService(),
       _gamificationService = gamificationService ?? GamificationService();

  Future<AcademyHomeData> getHome() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));

    final courses = [
      _course(
        id: 'discover-enactus',
        title: 'Découvrir Enactus',
        category: 'Culture Enactus',
        level: 'Débutant',
        description:
            'Mission, vision, esprit Enactus ESP et rôle d’un Enacteur.',
        lessons: const [
          AcademyLessonModel(
            id: 'l1',
            title: 'Qu’est-ce que Enactus ?',
            summary: 'Comprendre l’entrepreneuriat social par l’action.',
            durationMinutes: 8,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l2',
            title: 'People, Planet, Prosperity',
            summary: 'Lire un projet avec les trois piliers Enactus.',
            durationMinutes: 10,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l3',
            title: 'Rôles dans Enactus ESP',
            summary: 'Enacteur, EnacChef, alumni, advisor et partenaires.',
            durationMinutes: 7,
            completed: false,
          ),
        ],
        quizTitle: 'Les bases de Enactus',
        questions: const [
          AcademyQuestionModel(
            question: 'Quel est le cœur de l’approche Enactus ?',
            choices: [
              'Entrepreneuriat social',
              'Simple bénévolat',
              'Compétition uniquement',
              'Gestion administrative',
            ],
            correctIndex: 0,
            explanation:
                'Enactus combine leadership entrepreneurial et impact positif durable.',
          ),
        ],
      ),
      _course(
        id: 'sdgs-impact',
        title: 'ODD et mesure d’impact',
        category: 'Impact',
        level: 'Intermédiaire',
        description:
            'Relier un problème aux ODD, distinguer reach, impact direct et indirect.',
        lessons: const [
          AcademyLessonModel(
            id: 'l4',
            title: 'ODD / SDGs',
            summary: 'Choisir les ODD pertinents sans forcer l’alignement.',
            durationMinutes: 12,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l5',
            title: 'Direct impact vs indirect impact',
            summary: 'Mesurer ce qui change réellement pour les bénéficiaires.',
            durationMinutes: 14,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l6',
            title: 'Preuves et méthodologie',
            summary: 'Structurer photos, enquêtes, registres et hypothèses.',
            durationMinutes: 13,
            completed: false,
          ),
        ],
        quizTitle: 'Impact direct ou indirect ?',
        questions: const [
          AcademyQuestionModel(
            question: 'Le reach mesure surtout...',
            choices: [
              'Les personnes touchées ou exposées',
              'Le profit net',
              'Les dépenses',
              'Le nombre de réunions',
            ],
            correctIndex: 0,
            explanation:
                'Le reach est la portée. Il ne remplace pas la mesure d’impact.',
          ),
        ],
      ),
      _course(
        id: 'business-finance',
        title: 'Business model et finance',
        category: 'Business Principles',
        level: 'Intermédiaire',
        description:
            'Revenus, coûts, surplus, viabilité économique et fundraising.',
        lessons: const [
          AcademyLessonModel(
            id: 'l7',
            title: 'Revenue vs profit / surplus',
            summary: 'Lire les chiffres d’un projet social sans confusion.',
            durationMinutes: 10,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l8',
            title: 'Fundraising responsable',
            summary: 'Préparer un dossier partenaire crédible.',
            durationMinutes: 12,
            completed: false,
          ),
        ],
        quizTitle: 'Finance et fundraising',
        questions: const [
          AcademyQuestionModel(
            question: 'Le surplus correspond à...',
            choices: [
              'Ce qui reste après les coûts',
              'Toutes les ventes',
              'Le budget demandé',
              'Le nombre de bénéficiaires',
            ],
            correctIndex: 0,
            explanation:
                'Le surplus permet d’évaluer la marge ou la capacité de réinvestissement.',
          ),
        ],
      ),
      _course(
        id: 'pitch-competition',
        title: 'Pitch et compétition',
        category: 'Compétition',
        level: 'Avancé',
        description: 'Annual report, pitch, Q&A judges et preuves de terrain.',
        lessons: const [
          AcademyLessonModel(
            id: 'l9',
            title: 'Construire le pitch',
            summary: 'Problème, solution, modèle, impact, équipe, preuves.',
            durationMinutes: 15,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l10',
            title: 'Répondre aux juges',
            summary: 'Anticiper les questions sur viabilité et méthodologie.',
            durationMinutes: 11,
            completed: false,
          ),
        ],
        quizTitle: 'Préparer un pitch',
        questions: const [
          AcademyQuestionModel(
            question: 'Une bonne réponse aux juges doit être...',
            choices: [
              'Claire, sourcée et honnête',
              'Longue et vague',
              'Basée sur des suppositions cachées',
              'Uniquement émotionnelle',
            ],
            correctIndex: 0,
            explanation:
                'La transparence et les preuves renforcent la crédibilité du projet.',
          ),
        ],
      ),
      _course(
        id: 'leadership-collaboration',
        title: 'Leadership et collaboration',
        category: 'Leadership',
        level: 'Débutant',
        description:
            'Travailler en équipe, passer les informations et grandir ensemble.',
        lessons: const [
          AcademyLessonModel(
            id: 'l11',
            title: 'Leadership entrepreneurial',
            summary: 'Prendre initiative sans écraser les autres.',
            durationMinutes: 9,
            completed: false,
          ),
          AcademyLessonModel(
            id: 'l12',
            title: 'Passation et mémoire collective',
            summary: 'Documenter pour que l’équipe suivante avance plus vite.',
            durationMinutes: 10,
            completed: false,
          ),
        ],
        quizTitle: 'Team Player',
        questions: const [
          AcademyQuestionModel(
            question: 'Une bonne passation sert à...',
            choices: [
              'Préserver la mémoire et accélérer la suite',
              'Remplacer tout le monde',
              'Cacher les erreurs',
              'Faire plus de réunions',
            ],
            correctIndex: 0,
            explanation:
                'La mémoire collective rend EnactSpace utile au-delà d’un mandat.',
          ),
        ],
      ),
    ];

    final personalizedCourses = courses.map(_applyProgress).toList();

    final totalLessons = personalizedCourses.fold<int>(
      0,
      (sum, course) => sum + course.lessonCount,
    );
    final completedLessons = personalizedCourses.fold<int>(
      0,
      (sum, course) =>
          sum + course.lessons.where((lesson) => lesson.completed).length,
    );

    return AcademyHomeData(
      courses: personalizedCourses,
      paths: const [
        AcademyPathModel(
          id: 'onboarding',
          title: 'Nouveau membre',
          description:
              'Bienvenue, culture Enactus, règles internes, chat, tâches, impact et quiz final.',
          courseIds: ['discover-enactus', 'sdgs-impact'],
          progress: 42,
        ),
        AcademyPathModel(
          id: 'impact-builder',
          title: 'Impact Builder',
          description:
              'ODD, direct impact, méthodologie, preuves et annual report.',
          courseIds: ['sdgs-impact', 'pitch-competition'],
          progress: 35,
        ),
        AcademyPathModel(
          id: 'pitch-ready',
          title: 'Pitch Ready',
          description:
              'Business model, Q&A judges, storytelling et préparation compétition.',
          courseIds: ['business-finance', 'pitch-competition'],
          progress: 18,
        ),
      ],
      badges: const [
        AcademyBadgeModel(
          id: 'discoverer',
          label: 'Découvreur Enactus',
          description: 'Bases Enactus terminées.',
          iconName: 'explore',
          unlocked: true,
        ),
        AcademyBadgeModel(
          id: 'sdg',
          label: 'Champion ODD',
          description: 'Comprend les ODD et l’alignement impact.',
          iconName: 'public',
          unlocked: false,
        ),
        AcademyBadgeModel(
          id: 'impact',
          label: 'Impact Builder',
          description: 'Maîtrise impact direct, indirect et preuves.',
          iconName: 'insights',
          unlocked: false,
        ),
        AcademyBadgeModel(
          id: 'pitch',
          label: 'Pitch Ready',
          description: 'Prêt pour le pitch et les questions juges.',
          iconName: 'record_voice_over',
          unlocked: false,
        ),
      ],
      progress: AcademyProgressModel(
        completedLessons: completedLessons,
        totalLessons: totalLessons,
        passedQuizzes: _passedQuizIds.length,
        totalQuizzes: personalizedCourses.length,
        points: _academyPoints,
        rank: 6,
        monthlyProgress: 58,
      ),
    );
  }

  Future<AcademyRewardResult> completeLesson({
    required AcademyCourseModel course,
    required AcademyLessonModel lesson,
  }) async {
    if (_completedLessonIds.contains(lesson.id)) {
      return const AcademyRewardResult(
        points: 0,
        label: 'Leçon déjà terminée',
        syncedWithGamification: true,
      );
    }

    _completedLessonIds.add(lesson.id);
    _academyPoints += 40;

    final synced = await _awardGamificationPoints(
      points: 40,
      reason: 'Academy - leçon terminée: ${course.title} / ${lesson.title}',
    );

    return AcademyRewardResult(
      points: 40,
      label: 'Leçon terminée',
      syncedWithGamification: synced,
    );
  }

  Future<AcademyRewardResult> passQuiz({
    required AcademyCourseModel course,
  }) async {
    if (_passedQuizIds.contains(course.quiz.id)) {
      return const AcademyRewardResult(
        points: 0,
        label: 'Quiz déjà validé',
        syncedWithGamification: true,
      );
    }

    _passedQuizIds.add(course.quiz.id);
    _academyPoints += 60;

    final synced = await _awardGamificationPoints(
      points: 60,
      reason: 'Academy - quiz réussi: ${course.quiz.title}',
    );

    return AcademyRewardResult(
      points: 60,
      label: 'Quiz réussi',
      syncedWithGamification: synced,
    );
  }

  AcademyCourseModel _course({
    required String id,
    required String title,
    required String category,
    required String level,
    required String description,
    required List<AcademyLessonModel> lessons,
    required String quizTitle,
    required List<AcademyQuestionModel> questions,
  }) {
    return AcademyCourseModel(
      id: id,
      title: title,
      category: category,
      level: level,
      description: description,
      durationMinutes: lessons.fold(
        0,
        (sum, lesson) => sum + lesson.durationMinutes,
      ),
      points: lessons.length * 40 + questions.length * 60,
      lessons: lessons,
      quiz: AcademyQuizModel(
        id: '$id-quiz',
        title: quizTitle,
        category: category,
        level: level,
        timeLimitMinutes: 8,
        questions: questions,
      ),
    );
  }

  AcademyCourseModel _applyProgress(AcademyCourseModel course) {
    return AcademyCourseModel(
      id: course.id,
      title: course.title,
      category: course.category,
      level: course.level,
      description: course.description,
      durationMinutes: course.durationMinutes,
      points: course.points,
      lessons: course.lessons
          .map(
            (lesson) => AcademyLessonModel(
              id: lesson.id,
              title: lesson.title,
              summary: lesson.summary,
              durationMinutes: lesson.durationMinutes,
              completed: _completedLessonIds.contains(lesson.id),
            ),
          )
          .toList(),
      quiz: course.quiz,
    );
  }

  Future<bool> _awardGamificationPoints({
    required int points,
    required String reason,
  }) async {
    try {
      final user = await _authService.getCurrentUser();
      final userId = user['id']?.toString();
      if (userId == null || userId.isEmpty) return false;

      await _gamificationService.createPoint(
        userId: userId,
        sourceType: 'manual',
        points: points,
        reason: reason,
      );

      return true;
    } catch (_) {
      return false;
    }
  }
}
