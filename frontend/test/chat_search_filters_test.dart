import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/services/chat_search_filters.dart';

void main() {
  test('search matches accents, tokens and names in reverse order', () {
    expect(chatTextMatches('Élodie Exemple', 'exemple'), isTrue);
    expect(chatTextMatches('Élodie Exemple', 'EXEM elo'), isTrue);
    expect(chatTextMatches('Alice Dupont', 'dupont alice'), isTrue);
    expect(chatTextMatches('Gestion ESP', 'gest esp'), isTrue);
    expect(chatTextMatches('Alice Dupont', 'henri'), isFalse);
  });

  test('search accepts emails and trims repeated spaces', () {
    expect(chatTextMatches('Awa@esp.sn', '   awa@ESP.sn '), isTrue);
    expect(chatTextMatches('Jury groupe', ''), isTrue);
    expect(chatTextMatches('Membre 12', 'membre   12'), isTrue);
  });
}
