String academyCategoryLabel(String value) => switch (value.toLowerCase()) {
  'culture_enactus' => 'Culture Enactus',
  'impact' => 'Impact',
  'business_principles' => 'Principes entrepreneuriaux',
  'competition' => 'Compétition',
  'leadership' => 'Leadership',
  _ => value.replaceAll('_', ' '),
};

String academyRoleLabel(String value) => switch (value.toLowerCase()) {
  'admin' || 'administrateur' => 'Administrateur',
  'team_leader' => 'Team Leader',
  'secretaire_generale' || 'secretaire_general' => 'Secrétariat général',
  'chef_pole' || 'chef_de_pole' => 'Chef de pôle',
  'adjoint_chef_pole' || 'adjoint_chef_de_pole' => 'Adjoint chef de pôle',
  'chef_projet' || 'chef_de_projet' => 'Chef de projet',
  'adjoint_chef_projet' || 'adjoint_chef_de_projet' => 'Adjoint chef de projet',
  'enacteur' => 'Enacteur/Enactrice',
  'alumni' => 'Alumni',
  _ => value.replaceAll('_', ' '),
};

class AcademyPrerequisiteModel {
  final String id;
  final String title;
  final bool completed;
  final bool available;
  const AcademyPrerequisiteModel({
    required this.id,
    required this.title,
    this.completed = false,
    this.available = true,
  });
}

class AcademyCourseModel {
  final String id;
  final String title;
  final String category;
  final String level;
  final String description;
  final int durationMinutes;
  final int points;
  final bool isRequired;
  final List<String> targetRoles;
  final bool isPublished;
  final String? poleId;
  final String? projectId;
  final List<AcademyLessonModel> lessons;
  final AcademyQuizModel quiz;
  final bool quizPassed;
  final bool isLocked;
  final String lockReason;
  final List<String> prerequisiteCourseIds;
  final List<AcademyPrerequisiteModel> prerequisites;
  final bool? serverMastered;

  const AcademyCourseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.durationMinutes,
    required this.points,
    required this.isRequired,
    this.targetRoles = const [],
    this.isPublished = true,
    this.poleId,
    this.projectId,
    required this.lessons,
    required this.quiz,
    this.quizPassed = false,
    this.isLocked = false,
    this.lockReason = '',
    this.prerequisiteCourseIds = const [],
    this.prerequisites = const [],
    this.serverMastered,
  });

  int get lessonCount => lessons.length;
  int get completedLessonCount =>
      lessons.where((lesson) => lesson.completed).length;
  bool get isCompleted =>
      lessonCount > 0 && completedLessonCount == lessonCount;
  bool get isMastered =>
      serverMastered ?? (isCompleted && (quiz.id.isEmpty || quizPassed));
  bool get canTakeQuiz => !isLocked && isCompleted && quiz.id.isNotEmpty;
  bool get isInProgress => completedLessonCount > 0 && !isCompleted;
  double get progress {
    if (lessonCount == 0) return 0;
    return completedLessonCount / lessonCount;
  }

  String get levelLabel => switch (level.toLowerCase()) {
    'debutant' || 'débutant' => 'Débutant',
    'intermediaire' || 'intermédiaire' => 'Intermédiaire',
    'avance' || 'avancé' => 'Avancé',
    'responsable' => 'Responsable',
    _ => level,
  };

  String get categoryLabel => academyCategoryLabel(category);
  String get targetRolesLabel => targetRoles.isEmpty
      ? 'Tous'
      : targetRoles.map(academyRoleLabel).join(', ');
}

class AcademyLessonModel {
  final String id;
  final String title;
  final String summary;
  final int durationMinutes;
  final bool completed;
  final String lessonType;
  final String? content;
  final String? resourceFileId;
  final String? externalUrl;
  final bool started;
  final int orderIndex;
  final bool isPublished;

  const AcademyLessonModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.durationMinutes,
    required this.completed,
    this.lessonType = 'texte',
    this.content,
    this.resourceFileId,
    this.externalUrl,
    this.started = false,
    this.orderIndex = 0,
    this.isPublished = true,
  });

  int get readingMinutes =>
      ((content ?? summary).split(RegExp(r'\s+')).length / 180).ceil().clamp(
        1,
        999,
      );
  int get practiceMinutes => (durationMinutes - readingMinutes).clamp(0, 999);

  String get typeLabel => switch (lessonType) {
    'video' => 'Vidéo',
    'document' => 'Document',
    'quiz' => 'Quiz',
    'activite' => 'Activité',
    _ => 'Texte',
  };

  String get statusLabel => completed
      ? 'Terminé'
      : started
      ? 'En cours'
      : 'À commencer';
}

class AcademyQuizModel {
  final String id;
  final String title;
  final String category;
  final String level;
  final int timeLimitMinutes;
  final List<AcademyQuestionModel> questions;

  const AcademyQuizModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.timeLimitMinutes,
    required this.questions,
  });
}

class AcademyQuestionModel {
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  const AcademyQuestionModel({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });
}

class AcademyBadgeModel {
  final String id;
  final String label;
  final String description;
  final String iconName;
  final bool unlocked;

  const AcademyBadgeModel({
    required this.id,
    required this.label,
    required this.description,
    required this.iconName,
    required this.unlocked,
  });
}

class AcademyCaseStudyModel {
  final String id;
  final String title;
  final String projectName;
  final String context;
  final String problem;
  final String solution;
  final String impact;
  final String difficulties;
  final List<String> lessons;
  final List<String> reflectionQuestions;
  final AcademyQuizModel quiz;

  const AcademyCaseStudyModel({
    required this.id,
    required this.title,
    required this.projectName,
    required this.context,
    required this.problem,
    required this.solution,
    required this.impact,
    required this.difficulties,
    required this.lessons,
    required this.reflectionQuestions,
    required this.quiz,
  });
}

class AcademyPathModel {
  final String id;
  final String title;
  final String description;
  final List<String> courseIds;
  final double progress;

  const AcademyPathModel({
    required this.id,
    required this.title,
    required this.description,
    required this.courseIds,
    required this.progress,
  });
}

class AcademyProgressModel {
  final int completedLessons;
  final int totalLessons;
  final int passedQuizzes;
  final int totalQuizzes;
  final int points;
  final int rank;
  final double monthlyProgress;

  const AcademyProgressModel({
    required this.completedLessons,
    required this.totalLessons,
    required this.passedQuizzes,
    required this.totalQuizzes,
    required this.points,
    required this.rank,
    required this.monthlyProgress,
  });

  double get lessonsProgress {
    if (totalLessons == 0) return 0;
    return completedLessons / totalLessons;
  }

  double get quizProgress {
    if (totalQuizzes == 0) return 0;
    return passedQuizzes / totalQuizzes;
  }
}

class AcademyHomeData {
  final List<AcademyCourseModel> courses;
  final List<AcademyPathModel> paths;
  final List<AcademyBadgeModel> badges;
  final List<AcademyCaseStudyModel> caseStudies;
  final AcademyProgressModel progress;
  final bool offline;
  final int pendingActions;

  const AcademyHomeData({
    required this.courses,
    required this.paths,
    required this.badges,
    required this.caseStudies,
    required this.progress,
    this.offline = false,
    this.pendingActions = 0,
  });
}

class AcademyRewardResult {
  final int points;
  final String label;
  final bool syncedWithGamification;

  const AcademyRewardResult({
    required this.points,
    required this.label,
    required this.syncedWithGamification,
  });
}

class AcademyQuizResult {
  final double score;
  final bool passed;
  final int? correctAnswers;
  final int total;
  final int points;
  final int? attemptNumber;
  final List<Map<String, dynamic>> feedback;

  const AcademyQuizResult({
    required this.score,
    required this.passed,
    required this.correctAnswers,
    required this.total,
    this.feedback = const [],
    required this.points,
    required this.attemptNumber,
  });
}

class AcademyAdminSummary {
  final int courses;
  final int publishedCourses;
  final int learners;
  final int completions;

  const AcademyAdminSummary({
    required this.courses,
    required this.publishedCourses,
    required this.learners,
    required this.completions,
  });
}
