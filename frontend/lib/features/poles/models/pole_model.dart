class PoleModel {
  static const corePoleNames = {'tech', 'chimie', 'gestion', 'it'};
  static const supportPoleNames = {'communication', 'organisation', 'veille'};

  final String id;
  final String? seasonId;
  final String name;
  final String? shortName;
  final String type;
  final String? description;
  final String? objectives;
  final DateTime createdAt;

  const PoleModel({
    required this.id,
    required this.seasonId,
    required this.name,
    required this.shortName,
    required this.type,
    required this.description,
    required this.objectives,
    required this.createdAt,
  });

  factory PoleModel.fromJson(Map<String, dynamic> json) {
    return PoleModel(
      id: json['id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      name: json['name']?.toString() ?? 'Pôle sans nom',
      shortName: json['short_name']?.toString(),
      type: json['type']?.toString() ?? 'metier',
      description: json['description']?.toString(),
      objectives: json['objectives']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get displayShortName {
    if (shortName != null && shortName!.trim().isNotEmpty) {
      return shortName!.trim();
    }

    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'PO';
    }

    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(1, 3))
          .toUpperCase();
    }

    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  String get typeLabel {
    if (isCorePole) return 'Pôle cœur';
    if (isSupportPole) return 'Pôle support';

    switch (type.trim().toLowerCase()) {
      case 'coeur':
      case 'core':
      case 'metier':
      case 'métier':
        return 'Pôle cœur';
      case 'support':
        return 'Pôle support';
      case 'projet':
        return 'Projet';
      case 'bureau':
        return 'Bureau';
      default:
        return 'Pôle';
    }
  }

  bool get isCorePole {
    final normalizedName = _normalizeName(name);
    final normalizedType = _normalizeName(type);
    return normalizedType == 'coeur' ||
        normalizedType == 'core' ||
        normalizedType == 'metier' ||
        corePoleNames.contains(normalizedName);
  }

  bool get isSupportPole {
    final normalizedName = _normalizeName(name);
    final normalizedType = _normalizeName(type);
    return normalizedType == 'support' ||
        supportPoleNames.contains(normalizedName);
  }

  String get descriptionLabel {
    final value = description?.trim();
    if (value == null || value.isEmpty) {
      return 'Aucune description renseignée pour ce pôle.';
    }
    return value;
  }

  String get objectivesLabel {
    final value = objectives?.trim();
    if (value == null || value.isEmpty) return 'Objectifs à préciser.';
    return value;
  }
}

String _normalizeName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), '_');
}
