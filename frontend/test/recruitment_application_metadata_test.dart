import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recruitment/models/recruitment_application_metadata.dart';

void main() {
  test('promotion accepts only consecutive academic years or an empty optional answer', () {
    for (final value in ['', '2025-2026', '2023-2024', ' 2025-2026 ']) {
      expect(promotionAcademicYearError(value), isNull);
    }
    for (final value in ['2025', '2025-2027', '2025-2025', 'DIC3', '1899-1900']) {
      expect(promotionAcademicYearError(value), isNotNull);
    }
  });
  test('every canonical channel round trips including another means', () {
    for (final key in recruitmentDiscoveryChannels.keys) {
      final answer = discoveryAnswer(key, 'Radio');
      expect(discoveryChannelCode(answer), key);
    }
    expect(discoveryAnswer('other', ' Radio '), 'Autre : Radio');
    expect(discoveryChannelCode('Une ancienne réponse libre'), isNull);
  });
}
