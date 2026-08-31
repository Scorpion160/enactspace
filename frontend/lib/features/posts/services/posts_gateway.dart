import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/post_comment_model.dart';
import '../models/post_model.dart';
import '../models/post_reaction_model.dart';
import '../models/post_stats_model.dart';
import '../models/post_update_model.dart';
import 'posts_service.dart';

class PostsQuery {
  final String search;
  final String postType;
  final String visibility;
  final String? poleId;
  final String? projectId;

  const PostsQuery({
    this.search = '',
    this.postType = 'all',
    this.visibility = 'all',
    this.poleId,
    this.projectId,
  });
}

class PostsFeedData {
  final List<PostModel> posts;
  final UserExperience? user;
  final List<MemberModel> members;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final Map<String, PostStatsModel> statsByPostId;

  const PostsFeedData({
    required this.posts,
    this.user,
    this.members = const [],
    this.poles = const [],
    this.projects = const [],
    this.statsByPostId = const {},
  });
}

abstract interface class PostsGateway {
  Future<PostsFeedData> loadFeed(PostsQuery query);

  Future<PostUploadedMediaModel> uploadMediaBase64({
    required String fileName,
    required String dataBase64,
    String? contentType,
  });

  Future<PostModel> createPost({
    String? title,
    required String content,
    required String postType,
    required String visibility,
    required bool isOfficial,
    String? poleId,
    String? projectId,
    String? mediaFileId,
  });

  Future<PostModel> updatePost({
    required String postId,
    required PostUpdateModel update,
  });

  Future<List<PostCommentModel>> getComments(String postId);

  Future<PostCommentModel> createComment({
    required String postId,
    required String content,
  });

  Future<PostReactionModel> createReaction({
    required String postId,
    required String reactionType,
  });

  Future<PostStatsModel?> getStats(String postId);

  Future<PostModel> pinPost(String postId);

  Future<PostModel> unpinPost(String postId);

  Future<void> deletePost(String postId);

  Future<Uint8List> loadMediaBytes(String url);
}

class ApiPostsGateway implements PostsGateway {
  final PostsService _posts;
  final MembersService _members;
  final AuthService _auth;
  final PolesService _poles;
  final ProjectsService _projects;
  final http.Client _httpClient;

  ApiPostsGateway({
    PostsService? postsService,
    MembersService? membersService,
    AuthService? authService,
    PolesService? polesService,
    ProjectsService? projectsService,
    http.Client? httpClient,
  }) : _posts = postsService ?? PostsService(),
       _members = membersService ?? MembersService(),
       _auth = authService ?? AuthService(),
       _poles = polesService ?? PolesService(),
       _projects = projectsService ?? ProjectsService(),
       _httpClient = httpClient ?? http.Client();

  @override
  Future<PostsFeedData> loadFeed(PostsQuery query) async {
    final posts = await _posts.getPosts(
      search: query.search,
      postType: query.postType,
      visibility: query.visibility,
      poleId: query.poleId,
      projectId: query.projectId,
    );
    final supporting = await Future.wait<dynamic>([
      _loadUserSafely(),
      _loadMembersSafely(),
      _loadPolesSafely(),
      _loadProjectsSafely(),
    ]);
    final statsEntries = await Future.wait(
      posts.map((post) async {
        final stats = await getStats(post.id);
        return stats == null ? null : MapEntry(post.id, stats);
      }),
    );
    return PostsFeedData(
      posts: posts,
      user: supporting[0] as UserExperience?,
      members: supporting[1] as List<MemberModel>,
      poles: supporting[2] as List<PoleModel>,
      projects: supporting[3] as List<ProjectModel>,
      statsByPostId: Map.fromEntries(
        statsEntries.whereType<MapEntry<String, PostStatsModel>>(),
      ),
    );
  }

  Future<UserExperience?> _loadUserSafely() async {
    try {
      return UserExperience.fromJson(await _auth.getCurrentUser());
    } catch (_) {
      return null;
    }
  }

  Future<List<MemberModel>> _loadMembersSafely() async {
    try {
      return await _members.getMembers();
    } catch (_) {
      return const [];
    }
  }

  Future<List<PoleModel>> _loadPolesSafely() async {
    try {
      return await _poles.getPoles();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ProjectModel>> _loadProjectsSafely() async {
    try {
      return await _projects.getProjects();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PostStatsModel?> getStats(String postId) async {
    try {
      return await _posts.getStats(postId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List> loadMediaBytes(String url) async {
    final token = await _auth.getToken();
    if (token == null) throw Exception('Utilisateur non connecté.');
    final absoluteUrl = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : '${ApiClient.serverUrl}$url';
    final response = await _httpClient.get(
      Uri.parse(absoluteUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Média indisponible (${response.statusCode}).');
    }
    return response.bodyBytes;
  }

  @override
  Future<PostUploadedMediaModel> uploadMediaBase64({
    required String fileName,
    required String dataBase64,
    String? contentType,
  }) => _posts.uploadMediaBase64(
    fileName: fileName,
    dataBase64: dataBase64,
    contentType: contentType,
  );

  @override
  Future<PostModel> createPost({
    String? title,
    required String content,
    required String postType,
    required String visibility,
    required bool isOfficial,
    String? poleId,
    String? projectId,
    String? mediaFileId,
  }) => _posts.createPost(
    title: title,
    content: content,
    postType: postType,
    visibility: visibility,
    isOfficial: isOfficial,
    poleId: poleId,
    projectId: projectId,
    mediaFileId: mediaFileId,
  );

  @override
  Future<PostModel> updatePost({
    required String postId,
    required PostUpdateModel update,
  }) => _posts.updatePost(postId: postId, update: update);

  @override
  Future<List<PostCommentModel>> getComments(String postId) =>
      _posts.getComments(postId);

  @override
  Future<PostCommentModel> createComment({
    required String postId,
    required String content,
  }) => _posts.createComment(postId: postId, content: content);

  @override
  Future<PostReactionModel> createReaction({
    required String postId,
    required String reactionType,
  }) => _posts.createReaction(postId: postId, reactionType: reactionType);

  @override
  Future<PostModel> pinPost(String postId) => _posts.pinPost(postId);

  @override
  Future<PostModel> unpinPost(String postId) => _posts.unpinPost(postId);

  @override
  Future<void> deletePost(String postId) => _posts.deletePost(postId);
}
