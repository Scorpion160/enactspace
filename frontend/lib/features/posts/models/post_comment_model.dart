class PostCommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;

  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    return PostCommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
