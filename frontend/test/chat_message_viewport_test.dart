import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/widgets/chat_message_viewport.dart';

Widget fixture(List<String> ids, {Set<String> mine = const {}, String thread = 'a'}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 420,
          child: ChatMessageViewport(
            key: ValueKey('viewport-$thread'),
            conversationId: thread,
            messageIds: ids,
            authoredMessageIds: mine,
            messageBuilder: (context, index) => SizedBox(
              height: 66,
              child: Text('Message ${ids[index]}'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a conversation opens on the newest messages', (tester) async {
    final ids = List.generate(50, (i) => 'm$i');
    await tester.pumpWidget(fixture(ids));
    await tester.pumpAndSettle();
    expect(find.text('Message m49'), findsOneWidget);
    expect(find.text('Message m0'), findsNothing);
    final view = tester.widget<ListView>(
      find.byKey(const Key('chat-bottom-anchored-list')),
    );
    expect(view.reverse, isTrue);
    expect(find.byKey(const Key('chat-scroll-to-latest')), findsNothing);
  });

  testWidgets('incoming messages do not steal history scroll', (tester) async {
    final ids = List.generate(50, (i) => 'm$i');
    await tester.pumpWidget(fixture(ids));
    await tester.pumpAndSettle();

    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('chat-bottom-anchored-list')),
        matching: find.byType(Scrollable),
      ),
    );
    scroll.position.jumpTo(430);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-scroll-to-latest')), findsOneWidget);

    await tester.pumpWidget(fixture([...ids, 'm50']));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(200));
    expect(find.text('1 nouveau'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-scroll-to-latest')));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(0, 0.5));
    expect(find.text('Message m50'), findsOneWidget);
    expect(find.byKey(const Key('chat-scroll-to-latest')), findsNothing);
  });

  testWidgets('outgoing message comes into view even when reading history',
      (tester) async {
    final ids = List.generate(50, (i) => 'm$i');
    await tester.pumpWidget(fixture(ids));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('chat-bottom-anchored-list')),
        matching: find.byType(Scrollable),
      ),
    );
    scroll.position.jumpTo(500);
    await tester.pumpAndSettle();

    await tester.pumpWidget(fixture([...ids, 'local-1'], mine: {'local-1'}));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, closeTo(0, 0.5));
    expect(find.text('Message local-1'), findsOneWidget);
  });

  testWidgets('changing conversations starts with the newest message',
      (tester) async {
    final older = List.generate(50, (i) => 'a$i');
    final other = List.generate(50, (i) => 'b$i');
    await tester.pumpWidget(fixture(older));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('chat-bottom-anchored-list')),
        matching: find.byType(Scrollable),
      ),
    );
    state.position.jumpTo(450);
    await tester.pumpAndSettle();

    await tester.pumpWidget(fixture(other, thread: 'b'));
    await tester.pumpAndSettle();
    expect(find.text('Message b49'), findsOneWidget);
    expect(find.text('Message a49'), findsNothing);
    expect(find.byKey(const Key('chat-scroll-to-latest')), findsNothing);
  });
}
