import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

enum _LocalMessageStatus { sending, failed }

class _PendingMessageDraft {
  final String content;
  final String messageType;
  final String? attachmentFileId;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final String? stickerPack;

  const _PendingMessageDraft({
    required this.content,
    this.messageType = 'text',
    this.attachmentFileId,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
    this.durationSeconds,
    this.thumbnailUrl,
    this.stickerPack,
  });
}

class ChatScreen extends StatefulWidget {
  final String? initialThreadId;

  const ChatScreen({super.key, this.initialThreadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();
  final RealtimeService _realtimeService = RealtimeService();
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
  bool _messagesLoading = false;
  bool _sending = false;
  bool _backgroundSyncing = false;
  bool _usingLocalCache = false;
  String? _error;
  Timer? _syncTimer;
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;
  DateTime? _lastSyncedAt;
  UserExperience? _user;
  List<ChatThreadModel> _threads = [];
  List<ChatMessageModel> _messages = [];
  Set<String> _pinnedThreadIds = {};
  Set<String> _hiddenThreadIds = {};
  Set<String> _pinnedMessageIds = {};
  final Map<String, String> _messageReactions = {};
  final Set<String> _removedServerReactionIds = {};
  final Set<String> _hiddenMessageIds = {};
  final Map<String, _LocalMessageStatus> _localMessageStatuses = {};
  final Map<String, _PendingMessageDraft> _pendingMessageDrafts = {};
  final Set<String> _onlineUserIds = {};
  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingExpiryTimers = {};
  Timer? _typingStartTimer;
  Timer? _typingStopTimer;
  bool _typingSent = false;
  String? _typingThreadId;
  ChatMessageModel? _replyingToMessage;
  ChatThreadModel? _selectedThread;
  String? _pendingThreadId;
  int _localMessageCounter = 0;

  @override
  void initState() {
    super.initState();
    _pendingThreadId = _normalizeThreadId(widget.initialThreadId);
    _realtimeSubscription = _realtimeService.events.listen(
      _handleRealtimeEvent,
    );
    _messageController.addListener(_handleComposerChanged);
    unawaited(_realtimeService.start());
    _loadChat();
    _syncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && !_loading && !_messagesLoading && !_sending) {
        _syncActiveChat();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextThreadId = _normalizeThreadId(widget.initialThreadId);
    if (nextThreadId == _normalizeThreadId(oldWidget.initialThreadId)) return;

    _pendingThreadId = nextThreadId;
    if (nextThreadId != null && !_loading) {
      _openPendingThread(_threads);
    }
  }

  @override
  void dispose() {
    _stopTyping();
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _syncTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_realtimeService.dispose());
    _messageController.dispose();
    super.dispose();
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    if (event['type'] == 'connected') {
      final onlineIds = event['online_user_ids'];
      if (onlineIds is List) {
        setState(() {
          _onlineUserIds
            ..clear()
            ..addAll(onlineIds.map((id) => id.toString()));
        });
      }
      return;
    }

    if (event['type'] == 'presence') {
      final userId = event['user_id']?.toString();
      if (userId == null || userId.isEmpty) return;
      setState(() {
        if (event['is_online'] == true) {
          _onlineUserIds.add(userId);
        } else {
          _onlineUserIds.remove(userId);
        }
      });
      return;
    }

    if (event['type'] == 'read') {
      _applyReadReceipt(event);
      return;
    }

    if (event['type'] == 'chat' &&
        !_loading &&
        !_messagesLoading &&
        !_sending) {
      _syncActiveChat();
      return;
    }

    if (event['type'] != 'typing' ||
        event['thread_id']?.toString() != _selectedThread?.id ||
        event['user_id']?.toString() == _user?.id) {
      return;
    }

    final userId = event['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;

    _typingExpiryTimers.remove(userId)?.cancel();
    if (event['is_typing'] == true) {
      setState(() {
        _typingUsers[userId] =
            event['display_name']?.toString().trim().isNotEmpty == true
            ? event['display_name'].toString()
            : 'Un membre';
      });
      _typingExpiryTimers[userId] = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _typingUsers.remove(userId));
      });
    } else {
      setState(() => _typingUsers.remove(userId));
    }
  }

  void _applyReadReceipt(Map<String, dynamic> event) {
    final threadId = event['thread_id']?.toString();
    final userId = event['user_id']?.toString();
    final readAt = DateTime.tryParse(event['read_at']?.toString() ?? '');
    if (threadId == null || userId == null || readAt == null) return;

    ChatThreadModel updateThread(ChatThreadModel thread) {
      if (thread.id != threadId) return thread;
      return thread.copyWith(
        participantsPreview: thread.participantsPreview
            .map(
              (participant) => participant.userId == userId
                  ? participant.copyWith(lastReadAt: readAt)
                  : participant,
            )
            .toList(),
      );
    }

    setState(() {
      _threads = _threads.map(updateThread).toList();
      if (_selectedThread?.id == threadId) {
        _selectedThread = updateThread(_selectedThread!);
      }
    });
  }

  void _sendReadReceipt(String threadId) {
    _realtimeService.send({'type': 'read', 'thread_id': threadId});
  }

  void _handleComposerChanged() {
    final threadId = _selectedThread?.id;
    final hasText = _messageController.text.trim().isNotEmpty;
    if (threadId == null || !hasText) {
      _stopTyping();
      return;
    }

    if (!_typingSent || _typingThreadId != threadId) {
      _typingStartTimer?.cancel();
      _typingStartTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted ||
            _selectedThread?.id != threadId ||
            _messageController.text.trim().isEmpty) {
          return;
        }
        _typingSent = true;
        _typingThreadId = threadId;
        _realtimeService.send({
          'type': 'typing',
          'thread_id': threadId,
          'is_typing': true,
        });
      });
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 4), _stopTyping);
  }

  void _stopTyping() {
    _typingStartTimer?.cancel();
    _typingStartTimer = null;
    _typingStopTimer?.cancel();
    _typingStopTimer = null;
    if (!_typingSent) {
      _typingThreadId = null;
      return;
    }

    final threadId = _typingThreadId ?? _selectedThread?.id;
    _typingSent = false;
    _typingThreadId = null;
    if (threadId != null) {
      _realtimeService.send({
        'type': 'typing',
        'thread_id': threadId,
        'is_typing': false,
      });
    }
  }

  void _clearTypingIndicators() {
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _typingExpiryTimers.clear();
    _typingUsers.clear();
  }

  void _leaveSelectedThread() {
    _stopTyping();
    _clearTypingIndicators();
    setState(() => _selectedThread = null);
  }

  String? _normalizeThreadId(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _openPendingThread(List<ChatThreadModel> threads) {
    final threadId = _pendingThreadId;
    if (threadId == null || _selectedThread?.id == threadId) return;

    final thread = threads.where((item) => item.id == threadId).firstOrNull;
    if (thread == null) return;

    _pendingThreadId = null;
    unawaited(_selectThread(thread));
  }

  Future<void> _loadChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = UserExperience.fromJson(await _authService.getCurrentUser());
      final pinnedThreadIds = await _chatService.getPinnedThreadIds(
        userId: user.id,
      );
      final hiddenThreadIds = await _chatService.getHiddenThreadIds(
        userId: user.id,
      );
      final cachedThreads = await _chatService.getCachedThreads(
        userId: user.id,
      );

      if (mounted && cachedThreads.isNotEmpty) {
        setState(() {
          _user = user;
          _pinnedThreadIds = pinnedThreadIds;
          _hiddenThreadIds = hiddenThreadIds;
          _threads = _visibleSortedThreads(
            cachedThreads,
            pinnedThreadIds,
            hiddenThreadIds,
          );
          _usingLocalCache = true;
          _loading = false;
        });
        _openPendingThread(cachedThreads);
      }

      final threads = await _chatService.getThreads();
      await _chatService.cacheThreads(userId: user.id, threads: threads);

      if (!mounted) return;

      setState(() {
        _user = user;
        _pinnedThreadIds = pinnedThreadIds;
        _hiddenThreadIds = hiddenThreadIds;
        _threads = _visibleSortedThreads(
          threads,
          pinnedThreadIds,
          hiddenThreadIds,
        );
        _usingLocalCache = false;
        _lastSyncedAt = DateTime.now();
      });
      _openPendingThread(threads);
    } catch (e) {
      if (!mounted) return;
      if (_threads.isNotEmpty) {
        setState(() {
          _usingLocalCache = true;
        });
        _showInfo('Connexion indisponible. Chats affichés depuis ce support.');
      } else {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _mergeServerReactions(List<ChatMessageModel> messages) {
    for (final message in messages) {
      final reaction = message.currentUserReaction;
      if (reaction != null && reaction.trim().isNotEmpty) {
        _messageReactions[message.id] = reaction;
        _removedServerReactionIds.remove(message.id);
      } else {
        _messageReactions.remove(message.id);
        _removedServerReactionIds.remove(message.id);
      }
    }
  }

  String _nextLocalMessageId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'local-$timestamp-${_localMessageCounter++}';
  }

  ChatMessageModel _buildLocalMessage({
    required String id,
    required ChatThreadModel thread,
    required _PendingMessageDraft draft,
  }) {
    return ChatMessageModel(
      id: id,
      threadId: thread.id,
      authorId: _user?.id ?? '',
      content: draft.content,
      messageType: draft.messageType,
      attachmentFileId: draft.attachmentFileId,
      attachmentUrl: draft.attachmentUrl,
      attachmentName: draft.attachmentName,
      attachmentMimeType: draft.attachmentMimeType,
      attachmentSizeBytes: draft.attachmentSizeBytes,
      durationSeconds: draft.durationSeconds,
      thumbnailUrl: draft.thumbnailUrl,
      stickerPack: draft.stickerPack,
      reactionsCount: 0,
      reactionsSummary: const {},
      currentUserReaction: null,
      createdAt: DateTime.now(),
      editedAt: null,
      deletedAt: null,
    );
  }

  List<ChatMessageModel> _cacheableMessages(List<ChatMessageModel> messages) {
    return messages
        .where((message) => !_localMessageStatuses.containsKey(message.id))
        .toList();
  }

  List<ChatMessageModel> _mergeWithLocalMessages(
    String threadId,
    List<ChatMessageModel> serverMessages,
  ) {
    final serverIds = serverMessages.map((message) => message.id).toSet();
    final localMessages = _messages.where((message) {
      return message.threadId == threadId &&
          _localMessageStatuses.containsKey(message.id) &&
          !serverIds.contains(message.id);
    });

    final merged = [...serverMessages, ...localMessages];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _replaceLocalMessage(String localId, ChatMessageModel serverMessage) {
    _localMessageStatuses.remove(localId);
    _pendingMessageDrafts.remove(localId);
    _messages = _messages
        .where((message) => message.id != serverMessage.id)
        .toList();
    _messages = _messages
        .map((message) => message.id == localId ? serverMessage : message)
        .toList();
  }

  void _markThreadLocallyRead(String threadId) {
    _threads = _threads
        .map(
          (thread) =>
              thread.id == threadId ? thread.copyWith(unreadCount: 0) : thread,
        )
        .toList();
    if (_selectedThread?.id == threadId) {
      _selectedThread = _selectedThread!.copyWith(unreadCount: 0);
    }
  }

  Future<void> _selectThread(
    ChatThreadModel thread, {
    bool silent = false,
  }) async {
    _stopTyping();
    _clearTypingIndicators();
    if (!silent) {
      setState(() {
        _selectedThread = thread;
        _messagesLoading = true;
      });
    } else {
      setState(() {
        _messagesLoading = true;
      });
    }

    var displayedCachedMessages = false;
    var pinnedMessageIds = <String>{};

    try {
      final userId = _user?.id;
      if (userId != null) {
        if (_hiddenThreadIds.contains(thread.id)) {
          await _chatService.setThreadHidden(
            userId: userId,
            threadId: thread.id,
            hidden: false,
          );
          _hiddenThreadIds.remove(thread.id);
        }
        pinnedMessageIds = await _chatService.getPinnedMessageIds(
          userId: userId,
          threadId: thread.id,
        );
        final cached = await _chatService.getCachedMessages(
          userId: userId,
          threadId: thread.id,
        );
        if (mounted && cached.isNotEmpty) {
          setState(() {
            _messages = cached;
            _mergeServerReactions(cached);
            _pinnedMessageIds = pinnedMessageIds;
            _usingLocalCache = true;
          });
          displayedCachedMessages = true;
        }
      }

      final messages = await _chatService.getMessages(thread.id);
      await _chatService.markThreadAsRead(thread.id);
      _sendReadReceipt(thread.id);
      if (!mounted) return;
      setState(() {
        final displayedMessages = _mergeWithLocalMessages(thread.id, messages);
        if (!_threads.any((item) => item.id == thread.id)) {
          _threads = _sortThreads([..._threads, thread], _pinnedThreadIds);
        }
        _selectedThread = thread;
        _messages = displayedMessages;
        _mergeServerReactions(messages);
        _pinnedMessageIds = pinnedMessageIds;
        _usingLocalCache = false;
        _lastSyncedAt = DateTime.now();
        _markThreadLocallyRead(thread.id);
      });
      if (userId != null) {
        await _chatService.cacheMessages(
          userId: userId,
          threadId: thread.id,
          messages: messages,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (displayedCachedMessages) {
        _showInfo('Messages affichés depuis ce support.');
      } else {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _messagesLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final thread = _selectedThread;
    final content = _messageController.text.trim();
    final reply = _replyingToMessage;

    if (thread == null || content.isEmpty || _sending) return;

    final draft = _PendingMessageDraft(
      content: reply == null
          ? content
          : 'Réponse à "${_messagePreview(reply)}"\n$content',
    );
    final localId = _nextLocalMessageId();
    final localMessage = _buildLocalMessage(
      id: localId,
      thread: thread,
      draft: draft,
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, localMessage];
      _localMessageStatuses[localId] = _LocalMessageStatus.sending;
      _pendingMessageDrafts[localId] = draft;
      _replyingToMessage = null;
    });
    _messageController.clear();
    _stopTyping();

    try {
      final message = await _sendDraft(thread: thread, draft: draft);

      if (!mounted) return;
      setState(() {
        _replaceLocalMessage(localId, message);
      });
      if (_user != null) {
        await _chatService.cacheMessages(
          userId: _user!.id,
          threadId: thread.id,
          messages: _cacheableMessages(_messages),
        );
      }
      await _refreshThreads();
    } catch (e) {
      if (mounted) {
        setState(() {
          _localMessageStatuses[localId] = _LocalMessageStatus.failed;
        });
      }
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _sendAttachmentMessage(_OutgoingAttachment attachment) async {
    final thread = _selectedThread;

    if (thread == null || _sending) return;

    final draft = _PendingMessageDraft(
      content: attachment.caption,
      messageType: attachment.messageType,
      attachmentFileId: attachment.fileId,
      attachmentUrl: attachment.url,
      attachmentName: attachment.name,
      attachmentMimeType: attachment.mimeType,
      attachmentSizeBytes: attachment.sizeBytes,
      durationSeconds: attachment.durationSeconds,
      thumbnailUrl: attachment.thumbnailUrl,
      stickerPack: attachment.stickerPack,
    );
    final localId = _nextLocalMessageId();
    final localMessage = _buildLocalMessage(
      id: localId,
      thread: thread,
      draft: draft,
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, localMessage];
      _localMessageStatuses[localId] = _LocalMessageStatus.sending;
      _pendingMessageDrafts[localId] = draft;
    });

    try {
      final message = await _sendDraft(thread: thread, draft: draft);

      if (!mounted) return;
      setState(() {
        _replaceLocalMessage(localId, message);
      });
      if (_user != null) {
        await _chatService.cacheMessages(
          userId: _user!.id,
          threadId: thread.id,
          messages: _cacheableMessages(_messages),
        );
      }
      await _refreshThreads();
    } catch (e) {
      if (mounted) {
        setState(() {
          _localMessageStatuses[localId] = _LocalMessageStatus.failed;
        });
      }
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<ChatMessageModel> _sendDraft({
    required ChatThreadModel thread,
    required _PendingMessageDraft draft,
  }) {
    return _chatService.sendMessage(
      threadId: thread.id,
      content: draft.content,
      messageType: draft.messageType,
      attachmentFileId: draft.attachmentFileId,
      attachmentUrl: draft.attachmentUrl,
      attachmentName: draft.attachmentName,
      attachmentMimeType: draft.attachmentMimeType,
      attachmentSizeBytes: draft.attachmentSizeBytes,
      durationSeconds: draft.durationSeconds,
      thumbnailUrl: draft.thumbnailUrl,
      stickerPack: draft.stickerPack,
    );
  }

  Future<void> _retryMessage(ChatMessageModel localMessage) async {
    final thread = _selectedThread;
    final draft = _pendingMessageDrafts[localMessage.id];
    if (thread == null || draft == null || _sending) return;

    setState(() {
      _sending = true;
      _localMessageStatuses[localMessage.id] = _LocalMessageStatus.sending;
    });

    try {
      final message = await _sendDraft(thread: thread, draft: draft);
      if (!mounted) return;
      setState(() {
        _replaceLocalMessage(localMessage.id, message);
      });
      if (_user != null) {
        await _chatService.cacheMessages(
          userId: _user!.id,
          threadId: thread.id,
          messages: _cacheableMessages(_messages),
        );
      }
      await _refreshThreads();
    } catch (e) {
      if (mounted) {
        setState(() {
          _localMessageStatuses[localMessage.id] = _LocalMessageStatus.failed;
        });
      }
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _openAttachmentDialog() async {
    if (_selectedThread == null || _sending) return;

    final attachment = await showDialog<_OutgoingAttachment>(
      context: context,
      builder: (context) => _AttachmentMessageDialog(
        chatService: _chatService,
        threadId: _selectedThread!.id,
      ),
    );

    if (attachment == null) return;
    await _sendAttachmentMessage(attachment);
  }

  Future<void> _refreshThreads() async {
    final threads = await _chatService.getThreads();
    if (_user != null) {
      await _chatService.cacheThreads(userId: _user!.id, threads: threads);
    }
    if (!mounted) return;
    setState(() {
      _threads = _visibleSortedThreads(
        threads,
        _pinnedThreadIds,
        _hiddenThreadIds,
      );
      if (_selectedThread != null) {
        _selectedThread = threads
            .where((thread) => thread.id == _selectedThread!.id)
            .firstOrNull;
      }
      _lastSyncedAt = DateTime.now();
    });
  }

  Future<void> _syncActiveChat() async {
    if (_backgroundSyncing) return;

    final user = _user;
    final selectedId = _selectedThread?.id;

    setState(() {
      _backgroundSyncing = true;
    });

    try {
      final threads = await _chatService.getThreads();
      if (user != null) {
        await _chatService.cacheThreads(userId: user.id, threads: threads);
      }

      final selectedThread = selectedId == null
          ? null
          : threads.where((thread) => thread.id == selectedId).firstOrNull;

      List<ChatMessageModel>? messages;
      if (selectedThread != null) {
        messages = await _chatService.getMessages(selectedThread.id);
        if (user != null) {
          await _chatService.cacheMessages(
            userId: user.id,
            threadId: selectedThread.id,
            messages: messages,
          );
          await _chatService.markThreadAsRead(selectedThread.id);
          _sendReadReceipt(selectedThread.id);
        }
      }

      if (!mounted) return;
      setState(() {
        _threads = _visibleSortedThreads(
          threads,
          _pinnedThreadIds,
          _hiddenThreadIds,
        );
        _selectedThread = selectedId == null ? _selectedThread : selectedThread;
        if (messages != null) {
          _messages = _mergeWithLocalMessages(selectedThread!.id, messages);
          _mergeServerReactions(messages);
          _markThreadLocallyRead(selectedThread.id);
        } else if (selectedId != null && selectedThread == null) {
          _messages = [];
        }
        _usingLocalCache = false;
        _lastSyncedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usingLocalCache = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _backgroundSyncing = false;
        });
      }
    }
  }

  List<ChatThreadModel> _sortThreads(
    List<ChatThreadModel> threads,
    Set<String> pinnedIds,
  ) {
    final sorted = [...threads];
    sorted.sort((a, b) {
      final pinnedCompare = (pinnedIds.contains(b.id) ? 1 : 0).compareTo(
        pinnedIds.contains(a.id) ? 1 : 0,
      );
      if (pinnedCompare != 0) return pinnedCompare;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  List<ChatThreadModel> _visibleSortedThreads(
    List<ChatThreadModel> threads,
    Set<String> pinnedIds,
    Set<String> hiddenIds,
  ) {
    final visible = threads.where((thread) {
      return !hiddenIds.contains(thread.id) || thread.unreadCount > 0;
    }).toList();
    return _sortThreads(visible, pinnedIds);
  }

  Future<void> _openNewThreadDialog() async {
    final created = await showDialog<ChatThreadModel>(
      context: context,
      builder: (context) => NewChatThreadDialog(
        chatService: _chatService,
        polesService: _polesService,
        projectsService: _projectsService,
      ),
    );

    if (created == null) return;

    await _loadChat();
    await _selectThread(created);
  }

  Future<void> _toggleSelectedThreadPin() async {
    final user = _user;
    final thread = _selectedThread;
    if (user == null || thread == null) return;

    final shouldPin = !_pinnedThreadIds.contains(thread.id);
    await _chatService.setThreadPinned(
      userId: user.id,
      threadId: thread.id,
      pinned: shouldPin,
    );

    if (!mounted) return;
    setState(() {
      if (shouldPin) {
        _pinnedThreadIds.add(thread.id);
      } else {
        _pinnedThreadIds.remove(thread.id);
      }
      _threads = _visibleSortedThreads(
        _threads,
        _pinnedThreadIds,
        _hiddenThreadIds,
      );
    });
  }

  Future<void> _toggleMessagePin(ChatMessageModel message) async {
    final user = _user;
    final thread = _selectedThread;
    if (user == null || thread == null) return;

    final shouldPin = !_pinnedMessageIds.contains(message.id);
    await _chatService.setMessagePinned(
      userId: user.id,
      threadId: thread.id,
      messageId: message.id,
      pinned: shouldPin,
    );

    if (!mounted) return;
    setState(() {
      if (shouldPin) {
        _pinnedMessageIds.add(message.id);
      } else {
        _pinnedMessageIds.remove(message.id);
      }
    });
  }

  Future<void> _copyMessage(ChatMessageModel message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    _showInfo('Message copié.');
  }

  void _replyToMessage(ChatMessageModel message) {
    setState(() {
      _replyingToMessage = message;
    });
  }

  void _clearReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  Future<void> _reactToMessage(ChatMessageModel message, String emoji) async {
    final thread = _selectedThread;
    final shouldRemove = _messageReactions[message.id] == emoji;
    setState(() {
      if (shouldRemove) {
        _messageReactions.remove(message.id);
        if (message.currentUserReaction != null) {
          _removedServerReactionIds.add(message.id);
        }
      } else {
        _messageReactions[message.id] = emoji;
        _removedServerReactionIds.remove(message.id);
      }
    });

    if (thread == null) {
      _showInfo(
        shouldRemove ? 'Réaction retirée.' : '$emoji réaction ajoutée.',
      );
      return;
    }

    try {
      if (shouldRemove) {
        await _chatService.deleteMessageReaction(
          threadId: thread.id,
          messageId: message.id,
        );
      } else {
        await _chatService.reactToMessage(
          threadId: thread.id,
          messageId: message.id,
          reactionType: emoji,
        );
      }
      _showInfo(
        shouldRemove ? 'Réaction retirée.' : '$emoji réaction synchronisée.',
      );
    } catch (_) {
      _showInfo(
        shouldRemove
            ? 'Réaction retirée sur cet appareil.'
            : '$emoji réaction gardée sur cet appareil.',
      );
    }
  }

  void _deleteMessageForMe(ChatMessageModel message) {
    setState(() {
      _hiddenMessageIds.add(message.id);
      _messageReactions.remove(message.id);
      _removedServerReactionIds.remove(message.id);
      _pinnedMessageIds.remove(message.id);
      _localMessageStatuses.remove(message.id);
      _pendingMessageDrafts.remove(message.id);
      if (_replyingToMessage?.id == message.id) {
        _replyingToMessage = null;
      }
    });
    _showInfo('Message supprimé pour vous.');
  }

  Future<void> _openMessageActions(ChatMessageModel message) async {
    final pinned = _pinnedMessageIds.contains(message.id);
    final localStatus = _localMessageStatuses[message.id];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Répondre'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _replyToMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copier'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _copyMessage(message);
                  },
                ),
                if (localStatus == _LocalMessageStatus.failed)
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Réessayer'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _retryMessage(message);
                    },
                  ),
                if (localStatus == null)
                  ListTile(
                    leading: Icon(
                      pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    ),
                    title: Text(pinned ? 'Désépingler' : 'Épingler'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _toggleMessagePin(message);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Supprimer pour moi'),
                  subtitle: const Text(
                    'Retire seulement ce message de cet appareil.',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessageForMe(message);
                  },
                ),
                if (localStatus == null) ...[
                  const Divider(),
                  Wrap(
                    spacing: 10,
                    children: ['👍', '👏', '💛', '🔥', '🙏'].map((emoji) {
                      return ActionChip(
                        label: Text(emoji),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _reactToMessage(message, emoji);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedThread() async {
    final thread = _selectedThread;
    if (thread == null) return;

    _stopTyping();
    _clearTypingIndicators();
    await _chatService.deleteThread(thread.id);
    if (!mounted) return;
    setState(() {
      _selectedThread = null;
      _messages = [];
    });
    await _loadChat();
  }

  Future<void> _hideSelectedThreadForMe() async {
    final user = _user;
    final thread = _selectedThread;
    if (user == null || thread == null) return;

    _stopTyping();
    _clearTypingIndicators();
    await _chatService.setThreadHidden(
      userId: user.id,
      threadId: thread.id,
      hidden: true,
    );
    if (!mounted) return;
    setState(() {
      _hiddenThreadIds.add(thread.id);
      _threads = _threads.where((item) => item.id != thread.id).toList();
      _selectedThread = null;
      _messages = [];
    });
  }

  Future<void> _openConversationInfo() async {
    final thread = _selectedThread;
    if (thread == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _ConversationInfoDialog(
        thread: thread,
        chatService: _chatService,
        currentUserId: _user?.id,
        pinned: _pinnedThreadIds.contains(thread.id),
        onChanged: () async {
          await _refreshThreads();
          final selected = _selectedThread;
          if (selected != null) {
            await _selectThread(selected, silent: true);
          }
        },
        onTogglePin: () async {
          await _toggleSelectedThreadPin();
          if (context.mounted) Navigator.of(context).pop();
        },
        onLeave: () async {
          final user = _user;
          if (user == null) return;
          await _chatService.removeParticipant(
            threadId: thread.id,
            userId: user.id,
          );
          if (!mounted) return;
          _stopTyping();
          _clearTypingIndicators();
          setState(() {
            _selectedThread = null;
            _messages = [];
          });
          await _loadChat();
          if (context.mounted) Navigator.of(context).pop();
        },
        onHideForMe: () async {
          await _hideSelectedThreadForMe();
          if (context.mounted) Navigator.of(context).pop();
        },
        onAddMember: thread.canManageMembers && thread.threadType != 'direct'
            ? () async {
                final selectedIds = await showDialog<List<String>>(
                  context: context,
                  builder: (context) => _AddChatMembersDialog(
                    chatService: _chatService,
                    existingUserIds: thread.participantsPreview
                        .map((participant) => participant.userId)
                        .toSet(),
                  ),
                );
                if (selectedIds == null || selectedIds.isEmpty) return;
                await _chatService.addParticipants(
                  threadId: thread.id,
                  userIds: selectedIds,
                );
                await _refreshThreads();
              }
            : null,
        onDelete: thread.canManageMembers && thread.threadType != 'direct'
            ? () async {
                await _deleteSelectedThread();
                if (context.mounted) Navigator.of(context).pop();
              }
            : null,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red.shade700, content: Text(message)),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;

        if (!isWide) {
          return _buildMobileChat();
        }

        return RefreshIndicator(
          onRefresh: _loadChat,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    children: [
                      _ChatHeader(
                        onNewThread: _openNewThreadDialog,
                        usingLocalCache: _usingLocalCache,
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const _LoadingCard()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadChat)
                      else
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height - 170,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 360,
                                child: _ThreadsPanel(
                                  threads: _threads,
                                  selectedThread: _selectedThread,
                                  pinnedThreadIds: _pinnedThreadIds,
                                  onlineUserIds: _onlineUserIds,
                                  currentUserId: _user?.id,
                                  onSelect: _selectThread,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _conversationPanel()),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileChat() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_ErrorCard(message: _error!, onRetry: _loadChat)],
      );
    }
    if (_selectedThread != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _leaveSelectedThread();
          }
        },
        child: _conversationPanel(showBack: true, framed: false),
      );
    }

    return Column(
      children: [
        _MobileChatToolbar(
          usingLocalCache: _usingLocalCache,
          onNewThread: _openNewThreadDialog,
        ),
        Expanded(
          child: _ThreadsPanel(
            threads: _threads,
            selectedThread: null,
            pinnedThreadIds: _pinnedThreadIds,
            onlineUserIds: _onlineUserIds,
            currentUserId: _user?.id,
            onSelect: _selectThread,
            framed: false,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _conversationPanel({bool showBack = false, bool framed = true}) {
    final content = Column(
      children: [
        _ConversationHeader(
          thread: _selectedThread,
          currentUserId: _user?.id,
          online:
              _selectedThread != null &&
              _isDirectThreadOnline(
                _selectedThread!,
                _user?.id,
                _onlineUserIds,
              ),
          showBack: showBack,
          pinned: _selectedThread == null
              ? false
              : _pinnedThreadIds.contains(_selectedThread!.id),
          syncing: _backgroundSyncing,
          lastSyncedAt: _lastSyncedAt,
          onBack: _leaveSelectedThread,
          onInfo: _openConversationInfo,
          onTogglePin: _toggleSelectedThreadPin,
        ),
        const Divider(height: 1),
        Expanded(
          child: _messagesLoading
              ? const Center(child: CircularProgressIndicator())
              : _selectedThread == null
              ? const _EmptyConversation()
              : _MessagesList(
                  thread: _selectedThread!,
                  messages: _messages
                      .where(
                        (message) => !_hiddenMessageIds.contains(message.id),
                      )
                      .toList(),
                  currentUserId: _user?.id,
                  pinnedMessageIds: _pinnedMessageIds,
                  messageReactions: _messageReactions,
                  removedServerReactionIds: _removedServerReactionIds,
                  localMessageStatuses: _localMessageStatuses,
                  onMessageLongPress: _openMessageActions,
                  onRetryMessage: _retryMessage,
                ),
        ),
        if (_selectedThread != null)
          if (_typingUsers.isNotEmpty)
            _TypingIndicator(names: _typingUsers.values.toList()),
        if (_selectedThread != null)
          _MessageComposer(
            controller: _messageController,
            sending: _sending,
            replyingTo: _replyingToMessage,
            onClearReply: _clearReply,
            onSend: _sendMessage,
            onAttach: _openAttachmentDialog,
          ),
      ],
    );

    if (!framed) {
      return Material(color: Colors.white, child: content);
    }
    return Card(child: content);
  }
}

class _MobileChatToolbar extends StatelessWidget {
  final bool usingLocalCache;
  final VoidCallback onNewThread;

  const _MobileChatToolbar({
    required this.usingLocalCache,
    required this.onNewThread,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Discussions',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ),
            if (usingLocalCache)
              const Tooltip(
                message: 'Disponible localement',
                child: Icon(Icons.offline_bolt_rounded, size: 20),
              ),
            IconButton(
              onPressed: onNewThread,
              tooltip: 'Nouvelle discussion',
              icon: const Icon(Icons.add_comment_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final VoidCallback onNewThread;
  final bool usingLocalCache;

  const _ChatHeader({required this.onNewThread, required this.usingLocalCache});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.softBlack,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final title = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chat EnactSpace',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Discussions directes et groupes de travail.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  if (usingLocalCache) ...[
                    const SizedBox(height: 8),
                    const _LocalCacheChip(),
                  ],
                ],
              ),
            );
            final action = ElevatedButton.icon(
              onPressed: onNewThread,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Nouvelle'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.enactusYellow,
                        foregroundColor: AppTheme.softBlack,
                        child: Icon(Icons.chat_rounded),
                      ),
                      const SizedBox(width: 14),
                      title,
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: action),
                ],
              );
            }

            return Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Icon(Icons.chat_rounded),
                ),
                const SizedBox(width: 14),
                title,
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LocalCacheChip extends StatelessWidget {
  const _LocalCacheChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Text(
              'Disponible localement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadsPanel extends StatefulWidget {
  final List<ChatThreadModel> threads;
  final ChatThreadModel? selectedThread;
  final Set<String> pinnedThreadIds;
  final Set<String> onlineUserIds;
  final String? currentUserId;
  final ValueChanged<ChatThreadModel> onSelect;
  final bool framed;
  final bool compact;

  const _ThreadsPanel({
    required this.threads,
    required this.selectedThread,
    required this.pinnedThreadIds,
    required this.onlineUserIds,
    required this.currentUserId,
    required this.onSelect,
    this.framed = true,
    this.compact = false,
  });

  @override
  State<_ThreadsPanel> createState() => _ThreadsPanelState();
}

class _ThreadsPanelState extends State<_ThreadsPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredThreads = widget.threads.where((thread) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return _threadSearchText(thread, widget.currentUserId).contains(query);
    }).toList();

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (!widget.compact)
            const ListTile(
              leading: Icon(Icons.forum_rounded),
              title: Text(
                'Conversations',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Rechercher une discussion',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: widget.threads.isEmpty
                ? const _EmptyThreads()
                : filteredThreads.isEmpty
                ? const _EmptySearchResult()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filteredThreads.length,
                    itemBuilder: (context, index) {
                      final thread = filteredThreads[index];
                      final selected = thread.id == widget.selectedThread?.id;

                      return _ThreadTile(
                        thread: thread,
                        selected: selected,
                        pinned: widget.pinnedThreadIds.contains(thread.id),
                        online: _isDirectThreadOnline(
                          thread,
                          widget.currentUserId,
                          widget.onlineUserIds,
                        ),
                        currentUserId: widget.currentUserId,
                        onTap: () => widget.onSelect(thread),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (!widget.framed) {
      return Material(color: Colors.white, child: content);
    }
    return Card(child: content);
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThreadModel thread;
  final bool selected;
  final bool pinned;
  final bool online;
  final String? currentUserId;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.thread,
    required this.selected,
    required this.pinned,
    required this.online,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _threadDisplayTitle(thread, currentUserId);
    final hasUnread = thread.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.enactusYellow.withValues(alpha: 0.24)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                child: Badge(
                  isLabelVisible: online,
                  backgroundColor: Colors.green.shade600,
                  smallSize: 11,
                  child: _ChatAvatar(
                    title: title,
                    imageUrl: _threadAvatarUrl(thread, currentUserId),
                    selected: selected,
                    icon: thread.threadType == 'direct'
                        ? Icons.person
                        : Icons.groups,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: hasUnread
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      thread.lastMessage ??
                          _threadSubtitle(thread, currentUserId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: hasUnread ? AppTheme.softBlack : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _threadTimeLabel(
                        thread.lastMessageAt ?? thread.updatedAt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? Colors.green.shade700
                            : Colors.black45,
                        fontSize: 11,
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (pinned)
                            const Icon(Icons.push_pin_rounded, size: 15),
                          if (pinned && hasUnread) const SizedBox(width: 4),
                          if (hasUnread)
                            Badge(
                              label: Text(
                                thread.unreadCount > 99
                                    ? '99+'
                                    : '${thread.unreadCount}',
                              ),
                              backgroundColor: Colors.green.shade600,
                              textColor: Colors.white,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final bool selected;
  final IconData icon;

  const _ChatAvatar({
    required this.title,
    required this.imageUrl,
    required this.selected,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.black12,
        backgroundImage: NetworkImage(url),
      );
    }

    final initials = _initials(title);
    return CircleAvatar(
      backgroundColor: selected ? AppTheme.enactusYellow : Colors.black12,
      foregroundColor: AppTheme.softBlack,
      child: initials == '?' ? Icon(icon) : Text(initials),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  final ChatThreadModel? thread;
  final String? currentUserId;
  final bool showBack;
  final bool pinned;
  final bool syncing;
  final bool online;
  final DateTime? lastSyncedAt;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback onTogglePin;

  const _ConversationHeader({
    required this.thread,
    required this.currentUserId,
    required this.showBack,
    required this.pinned,
    required this.syncing,
    required this.online,
    required this.lastSyncedAt,
    required this.onBack,
    required this.onInfo,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final title = thread == null
        ? 'Sélectionne une conversation'
        : _threadDisplayTitle(thread!, currentUserId);

    return ListTile(
      leading: showBack
          ? IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : _ChatAvatar(
              title: title,
              imageUrl: thread == null
                  ? null
                  : _threadAvatarUrl(thread!, currentUserId),
              selected: true,
              icon: Icons.chat_bubble_rounded,
            ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: thread == null
          ? const Text('Tes messages apparaîtront ici.')
          : _ConversationSubtitle(
              thread: thread!,
              currentUserId: currentUserId,
              syncing: syncing,
              online: online,
              lastSyncedAt: lastSyncedAt,
            ),
      trailing: thread == null
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'pin') onTogglePin();
                if (value == 'info') onInfo();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: ListTile(
                    leading: Icon(
                      pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    ),
                    title: Text(pinned ? 'Désépingler' : 'Épingler'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Infos'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ConversationSubtitle extends StatelessWidget {
  final ChatThreadModel thread;
  final String? currentUserId;
  final bool syncing;
  final bool online;
  final DateTime? lastSyncedAt;

  const _ConversationSubtitle({
    required this.thread,
    required this.currentUserId,
    required this.syncing,
    required this.online,
    required this.lastSyncedAt,
  });

  @override
  Widget build(BuildContext context) {
    if (thread.threadType == 'direct' && online) {
      return Text(
        'En ligne',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final syncLabel = syncing
        ? 'synchro...'
        : lastSyncedAt == null
        ? null
        : 'sync ${DateFormat('HH:mm').format(lastSyncedAt!)}';

    return Text(
      [_threadSubtitle(thread, currentUserId), ?syncLabel].join(' • '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MessagesList extends StatelessWidget {
  final ChatThreadModel thread;
  final List<ChatMessageModel> messages;
  final String? currentUserId;
  final Set<String> pinnedMessageIds;
  final Map<String, String> messageReactions;
  final Set<String> removedServerReactionIds;
  final Map<String, _LocalMessageStatus> localMessageStatuses;
  final ValueChanged<ChatMessageModel> onMessageLongPress;
  final ValueChanged<ChatMessageModel> onRetryMessage;

  const _MessagesList({
    required this.thread,
    required this.messages,
    required this.currentUserId,
    required this.pinnedMessageIds,
    required this.messageReactions,
    required this.removedServerReactionIds,
    required this.localMessageStatuses,
    required this.onMessageLongPress,
    required this.onRetryMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Aucun message. Lance la discussion.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final mine = message.authorId == currentUserId;
        final pinned = pinnedMessageIds.contains(message.id);
        final reaction = _messageReactionLabel(
          message,
          messageReactions[message.id],
          removedServerReactionIds.contains(message.id),
        );
        final readByOthers = _messageReadByOthers(
          thread: thread,
          message: message,
          currentUserId: currentUserId,
        );
        final localStatus = mine ? localMessageStatuses[message.id] : null;

        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => onMessageLongPress(message),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppTheme.enactusYellow : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: mine ? const Radius.circular(4) : null,
                  bottomLeft: mine ? null : const Radius.circular(4),
                ),
                border: pinned
                    ? Border.all(color: AppTheme.softBlack, width: 1.4)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pinned)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(Icons.push_pin_rounded, size: 14),
                    ),
                  _MessageBody(message: message),
                  if (reaction != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(reaction),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.48),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 5),
                        _MessageStatusIndicator(
                          status: localStatus,
                          readByOthers: readByOthers,
                          onRetry: localStatus == _LocalMessageStatus.failed
                              ? () => onRetryMessage(message)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageStatusIndicator extends StatelessWidget {
  final _LocalMessageStatus? status;
  final bool readByOthers;
  final VoidCallback? onRetry;

  const _MessageStatusIndicator({
    required this.status,
    required this.readByOthers,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == _LocalMessageStatus.sending) {
      return Tooltip(
        message: 'Envoi en cours',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.black.withValues(alpha: 0.48),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'Envoi',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.48),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    if (status == _LocalMessageStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Échec de l’envoi',
            child: Icon(
              Icons.error_rounded,
              size: 15,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 2),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade800,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      );
    }

    // TODO backend: expose delivered/read per recipient to split "livré" from "lu".
    final label = readByOthers ? 'Lu' : 'Envoyé';
    final color = readByOthers
        ? Colors.blue.shade700
        : Colors.black.withValues(alpha: 0.48);
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            readByOthers ? Icons.done_all_rounded : Icons.done_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  final ChatMessageModel message;

  const _MessageBody({required this.message});

  @override
  Widget build(BuildContext context) {
    if (!message.isMedia) {
      return Text(message.content, style: const TextStyle(height: 1.35));
    }

    if (message.messageType == 'image' || message.messageType == 'sticker') {
      final url = message.absoluteAttachmentUrl;
      if (url == null || url.isEmpty) {
        return _MediaFallback(message: message, unavailable: true);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final targetWidth = message.messageType == 'sticker'
                  ? 150.0
                  : 260.0;
              final width =
                  constraints.maxWidth.isFinite &&
                      constraints.maxWidth < targetWidth
                  ? constraints.maxWidth
                  : targetWidth;
              final height = message.messageType == 'sticker' ? 150.0 : 170.0;

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      url,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _MediaLoadingBox(width: width, height: height);
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _MediaFallback(
                          message: message,
                          unavailable: true,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _AttachmentActionButton(message: message),
                  ),
                ],
              );
            },
          ),
          if (message.attachmentSizeBytes != null) ...[
            const SizedBox(height: 6),
            Text(
              _formatBytes(message.attachmentSizeBytes!),
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.54),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (message.content.trim().isNotEmpty &&
              message.content != message.attachmentLabel) ...[
            const SizedBox(height: 8),
            Text(message.content, style: const TextStyle(height: 1.35)),
          ],
        ],
      );
    }

    return _MediaFallback(message: message);
  }
}

class _MediaFallback extends StatelessWidget {
  final ChatMessageModel message;
  final bool unavailable;

  const _MediaFallback({required this.message, this.unavailable = false});

  @override
  Widget build(BuildContext context) {
    final icon = switch (message.messageType) {
      'audio' => Icons.graphic_eq_rounded,
      'video' => Icons.play_circle_fill_rounded,
      'document' => Icons.description_rounded,
      'sticker' => Icons.emoji_emotions_rounded,
      'image' => Icons.image_rounded,
      _ => Icons.attach_file_rounded,
    };
    final details = [
      _messageTypeLabel(message.messageType),
      if (message.attachmentSizeBytes != null)
        _formatBytes(message.attachmentSizeBytes!),
      if (message.durationSeconds != null)
        _formatDuration(message.durationSeconds!),
    ].join(' · ');

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.softBlack,
            foregroundColor: Colors.white,
            child: Icon(icon),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unavailable
                      ? 'Pièce jointe indisponible'
                      : message.attachmentLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (message.content.trim().isNotEmpty &&
                    message.content != message.attachmentLabel)
                  Text(
                    message.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AttachmentActionButton(message: message, compact: true),
        ],
      ),
    );
  }
}

class _MediaLoadingBox extends StatelessWidget {
  final double width;
  final double height;

  const _MediaLoadingBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _AttachmentActionButton extends StatelessWidget {
  final ChatMessageModel message;
  final bool compact;

  const _AttachmentActionButton({required this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final hasUrl = message.absoluteAttachmentUrl?.isNotEmpty == true;
    final icon = compact ? Icons.file_open_rounded : Icons.download_rounded;

    return Tooltip(
      message: hasUrl ? 'Copier le lien' : 'Pièce jointe indisponible',
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        onPressed: hasUrl ? () => _copyAttachmentLink(context, message) : null,
        icon: Icon(icon, size: compact ? 18 : 20),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final List<String> names;

  const _TypingIndicator({required this.names});

  @override
  Widget build(BuildContext context) {
    final label = names.length == 1
        ? '${names.first} est en train d’écrire...'
        : 'Plusieurs personnes écrivent...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final ChatMessageModel? replyingTo;
  final VoidCallback onClearReply;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.replyingTo,
    required this.onClearReply,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          if (replyingTo != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.enactusYellow.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _messagePreview(replyingTo!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onClearReply,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ],
          if (sending) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Envoi en cours...',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Joindre',
                onPressed: sending ? null : onAttach,
                icon: const Icon(Icons.attach_file_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un message...',
                    prefixIcon: Icon(Icons.message_rounded),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationInfoDialog extends StatelessWidget {
  final ChatThreadModel thread;
  final ChatService chatService;
  final String? currentUserId;
  final bool pinned;
  final Future<void> Function() onChanged;
  final Future<void> Function() onTogglePin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onHideForMe;
  final Future<void> Function()? onAddMember;
  final Future<void> Function()? onDelete;

  const _ConversationInfoDialog({
    required this.thread,
    required this.chatService,
    required this.currentUserId,
    required this.pinned,
    required this.onChanged,
    required this.onTogglePin,
    required this.onLeave,
    required this.onHideForMe,
    required this.onAddMember,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = _threadDisplayTitle(thread, currentUserId);
    final directParticipant = _directParticipant(thread, currentUserId);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Infos'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(280.0, 520.0)
            .toDouble(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChatAvatar(
                title: title,
                imageUrl: _threadAvatarUrl(thread, currentUserId),
                selected: true,
                icon: thread.threadType == 'direct'
                    ? Icons.person_rounded
                    : Icons.groups_rounded,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _threadSubtitle(thread, currentUserId),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              _ConversationInfoGrid(
                children: [
                  _ConversationInfoTile(
                    icon: thread.threadType == 'direct'
                        ? Icons.lock_person_rounded
                        : Icons.groups_2_rounded,
                    label: 'Type',
                    value: _conversationTypeLabel(thread),
                  ),
                  if (directParticipant != null) ...[
                    _ConversationInfoTile(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: directParticipant.email.isEmpty
                          ? 'Non renseigné'
                          : directParticipant.email,
                    ),
                    _ConversationInfoTile(
                      icon: Icons.verified_user_rounded,
                      label: 'Statut',
                      value: _memberStatusLabel(directParticipant.status),
                    ),
                    _ConversationInfoTile(
                      icon: Icons.badge_rounded,
                      label: 'Rôle',
                      value: _participantRoleLabel(
                        directParticipant.participantRole,
                      ),
                    ),
                  ] else ...[
                    _ConversationInfoTile(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Admins',
                      value:
                          '${thread.participantsPreview.where((participant) => participant.participantRole == 'owner' || participant.participantRole == 'admin').length}',
                    ),
                    _ConversationInfoTile(
                      icon: Icons.hub_rounded,
                      label: 'Portée',
                      value: _conversationScopeLabel(thread),
                    ),
                    _ConversationInfoTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Votre rôle',
                      value: _participantRoleLabel(thread.currentUserRole),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _ConversationActionButton(
                    onPressed: onTogglePin,
                    icon: pinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    label: pinned ? 'Désépingler' : 'Épingler',
                  ),
                  if (onAddMember != null)
                    _ConversationActionButton(
                      onPressed: onAddMember,
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Ajouter',
                    ),
                  if (thread.threadType != 'direct')
                    _ConversationActionButton(
                      onPressed: onLeave,
                      icon: Icons.logout_rounded,
                      label: 'Quitter',
                    ),
                  _ConversationActionButton(
                    onPressed: onHideForMe,
                    icon: Icons.delete_sweep_rounded,
                    label: 'Supprimer pour moi',
                  ),
                  if (onDelete != null) ...[
                    _ConversationActionButton(
                      onPressed: onDelete,
                      icon: Icons.delete_outline_rounded,
                      label: 'Supprimer pour tous',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${thread.participantsCount} participant(s)',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),
              ...thread.participantsPreview.map((participant) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _ChatAvatar(
                    title: participant.displayName,
                    imageUrl: _absoluteUrl(participant.photoUrl),
                    selected: false,
                    icon: Icons.person_rounded,
                  ),
                  title: Text(participant.displayName),
                  subtitle: Text(
                    _participantSubtitle(participant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _ParticipantManagementMenu(
                    thread: thread,
                    participant: participant,
                    currentUserId: currentUserId,
                    chatService: chatService,
                    onChanged: onChanged,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _ConversationInfoGrid extends StatelessWidget {
  final List<Widget> children;

  const _ConversationInfoGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 430
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _ConversationInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConversationInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.softBlack),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const _ConversationActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _ParticipantManagementMenu extends StatelessWidget {
  final ChatThreadModel thread;
  final ChatThreadMemberModel participant;
  final String? currentUserId;
  final ChatService chatService;
  final Future<void> Function() onChanged;

  const _ParticipantManagementMenu({
    required this.thread,
    required this.participant,
    required this.currentUserId,
    required this.chatService,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final role = participant.participantRole;
    final canManage =
        thread.canManageMembers &&
        thread.threadType != 'direct' &&
        participant.userId != currentUserId &&
        role != 'owner';

    if (!canManage) {
      return role == 'member'
          ? const SizedBox.shrink()
          : Chip(label: Text(role));
    }

    return PopupMenuButton<String>(
      tooltip: 'Gérer ce membre',
      onSelected: (value) async {
        try {
          if (value == 'admin' || value == 'member') {
            await chatService.updateParticipantRole(
              threadId: thread.id,
              userId: participant.userId,
              participantRole: value,
            );
          }
          if (value == 'remove') {
            await chatService.removeParticipant(
              threadId: thread.id,
              userId: participant.userId,
            );
          }
          await onChanged();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conversation mise à jour.')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red.shade700,
                content: Text(e.toString().replaceAll('Exception: ', '')),
              ),
            );
          }
        }
      },
      itemBuilder: (context) => [
        if (role != 'admin')
          const PopupMenuItem(
            value: 'admin',
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_rounded),
              title: Text('Promouvoir admin'),
            ),
          ),
        if (role == 'admin')
          const PopupMenuItem(
            value: 'member',
            child: ListTile(
              leading: Icon(Icons.person_rounded),
              title: Text('Retirer admin'),
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: Icon(Icons.person_remove_alt_1_rounded),
            title: Text('Retirer du groupe'),
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role != 'member') Chip(label: Text(role)),
          const Icon(Icons.more_vert_rounded),
        ],
      ),
    );
  }
}

class _AddChatMembersDialog extends StatefulWidget {
  final ChatService chatService;
  final Set<String> existingUserIds;

  const _AddChatMembersDialog({
    required this.chatService,
    required this.existingUserIds,
  });

  @override
  State<_AddChatMembersDialog> createState() => _AddChatMembersDialogState();
}

class _AddChatMembersDialogState extends State<_AddChatMembersDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _loading = true;
  String? _error;
  List<ChatContactModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final contacts = await widget.chatService.getContacts(
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts
            .where((contact) => !widget.existingUserIds.contains(contact.id))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Ajouter des membres'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(280.0, 520.0)
            .toDouble(),
        height: (MediaQuery.sizeOf(context).height * 0.58)
            .clamp(320.0, 560.0)
            .toDouble(),
        child: Column(
          children: [
            if (_error != null) _DialogError(message: _error!),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher une personne',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _loadContacts,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => _loadContacts(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                  ? const Center(child: Text('Aucun membre à ajouter.'))
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        final selected = _selectedIds.contains(contact.id);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(contact.id);
                              } else {
                                _selectedIds.remove(contact.id);
                              }
                            });
                          },
                          title: Text(contact.displayName),
                          subtitle: Text(contact.email),
                          secondary: _ChatAvatar(
                            title: contact.displayName,
                            imageUrl: _absoluteUrl(contact.photoUrl),
                            selected: selected,
                            icon: Icons.person_rounded,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _OutgoingAttachment {
  final String messageType;
  final String? fileId;
  final String url;
  final String name;
  final String caption;
  final String? mimeType;
  final int? sizeBytes;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final String? stickerPack;

  const _OutgoingAttachment({
    required this.messageType,
    required this.fileId,
    required this.url,
    required this.name,
    required this.caption,
    required this.mimeType,
    required this.sizeBytes,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.stickerPack,
  });
}

class _PickedFilePreview extends StatelessWidget {
  final String fileName;
  final int? sizeBytes;

  const _PickedFilePreview({required this.fileName, required this.sizeBytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.enactusYellow),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.softBlack,
            foregroundColor: Colors.white,
            child: Icon(Icons.attach_file_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (sizeBytes != null)
                  Text(
                    _formatBytes(sizeBytes!),
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.56),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentMessageDialog extends StatefulWidget {
  final ChatService chatService;
  final String threadId;

  const _AttachmentMessageDialog({
    required this.chatService,
    required this.threadId,
  });

  @override
  State<_AttachmentMessageDialog> createState() =>
      _AttachmentMessageDialogState();
}

class _AttachmentMessageDialogState extends State<_AttachmentMessageDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _mimeController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _thumbnailController = TextEditingController();
  final TextEditingController _stickerPackController = TextEditingController();
  final TextEditingController _dataBase64Controller = TextEditingController();

  String _messageType = 'image';
  bool _uploading = false;
  bool _picking = false;
  bool _showAdvanced = false;
  String? _pickedFileName;
  int? _pickedFileSize;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _captionController.dispose();
    _mimeController.dispose();
    _sizeController.dispose();
    _durationController.dispose();
    _thumbnailController.dispose();
    _stickerPackController.dispose();
    _dataBase64Controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _picking = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = 'Impossible de lire ce fichier sur ce support.';
        });
        return;
      }

      final inferredType = _inferMessageTypeFromFileName(file.name);
      final inferredMime = _inferMimeTypeFromFileName(file.name);

      setState(() {
        _messageType = inferredType;
        _pickedFileName = file.name;
        _pickedFileSize = file.size;
        _nameController.text = file.name;
        _mimeController.text = inferredMime ?? '';
        _sizeController.text = file.size.toString();
        _dataBase64Controller.text = base64Encode(bytes);
        _urlController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    final dataBase64 = _dataBase64Controller.text.trim();
    final name = _nameController.text.trim().isEmpty
        ? _messageTypeLabel(_messageType)
        : _nameController.text.trim();

    if (url.isEmpty && dataBase64.isEmpty) {
      setState(() {
        _error = 'Choisis un fichier à envoyer.';
      });
      return;
    }

    if (dataBase64.isNotEmpty && _nameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Donne un nom au fichier à uploader.';
      });
      return;
    }

    var finalUrl = url;
    String? finalFileId;
    var finalSizeBytes = int.tryParse(_sizeController.text.trim());
    var finalMimeType = _optional(_mimeController.text);

    if (dataBase64.isNotEmpty) {
      setState(() {
        _uploading = true;
        _error = null;
      });

      try {
        final upload = await widget.chatService.uploadMediaBase64(
          fileName: name,
          dataBase64: dataBase64,
          messageType: _messageType,
          threadId: widget.threadId,
          contentType: finalMimeType,
        );
        finalFileId = upload.fileId;
        finalUrl = upload.url;
        finalSizeBytes = upload.sizeBytes;
        finalMimeType = upload.contentType;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _uploading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      _OutgoingAttachment(
        messageType: _messageType,
        fileId: finalFileId,
        url: finalUrl,
        name: name,
        caption: _captionController.text.trim(),
        mimeType: finalMimeType,
        sizeBytes: finalSizeBytes,
        durationSeconds: int.tryParse(_durationController.text.trim()),
        thumbnailUrl: _optional(_thumbnailController.text),
        stickerPack: _optional(_stickerPackController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDuration =
        _showAdvanced && (_messageType == 'audio' || _messageType == 'video');
    final showThumbnail = _showAdvanced && _messageType == 'video';
    final showStickerPack = _showAdvanced && _messageType == 'sticker';

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Envoyer un média'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(280.0, 520.0)
            .toDouble(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) _DialogError(message: _error!),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.enactusYellow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.enactusYellow.withValues(alpha: 0.32),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_file_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Choisis ton fichier, ajoute une légende si besoin, puis envoie. Le type et l’upload sont gérés automatiquement.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _picking || _uploading ? null : _pickFile,
                icon: _picking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open_rounded),
                label: Text(_picking ? 'Ouverture...' : 'Choisir un fichier'),
              ),
              if (_pickedFileName != null) ...[
                const SizedBox(height: 10),
                _PickedFilePreview(
                  fileName: _pickedFileName!,
                  sizeBytes: _pickedFileSize,
                ),
              ],
              const SizedBox(height: 12),
              if (_showAdvanced) ...[
                DropdownButtonFormField<String>(
                  initialValue: _messageType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nature du média',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'image', child: Text('Photo')),
                    DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                    DropdownMenuItem(value: 'audio', child: Text('Audio')),
                    DropdownMenuItem(
                      value: 'document',
                      child: Text('Document'),
                    ),
                    DropdownMenuItem(value: 'sticker', child: Text('Sticker')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _messageType = value;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              if (_showAdvanced)
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Lien du fichier existant',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
              const SizedBox(height: 12),
              if (_showAdvanced)
                TextField(
                  controller: _dataBase64Controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Données base64 à uploader',
                    prefixIcon: Icon(Icons.cloud_upload_rounded),
                  ),
                ),
              const SizedBox(height: 12),
              if (_showAdvanced)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom affiché',
                    prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Légende optionnelle',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (_showAdvanced)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAdvanced = !_showAdvanced;
                      });
                    },
                    icon: Icon(
                      _showAdvanced
                          ? Icons.expand_less_rounded
                          : Icons.tune_rounded,
                    ),
                    label: Text(
                      _showAdvanced
                          ? 'Masquer les options'
                          : 'Options avancées',
                    ),
                  ),
                ),
              if (_showAdvanced) const SizedBox(height: 8),
              if (_showAdvanced)
                TextField(
                  controller: _mimeController,
                  decoration: const InputDecoration(
                    labelText: 'Type MIME optionnel',
                    prefixIcon: Icon(Icons.code_rounded),
                  ),
                ),
              const SizedBox(height: 12),
              if (_showAdvanced)
                TextField(
                  controller: _sizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Taille en octets optionnelle',
                    prefixIcon: Icon(Icons.storage_rounded),
                  ),
                ),
              if (showDuration) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée en secondes',
                    prefixIcon: Icon(Icons.timer_rounded),
                  ),
                ),
              ],
              if (showThumbnail) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _thumbnailController,
                  decoration: const InputDecoration(
                    labelText: 'Miniature optionnelle',
                    prefixIcon: Icon(Icons.image_rounded),
                  ),
                ),
              ],
              if (showStickerPack) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _stickerPackController,
                  decoration: const InputDecoration(
                    labelText: 'Pack sticker optionnel',
                    prefixIcon: Icon(Icons.emoji_emotions_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _submit,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_uploading ? 'Upload...' : 'Envoyer'),
        ),
      ],
    );
  }
}

class NewChatThreadDialog extends StatefulWidget {
  final ChatService chatService;
  final PolesService polesService;
  final ProjectsService projectsService;

  const NewChatThreadDialog({
    super.key,
    required this.chatService,
    required this.polesService,
    required this.projectsService,
  });

  @override
  State<NewChatThreadDialog> createState() => _NewChatThreadDialogState();
}

class _NewChatThreadDialogState extends State<NewChatThreadDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _creating = false;
  String? _error;
  String _threadType = 'direct';
  String? _scopeId;
  List<ChatContactModel> _contacts = [];
  List<PoleModel> _poles = [];
  List<ProjectModel> _projects = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.chatService.getContacts(search: _searchController.text),
        widget.polesService.getPoles(),
        widget.projectsService.getProjects(),
      ]);
      if (!mounted) return;
      setState(() {
        _contacts = results[0] as List<ChatContactModel>;
        _poles = results[1] as List<PoleModel>;
        _projects = results[2] as List<ProjectModel>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    if (_threadType == 'direct' && _selectedIds.length != 1) {
      setState(() {
        _error = 'Choisis une seule personne pour un chat privé.';
      });
      return;
    }

    if (_threadType != 'direct' && _titleController.text.trim().isEmpty) {
      setState(() {
        _error = 'Donne un nom à cette conversation.';
      });
      return;
    }

    if ((_threadType == 'pole' || _threadType == 'project') &&
        _scopeId == null) {
      setState(() {
        _error = 'Choisis le périmètre de la conversation.';
      });
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final thread = await widget.chatService.createThread(
        title: _threadType == 'direct' ? null : _titleController.text,
        threadType: _threadType,
        scopeType:
            _threadType == 'pole' ||
                _threadType == 'project' ||
                _threadType == 'enacchef'
            ? _threadType
            : null,
        scopeId: _scopeId,
        participantIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(thread);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Nouvelle conversation'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 32)
            .clamp(280.0, 560.0)
            .toDouble(),
        height: (MediaQuery.sizeOf(context).height * 0.66)
            .clamp(360.0, 620.0)
            .toDouble(),
        child: Column(
          children: [
            if (_error != null) _DialogError(message: _error!),
            if (_threadType != 'direct') ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la conversation',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _threadType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type de chat',
                prefixIcon: Icon(Icons.forum_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'direct', child: Text('Privé')),
                DropdownMenuItem(value: 'group', child: Text('Groupe libre')),
                DropdownMenuItem(value: 'pole', child: Text('Chat de pôle')),
                DropdownMenuItem(
                  value: 'project',
                  child: Text('Chat de projet'),
                ),
                DropdownMenuItem(value: 'enacchef', child: Text('Enacchef')),
              ],
              onChanged: _creating
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _threadType = value;
                        _scopeId = null;
                        if (value == 'direct') {
                          _titleController.clear();
                        }
                        if (value == 'direct' && _selectedIds.length > 1) {
                          final first = _selectedIds.first;
                          _selectedIds
                            ..clear()
                            ..add(first);
                        }
                      });
                    },
            ),
            if (_threadType == 'pole') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _scopeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pôle',
                  prefixIcon: Icon(Icons.hub_rounded),
                ),
                items: _poles.map((pole) {
                  return DropdownMenuItem(
                    value: pole.id,
                    child: Text(pole.name),
                  );
                }).toList(),
                onChanged: _creating
                    ? null
                    : (value) => setState(() => _scopeId = value),
              ),
            ],
            if (_threadType == 'project') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _scopeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Projet',
                  prefixIcon: Icon(Icons.rocket_launch_rounded),
                ),
                items: _projects.map((project) {
                  return DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  );
                }).toList(),
                onChanged: _creating
                    ? null
                    : (value) => setState(() => _scopeId = value),
              ),
            ],
            if (_threadType == 'pole' ||
                _threadType == 'project' ||
                _threadType == 'enacchef') ...[
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Les membres du périmètre seront ajoutés automatiquement. Tu peux ajouter d’autres participants si besoin.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: _threadType == 'direct'
                    ? 'Rechercher une personne'
                    : 'Ajouter des membres',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _loadContacts,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => _loadContacts(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        final selected = _selectedIds.contains(contact.id);

                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                if (_threadType == 'direct') {
                                  _selectedIds.clear();
                                }
                                _selectedIds.add(contact.id);
                              } else {
                                _selectedIds.remove(contact.id);
                              }
                            });
                          },
                          title: Text(contact.displayName),
                          subtitle: Text(contact.email),
                          secondary: _ChatAvatar(
                            title: contact.displayName,
                            imageUrl: _absoluteUrl(contact.photoUrl),
                            selected: selected,
                            icon: Icons.person_rounded,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _creating ? null : _create,
          icon: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_creating ? 'Création...' : 'Créer'),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(42),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyThreads extends StatelessWidget {
  const _EmptyThreads();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aucune conversation. Crée un premier échange.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aucune discussion trouvée.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Choisis une conversation pour commencer.',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

class _DialogError extends StatelessWidget {
  final String message;

  const _DialogError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
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

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _threadDisplayTitle(ChatThreadModel thread, String? currentUserId) {
  final directParticipant = _directParticipant(thread, currentUserId);
  if (directParticipant != null) return directParticipant.displayName;
  return thread.displayTitle;
}

String? _threadAvatarUrl(ChatThreadModel thread, String? currentUserId) {
  final directParticipant = _directParticipant(thread, currentUserId);
  if (directParticipant != null) {
    return _absoluteUrl(directParticipant.photoUrl);
  }
  return thread.absoluteAvatarUrl;
}

String _threadSearchText(ChatThreadModel thread, String? currentUserId) {
  final participants = thread.participantsPreview
      .expand(
        (participant) => [
          participant.displayName,
          participant.email,
          participant.status,
          participant.participantRole,
        ],
      )
      .join(' ');

  return [
    _threadDisplayTitle(thread, currentUserId),
    _threadSubtitle(thread, currentUserId),
    thread.lastMessage ?? '',
    thread.threadType,
    thread.scopeType ?? '',
    participants,
  ].join(' ').toLowerCase();
}

ChatThreadMemberModel? _directParticipant(
  ChatThreadModel thread,
  String? currentUserId,
) {
  if (thread.threadType != 'direct') return null;
  if (thread.participantsPreview.isEmpty) return null;
  if (currentUserId == null || currentUserId.trim().isEmpty) {
    return thread.participantsPreview.length == 1
        ? thread.participantsPreview.first
        : null;
  }

  final others = thread.participantsPreview.where((participant) {
    return participant.userId.isNotEmpty && participant.userId != currentUserId;
  });

  return others.firstOrNull ?? thread.participantsPreview.first;
}

bool _isDirectThreadOnline(
  ChatThreadModel thread,
  String? currentUserId,
  Set<String> onlineUserIds,
) {
  final participant = _directParticipant(thread, currentUserId);
  return participant != null && onlineUserIds.contains(participant.userId);
}

String _threadSubtitle(ChatThreadModel thread, String? currentUserId) {
  final directParticipant = _directParticipant(thread, currentUserId);
  if (directParticipant != null) {
    final email = directParticipant.email.trim();
    final status = directParticipant.status.trim();
    if (email.isNotEmpty && status.isNotEmpty) return '$email · $status';
    if (email.isNotEmpty) return email;
    return 'Discussion privée';
  }

  final names = thread.participantsPreview
      .map((participant) => participant.displayName)
      .where((name) => name.trim().isNotEmpty)
      .take(3)
      .join(', ');

  if (names.isNotEmpty) {
    final suffix = thread.participantsCount > 3
        ? ' +${thread.participantsCount - 3}'
        : '';
    return '$names$suffix';
  }

  return '${thread.participantsCount} participant(s)';
}

String _threadTimeLabel(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  final difference = today.difference(messageDay).inDays;

  if (difference == 0) return DateFormat('HH:mm').format(local);
  if (difference == 1) return 'Hier';
  if (difference < 7) return DateFormat('EEE', 'fr').format(local);
  return DateFormat('dd/MM/yy').format(local);
}

String _conversationTypeLabel(ChatThreadModel thread) {
  switch (thread.threadType) {
    case 'direct':
      return 'Discussion privée';
    case 'club':
      return 'Canal club';
    case 'pole':
      return 'Discussion de pôle';
    case 'project':
      return 'Discussion de projet';
    default:
      return 'Groupe';
  }
}

String _conversationScopeLabel(ChatThreadModel thread) {
  final scope = thread.scopeType?.trim();
  if (scope == null || scope.isEmpty) return 'Toute la communauté';

  switch (scope) {
    case 'pole':
      return 'Pôle';
    case 'project':
      return 'Projet';
    case 'enacchefs':
      return 'Enacchefs';
    case 'club':
      return 'Club';
    default:
      return scope;
  }
}

String _participantRoleLabel(String role) {
  switch (role.trim().toLowerCase()) {
    case 'owner':
      return 'Propriétaire';
    case 'admin':
      return 'Administrateur';
    case 'member':
      return 'Membre';
    default:
      return role.trim().isEmpty ? 'Membre' : role;
  }
}

String _memberStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'active':
      return 'Actif';
    case 'pending':
      return 'En attente';
    case 'inactive':
      return 'Inactif';
    case 'alumni':
      return 'Alumni';
    default:
      return status.trim().isEmpty ? 'Non renseigné' : status;
  }
}

String _participantSubtitle(ChatThreadMemberModel participant) {
  final details = <String>[
    if (participant.email.trim().isNotEmpty) participant.email.trim(),
    _memberStatusLabel(participant.status),
    _participantRoleLabel(participant.participantRole),
  ];

  return details.join(' · ');
}

String _messagePreview(ChatMessageModel message) {
  final value = message.isMedia ? message.attachmentLabel : message.content;
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 70) return normalized;
  return '${normalized.substring(0, 70)}...';
}

String? _messageReactionLabel(
  ChatMessageModel message,
  String? localReaction,
  bool removedServerReaction,
) {
  final summary = Map<String, int>.from(message.reactionsSummary);
  final serverReaction = message.currentUserReaction?.trim();

  if (removedServerReaction &&
      serverReaction != null &&
      serverReaction.isNotEmpty &&
      summary.containsKey(serverReaction)) {
    summary[serverReaction] = summary[serverReaction]! - 1;
  }

  final reaction = localReaction?.trim();
  if (reaction != null && reaction.isNotEmpty) {
    summary[reaction] = summary.containsKey(reaction) ? summary[reaction]! : 1;
  }

  final visible = summary.entries
      .where((entry) => entry.value > 0)
      .take(3)
      .map(
        (entry) => entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
      )
      .join('  ');

  return visible.isEmpty ? null : visible;
}

bool _messageReadByOthers({
  required ChatThreadModel thread,
  required ChatMessageModel message,
  required String? currentUserId,
}) {
  if (currentUserId == null || message.authorId != currentUserId) return false;

  return thread.participantsPreview.any((participant) {
    if (participant.userId == currentUserId) return false;
    final lastReadAt = participant.lastReadAt;
    if (lastReadAt == null) return false;
    return !lastReadAt.isBefore(message.createdAt);
  });
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _absoluteUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${ApiClient.serverUrl}$url';
}

String _messageTypeLabel(String type) {
  switch (type) {
    case 'image':
      return 'Photo';
    case 'video':
      return 'Vidéo';
    case 'audio':
      return 'Audio';
    case 'document':
      return 'Document';
    case 'sticker':
      return 'Sticker';
    default:
      return 'Média';
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 100 ? 1 : 0)} Ko';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 100 ? 1 : 0)} Mo';
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes <= 0) return '${remainingSeconds}s';
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

void _copyAttachmentLink(BuildContext context, ChatMessageModel message) {
  final url = message.absoluteAttachmentUrl;
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pièce jointe indisponible.')));
    return;
  }

  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Lien de la pièce jointe copié.')),
  );
}

String _inferMessageTypeFromFileName(String fileName) {
  final extension = _fileExtension(fileName);

  if (['webp', 'gif'].contains(extension) &&
      fileName.toLowerCase().contains('sticker')) {
    return 'sticker';
  }

  if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
    return 'image';
  }

  if (['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'].contains(extension)) {
    return 'video';
  }

  if (['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'weba'].contains(extension)) {
    return 'audio';
  }

  return 'document';
}

String? _inferMimeTypeFromFileName(String fileName) {
  switch (_fileExtension(fileName)) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
    case 'opus':
      return 'audio/ogg';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    default:
      return null;
  }
}

String _fileExtension(String fileName) {
  final parts = fileName.toLowerCase().split('.');
  return parts.length > 1 ? parts.last : '';
}
