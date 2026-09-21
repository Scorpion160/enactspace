import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/push/firebase_push_platform.dart';

void main() {
  test('Android token retrieval never waits for APNs', () async {
    var apnsReads = 0;
    var firebaseReads = 0;

    final token = await readFirebaseTokenWhenReady(
      requiresApnsToken: false,
      readFirebaseToken: () async {
        firebaseReads++;
        return 'android-token';
      },
      readApnsToken: () async {
        apnsReads++;
        return null;
      },
    );

    expect(token, 'android-token');
    expect(firebaseReads, 1);
    expect(apnsReads, 0);
  });

  test('Apple retrieves FCM token only after APNs becomes ready', () async {
    var apnsReads = 0;
    var firebaseReads = 0;
    var delays = 0;

    final token = await readFirebaseTokenWhenReady(
      requiresApnsToken: true,
      maxAttempts: 3,
      retryDelay: Duration.zero,
      delay: (_) async => delays++,
      readApnsToken: () async => ++apnsReads == 2 ? 'apns-token' : null,
      readFirebaseToken: () async {
        firebaseReads++;
        return 'ios-token';
      },
    );

    expect(token, 'ios-token');
    expect(apnsReads, 2);
    expect(delays, 1);
    expect(firebaseReads, 1);
  });

  test(
    'Apple default APNs wait is bounded and defers FCM token retrieval',
    () async {
      var apnsReads = 0;
      var firebaseReads = 0;
      var delays = 0;

      final token = await readFirebaseTokenWhenReady(
        requiresApnsToken: true,

        delay: (_) async => delays++,
        readApnsToken: () async {
          apnsReads++;
          return null;
        },
        readFirebaseToken: () async {
          firebaseReads++;
          return 'must-not-be-read';
        },
      );

      expect(token, isNull);
      expect(apnsReads, 20);
      expect(delays, 19);
      expect(firebaseReads, 0);
    },
  );
}
