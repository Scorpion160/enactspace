import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/storage/session_private_data.dart';
import 'package:frontend/features/chat/models/chat_models.dart';
import 'package:frontend/features/chat/services/chat_offline_cache.dart';
import 'package:frontend/features/chat/services/chat_service.dart';

class _CountingEncryptedStore implements ChatOfflineCacheStore {
  String? stored;
  int writes = 0;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async {
    writes++;
    stored = value;
  }

  @override
  Future<void> delete() async => stored = null;
}

ChatThreadModel _thread({int unread = 0}) => ChatThreadModel.fromJson({
  'id': 'thread-test',
  'title': 'Groupe Test',
  'display_title': 'Groupe Test',
  'thread_type': 'group',
  'created_at': '2026-11-01T00:00:00Z',
  'updated_at': '2026-11-14T00:00:00Z',
  'participants_count': 2,
  'unread_count': unread,
  'current_user_role': 'member',
});

ChatMessageModel _message(String content) => ChatMessageModel.fromJson({
  'id': 'msg-1',
  'thread_id': 'thread-test',
  'author_id': 'member-1',
  'message_type': 'text',
  'content': content,
  'created_at': '2026-11-14T10:00:00Z',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    purgePrivateSessionMemory();
  });
  tearDown(purgePrivateSessionMemory);

  test(
    'periodic identical threads are not rewritten to encrypted storage',
    () async {
      final cache = _CountingEncryptedStore();
      final chat = ChatService(offlineCache: cache);
      await chat.cacheThreads(userId: 'member-test', threads: [_thread()]);
      expect(cache.writes, 1);

      await chat.cacheThreads(userId: 'member-test', threads: [_thread()]);
      expect(cache.writes, 1);

      await chat.cacheThreads(
        userId: 'member-test',
        threads: [_thread(unread: 2)],
      );
      expect(cache.writes, 2);
      expect(
        (await ChatService(
          offlineCache: cache,
        ).getCachedThreads(userId: 'member-test')).single.unreadCount,
        2,
      );
    },
  );

  test('unchanged messages skip writes but edited content is saved', () async {
    final cache = _CountingEncryptedStore();
    final chat = ChatService(offlineCache: cache);
    await chat.cacheMessages(
      userId: 'member-test',
      threadId: 'thread-test',
      messages: [_message('Message initial')],
    );
    expect(cache.writes, 1);
    await chat.cacheMessages(
      userId: 'member-test',
      threadId: 'thread-test',
      messages: [_message('Message initial')],
    );
    expect(cache.writes, 1);
    await chat.cacheMessages(
      userId: 'member-test',
      threadId: 'thread-test',
      messages: [_message('Message modifié')],
    );
    expect(cache.writes, 2);

    purgePrivateSessionMemory();
    final restarted = ChatService(offlineCache: cache);
    final restored = await restarted.getCachedMessages(
      userId: 'member-test',
      threadId: 'thread-test',
    );
    expect(restored.single.content, 'Message modifié');
  });

  test('different users have independent encrypted entries', () async {
    final cache = _CountingEncryptedStore();
    final chat = ChatService(offlineCache: cache);
    await chat.cacheThreads(userId: 'member-A', threads: [_thread()]);
    await chat.cacheThreads(userId: 'member-B', threads: [_thread()]);
    expect(cache.writes, 2);
    purgePrivateSessionMemory();
    expect((await chat.getCachedThreads(userId: 'member-A')).length, 1);
    expect((await chat.getCachedThreads(userId: 'member-B')).length, 1);
  });
}
