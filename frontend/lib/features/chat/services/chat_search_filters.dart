/// Search names in flexible order, ignoring common diacritics and extra spaces.
String chatFold(String input) {
  const accent = 'àáâãäåæçèéêëìíîïñòóôõöœùúûüýÿ';
  const plain = [
    'a',
    'a',
    'a',
    'a',
    'a',
    'a',
    'ae',
    'c',
    'e',
    'e',
    'e',
    'e',
    'i',
    'i',
    'i',
    'i',
    'n',
    'o',
    'o',
    'o',
    'o',
    'o',
    'oe',
    'u',
    'u',
    'u',
    'u',
    'y',
    'y',
  ];
  var text = input.toLowerCase();
  for (var i = 0; i < accent.length; i++) {
    text = text.replaceAll(accent[i], plain[i]);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9@]+'), ' ').trim();
}

bool chatTextMatches(String searchable, String query) {
  final tokens = chatFold(
    query,
  ).split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
  if (tokens.isEmpty) return true;
  final haystack = chatFold(searchable);
  return tokens.every(haystack.contains);
}
