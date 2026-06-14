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
                Text(message.content, style: const TextStyle(height: 1.35)),
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

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
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
