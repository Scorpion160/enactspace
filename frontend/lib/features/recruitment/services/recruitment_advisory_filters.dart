/// Optional analytical filters for the recruitment workbench.
///
/// This estimate is deliberately independent of candidature eligibility and
/// selection decisions. It never prevents a dossier from being evaluated.
int? estimatedAcademicYearsRemaining(String? studyLevel) {
  final normalized = (studyLevel ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final match = RegExp(r'^(DUT|DIC|DST|DIT|LICENCE|MASTER|DESCAF)([1-3])$')
      .firstMatch(normalized);
  if (match == null) return null;

  const durations = <String, int>{
    'DUT': 2,
    'DIC': 3,
    'DST': 2,
    'DIT': 2,
    'LICENCE': 3,
    'MASTER': 2,
    'DESCAF': 3,
  };
  final duration = durations[match.group(1)];
  final currentYear = int.tryParse(match.group(2)!);
  if (duration == null || currentYear == null || currentYear > duration) {
    return null;
  }
  return duration - currentYear + 1;
}

/// 'all' never filters candidates; other values support advisory exploration.
bool matchesAcademicHorizon(String? studyLevel, String choice) {
  if (choice == 'all') return true;
  final remaining = estimatedAcademicYearsRemaining(studyLevel);
  return switch (choice) {
    'two_plus' => remaining != null && remaining >= 2,
    'last_year' => remaining == 1,
    'unknown' => remaining == null,
    _ => true,
  };
}
