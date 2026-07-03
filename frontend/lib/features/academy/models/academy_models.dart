class AcademyCourseModel {
  final String id;
  final String title;
  final String category;
  final String level;
  final String description;
  final int durationMinutes;
  final int points;
  final bool isRequired;
  final List<AcademyLessonModel> lessons;
  final AcademyQuizModel quiz;

  const AcademyCourseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.durationMinutes,
    required this.points,
    required this.isRequired,
    required this.lessons,
    required this.quiz,
  });

  int get lessonCount => lessons.length;
  int get completedLessonCount =>
      lessons.where((lesson) => lesson.completed).length;
  bool get isCompleted =>
      lessonCount > 0 && completedLessonCount == lessonCount;
  bool get isInProgress => completedLessonCount > 0 && !isCompleted;
  double get progress {
    if (lessonCount == 0) return 0;
    return completedLessonCount / lessonCount;
  }
}

class AcademyLessonModel {
  final String id;
  final String title;
  final String summary;
  final int durationMinutes;
  final bool completed;

  const AcademyLessonModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.durationMinutes,
    required this.completed,
  });
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

  const AcademyHomeData({
    required this.courses,
    required this.paths,
    required this.badges,
    required this.caseStudies,
    required this.progress,
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
