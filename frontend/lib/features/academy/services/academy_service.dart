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
      caseStudies: [
        _caseStudy(
          id: 'case-dimbali',
          projectName: 'DIMBALI',
          title: 'Cas Dimbali: nutrition, revenus et reboisement',
          context:
              'Projet historique combinant impact social, économique et environnemental.',
          problem:
              'Malnutrition, revenus faibles et pression sur les ressources locales.',
          solution:
              'Valoriser des ressources locales, structurer des activités génératrices de revenus et planter des arbres.',
          impact:
              'Vies impactées, emplois créés, arbres plantés et apprentissage fort sur la preuve terrain.',
          difficulties:
              'Mesurer précisément les effets et maintenir la dynamique communautaire dans le temps.',
          lessons: [
            'Relier impact social et modèle économique',
            'Documenter les preuves dès le départ',
            'Former des relais locaux',
          ],
        ),
        _caseStudy(
          id: 'case-deconaane',
          projectName: 'DECONAANE',
          title: 'Cas Deconaane: eau sûre, moringa et santé',
          context:
              'Projet orienté santé publique et création de revenus communautaires.',
          problem:
              'Accès insuffisant à une eau sûre et manque d’éducation préventive.',
          solution:
              'Associer sensibilisation, solutions locales et produits à base de moringa.',
          impact:
              'Prévention sanitaire, revenus, emplois et meilleure confiance communautaire.',
          difficulties:
              'Convaincre les utilisateurs et garantir une utilisation correcte.',
          lessons: [
            'La pédagogie d’usage est essentielle',
            'Le produit seul ne suffit pas',
            'La confiance locale accélère l’adoption',
          ],
        ),
        _caseStudy(
          id: 'case-javelisel',
          projectName: 'JAVELISEL',
          title: 'Cas Javelisel: hygiène et prévention',
          context:
              'Projet de santé publique centré sur l’eau de javel et les gestes d’hygiène.',
          problem:
              'Risques sanitaires liés à une hygiène insuffisante et à l’eau non traitée.',
          solution:
              'Développer une solution accessible, accompagnée de sensibilisation terrain.',
          impact:
              'Prévention de maladies, sensibilisation et adoption de pratiques plus sûres.',
          difficulties:
              'Sécurité produit, dosage, emballage et pédagogie continue.',
          lessons: [
            'La sécurité doit guider le design',
            'Un message simple se diffuse mieux',
            'La mesure d’usage est aussi importante que la vente',
          ],
        ),
        _caseStudy(
          id: 'case-mobigel',
          projectName: 'MOBIGEL',
          title: 'Cas Mobigel: innovation rapide Covid-19',
          context:
              'Projet né d’un besoin urgent pendant la crise sanitaire Covid-19.',
          problem:
              'Besoin d’hygiène mobile, rapide et accessible dans les espaces publics.',
          solution:
              'Prototype mobile, test utilisateur et communication préventive.',
          impact:
              'Réponse rapide, sensibilisation et démonstration de capacité d’innovation.',
          difficulties:
              'Agir vite sans perdre la rigueur de test et de sécurité.',
          lessons: [
            'Tester vite vaut mieux que supposer longtemps',
            'L’urgence peut stimuler l’innovation',
            'Un prototype doit rester mesurable',
          ],
        ),
        _caseStudy(
          id: 'case-meune-nagn',
          projectName: 'MEUNE NAGN',
          title: 'Cas Meune Nagn: coopérative et chaîne de valeur',
          context:
              'Projet en Casamance autour de la structuration et de la valorisation locale.',
          problem:
              'Chaînes de valeur peu structurées et revenus instables pour les producteurs.',
          solution:
              'Organisation coopérative, transformation et amélioration des débouchés.',
          impact:
              'Création de valeur locale, revenus plus stables et apprentissage sur la gouvernance.',
          difficulties:
              'Aligner les acteurs, clarifier les responsabilités et maintenir la qualité.',
          lessons: [
            'La gouvernance est une condition d’impact',
            'La chaîne complète doit être pensée',
            'Les producteurs doivent co-construire la solution',
          ],
        ),
        _caseStudy(
          id: 'case-soukhali',
          projectName: 'SOUKHALI',
          title: 'Cas Soukhali: ressources locales transformées',
          context:
              'Projet autour du Neem, de la mangue, du Madd et des pertes post-récolte.',
          problem:
              'Ressources locales sous-valorisées et pertes de production.',
          solution:
              'Transformation, branding, vente pilote et création de débouchés.',
          impact:
              'Valorisation économique, réduction de pertes et apprentissage produit-marché.',
          difficulties:
              'Packaging, conservation, régularité de l’approvisionnement et positionnement.',
          lessons: [
            'Le marché valide la solution',
            'Le design produit crée la confiance',
            'Les pertes peuvent devenir une opportunité',
          ],
        ),
        _caseStudy(
          id: 'case-kong-serve',
          projectName: 'KONG’SERVE',
          title: 'Cas Kong’Serve: conservation et valeur',
          context:
              'Projet sur la conservation alimentaire et la transformation locale.',
          problem: 'Pertes alimentaires et durée de conservation limitée.',
          solution:
              'Méthodes de conservation accessibles et produits transformés.',
          impact:
              'Réduction des pertes, meilleure valeur commerciale et apprentissage terrain.',
          difficulties:
              'Tester la conservation, rassurer les clients et maîtriser les coûts.',
          lessons: [
            'La conservation doit rester simple',
            'Le coût doit être compatible avec le marché',
            'La preuve produit est indispensable',
          ],
        ),
        _caseStudy(
          id: 'case-sukhalii-gokh',
          projectName: 'SUKHALII GOKH',
          title: 'Cas Sukhalii Gokh: quartier et action locale',
          context:
              'Projet d’amélioration locale basé sur la participation communautaire.',
          problem:
              'Besoins locaux dispersés et manque de coordination dans le quartier.',
          solution:
              'Diagnostic participatif, micro-actions et suivi communautaire.',
          impact:
              'Mobilisation locale, apprentissage citoyen et amélioration de proximité.',
          difficulties:
              'Prioriser les actions et documenter des impacts parfois diffus.',
          lessons: [
            'La communauté connaît ses priorités',
            'Les petits actes doivent être suivis',
            'La mémoire collective évite de recommencer à zéro',
          ],
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

  AcademyCaseStudyModel _caseStudy({
    required String id,
    required String projectName,
    required String title,
    required String context,
    required String problem,
    required String solution,
    required String impact,
    required String difficulties,
    required List<String> lessons,
  }) {
    return AcademyCaseStudyModel(
      id: id,
      title: title,
      projectName: projectName,
      context: context,
      problem: problem,
      solution: solution,
      impact: impact,
      difficulties: difficulties,
      lessons: lessons,
      reflectionQuestions: [
        'Quelle preuve aurait rendu ce projet plus solide ?',
        'Quel indicateur People, Planet ou Prosperity faut-il suivre ?',
        'Comment adapter ce projet à une nouvelle saison Enactus ESP ?',
      ],
      quiz: AcademyQuizModel(
        id: '$id-quiz',
        title: 'Mini quiz $projectName',
        category: 'Étude de cas',
        level: 'Intermédiaire',
        timeLimitMinutes: 5,
        questions: [
          AcademyQuestionModel(
            question: 'Quel est le meilleur réflexe après un cas pratique ?',
            choices: [
              'Identifier les preuves et les leçons réutilisables',
              'Copier le projet sans adaptation',
              'Ignorer les difficultés',
              'Ne regarder que les prix obtenus',
            ],
            correctIndex: 0,
            explanation:
                'Un cas pratique sert surtout à apprendre, adapter et mieux mesurer.',
          ),
        ],
      ),
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
