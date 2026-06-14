class PostReactionModel {
  final String id;
  final String postId;
  final String userId;
  final String reactionType;
  final DateTime createdAt;

  const PostReactionModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
  });

  factory PostReactionModel.fromJson(Map<String, dynamic> json) {
    return PostReactionModel(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      reactionType: json['reaction_type']?.toString() ?? 'like',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get label {
    switch (reactionType) {
      case 'bravo':
        return 'Bravo';
      case 'important':
        return 'Important';
      case 'idee':
        return 'Idée';
      case 'merci':
        return 'Merci';
      case 'soutien':
        return 'Soutien';
      default:
        return 'Like';
    }
  }
}
