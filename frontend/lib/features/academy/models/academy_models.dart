class AcademyCourseModel {
  final String id;
  final String title;
  final String category;
  final String level;
  final String description;
  final int durationMinutes;
  final int points;
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
    required this.lessons,
    required this.quiz,
  });

  int get lessonCount => lessons.length;
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
  final AcademyProgressModel progress;

  const AcademyHomeData({
    required this.courses,
    required this.paths,
    required this.badges,
    required this.progress,
  });
}
