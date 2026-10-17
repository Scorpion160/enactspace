/// Canonical labels also understood by older API versions and recruitment views.
const recruitmentDiscoveryChannels = <String, String>{
  'social_media': 'Réseaux sociaux',
  'activities': 'Activités ou événements d’Enactus ESP',
  'member': 'Un membre d’Enactus ESP',
  'teaching': 'Un enseignant ou un cours',
  'poster': 'Une affiche ou un support imprimé',
  'web': 'Un site web ou une recherche en ligne',
  'other': 'Autre',
};

String? promotionAcademicYearError(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{4})$').firstMatch(text);
  if (match == null) return 'Utilise le format 2025-2026.';
  final start = int.parse(match[1]!);
  final end = int.parse(match[2]!);
  if (start < 1900 || start > 2199 || end != start + 1) {
    return 'Indique deux années consécutives, par exemple 2025-2026.';
  }
  return null;
}

String discoveryAnswer(String? channel, String other) {
  if (channel == null) return '';
  if (channel == 'other') return 'Autre : ${other.trim()}';
  return recruitmentDiscoveryChannels[channel] ?? '';
}

String? discoveryChannelCode(String? answer) {
  final value = (answer ?? '').trim();
  if (value.startsWith('Autre : ')) return 'other';
  for (final entry in recruitmentDiscoveryChannels.entries) {
    if (entry.key != 'other' && entry.value == value) return entry.key;
  }
  return null;
}
