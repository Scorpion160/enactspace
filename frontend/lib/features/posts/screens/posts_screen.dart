import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/post_comment_model.dart';
import '../models/post_model.dart';
import '../models/post_stats_model.dart';
import '../services/posts_service.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> with WidgetsBindingObserver {
  final PostsService _postsService = PostsService();
  final MembersService _membersService = MembersService();
  final AuthService _authService = AuthService();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final Map<String, TextEditingController> _commentControllers = {};

  bool _loading = true;
  bool _creating = false;
  bool _refreshing = false;
  String? _error;
  Timer? _refreshTimer;
  UserExperience? _user;

  List<PostModel> _posts = [];
  List<PoleModel> _poles = [];
  List<ProjectModel> _projects = [];
  Map<String, MemberModel> _membersById = {};
  Map<String, PostStatsModel> _statsByPostId = {};
  final Map<String, List<PostCommentModel>> _commentsByPostId = {};
  final Set<String> _expandedPosts = {};
  final Set<String> _loadingComments = {};

  String _feedFilter = 'all';
  String _postType = 'all';
  String _visibility = 'all';
  String? _filterPoleId;
  String? _filterProjectId;
  String _composerPostType = 'general';
  String _composerVisibility = 'internal';
  String? _composerPoleId;
  String? _composerProjectId;
  bool _composerOfficial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPosts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_loading && !_creating) {
        _loadPosts(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();

    for (final controller in _commentControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) {
      _loadPosts(showLoading: false);
    }
  }

  Future<void> _loadPosts({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final posts = await _postsService.getPosts(
        search: _searchController.text,
        postType: _postType,
        visibility: _visibility,
        poleId: _filterPoleId,
        projectId: _filterProjectId,
      );

      final user = await _loadUserSafely();
      final members = await _loadMembersSafely();
      final poles = _poles.isEmpty ? await _loadPolesSafely() : _poles;
      final projects = _projects.isEmpty
          ? await _loadProjectsSafely()
          : _projects;
      final stats = await Future.wait(posts.map(_loadStatsSafely));

      if (!mounted) return;

      setState(() {
        _posts = _sortPosts(_applyFeedFilter(posts, user));
        _user = user;
        _membersById = {for (final member in members) member.id: member};
        _poles = poles;
        _projects = projects;
        _statsByPostId = {for (final stat in stats) stat.postId: stat};
      });
    } catch (e) {
      if (!mounted) return;

      if (showLoading) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      _refreshing = false;
      if (mounted) {
        setState(() {
          if (showLoading) _loading = false;
        });
      }
    }
  }

  Future<List<MemberModel>> _loadMembersSafely() async {
    try {
      return await _membersService.getMembers();
    } catch (_) {
      return [];
    }
  }

  Future<UserExperience?> _loadUserSafely() async {
    try {
      return UserExperience.fromJson(await _authService.getCurrentUser());
    } catch (_) {
      return null;
    }
  }

  Future<List<PoleModel>> _loadPolesSafely() async {
    try {
      return await _polesService.getPoles();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProjectModel>> _loadProjectsSafely() async {
    try {
      return await _projectsService.getProjects();
    } catch (_) {
      return [];
    }
  }

  Future<PostStatsModel> _loadStatsSafely(PostModel post) async {
    try {
      return await _postsService.getStats(post.id);
    } catch (_) {
      return PostStatsModel(
        postId: post.id,
        commentsCount: 0,
        reactionsCount: 0,
      );
    }
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      _showError('Le contenu de la publication est obligatoire.');
      return;
    }
    if (_composerVisibility == 'pole_only' && _composerPoleId == null) {
      _showError('Sélectionnez le pôle concerné.');
      return;
    }
    if (_composerVisibility == 'project_only' && _composerProjectId == null) {
      _showError('Sélectionnez le projet concerné.');
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      await _postsService.createPost(
        title: _titleController.text,
        content: content,
        postType: _composerPostType,
        visibility: _composerVisibility,
        isOfficial: (_user?.isEnacchef ?? false) && _composerOfficial,
        poleId: _composerVisibility == 'pole_only' ? _composerPoleId : null,
        projectId: _composerVisibility == 'project_only'
            ? _composerProjectId
            : null,
      );

      _titleController.clear();
      _contentController.clear();

      if (!mounted) return;
      setState(() {
        _composerPostType = 'general';
        _composerVisibility = 'internal';
        _composerOfficial = false;
        _composerPoleId = null;
        _composerProjectId = null;
      });

      await _loadPosts();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publication créée.')));
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _toggleComments(PostModel post) async {
    final expanded = _expandedPosts.contains(post.id);

    setState(() {
      if (expanded) {
        _expandedPosts.remove(post.id);
      } else {
        _expandedPosts.add(post.id);
      }
    });

    if (!expanded && !_commentsByPostId.containsKey(post.id)) {
      await _loadComments(post);
    }
  }

  Future<void> _loadComments(PostModel post) async {
    setState(() {
      _loadingComments.add(post.id);
    });

    try {
      final comments = await _postsService.getComments(post.id);

      if (!mounted) return;
      setState(() {
        _commentsByPostId[post.id] = comments;
      });
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loadingComments.remove(post.id);
        });
      }
    }
  }

  Future<void> _createComment(PostModel post) async {
    final controller = _commentControllerFor(post.id);
    final content = controller.text.trim();

    if (content.isEmpty) return;

    try {
      await _postsService.createComment(postId: post.id, content: content);
      controller.clear();

      await _loadComments(post);
      final stat = await _loadStatsSafely(post);

      if (!mounted) return;
      setState(() {
        _statsByPostId[post.id] = stat;
      });
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _react(PostModel post) async {
    await _reactWith(post, 'like');
  }

  Future<void> _reactWith(PostModel post, String reactionType) async {
    try {
      await _postsService.createReaction(
        postId: post.id,
        reactionType: reactionType,
      );
      final stat = await _loadStatsSafely(post);

      if (!mounted) return;
      setState(() {
        _statsByPostId[post.id] = stat;
      });
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<PostModel> _sortPosts(List<PostModel> posts) {
    final sorted = [...posts];
    sorted.sort((a, b) {
      final pinnedCompare = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinnedCompare != 0) return pinnedCompare;

      final officialCompare = (b.isOfficial ? 1 : 0).compareTo(
        a.isOfficial ? 1 : 0,
      );
      if (officialCompare != 0) return officialCompare;

      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  List<PostModel> _applyFeedFilter(
    List<PostModel> posts,
    UserExperience? user,
  ) {
    return posts.where((post) {
      switch (_feedFilter) {
        case 'official':
          return post.isOfficial;
        case 'pole':
          return post.postType == 'pole' ||
              post.visibility == 'pole_only' ||
              post.poleId != null;
        case 'project':
          return post.postType == 'project' ||
              post.visibility == 'project_only' ||
              post.projectId != null;
        case 'mine':
          return user != null && post.authorId == user.id;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _togglePostPin(PostModel post) async {
    try {
      if (post.isPinned) {
        await _postsService.unpinPost(post.id);
      } else {
        await _postsService.pinPost(post.id);
      }

      await _loadPosts();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la publication'),
        content: Text('Supprimer "${post.displayTitle}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _postsService.deletePost(post.id);
      await _loadPosts();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  TextEditingController _commentControllerFor(String postId) {
    return _commentControllers.putIfAbsent(postId, TextEditingController.new);
  }

  String _authorName(PostModel post) {
    final member = _membersById[post.authorId];
    if (member != null) return member.displayName;

    if (post.authorId.length <= 8) return post.authorId;
    return '${post.authorId.substring(0, 8)}...';
  }

  String _authorSubtitle(PostModel post) {
    final member = _membersById[post.authorId];
    if (member == null) return 'Membre Enactus';

    final roles = member.rolesLabel == 'Aucun rôle' ? null : member.rolesLabel;
    final department = member.departmentLabel == 'Non défini'
        ? null
        : member.departmentLabel;

    return [?roles, ?department, member.statusLabel].join(' · ');
  }

  String _authorRoleLabel(PostModel post) {
    final member = _membersById[post.authorId];
    if (member == null) return 'Membre Enactus';
    if (member.status == 'alumni') return 'Alumni';

    final normalizedRoles = member.roles
        .map((role) => role.toLowerCase().replaceAll('-', '_').trim())
        .toSet();

    if (normalizedRoles.any(
      (role) =>
          role.contains('team_leader') ||
          role.contains('president') ||
          role == 'tl',
    )) {
      return 'Team Leader';
    }
    if (normalizedRoles.any(
      (role) => role.contains('secretaire') || role == 'sg',
    )) {
      return 'SG';
    }
    if (normalizedRoles.any(
      (role) => role.contains('chef_pole') || role.contains('pole_lead'),
    )) {
      return 'Chef pôle';
    }
    if (normalizedRoles.any(
      (role) => role.contains('chef_projet') || role.contains('project_lead'),
    )) {
      return 'Chef projet';
    }
    if (normalizedRoles.any((role) => role.contains('adjoint'))) {
      return 'Adjoint';
    }
    return 'Enacteur';
  }

  String? _authorPhotoUrl(PostModel post) {
    return _absoluteUrl(_membersById[post.authorId]?.photoUrl);
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red.shade700, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1180;
          final horizontalPadding = constraints.maxWidth < 560 ? 10.0 : 24.0;
          final sidebarWidth = (constraints.maxWidth * 0.31)
              .clamp(340.0, 410.0)
              .toDouble();

          final header = _PostsHeader(
            total: _posts.length,
            official: _posts.where((post) => post.isOfficial).length,
            pinned: _posts.where((post) => post.isPinned).length,
            onRefresh: _loadPosts,
          );
          final canModerate = _user?.isEnacchef ?? false;

          final composer = _PostComposer(
            titleController: _titleController,
            contentController: _contentController,
            postType: _composerPostType,
            visibility: _composerVisibility,
            poles: _poles,
            projects: _projects,
            selectedPoleId: _composerPoleId,
            selectedProjectId: _composerProjectId,
            isOfficial: _composerOfficial,
            canPublishOfficial: canModerate,
            creating: _creating,
            onPostTypeChanged: (value) {
              setState(() => _composerPostType = value);
            },
            onVisibilityChanged: (value) {
              setState(() {
                _composerVisibility = value;
                if (value != 'pole_only') _composerPoleId = null;
                if (value != 'project_only') _composerProjectId = null;
              });
            },
            onPoleChanged: (value) => setState(() => _composerPoleId = value),
            onProjectChanged: (value) =>
                setState(() => _composerProjectId = value),
            onOfficialChanged: (value) {
              setState(() => _composerOfficial = value);
            },
            onSubmit: _createPost,
          );

          final filters = _PostFilters(
            searchController: _searchController,
            postType: _postType,
            visibility: _visibility,
            poles: _poles,
            projects: _projects,
            selectedPoleId: _filterPoleId,
            selectedProjectId: _filterProjectId,
            onSearch: _loadPosts,
            onPostTypeChanged: (value) async {
              setState(() => _postType = value);
              await _loadPosts();
            },
            onVisibilityChanged: (value) async {
              setState(() {
                _visibility = value;
                if (value != 'pole_only') _filterPoleId = null;
                if (value != 'project_only') _filterProjectId = null;
              });
              await _loadPosts();
            },
            onPoleChanged: (value) async {
              setState(() => _filterPoleId = value);
              await _loadPosts();
            },
            onProjectChanged: (value) async {
              setState(() => _filterProjectId = value);
              await _loadPosts();
            },
          );

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              constraints.maxWidth < 560 ? 12 : 20,
              horizontalPadding,
              28 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    children: [
                      header,
                      const SizedBox(height: 18),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: sidebarWidth,
                              child: Column(
                                children: [
                                  composer,
                                  const SizedBox(height: 18),
                                  filters,
                                  const SizedBox(height: 18),
                                  const _CommunityPulseCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 22),
                            Expanded(child: _buildFeed()),
                          ],
                        )
                      else ...[
                        composer,
                        const SizedBox(height: 18),
                        filters,
                        const SizedBox(height: 22),
                        _buildFeed(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeed() {
    final quickFilters = _PostQuickFilters(
      selected: _feedFilter,
      onChanged: (value) async {
        setState(() => _feedFilter = value);
        await _loadPosts();
      },
    );

    if (_loading) {
      return Column(
        children: [
          quickFilters,
          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          quickFilters,
          const SizedBox(height: 12),
          _ErrorCard(message: _error!, onRetry: _loadPosts),
        ],
      );
    }

    if (_posts.isEmpty) {
      return Column(
        children: [
          quickFilters,
          const SizedBox(height: 12),
          const _EmptyFeedCard(),
        ],
      );
    }

    return Column(
      children: [
        quickFilters,
        const SizedBox(height: 12),
        for (final post in _posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _PostCard(
              post: post,
              authorName: _authorName(post),
              authorRole: _authorRoleLabel(post),
              authorSubtitle: _authorSubtitle(post),
              authorPhotoUrl: _authorPhotoUrl(post),
              stats: _statsByPostId[post.id],
              comments: _commentsByPostId[post.id] ?? const [],
              membersById: _membersById,
              commentsExpanded: _expandedPosts.contains(post.id),
              commentsLoading: _loadingComments.contains(post.id),
              commentController: _commentControllerFor(post.id),
              onToggleComments: () => _toggleComments(post),
              onCreateComment: () => _createComment(post),
              onReact: () => _react(post),
              onReactionSelected: (reactionType) =>
                  _reactWith(post, reactionType),
              canModerate: _user?.isEnacchef ?? false,
              canDelete:
                  (_user?.isEnacchef ?? false) || post.authorId == _user?.id,
              onTogglePin: () => _togglePostPin(post),
              onDelete: () => _deletePost(post),
            ),
          ),
      ],
    );
  }
}

class _PostsHeader extends StatelessWidget {
  final int total;
  final int official;
  final int pinned;
  final VoidCallback onRefresh;

  const _PostsHeader({
    required this.total,
    required this.official,
    required this.pinned,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;
    final compact = MediaQuery.of(context).size.width < 560;

    final content = [
      const _HeaderIcon(),
      SizedBox(width: compact ? 12 : 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Communication',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fil d’actualité, annonces, commentaires et réactions.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeaderChip(label: '$total publication(s)'),
                _HeaderChip(label: '$official officielle(s)'),
                _HeaderChip(label: '$pinned épinglée(s)'),
              ],
            ),
          ],
        ),
      ),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: isWide
          ? Row(
              children: [
                ...content,
                const SizedBox(width: 18),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualiser'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: content),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualiser'),
                ),
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.forum_rounded,
        color: AppTheme.softBlack,
        size: 34,
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;

  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}

class _CommunityPulseCard extends StatelessWidget {
  const _CommunityPulseCard();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.enactusYellow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.softBlack,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Vie de communauté',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les annonces, idées, opportunités et retours terrain vivent ici. '
              'Un fil clair aide les Enacteurs à rester alignés sans fouiller '
              'dans plusieurs groupes.',
              style: TextStyle(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _MetaChip(label: 'Annonces', icon: Icons.campaign_rounded),
                _MetaChip(label: 'Idées', icon: Icons.lightbulb_rounded),
                _MetaChip(label: 'Opportunités', icon: Icons.work_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostQuickFilters extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PostQuickFilters({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = const [
      ('all', 'Tous', Icons.dynamic_feed_rounded),
      ('official', 'Officiels', Icons.verified_rounded),
      ('pole', 'Pôle', Icons.hub_rounded),
      ('project', 'Projet', Icons.workspaces_rounded),
      ('mine', 'Mes posts', Icons.person_rounded),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in filters) ...[
                ChoiceChip(
                  selected: selected == filter.$1,
                  avatar: Icon(filter.$3, size: 16),
                  label: Text(filter.$2),
                  onSelected: (_) => onChanged(filter.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController contentController;
  final String postType;
  final String visibility;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final String? selectedPoleId;
  final String? selectedProjectId;
  final bool isOfficial;
  final bool canPublishOfficial;
  final bool creating;
  final ValueChanged<String> onPostTypeChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String?> onPoleChanged;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<bool> onOfficialChanged;
  final VoidCallback onSubmit;

  const _PostComposer({
    required this.titleController,
    required this.contentController,
    required this.postType,
    required this.visibility,
    required this.poles,
    required this.projects,
    required this.selectedPoleId,
    required this.selectedProjectId,
    required this.isOfficial,
    required this.canPublishOfficial,
    required this.creating,
    required this.onPostTypeChanged,
    required this.onVisibilityChanged,
    required this.onPoleChanged,
    required this.onProjectChanged,
    required this.onOfficialChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nouvelle publication',
                    style: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Titre optionnel',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: contentController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Contenu',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: _responsiveControlWidth(context, 240),
                  child: DropdownButtonFormField<String>(
                    initialValue: postType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: _postTypeItems(includeAll: false),
                    onChanged: (value) {
                      if (value != null) onPostTypeChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: _responsiveControlWidth(context, 240),
                  child: DropdownButtonFormField<String>(
                    initialValue: visibility,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Visibilité'),
                    items: _visibilityItems(includeAll: false),
                    onChanged: (value) {
                      if (value != null) onVisibilityChanged(value);
                    },
                  ),
                ),
                if (visibility == 'pole_only')
                  SizedBox(
                    width: _responsiveControlWidth(context, 240),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedPoleId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Pôle'),
                      items: poles
                          .map(
                            (pole) => DropdownMenuItem(
                              value: pole.id,
                              child: Text(
                                pole.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: onPoleChanged,
                    ),
                  ),
                if (visibility == 'project_only')
                  SizedBox(
                    width: _responsiveControlWidth(context, 240),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedProjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Projet'),
                      items: projects
                          .map(
                            (project) => DropdownMenuItem(
                              value: project.id,
                              child: Text(
                                project.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: onProjectChanged,
                    ),
                  ),
                if (canPublishOfficial)
                  FilterChip(
                    selected: isOfficial,
                    onSelected: onOfficialChanged,
                    avatar: const Icon(Icons.verified_rounded),
                    label: const Text('Officielle'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: compact ? Alignment.center : Alignment.centerRight,
              child: SizedBox(
                width: compact ? double.infinity : null,
                child: ElevatedButton.icon(
                  onPressed: creating ? null : onSubmit,
                  icon: creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Publier'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String postType;
  final String visibility;
  final List<PoleModel> poles;
  final List<ProjectModel> projects;
  final String? selectedPoleId;
  final String? selectedProjectId;
  final VoidCallback onSearch;
  final ValueChanged<String> onPostTypeChanged;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String?> onPoleChanged;
  final ValueChanged<String?> onProjectChanged;

  const _PostFilters({
    required this.searchController,
    required this.postType,
    required this.visibility,
    required this.poles,
    required this.projects,
    required this.selectedPoleId,
    required this.selectedProjectId,
    required this.onSearch,
    required this.onPostTypeChanged,
    required this.onVisibilityChanged,
    required this.onPoleChanged,
    required this.onProjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: _responsiveControlWidth(context, 320),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: onSearch,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            if (visibility == 'pole_only')
              SizedBox(
                width: _responsiveControlWidth(context, 220),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPoleId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pôle'),
                  items: poles
                      .map(
                        (pole) => DropdownMenuItem(
                          value: pole.id,
                          child: Text(
                            pole.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onPoleChanged,
                ),
              ),
            if (visibility == 'project_only')
              SizedBox(
                width: _responsiveControlWidth(context, 220),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedProjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Projet'),
                  items: projects
                      .map(
                        (project) => DropdownMenuItem(
                          value: project.id,
                          child: Text(
                            project.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onProjectChanged,
                ),
              ),
            SizedBox(
              width: _responsiveControlWidth(context, 220),
              child: DropdownButtonFormField<String>(
                initialValue: postType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _postTypeItems(),
                onChanged: (value) {
                  if (value != null) onPostTypeChanged(value);
                },
              ),
            ),
            SizedBox(
              width: _responsiveControlWidth(context, 220),
              child: DropdownButtonFormField<String>(
                initialValue: visibility,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Visibilité'),
                items: _visibilityItems(),
                onChanged: (value) {
                  if (value != null) onVisibilityChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final String authorName;
  final String authorRole;
  final String authorSubtitle;
  final String? authorPhotoUrl;
  final PostStatsModel? stats;
  final List<PostCommentModel> comments;
  final Map<String, MemberModel> membersById;
  final bool commentsExpanded;
  final bool commentsLoading;
  final TextEditingController commentController;
  final VoidCallback onToggleComments;
  final VoidCallback onCreateComment;
  final VoidCallback onReact;
  final ValueChanged<String> onReactionSelected;
  final bool canModerate;
  final bool canDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.authorName,
    required this.authorRole,
    required this.authorSubtitle,
    required this.authorPhotoUrl,
    required this.stats,
    required this.comments,
    required this.membersById,
    required this.commentsExpanded,
    required this.commentsLoading,
    required this.commentController,
    required this.onToggleComments,
    required this.onCreateComment,
    required this.onReact,
    required this.onReactionSelected,
    required this.canModerate,
    required this.canDelete,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    final date = DateFormat('dd/MM/yyyy HH:mm').format(post.createdAt);
    final commentsCount = stats?.commentsCount ?? 0;
    final reactionsCount = stats?.reactionsCount ?? 0;

    return Card(
      color: post.isOfficial
          ? AppTheme.enactusYellow.withValues(alpha: 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: post.isPinned || post.isOfficial
              ? AppTheme.enactusYellow.withValues(alpha: 0.72)
              : Colors.transparent,
          width: post.isPinned || post.isOfficial ? 1.2 : 0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.isPinned || post.isOfficial) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (post.isPinned)
                    const _MetaChip(
                      label: 'Épinglée',
                      icon: Icons.push_pin_rounded,
                      highlighted: true,
                    ),
                  if (post.isOfficial)
                    const _MetaChip(
                      label: 'Officielle',
                      icon: Icons.verified_rounded,
                      highlighted: true,
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PostAuthorAvatar(
                  authorName: authorName,
                  photoUrl: authorPhotoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.displayTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (post.isPinned)
                            const Icon(Icons.push_pin_rounded, size: 18),
                          if (canModerate || canDelete)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'pin') onTogglePin();
                                if (value == 'delete') onDelete();
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'pin',
                                  enabled: canModerate,
                                  child: ListTile(
                                    leading: Icon(
                                      post.isPinned
                                          ? Icons.push_pin_rounded
                                          : Icons.push_pin_outlined,
                                    ),
                                    title: Text(
                                      post.isPinned
                                          ? 'Désépingler'
                                          : 'Épingler',
                                    ),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline_rounded),
                                    title: Text('Supprimer'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$authorName · $date',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      _RolePill(label: authorRole),
                      const SizedBox(height: 5),
                      Text(
                        authorSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.46),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post.content,
              maxLines: compact ? 8 : 12,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: post.postTypeLabel,
                  icon: Icons.category_rounded,
                ),
                _MetaChip(
                  label: post.visibilityLabel,
                  icon: Icons.visibility_rounded,
                ),
                if (post.isOfficial)
                  const _MetaChip(
                    label: 'Officielle',
                    icon: Icons.verified_rounded,
                    highlighted: true,
                  ),
              ],
            ),
            const Divider(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton.icon(
                  onPressed: onReact,
                  icon: const Icon(Icons.thumb_up_alt_outlined),
                  label: Text('$reactionsCount réaction(s)'),
                ),
                _ReactionPicker(onSelected: onReactionSelected),
                TextButton.icon(
                  onPressed: onToggleComments,
                  icon: Icon(
                    commentsExpanded
                        ? Icons.mode_comment_rounded
                        : Icons.mode_comment_outlined,
                  ),
                  label: Text('$commentsCount commentaire(s)'),
                ),
              ],
            ),
            if (commentsExpanded) ...[
              const Divider(height: 24),
              if (commentsLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Aucun commentaire pour le moment.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: compact ? 280 : 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: comments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return _CommentTile(
                        comment: comment,
                        member: membersById[comment.userId],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final commentField = TextField(
                    controller: commentController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ajouter un commentaire',
                      prefixIcon: Icon(Icons.reply_rounded),
                    ),
                  );

                  final sendButton = IconButton.filled(
                    onPressed: onCreateComment,
                    icon: const Icon(Icons.send_rounded),
                  );

                  if (constraints.maxWidth < 340) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        commentField,
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: sendButton,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: commentField),
                      const SizedBox(width: 10),
                      sendButton,
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostAuthorAvatar extends StatelessWidget {
  final String authorName;
  final String? photoUrl;

  const _PostAuthorAvatar({required this.authorName, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundColor: Colors.black12,
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: 23,
      backgroundColor: AppTheme.enactusYellow,
      foregroundColor: AppTheme.softBlack,
      child: Text(
        _initials(authorName),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;

  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.softBlack.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ReactionPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _ReactionPicker({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Réagir',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'bravo', child: Text('👏 Bravo')),
        PopupMenuItem(value: 'idee', child: Text('💡 Idée')),
        PopupMenuItem(value: 'important', child: Text('⭐ Important')),
        PopupMenuItem(value: 'merci', child: Text('🙏 Merci')),
        PopupMenuItem(value: 'soutien', child: Text('💛 Soutien')),
      ],
      child: Chip(
        avatar: const Icon(Icons.add_reaction_outlined, size: 16),
        label: const Text('Réagir'),
        backgroundColor: Colors.white,
        side: BorderSide(color: AppTheme.enactusYellow.withValues(alpha: 0.52)),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlighted;

  const _MetaChip({
    required this.label,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: highlighted
          ? AppTheme.enactusYellow
          : AppTheme.enactusYellow.withValues(alpha: 0.14),
      side: BorderSide(color: AppTheme.enactusYellow.withValues(alpha: 0.34)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostCommentModel comment;
  final MemberModel? member;

  const _CommentTile({required this.comment, required this.member});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy HH:mm').format(comment.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostAuthorAvatar(
            authorName: member?.displayName ?? 'Membre Enactus',
            photoUrl: _absoluteUrl(member?.photoUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member?.displayName ?? 'Membre Enactus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  comment.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement des publications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  const _EmptyFeedCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Text(
            'Aucune publication ne correspond aux filtres actuels.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> _postTypeItems({bool includeAll = true}) {
  return [
    if (includeAll) const DropdownMenuItem(value: 'all', child: Text('Tous')),
    const DropdownMenuItem(value: 'general', child: Text('Général')),
    const DropdownMenuItem(value: 'announcement', child: Text('Annonce')),
    const DropdownMenuItem(value: 'pole', child: Text('Pôle')),
    const DropdownMenuItem(value: 'project', child: Text('Projet')),
    const DropdownMenuItem(value: 'event', child: Text('Événement')),
    const DropdownMenuItem(value: 'document', child: Text('Document')),
    const DropdownMenuItem(value: 'opportunity', child: Text('Opportunité')),
    const DropdownMenuItem(value: 'formation', child: Text('Formation')),
    const DropdownMenuItem(value: 'alumni', child: Text('Alumni')),
  ];
}

List<DropdownMenuItem<String>> _visibilityItems({bool includeAll = true}) {
  return [
    if (includeAll) const DropdownMenuItem(value: 'all', child: Text('Toutes')),
    const DropdownMenuItem(value: 'internal', child: Text('Interne')),
    const DropdownMenuItem(value: 'public_club', child: Text('Club')),
    const DropdownMenuItem(value: 'pole_only', child: Text('Pôle uniquement')),
    const DropdownMenuItem(
      value: 'project_only',
      child: Text('Projet uniquement'),
    ),
    const DropdownMenuItem(value: 'enacchef_only', child: Text('Bureau')),
    const DropdownMenuItem(value: 'alumni_only', child: Text('Alumni')),
    const DropdownMenuItem(value: 'private', child: Text('Privé')),
  ];
}

double _responsiveControlWidth(BuildContext context, double preferred) {
  final screenWidth = MediaQuery.sizeOf(context).width;

  if (screenWidth >= 560) return preferred;

  return (screenWidth - 92).clamp(180.0, preferred).toDouble();
}

String? _absoluteUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${ApiClient.serverUrl}$url';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';

  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }

  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
