class PoleModel {
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
    switch (type) {
      case 'support':
        return 'Support';
      case 'projet':
        return 'Projet';
      case 'bureau':
        return 'Bureau';
      default:
        return 'Métier';
    }
  }
}
