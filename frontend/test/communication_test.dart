import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/user_experience.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/chat/models/chat_models.dart';
import 'package:frontend/features/chat/screens/chat_screen.dart';
import 'package:frontend/features/chat/services/chat_gateway.dart';
import 'package:frontend/features/chat/services/chat_service.dart';
import 'package:frontend/features/notifications/models/notification_model.dart';
import 'package:frontend/features/notifications/models/notification_presentation.dart';
import 'package:frontend/features/notifications/screens/notifications_screen.dart';
import 'package:frontend/features/notifications/services/notifications_gateway.dart';
import 'package:frontend/features/poles/models/pole_model.dart';
import 'package:frontend/features/posts/models/post_comment_model.dart';
import 'package:frontend/features/posts/models/post_model.dart';
import 'package:frontend/features/posts/models/post_reaction_model.dart';
import 'package:frontend/features/posts/models/post_stats_model.dart';
import 'package:frontend/features/posts/models/post_update_model.dart';
import 'package:frontend/features/posts/screens/posts_screen.dart';
import 'package:frontend/features/posts/services/posts_gateway.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('présentation Communication', () {
    test('humanise les types, audiences et réactions des publications', () {
      final post = _post(postType: 'announcement', visibility: 'public_club');
      expect(post.postTypeLabel, 'Annonce');
      expect(post.visibilityLabel, 'Tout le club');
      expect(_post(visibility: 'internal').visibilityLabel, 'Membres');
      expect(
        _post(visibility: 'enacchef_only').visibilityLabel,
        'Responsables',
      );
      expect(
        PostReactionModel.fromJson({'reaction_type': 'idee'}).label,
        'Idée',
      );
    });

    test('centralise les familles, libellés et icônes de notifications', () {
      final task = notificationPresentation('task_late');
      expect(task.label, 'Tâche en retard');
      expect(task.family, NotificationFamily.tasks);
      expect(task.icon, Icons.task_alt_rounded);
      expect(
        notificationPresentation('post_comment').family,
        NotificationFamily.posts,
      );
      expect(
        notificationPresentation('unknown_backend_value').label,
        'Autre notification',
      );
    });

    test('humanise les types et rôles du chat', () {
      expect(_thread(threadType: 'club').threadTypeLabel, 'Club Enactus');
      expect(
        _thread(threadType: 'enacchef').threadTypeLabel,
        'Responsables Enactus',
      );
      expect(
        _thread(currentUserRole: 'owner').currentUserRoleLabel,
        'Propriétaire',
      );
    });
  });

  group('PostsScreen avec gateway mémoire', () {
    testWidgets('affiche chargement réussi, officiel et épinglé', (
      tester,
    ) async {
      final gateway = _FakePostsGateway(
        posts: [_post(isOfficial: true, isPinned: true)],
      );
      await _pump(tester, PostsScreen(gateway: gateway), const Size(1366, 768));
      expect(find.text('Publication de test'), findsOneWidget);
      expect(find.text('Officielle'), findsWidgets);
      expect(find.text('Épinglée'), findsWidgets);
      expect(find.text('2 réaction(s)'), findsOneWidget);
    });

    testWidgets('affiche les états vide et erreur', (tester) async {
      await _pump(
        tester,
        PostsScreen(gateway: _FakePostsGateway()),
        const Size(1000, 800),
      );
      expect(find.textContaining('Aucune publication'), findsOneWidget);

      await _pump(
        tester,
        PostsScreen(
          key: UniqueKey(),
          gateway: _FakePostsGateway(loadError: Exception('indisponible')),
        ),
        const Size(1000, 800),
      );
      expect(find.text('indisponible'), findsOneWidget);
    });

    testWidgets('charge les commentaires seulement à ouverture', (
      tester,
    ) async {
      final gateway = _FakePostsGateway(posts: [_post()]);
      await _pump(tester, PostsScreen(gateway: gateway), const Size(1000, 900));
      expect(gateway.commentLoads, 0);
      await tester.drag(find.byType(ListView).first, const Offset(0, -850));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 commentaire(s)'));
      await tester.pumpAndSettle();
      expect(gateway.commentLoads, 1);
      expect(find.text('Commentaire chargé à la demande'), findsOneWidget);
    });

    testWidgets('empêche le double submit du composer', (tester) async {
      final gateway = _FakePostsGateway();
      gateway.createCompleter = Completer<PostModel>();
      await _pump(tester, PostsScreen(gateway: gateway), const Size(1200, 900));
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Contenu',
        ),
        'Une publication',
      );
      final publish = find.widgetWithText(ElevatedButton, 'Publier');
      await tester.tap(publish);
      await tester.tap(publish);
      await tester.pump();
      expect(gateway.createCalls, 1);
      gateway.createCompleter!.complete(_post());
      await tester.pumpAndSettle();
    });

    testWidgets('réagit sans charger les commentaires', (tester) async {
      final gateway = _FakePostsGateway(posts: [_post()]);
      await _pump(tester, PostsScreen(gateway: gateway), const Size(1366, 900));
      await tester.tap(find.text('2 réaction(s)'));
      await tester.pumpAndSettle();
      expect(gateway.reactionCalls, 1);
      expect(gateway.commentLoads, 0);
    });

    testWidgets('reste sans overflow à 390 px', (tester) async {
      await _pump(
        tester,
        PostsScreen(gateway: _FakePostsGateway(posts: [_post()])),
        const Size(390, 844),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Publication de test'), findsOneWidget);
    });

    testWidgets('propose Modifier à l’auteur et au modérateur simulé', (
      tester,
    ) async {
      await _pump(
        tester,
        PostsScreen(
          gateway: _FakePostsGateway(posts: [_post()], user: _authorUser),
        ),
        const Size(1366, 900),
      );
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      await _pump(
        tester,
        PostsScreen(
          key: UniqueKey(),
          gateway: _FakePostsGateway(
            posts: [_post(authorId: 'member-9')],
            user: _user,
          ),
        ),
        const Size(1366, 900),
      );
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
    });

    testWidgets('préremplit le formulaire et humanise type et visibilité', (
      tester,
    ) async {
      final post = _post(
        postType: 'announcement',
        visibility: 'pole_only',
        poleId: 'pole-1',
        mediaFileId: 'media-old',
        mediaUrl: '/posts/media-old',
        mediaName: 'terrain.jpg',
      );
      await _pump(
        tester,
        PostsScreen(gateway: _FakePostsGateway(posts: [post])),
        const Size(1366, 900),
      );
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      final title = tester.widget<TextField>(
        find.byKey(const Key('edit-post-title')),
      );
      final content = tester.widget<TextField>(
        find.byKey(const Key('edit-post-content')),
      );
      expect(title.controller!.text, 'Publication de test');
      expect(content.controller!.text, 'Contenu utile pour toute l’équipe.');
      expect(find.text('Annonce'), findsWidgets);
      expect(find.text('Pôle sélectionné'), findsWidgets);
      expect(find.text('Média actuel conservé : terrain.jpg'), findsOneWidget);
      expect(find.text('Pôle conservé'), findsOneWidget);
    });

    testWidgets(
      'envoie seulement les champs modifiés sans scope ni média existant',
      (tester) async {
        final gateway = _FakePostsGateway(
          posts: [
            _post(
              visibility: 'project_only',
              projectId: 'project-1',
              mediaFileId: 'media-old',
              mediaUrl: '/posts/media-old',
            ),
          ],
        );
        await _pump(
          tester,
          PostsScreen(gateway: gateway),
          const Size(1366, 900),
        );
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Modifier'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('edit-post-title')),
          'Titre corrigé',
        );
        await tester.tap(find.byKey(const Key('edit-post-submit')));
        await tester.pumpAndSettle();

        expect(gateway.updateCalls, 1);
        expect(gateway.lastUpdate!.toJson(), {'title': 'Titre corrigé'});
        expect(gateway.lastUpdate!.toJson(), isNot(contains('pole_id')));
        expect(gateway.lastUpdate!.toJson(), isNot(contains('project_id')));
        expect(gateway.lastUpdate!.toJson(), isNot(contains('media_file_id')));
        expect(find.text('Publication modifiée.'), findsOneWidget);
      },
    );

    test('construit le payload PATCH de remplacement média sans scope', () {
      final update = PostUpdateModel.fromChanges(
        original: _post(
          poleId: 'pole-1',
          projectId: 'project-1',
          mediaFileId: 'media-old',
        ),
        title: 'Publication de test',
        content: 'Contenu utile pour toute l’équipe.',
        postType: 'general',
        visibility: 'internal',
        replacementMediaFileId: 'media-new',
      );

      expect(update.toJson(), {'media_file_id': 'media-new'});
      expect(update.toJson(), isNot(contains('pole_id')));
      expect(update.toJson(), isNot(contains('project_id')));
    });

    testWidgets('empêche le double submit de l’édition', (tester) async {
      final gateway = _FakePostsGateway(posts: [_post()]);
      gateway.updateCompleter = Completer<PostModel>();
      await _pump(tester, PostsScreen(gateway: gateway), const Size(1366, 900));
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-post-title')),
        'Titre modifié',
      );
      final submit = find.byKey(const Key('edit-post-submit'));
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(gateway.updateCalls, 1);
      gateway.updateCompleter!.complete(_post(title: 'Titre modifié'));
      await tester.pumpAndSettle();
    });

    testWidgets('conserve le formulaire et ses valeurs après une erreur', (
      tester,
    ) async {
      final gateway = _FakePostsGateway(
        posts: [_post()],
        updateError: Exception('Modification refusée'),
      );
      await _pump(tester, PostsScreen(gateway: gateway), const Size(1366, 900));
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-post-content')),
        'Valeur conservée après erreur',
      );
      await tester.tap(find.byKey(const Key('edit-post-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier la publication'), findsOneWidget);
      expect(find.text('Modification refusée'), findsOneWidget);
      final content = tester.widget<TextField>(
        find.byKey(const Key('edit-post-content')),
      );
      expect(content.controller!.text, 'Valeur conservée après erreur');
    });
  });

  group('ChatScreen avec gateway mémoire', () {
    testWidgets('rend les deux panneaux desktop et les non lus', (
      tester,
    ) async {
      final gateway = _FakeChatGateway();
      await _pump(tester, ChatScreen(gateway: gateway), const Size(1200, 800));
      expect(find.text('Conversations'), findsWidgets);
      expect(find.text('Équipe projet'), findsOneWidget);
      expect(
        DateFormat('EEE', 'fr_FR').format(DateTime.utc(2026, 8, 31)),
        'lun.',
      );
      expect(find.text('3'), findsWidgets);
      expect(find.textContaining('Choisis une conversation'), findsOneWidget);
    });

    testWidgets('mobile passe de la liste à la conversation plein écran', (
      tester,
    ) async {
      final gateway = _FakeChatGateway();
      await _pump(tester, ChatScreen(gateway: gateway), const Size(390, 844));
      expect(find.text('Équipe projet'), findsOneWidget);
      await tester.tap(find.text('Équipe projet'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Envoyer'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('respecte initialThreadId et envoie une seule fois', (
      tester,
    ) async {
      final gateway = _FakeChatGateway()
        ..sendCompleter = Completer<ChatMessageModel>();
      await _pump(
        tester,
        ChatScreen(initialThreadId: 'thread-1', gateway: gateway),
        const Size(1200, 800),
      );
      await tester.enterText(find.byType(TextField).last, 'Bonjour');
      final send = find.byTooltip('Envoyer');
      await tester.tap(send);
      await tester.tap(send);
      await tester.pump();
      expect(gateway.sendCalls, 1);
      expect(find.textContaining('Envoi en cours'), findsOneWidget);
      gateway.sendCompleter!.complete(_message(content: 'Bonjour'));
      await tester.pumpAndSettle();
    });

    testWidgets('realtime typing et présence restent branchés', (tester) async {
      final gateway = _FakeChatGateway();
      await _pump(
        tester,
        ChatScreen(initialThreadId: 'thread-1', gateway: gateway),
        const Size(1200, 800),
      );
      gateway.emit({
        'type': 'presence',
        'user_id': 'member-2',
        'is_online': true,
      });
      gateway.emit({
        'type': 'typing',
        'thread_id': 'thread-1',
        'user_id': 'member-2',
        'display_name': 'Awa Ndiaye',
        'is_typing': true,
      });
      await tester.pump();
      expect(
        find.textContaining('Awa Ndiaye est en train d’écrire'),
        findsOneWidget,
      );
    });

    testWidgets('utilise le cache si le réseau des conversations échoue', (
      tester,
    ) async {
      final gateway = _FakeChatGateway(networkFails: true);
      await _pump(tester, ChatScreen(gateway: gateway), const Size(1200, 800));
      expect(find.text('Équipe projet'), findsOneWidget);
      expect(find.text('Disponible localement'), findsWidgets);
    });

    testWidgets('création propose les six types réels humanisés', (
      tester,
    ) async {
      final gateway = _FakeChatGateway();
      await _pump(
        tester,
        NewChatThreadDialog(chatService: gateway),
        const Size(620, 800),
      );
      await tester.tap(find.text('Privé'));
      await tester.pumpAndSettle();
      expect(find.text('Groupe libre'), findsOneWidget);
      expect(find.text('Club Enactus'), findsOneWidget);
      expect(find.text('Chat de pôle'), findsOneWidget);
      expect(find.text('Chat de projet'), findsOneWidget);
      expect(find.text('Responsables Enactus'), findsOneWidget);
    });
  });

  group('NotificationsScreen avec gateway mémoire', () {
    testWidgets('charge, recherche et filtre les non lues', (tester) async {
      final gateway = _FakeNotificationsGateway();
      await _pump(
        tester,
        NotificationsScreen(gateway: gateway),
        const Size(1000, 800),
      );
      expect(find.text('Tâche urgente'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'message');
      await tester.pump();
      expect(find.text('Nouveau message'), findsWidgets);
      expect(find.text('Tâche urgente'), findsNothing);
      await tester.tap(find.text('Non lues'));
      await tester.pumpAndSettle();
      expect(gateway.lastUnreadOnly, isTrue);
    });

    testWidgets('marque lue puis non lue avec mutations optimistes', (
      tester,
    ) async {
      final gateway = _FakeNotificationsGateway();
      await _pump(
        tester,
        NotificationsScreen(gateway: gateway),
        const Size(1000, 900),
      );
      await tester.tap(find.byTooltip('Marquer comme lue').first);
      await tester.pumpAndSettle();
      expect(gateway.markReadCalls, 1);
      await tester.tap(find.byTooltip('Marquer comme non lue').first);
      await tester.pumpAndSettle();
      expect(gateway.markUnreadCalls, 1);
    });

    testWidgets('confirme la suppression et appelle le gateway', (
      tester,
    ) async {
      final gateway = _FakeNotificationsGateway();
      await _pump(
        tester,
        NotificationsScreen(gateway: gateway),
        const Size(1000, 900),
      );
      await tester.tap(find.byTooltip('Supprimer').first);
      await tester.pumpAndSettle();
      expect(find.text('Supprimer la notification'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();
      expect(gateway.deleteCalls, 1);
    });

    testWidgets('tout lire et realtime rafraîchissent sans concurrence', (
      tester,
    ) async {
      final gateway = _FakeNotificationsGateway();
      await _pump(
        tester,
        NotificationsScreen(gateway: gateway),
        const Size(1000, 900),
      );
      await tester.tap(find.text('Tout lire'));
      await tester.pumpAndSettle();
      expect(gateway.markAllCalls, 1);
      final before = gateway.loadCalls;
      gateway.emit({'type': 'notification'});
      await tester.pumpAndSettle();
      expect(gateway.loadCalls, before + 1);
    });

    testWidgets('route absente affiche un message clair', (tester) async {
      final gateway = _FakeNotificationsGateway(
        notifications: [_notification(type: 'unknown_backend_value')],
      );
      await _pump(
        tester,
        NotificationsScreen(gateway: gateway),
        const Size(1000, 800),
      );
      await tester.tap(find.text('Notification test'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucune page liée pour cette notification.'),
        findsOneWidget,
      );
    });

    testWidgets('reste compacte sans overflow à 390 px', (tester) async {
      await _pump(
        tester,
        NotificationsScreen(gateway: _FakeNotificationsGateway()),
        const Size(390, 844),
      );
      expect(find.byTooltip('Options'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

PostModel _post({
  String authorId = 'member-1',
  String? title = 'Publication de test',
  String postType = 'general',
  String visibility = 'internal',
  bool isOfficial = false,
  bool isPinned = false,
  String? poleId,
  String? projectId,
  String? mediaFileId,
  String? mediaUrl,
  String? mediaName,
}) => PostModel.fromJson({
  'id': 'post-1',
  'author_id': authorId,
  'title': title,
  'content': 'Contenu utile pour toute l’équipe.',
  'post_type': postType,
  'visibility': visibility,
  'pole_id': poleId,
  'project_id': projectId,
  'media_file_id': mediaFileId,
  'media_url': mediaUrl,
  'media_name': mediaName,
  'is_official': isOfficial,
  'is_pinned': isPinned,
  'created_at': '2026-08-31T10:00:00Z',
  'updated_at': '2026-08-31T10:00:00Z',
});

ChatThreadModel _thread({
  String threadType = 'group',
  String currentUserRole = 'member',
}) => ChatThreadModel.fromJson({
  'id': 'thread-1',
  'title': 'Équipe projet',
  'thread_type': threadType,
  'created_at': '2026-08-30T10:00:00Z',
  'updated_at': '2026-08-31T10:00:00Z',
  'participants_count': 2,
  'unread_count': 3,
  'last_message': 'Point terrain à 14 h',
  'last_message_at': '2026-08-31T10:00:00Z',
  'current_user_role': currentUserRole,
  'participants_preview': [
    {
      'user_id': 'member-1',
      'first_name': 'Aminata',
      'last_name': 'Diop',
      'email': 'aminata@example.test',
      'status': 'active',
      'participant_role': currentUserRole,
    },
    {
      'user_id': 'member-2',
      'first_name': 'Awa',
      'last_name': 'Ndiaye',
      'email': 'awa@example.test',
      'status': 'active',
      'participant_role': 'member',
    },
  ],
});

ChatMessageModel _message({String content = 'Message existant'}) =>
    ChatMessageModel.fromJson({
      'id': 'message-1',
      'thread_id': 'thread-1',
      'author_id': 'member-2',
      'content': content,
      'message_type': 'text',
      'created_at': '2026-08-31T10:00:00Z',
    });

NotificationModel _notification({
  String id = 'notification-1',
  String type = 'task_late',
  bool isRead = false,
}) => NotificationModel.fromJson({
  'id': id,
  'user_id': 'member-1',
  'title': type == 'chat_message'
      ? 'Nouveau message'
      : type == 'task_late'
      ? 'Tâche urgente'
      : 'Notification test',
  'message': type == 'chat_message' ? 'Message de l’équipe' : 'Action attendue',
  'type': type,
  'is_read': isRead,
  'created_at': '2026-08-31T10:00:00Z',
});

const _user = UserExperience(
  id: 'member-1',
  email: 'aminata@example.test',
  displayName: 'Aminata Diop',
  status: 'active',
  gender: 'female',
  profileType: 'enacteur',
  roles: {'administrateur'},
  canReviewJoinRequests: true,
);

const _authorUser = UserExperience(
  id: 'member-1',
  email: 'auteur@example.test',
  displayName: 'Auteur Test',
  status: 'active',
  gender: 'female',
  profileType: 'enacteur',
  roles: {},
  canReviewJoinRequests: false,
);

class _FakePostsGateway implements PostsGateway {
  final List<PostModel> posts;
  final Object? loadError;
  final Object? updateError;
  final UserExperience user;
  int commentLoads = 0;
  int createCalls = 0;
  int reactionCalls = 0;
  int updateCalls = 0;
  Completer<PostModel>? createCompleter;
  Completer<PostModel>? updateCompleter;
  PostUpdateModel? lastUpdate;

  _FakePostsGateway({
    this.posts = const [],
    this.loadError,
    this.updateError,
    this.user = _user,
  });

  @override
  Future<PostsFeedData> loadFeed(PostsQuery query) async {
    if (loadError != null) throw loadError!;
    return PostsFeedData(
      posts: posts,
      user: user,
      statsByPostId: {
        for (final post in posts)
          post.id: PostStatsModel(
            postId: post.id,
            commentsCount: 1,
            reactionsCount: 2,
          ),
      },
    );
  }

  @override
  Future<List<PostCommentModel>> getComments(String postId) async {
    commentLoads += 1;
    return [
      PostCommentModel(
        id: 'comment-1',
        postId: postId,
        userId: 'member-2',
        content: 'Commentaire chargé à la demande',
        createdAt: DateTime.utc(2026, 8, 31),
      ),
    ];
  }

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
  }) {
    createCalls += 1;
    return createCompleter?.future ?? Future.value(_post());
  }

  @override
  Future<PostModel> updatePost({
    required String postId,
    required PostUpdateModel update,
  }) {
    updateCalls += 1;
    lastUpdate = update;
    if (updateError != null) return Future.error(updateError!);
    return updateCompleter?.future ??
        Future.value(_post(title: update.toJson()['title']?.toString()));
  }

  @override
  Future<PostStatsModel?> getStats(String postId) async =>
      PostStatsModel(postId: postId, commentsCount: 1, reactionsCount: 2);

  @override
  Future<Uint8List> loadMediaBytes(String url) async => Uint8List(0);

  @override
  Future<PostReactionModel> createReaction({
    required String postId,
    required String reactionType,
  }) async {
    reactionCalls += 1;
    return PostReactionModel(
      id: 'reaction-1',
      postId: postId,
      userId: _user.id,
      reactionType: reactionType,
      createdAt: DateTime.utc(2026, 8, 31),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatGateway implements ChatGateway {
  final bool networkFails;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  int sendCalls = 0;
  Completer<ChatMessageModel>? sendCompleter;

  _FakeChatGateway({this.networkFails = false});

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Future<void> startRealtime() async {}
  @override
  Future<void> disposeRealtime() => _events.close();
  @override
  void sendRealtime(Map<String, dynamic> event) {}
  @override
  Future<UserExperience> getCurrentUser() async => _user;
  @override
  Future<List<ChatContactModel>> getContacts({String? search}) async => [];
  @override
  Future<List<PoleModel>> getPoles() async => [];
  @override
  Future<List<ProjectModel>> getProjects() async => [];
  @override
  Future<List<ChatThreadModel>> getThreads() async {
    if (networkFails) throw Exception('hors ligne');
    return [_thread()];
  }

  @override
  Future<List<ChatThreadModel>> getCachedThreads({
    required String userId,
  }) async => [_thread()];
  @override
  Future<List<ChatMessageModel>> getMessages(String threadId) async => [
    _message(),
  ];
  @override
  Future<List<ChatMessageModel>> getCachedMessages({
    required String userId,
    required String threadId,
  }) async => [_message()];
  @override
  Future<Set<String>> getPinnedThreadIds({required String userId}) async => {};
  @override
  Future<Set<String>> getHiddenThreadIds({required String userId}) async => {};
  @override
  Future<Set<String>> getPinnedMessageIds({
    required String userId,
    required String threadId,
  }) async => {};
  @override
  Future<ChatMediaCacheSettings> getMediaCacheSettings({
    required String userId,
  }) async => const ChatMediaCacheSettings();
  @override
  Future<int> estimateLocalMediaCacheBytes({required String userId}) async => 0;
  @override
  Future<void> cacheThreads({
    required String userId,
    required List<ChatThreadModel> threads,
  }) async {}
  @override
  Future<void> cacheMessages({
    required String userId,
    required String threadId,
    required List<ChatMessageModel> messages,
  }) async {}
  @override
  Future<void> markThreadAsRead(String threadId) async {}
  @override
  Future<ChatMessageModel> sendMessage({
    required String threadId,
    required String content,
    String messageType = 'text',
    String? attachmentFileId,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    int? durationSeconds,
    String? thumbnailUrl,
    String? stickerPack,
  }) {
    sendCalls += 1;
    return sendCompleter?.future ?? Future.value(_message(content: content));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationsGateway implements NotificationsGateway {
  final List<NotificationModel> notifications;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  bool lastUnreadOnly = false;
  int loadCalls = 0;
  int markReadCalls = 0;
  int markUnreadCalls = 0;
  int markAllCalls = 0;
  int deleteCalls = 0;

  _FakeNotificationsGateway({List<NotificationModel>? notifications})
    : notifications =
          notifications ??
          [
            _notification(),
            _notification(
              id: 'notification-2',
              type: 'chat_message',
              isRead: true,
            ),
          ];

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  void emit(Map<String, dynamic> event) => _events.add(event);
  @override
  Future<void> startRealtime() async {}
  @override
  Future<void> disposeRealtime() => _events.close();
  @override
  Future<NotificationsData> load({bool unreadOnly = false}) async {
    loadCalls += 1;
    lastUnreadOnly = unreadOnly;
    return NotificationsData(
      notifications: unreadOnly
          ? notifications.where((item) => !item.isRead).toList()
          : notifications,
      unreadCount: notifications.where((item) => !item.isRead).length,
    );
  }

  @override
  Future<NotificationModel> markAsRead(String notificationId) async {
    markReadCalls += 1;
    return notifications
        .firstWhere((item) => item.id == notificationId)
        .copyWith(isRead: true, readAt: DateTime.now().toIso8601String());
  }

  @override
  Future<NotificationModel> markAsUnread(String notificationId) async {
    markUnreadCalls += 1;
    return notifications
        .firstWhere((item) => item.id == notificationId)
        .copyWith(isRead: false, clearReadAt: true);
  }

  @override
  Future<int> markAllAsRead() async {
    markAllCalls += 1;
    return notifications.where((item) => !item.isRead).length;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    deleteCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
