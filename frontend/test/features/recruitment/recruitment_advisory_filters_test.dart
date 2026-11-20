import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/services/recruitment_advisory_filters.dart';

void main() {
  group('estimatedAcademicYearsRemaining', () {
    test('respects the indicated curriculum length', () {
      expect(estimatedAcademicYearsRemaining('DIC1'), 3);
      expect(estimatedAcademicYearsRemaining('DIC2'), 2);
      expect(estimatedAcademicYearsRemaining('DIC3'), 1);
      expect(estimatedAcademicYearsRemaining('DUT1'), 2);
      expect(estimatedAcademicYearsRemaining('DUT2'), 1);
      expect(estimatedAcademicYearsRemaining('Licence1'), 3);
      expect(estimatedAcademicYearsRemaining('Licence3'), 1);
      expect(estimatedAcademicYearsRemaining('Master1'), 2);
      expect(estimatedAcademicYearsRemaining('DESCAF2'), 2);
    });

    test('unknown levels remain unknown instead of excluding candidates', () {
      expect(estimatedAcademicYearsRemaining('Autre niveau'), isNull);
      expect(estimatedAcademicYearsRemaining(null), isNull);
      expect(estimatedAcademicYearsRemaining('DIC4'), isNull);
      expect(matchesAcademicHorizon(null, 'all'), isTrue);
      expect(matchesAcademicHorizon('Licence3', 'all'), isTrue);
      expect(matchesAcademicHorizon('Licence3', 'last_year'), isTrue);
      expect(matchesAcademicHorizon('Licence3', 'two_plus'), isFalse);
      expect(matchesAcademicHorizon('DIC1', 'two_plus'), isTrue);
      expect(matchesAcademicHorizon(null, 'unknown'), isTrue);
    });

    test('case and whitespace variations are normalized', () {
      expect(estimatedAcademicYearsRemaining(' licence 2 '), 2);
      expect(estimatedAcademicYearsRemaining('master 1'), 2);
    });
  });
}
