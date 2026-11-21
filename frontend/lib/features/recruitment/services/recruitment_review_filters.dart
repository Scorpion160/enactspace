/// Read-only tools to support a jury deliberation without changing decisions.
/// The API supplies the jury mean /20 when raw notes exist, otherwise the
/// structured rubric's /20 equivalent. Its origin is reported separately.
double? reviewJuryMean20(Map<String, dynamic> row) =>
    (row['jury_average_20'] as num?)?.toDouble();

bool reviewScoreBandMatches(
  Map<String, dynamic> row,
  String band,
  double lower,
  double upper,
) {
  if (band == 'all') return true;
  final score = reviewJuryMean20(row);
  if (band == 'missing') return score == null;
  if (score == null) return false;
  return switch (band) {
    'below' => score < lower,
    'middle' => score >= lower && score < upper,
    'above' => score >= upper,
    _ => true,
  };
}

bool reviewDecisionMatches(Map<String, dynamic> row, String choice) {
  if (choice == 'all') return true;
  final decision = row['decision'];
  return choice == 'pending' ? decision == null : decision == choice;
}

bool reviewDisagreementMatches(Map<String, dynamic> row, String choice) {
  if (choice == 'all') return true;
  final spread = (row['jury_spread_20'] as num?)?.toDouble();
  if (spread == null) return false;
  return switch (choice) {
    'high' => spread >= 5,
    'low' => spread < 5,
    _ => true,
  };
}
