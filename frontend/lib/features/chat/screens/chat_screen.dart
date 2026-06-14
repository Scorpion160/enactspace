import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../../core/theme/app_theme.dart';
import '../../poles/models/pole_model.dart';
import '../../poles/services/poles_service.dart';
import '../../projects/models/project_model.dart';
import '../../projects/services/projects_service.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final PolesService _polesService = PolesService();
  final ProjectsService _projectsService = ProjectsService();
  final TextEditingController _messageController = TextEditingController();

  bool _loading = true;
  bool _messagesLoading = false;
  bool _sending = false;
  bool _usingLocalCache = false;
  String? _error;
  UserExperience? _user;
  List<ChatThreadModel> _threads = [];
  List<ChatMessageModel> _messages = [];
  ChatThreadModel? _selectedThread;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = UserExperience.fromJson(await _authService.getCurrentUser());
      final cachedThreads = await _chatService.getCachedThreads(
        userId: user.id,
      );

      if (mounted && cachedThreads.isNotEmpty) {
        setState(() {
          _user = user;
          _threads = cachedThreads;
          _selectedThread = cachedThreads.first;
          _usingLocalCache = true;
          _loading = false;
        });

        await _loadCachedMessages(cachedThreads.first);
      }

      final threads = await _chatService.getThreads();
      await _chatService.cacheThreads(userId: user.id, threads: threads);

      if (!mounted) return;

      setState(() {
        _user = user;
        _threads = threads;
        _selectedThread = threads.isNotEmpty ? threads.first : null;
        _usingLocalCache = false;
      });

      if (threads.isNotEmpty) {
        await _selectThread(threads.first, silent: true);
      }
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

  Future<void> _loadCachedMessages(ChatThreadModel thread) async {
    final userId = _user?.id;
    if (userId == null) return;

    final cached = await _chatService.getCachedMessages(
      userId: userId,
      threadId: thread.id,
    );

    if (!mounted || cached.isEmpty) return;

    setState(() {
      _messages = cached;
    });
  }

  Future<void> _selectThread(
    ChatThreadModel thread, {
    bool silent = false,
  }) async {
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

    try {
      final userId = _user?.id;
      if (userId != null) {
        final cached = await _chatService.getCachedMessages(
          userId: userId,
          threadId: thread.id,
        );
        if (mounted && cached.isNotEmpty) {
          setState(() {
            _messages = cached;
            _usingLocalCache = true;
          });
          displayedCachedMessages = true;
        }
      }

      final messages = await _chatService.getMessages(thread.id);
      if (!mounted) return;
      setState(() {
        _selectedThread = thread;
        _messages = messages;
        _usingLocalCache = false;
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

    if (thread == null || content.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final message = await _chatService.sendMessage(
        threadId: thread.id,
        content: content,
      );
      _messageController.clear();

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
      });
      if (_user != null) {
        await _chatService.cacheMessages(
          userId: _user!.id,
          threadId: thread.id,
          messages: _messages,
        );
      }
      await _refreshThreads();
    } catch (e) {
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

    setState(() {
      _sending = true;
    });

    try {
      final message = await _chatService.sendMessage(
        threadId: thread.id,
        content: attachment.caption,
        messageType: attachment.messageType,
        attachmentUrl: attachment.url,
        attachmentName: attachment.name,
        attachmentMimeType: attachment.mimeType,
        attachmentSizeBytes: attachment.sizeBytes,
        durationSeconds: attachment.durationSeconds,
        thumbnailUrl: attachment.thumbnailUrl,
        stickerPack: attachment.stickerPack,
      );

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
      });
      if (_user != null) {
        await _chatService.cacheMessages(
          userId: _user!.id,
          threadId: thread.id,
          messages: _messages,
        );
      }
      await _refreshThreads();
    } catch (e) {
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
      builder: (context) => _AttachmentMessageDialog(chatService: _chatService),
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
      _threads = threads;
      if (_selectedThread != null) {
        _selectedThread = threads
            .where((thread) => thread.id == _selectedThread!.id)
            .firstOrNull;
      }
    });
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
    return RefreshIndicator(
      onRefresh: _loadChat,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 560 ? 12.0 : 24.0;
          final isWide = constraints.maxWidth >= 920;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              28,
            ),
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
                      else if (isWide)
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
                                  onSelect: _selectThread,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _conversationPanel()),
                            ],
                          ),
                        )
                      else
                        _selectedThread == null
                            ? SizedBox(
                                height: MediaQuery.sizeOf(context).height - 170,
                                child: _ThreadsPanel(
                                  threads: _threads,
                                  selectedThread: _selectedThread,
                                  onSelect: _selectThread,
                                ),
                              )
                            : SizedBox(
                                height: MediaQuery.sizeOf(context).height - 170,
                                child: _conversationPanel(showBack: true),
                              ),
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

  Widget _conversationPanel({bool showBack = false}) {
    return Card(
      child: Column(
        children: [
          _ConversationHeader(
            thread: _selectedThread,
            showBack: showBack,
            onBack: () => setState(() => _selectedThread = null),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messagesLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedThread == null
                ? const _EmptyConversation()
                : _MessagesList(messages: _messages, currentUserId: _user?.id),
          ),
          if (_selectedThread != null)
            _MessageComposer(
              controller: _messageController,
              sending: _sending,
              onSend: _sendMessage,
              onAttach: _openAttachmentDialog,
            ),
        ],
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

class _ThreadsPanel extends StatelessWidget {
  final List<ChatThreadModel> threads;
  final ChatThreadModel? selectedThread;
  final ValueChanged<ChatThreadModel> onSelect;

  const _ThreadsPanel({
    required this.threads,
    required this.selectedThread,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.forum_rounded),
              title: Text(
                'Conversations',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: threads.isEmpty
                  ? const _EmptyThreads()
                  : ListView.builder(
                      itemCount: threads.length,
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        final selected = thread.id == selectedThread?.id;

                        return _ThreadTile(
                          thread: thread,
                          selected: selected,
                          onTap: () => onSelect(thread),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThreadModel thread;
  final bool selected;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.thread,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.enactusYellow.withValues(alpha: 0.24)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: selected ? AppTheme.enactusYellow : Colors.black12,
          foregroundColor: AppTheme.softBlack,
          child: Icon(
            thread.threadType == 'direct' ? Icons.person : Icons.groups,
          ),
        ),
        title: Text(
          thread.displayTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          thread.lastMessage ?? '${thread.participantsCount} participant(s)',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: thread.unreadCount > 0
            ? Badge(
                label: Text(
                  thread.unreadCount > 99 ? '99+' : '${thread.unreadCount}',
                ),
                backgroundColor: AppTheme.enactusYellow,
                textColor: AppTheme.softBlack,
              )
            : null,
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  final ChatThreadModel? thread;
  final bool showBack;
  final VoidCallback onBack;

  const _ConversationHeader({
    required this.thread,
    required this.showBack,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: showBack
          ? IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : const CircleAvatar(
              backgroundColor: AppTheme.enactusYellow,
              foregroundColor: AppTheme.softBlack,
              child: Icon(Icons.chat_bubble_rounded),
            ),
      title: Text(
        thread?.displayTitle ?? 'Sélectionne une conversation',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: thread == null
          ? const Text('Tes messages apparaîtront ici.')
          : Text('${thread!.participantsCount} participant(s)'),
    );
  }
}

class _MessagesList extends StatelessWidget {
  final List<ChatMessageModel> messages;
  final String? currentUserId;

  const _MessagesList({required this.messages, required this.currentUserId});

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

        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessageBody(message: message),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              message.absoluteAttachmentUrl ?? '',
              width: message.messageType == 'sticker' ? 150 : 260,
              height: message.messageType == 'sticker' ? 150 : 170,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _MediaFallback(message: message);
              },
            ),
          ),
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

  const _MediaFallback({required this.message});

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

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
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
                  message.attachmentLabel,
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
                if (message.durationSeconds != null)
                  Text('${message.durationSeconds}s'),
                if (message.attachmentUrl != null)
                  Text(
                    message.attachmentUrl!,
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
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _MessageComposer({
    required this.controller,
    required this.sending,
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
      child: Row(
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
    );
  }
}

class _OutgoingAttachment {
  final String messageType;
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

  const _AttachmentMessageDialog({required this.chatService});

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
        _error = 'Ajoute un lien ou des données base64 du fichier.';
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
          contentType: finalMimeType,
        );
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
    final showDuration = _messageType == 'audio' || _messageType == 'video';
    final showThumbnail = _messageType == 'video';
    final showStickerPack = _messageType == 'sticker';

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
              DropdownButtonFormField<String>(
                initialValue: _messageType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'image', child: Text('Photo')),
                  DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                  DropdownMenuItem(value: 'audio', child: Text('Audio')),
                  DropdownMenuItem(value: 'document', child: Text('Document')),
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
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Lien du fichier existant',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
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
              TextField(
                controller: _mimeController,
                decoration: const InputDecoration(
                  labelText: 'Type MIME optionnel',
                  prefixIcon: Icon(Icons.code_rounded),
                ),
              ),
              const SizedBox(height: 12),
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
        title: _titleController.text,
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
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre optionnel',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
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
                labelText: 'Rechercher un contact',
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
                          secondary: CircleAvatar(
                            backgroundColor: AppTheme.enactusYellow,
                            foregroundColor: AppTheme.softBlack,
                            child: Text(_initials(contact.displayName)),
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

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
