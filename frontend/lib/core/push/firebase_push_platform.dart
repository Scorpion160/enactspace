import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_platform.dart';

const _projectId = String.fromEnvironment('ENACTSPACE_FIREBASE_PROJECT_ID');
const _senderId = String.fromEnvironment(
  'ENACTSPACE_FIREBASE_MESSAGING_SENDER_ID',
);
const _androidApiKey = String.fromEnvironment(
  'ENACTSPACE_FIREBASE_API_KEY_ANDROID',
);
const _androidAppId = String.fromEnvironment(
  'ENACTSPACE_FIREBASE_APP_ID_ANDROID',
);
const _iosApiKey = String.fromEnvironment('ENACTSPACE_FIREBASE_API_KEY_IOS');
const _iosAppId = String.fromEnvironment('ENACTSPACE_FIREBASE_APP_ID_IOS');
const _apnsReadinessAttempts = 20;
const _apnsReadinessDelay = Duration(milliseconds: 250);

typedef PushTokenReader = Future<String?> Function();
typedef PushReadinessDelay = Future<void> Function(Duration duration);

@visibleForTesting
Future<String?> readFirebaseTokenWhenReady({
  required bool requiresApnsToken,
  required PushTokenReader readFirebaseToken,
  required PushTokenReader readApnsToken,
  int maxAttempts = _apnsReadinessAttempts,
  Duration retryDelay = _apnsReadinessDelay,
  PushReadinessDelay delay = Future<void>.delayed,
}) async {
  if (!requiresApnsToken) return readFirebaseToken();
  if (maxAttempts < 1) return null;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final apnsToken = await readApnsToken();
    if (apnsToken != null && apnsToken.isNotEmpty) {
      return readFirebaseToken();
    }
    if (attempt + 1 < maxAttempts) await delay(retryDelay);
  }
  return null;
}

FirebaseOptions? _runtimeFirebaseOptions() {
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (kIsWeb || (!isAndroid && !isIos)) return null;
  final apiKey = isAndroid ? _androidApiKey : _iosApiKey;
  final appId = isAndroid ? _androidAppId : _iosAppId;
  if (_projectId.isEmpty ||
      _senderId.isEmpty ||
      apiKey.isEmpty ||
      appId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
    iosBundleId: isIos ? 'sn.enactusesp.enactspace' : null,
  );
}

@pragma('vm:entry-point')
Future<void> enactSpaceFirebaseBackgroundHandler(RemoteMessage message) async {
  final options = _runtimeFirebaseOptions();
  if (options == null) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
  } catch (_) {
    // System notification display does not depend on application UI work.
  }
}

class FirebasePushPlatform implements PushPlatform {
  final _foreground = StreamController<PushIncomingMessage>.broadcast();
  final _opened = StreamController<PushIncomingMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;

  FirebaseOptions? get _options => _runtimeFirebaseOptions();

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get configured => supported && _options != null;

  @override
  Stream<String> get tokenRefresh => _initialized
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream<String>.empty();

  @override
  Stream<PushIncomingMessage> get foregroundMessages => _foreground.stream;

  @override
  Stream<PushIncomingMessage> get openedMessages => _opened.stream;

  @override
  Future<bool> initialize() async {
    final options = _options;
    if (options == null) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(
        enactSpaceFirebaseBackgroundHandler,
      );
      _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
        (message) => _foreground.add(_fromRemote(message)),
      );
      _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _opened.add(_fromRemote(message)),
      );
      _initialized = true;
      return true;
    } catch (_) {
      _initialized = false;
      return false;
    }
  }

  PushIncomingMessage _fromRemote(RemoteMessage message) => PushIncomingMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data.map((key, value) => MapEntry(key, value.toString())),
  );

  PushAuthorization _authorization(AuthorizationStatus value) =>
      switch (value) {
        AuthorizationStatus.authorized => PushAuthorization.authorized,
        AuthorizationStatus.provisional => PushAuthorization.provisional,
        AuthorizationStatus.denied => PushAuthorization.denied,
        AuthorizationStatus.deniedPermanently => PushAuthorization.denied,
        AuthorizationStatus.notDetermined => PushAuthorization.notDetermined,
      };

  @override
  Future<PushAuthorization> permissionStatus() async {
    if (!_initialized) return PushAuthorization.denied;
    return _authorization(
      (await FirebaseMessaging.instance.getNotificationSettings())
          .authorizationStatus,
    );
  }

  @override
  Future<PushAuthorization> requestPermission() async {
    if (!_initialized) return PushAuthorization.denied;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _authorization(settings.authorizationStatus);
  }

  @override
  Future<String?> currentToken() {
    if (!_initialized) return Future<String?>.value();
    return readFirebaseTokenWhenReady(
      requiresApnsToken: defaultTargetPlatform == TargetPlatform.iOS,
      readFirebaseToken: FirebaseMessaging.instance.getToken,
      readApnsToken: FirebaseMessaging.instance.getAPNSToken,
    );
  }

  @override
  Future<void> deleteToken() async {
    if (_initialized) await FirebaseMessaging.instance.deleteToken();
  }

  @override
  Future<PushIncomingMessage?> initialMessage() async {
    if (!_initialized) return null;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _fromRemote(message);
  }
}
