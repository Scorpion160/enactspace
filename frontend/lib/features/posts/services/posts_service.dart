import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/post_comment_model.dart';
import '../models/post_model.dart';
import '../models/post_reaction_model.dart';
import '../models/post_stats_model.dart';

class PostsService {
  final ApiClient _apiClient;
  final AuthService _authService;

  PostsService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<PostModel>> getPosts({
    String? search,
    String? postType,
    String? visibility,
    String? poleId,
    String? projectId,
  }) async {
    final token = await _requireToken();
    final params = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    if (postType != null && postType != 'all') {
      params['post_type'] = postType;
    }

    if (visibility != null && visibility != 'all') {
      params['visibility'] = visibility;
    }
    if (poleId != null && poleId.isNotEmpty) {
      params['pole_id'] = poleId;
    }
    if (projectId != null && projectId.isNotEmpty) {
      params['project_id'] = projectId;
    }

    final response = await _apiClient.get(
      _withQuery('/posts/', params),
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(PostModel.fromJson).toList();
  }

  Future<PostModel> createPost({
    String? title,
    required String content,
    required String postType,
    required String visibility,
    required bool isOfficial,
    String? poleId,
    String? projectId,
  }) async {
    final token = await _requireToken();

    final response = await _apiClient.postJson(
      '/posts/',
      token: token,
      data: {
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
        'content': content.trim(),
        'post_type': postType,
        'visibility': visibility,
        'is_official': isOfficial,
        'pole_id': poleId,
        'project_id': projectId,
      },
    );

    if (response is Map<String, dynamic>) {
      return PostModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création de publication.');
  }

  Future<List<PostCommentModel>> getComments(String postId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/posts/$postId/comments',
      token: token,
    );

    return _extractList(
      response,
    ).whereType<Map<String, dynamic>>().map(PostCommentModel.fromJson).toList();
  }

  Future<PostCommentModel> createComment({
    required String postId,
    required String content,
  }) async {
    final token = await _requireToken();

    final response = await _apiClient.postJson(
      '/posts/comments',
      token: token,
      data: {'post_id': postId, 'content': content.trim()},
    );

    if (response is Map<String, dynamic>) {
      return PostCommentModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la création du commentaire.');
  }

  Future<PostReactionModel> createReaction({
    required String postId,
    required String reactionType,
  }) async {
    final token = await _requireToken();

    final response = await _apiClient.postJson(
      '/posts/reactions',
      token: token,
      data: {'post_id': postId, 'reaction_type': reactionType},
    );

    if (response is Map<String, dynamic>) {
      return PostReactionModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de la réaction.');
  }

  Future<List<PostReactionModel>> getReactions(String postId) async {
    final token = await _requireToken();
    final response = await _apiClient.get(
      '/posts/$postId/reactions',
      token: token,
    );

    return _extractList(response)
        .whereType<Map<String, dynamic>>()
        .map(PostReactionModel.fromJson)
        .toList();
  }

  Future<PostModel> pinPost(String postId) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/posts/$postId/pin',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return PostModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors de l’épinglage.');
  }

  Future<PostModel> unpinPost(String postId) async {
    final token = await _requireToken();
    final response = await _apiClient.postJson(
      '/posts/$postId/unpin',
      token: token,
      data: {},
    );

    if (response is Map<String, dynamic>) {
      return PostModel.fromJson(response);
    }

    throw Exception('Réponse invalide lors du désépinglage.');
  }

  Future<void> deletePost(String postId) async {
    final token = await _requireToken();
    await _apiClient.delete('/posts/$postId', token: token);
  }

  Future<PostStatsModel> getStats(String postId) async {
    final token = await _requireToken();
    final response = await _apiClient.get('/posts/$postId/stats', token: token);

    if (response is Map<String, dynamic>) {
      return PostStatsModel.fromJson(response);
    }

    return PostStatsModel(postId: postId, commentsCount: 0, reactionsCount: 0);
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    return token;
  }

  String _withQuery(String path, Map<String, String> params) {
    if (params.isEmpty) return path;

    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    return '$path?$query';
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    if (response is Map && response['items'] is List) {
      return response['items'] as List;
    }
    return [];
  }
}
