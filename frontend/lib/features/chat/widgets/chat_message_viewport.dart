import 'package:flutter/material.dart';

/// Keeps the newest messages at offset zero without interrupting a reader
/// exploring older parts of a conversation.
class ChatMessageViewport extends StatefulWidget {
  final String conversationId;
  final List<String> messageIds;
  final Set<String> authoredMessageIds;
  final IndexedWidgetBuilder messageBuilder;
  final Widget? emptyBuilder;

  const ChatMessageViewport({
    super.key,
    required this.conversationId,
    required this.messageIds,
    required this.authoredMessageIds,
    required this.messageBuilder,
    this.emptyBuilder,
  });

  @override
  State<ChatMessageViewport> createState() => _ChatMessageViewportState();
}

class _ChatMessageViewportState extends State<ChatMessageViewport> {
  static const double _nearLatestDistance = 96;
  static const double _showJumpDistance = 210;
  final ScrollController _controller = ScrollController();
  bool _showJumpButton = false;
  int _unseenIncoming = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  bool get _nearLatest =>
      !_controller.hasClients ||
      _controller.position.pixels <= _nearLatestDistance;

  void _onScroll() {
    if (!_controller.hasClients) return;
    final away = _controller.position.pixels > _showJumpDistance;
    final arrived = _nearLatest;
    if (away != _showJumpButton || (arrived && _unseenIncoming != 0)) {
      setState(() {
        _showJumpButton = away;
        if (arrived) _unseenIncoming = 0;
      });
    }
  }

  void _toLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (animate) {
        _controller.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _controller.jumpTo(0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatMessageViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _unseenIncoming = 0;
      _showJumpButton = false;
      _toLatest(animate: false);
      return;
    }

    final existing = oldWidget.messageIds.toSet();
    final newIds = widget.messageIds.where((id) => !existing.contains(id)).toList();
    if (newIds.isEmpty) return; // Edits, status updates, read receipts.

    final ownMessage = newIds.any(widget.authoredMessageIds.contains);
    if (ownMessage || _nearLatest) {
      _unseenIncoming = 0;
      _toLatest();
    } else {
      final incoming = newIds.where((id) => !widget.authoredMessageIds.contains(id)).length;
      if (incoming > 0) {
        // didUpdateWidget is immediately followed by build; calling setState
        // here would schedule a redundant rebuild during the parent's build.
        _unseenIncoming += incoming;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messageIds.isEmpty) {
      return widget.emptyBuilder ??
          const Center(child: Text('Aucun message. Lance la discussion.'));
    }
    final positions = <String, int>{
      for (var i = 0; i < widget.messageIds.length; i++)
        widget.messageIds[i]: widget.messageIds.length - 1 - i,
    };
    return Stack(
      children: [
        ListView.builder(
          key: const Key('chat-bottom-anchored-list'),
          controller: _controller,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: widget.messageIds.length,
          findChildIndexCallback: (key) =>
              key is ValueKey<String> ? positions[key.value] : null,
          itemBuilder: (context, reversedIndex) {
            final index = widget.messageIds.length - 1 - reversedIndex;
            return KeyedSubtree(
              key: ValueKey<String>(widget.messageIds[index]),
              child: widget.messageBuilder(context, index),
            );
          },
        ),
        if (_showJumpButton)
          Positioned(
            right: 14,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: FilledButton.tonalIcon(
                key: const Key('chat-scroll-to-latest'),
                onPressed: () {
                  setState(() => _unseenIncoming = 0);
                  _toLatest();
                },
                icon: const Icon(Icons.keyboard_double_arrow_down_rounded),
                label: Text(_unseenIncoming > 0
                    ? '$_unseenIncoming nouveau${_unseenIncoming > 1 ? 'x' : ''}'
                    : 'Derniers messages'),
              ),
            ),
          ),
      ],
    );
  }
}
