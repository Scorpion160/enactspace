import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ChatMessageBubble extends StatelessWidget {
  final bool mine;
  final bool pinned;
  final VoidCallback onLongPress;
  final Widget child;

  const ChatMessageBubble({
    super.key,
    required this.mine,
    required this.pinned,
    required this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Semantics(
      container: true,
      label: mine ? 'Votre message' : 'Message reçu',
      child: GestureDetector(
        onLongPress: onLongPress,
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
          child: child,
        ),
      ),
    ),
  );
}
