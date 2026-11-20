import 'package:flutter/widgets.dart';

/// Keeps composer text and cursor position separated by conversation.
///
/// In-memory only: never carries a draft into another recipient's composer.
class ChatComposerDrafts {
  final Map<String, TextEditingValue> _drafts = {};

  TextEditingValue switchThread({
    required String? previousThreadId,
    required String? nextThreadId,
    required TextEditingValue currentValue,
  }) {
    if (previousThreadId == nextThreadId) return currentValue;
    if (previousThreadId != null) {
      if (currentValue.text.isEmpty) {
        _drafts.remove(previousThreadId);
      } else {
        _drafts[previousThreadId] = currentValue;
      }
    }
    if (nextThreadId == null) return TextEditingValue.empty;
    return _drafts[nextThreadId] ?? TextEditingValue.empty;
  }

  void forgetThread(String threadId) => _drafts.remove(threadId);
}
