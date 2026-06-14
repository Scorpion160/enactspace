class PostStatsModel {
  final String postId;
  final int commentsCount;
  final int reactionsCount;

  const PostStatsModel({
    required this.postId,
    required this.commentsCount,
    required this.reactionsCount,
  });

  factory PostStatsModel.fromJson(Map<String, dynamic> json) {
    return PostStatsModel(
      postId: json['post_id']?.toString() ?? '',
      commentsCount:
          int.tryParse(json['comments_count']?.toString() ?? '0') ?? 0,
      reactionsCount:
          int.tryParse(json['reactions_count']?.toString() ?? '0') ?? 0,
    );
  }
}
