class RecruitmentScheduleModel {
  final Map<String, String> dates;
  const RecruitmentScheduleModel(this.dates);

  static const labels = {
    'applications_open': 'Ouverture des dépôts',
    'applications_close': 'Clôture des dépôts',
    'screening_start': 'Début de l’étude',
    'screening_end': 'Fin de l’étude',
    'screening_results': 'Résultat du dossier',
    'interviews_start': 'Début des entretiens',
    'interviews_end': 'Fin des entretiens',
    'final_results': 'Résultats finaux',
  };

  static RecruitmentScheduleModel? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    return RecruitmentScheduleModel(Map<String, String>.unmodifiable({
      for (final key in labels.keys)
        if (raw[key] != null) key: raw[key].toString(),
    }));
  }

  DateTime? date(String key) => DateTime.tryParse(dates[key] ?? '');

  String label(String key) {
    final value = date(key);
    if (value == null) return 'À confirmer';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().padLeft(4, '0')}';
  }

  String range(String start, String end) => dates[start] == dates[end]
      ? label(start) : '${label(start)} – ${label(end)}';

  static DateTime? parseFrench(String text) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text.trim());
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final value = DateTime(year, month, day);
    return value.day == day && value.month == month && value.year == year ? value : null;
  }

  String? get validationError {
    if (labels.keys.any((key) => date(key) == null)) return 'Renseigne toutes les dates du calendrier.';
    const sequence = ['applications_open', 'applications_close', 'screening_end',
      'screening_results', 'interviews_start', 'interviews_end', 'final_results'];
    for (var index = 1; index < sequence.length; index++) {
      if (date(sequence[index])!.isBefore(date(sequence[index - 1])!)) {
        return 'Les dates doivent suivre l’ordre des dépôts, de l’étude, des résultats du dossier, des entretiens et des résultats finaux.';
      }
    }
    if (date('screening_start')!.isBefore(date('applications_open')!) ||
        date('screening_start')!.isAfter(date('screening_end')!)) {
      return 'La période d’étude doit commencer après l’ouverture et avant sa date de fin.';
    }
    return null;
  }
}
