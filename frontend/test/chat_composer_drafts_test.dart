import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/services/chat_composer_drafts.dart';

void main() {
  test('draft and cursor remain private to their conversation', () {
    final drafts = ChatComposerDrafts();
    const a = TextEditingValue(
      text: 'Pour Alice',
      selection: TextSelection.collapsed(offset: 5),
    );
    final b = drafts.switchThread(
      previousThreadId: 'alice',
      nextThreadId: 'bob',
      currentValue: a,
    );
    expect(b.text, isEmpty);
    const bobDraft = TextEditingValue(
      text: 'Pour Bob',
      selection: TextSelection.collapsed(offset: 8),
    );
    final restored = drafts.switchThread(
      previousThreadId: 'bob',
      nextThreadId: 'alice',
      currentValue: bobDraft,
    );
    expect(restored, a);
    final bobRestored = drafts.switchThread(
      previousThreadId: 'alice',
      nextThreadId: 'bob',
      currentValue: restored,
    );
    expect(bobRestored, bobDraft);
  });

  test('closing a conversation clears the active field, not its draft', () {
    final drafts = ChatComposerDrafts();
    final clear = drafts.switchThread(
      previousThreadId: 'a',
      nextThreadId: null,
      currentValue: const TextEditingValue(text: 'Brouillon'),
    );
    expect(clear.text, isEmpty);
    final reopened = drafts.switchThread(
      previousThreadId: null,
      nextThreadId: 'a',
      currentValue: clear,
    );
    expect(reopened.text, 'Brouillon');
  });

  test('deleted conversations can forget drafts', () {
    final drafts = ChatComposerDrafts();
    drafts.switchThread(
      previousThreadId: 'a',
      nextThreadId: 'b',
      currentValue: const TextEditingValue(text: 'Confidentiel'),
    );
    drafts.forgetThread('a');
    final reopened = drafts.switchThread(
      previousThreadId: 'b',
      nextThreadId: 'a',
      currentValue: TextEditingValue.empty,
    );
    expect(reopened.text, isEmpty);
  });
}
