import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/chat/models/chat_models.dart';
import 'package:frontend/features/chat/services/chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      '_chat_messages_cache_thread-1': 'legacy private body',
      'enactspace_chat_messages_member-1_thread-1': 'private body',
      'enactspace_chat_threads_member-1': 'private thread preview',
      'enactspace_theme_mode': 'dark',
    });
  });

  test(
    'message bodies use memory only and legacy persisted caches are purged',
    () async {
      final service = ChatService();
      final message = ChatMessageModel.fromJson({
        'id': 'message-1',
        'thread_id': 'thread-1',
        'author_id': 'member-1',
        'content': 'private message body',
        'message_type': 'text',
        'created_at': '2026-09-13T00:00:00Z',
      });

      await service.cacheMessages(
        userId: 'member-1',
        threadId: 'thread-1',
        messages: [message],
      );

      expect(
        (await service.getCachedMessages(
          userId: 'member-1',
          threadId: 'thread-1',
        )).single.content,
        'private message body',
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getKeys().where(
          (key) =>
              key.startsWith('_chat_messages_cache_') ||
              key.startsWith('enactspace_chat_messages_') ||
              key.startsWith('enactspace_chat_threads_'),
        ),
        isEmpty,
      );
      expect(preferences.getString('enactspace_theme_mode'), 'dark');
    },
  );
}
