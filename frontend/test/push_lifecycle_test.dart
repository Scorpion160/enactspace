import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/push/push_gateway.dart';
import 'package:frontend/core/push/push_installation_store.dart';
import 'package:frontend/core/push/push_lifecycle_controller.dart';
import 'package:frontend/core/push/push_navigation_resolver.dart';
import 'package:frontend/core/push/push_platform.dart';
import 'package:frontend/core/theme/appearance_controller.dart';
import 'package:frontend/features/legal/models/legal_models.dart';
import 'package:frontend/features/legal/services/legal_gateway.dart';
import 'package:frontend/features/legal/widgets/legal_acceptance_gate.dart';
import 'package:frontend/features/notifications/models/notification_model.dart';
import 'package:frontend/features/settings/controllers/settings_controller.dart';
import 'package:frontend/features/settings/models/settings_models.dart';
import 'package:frontend/features/settings/screens/settings_screen.dart';
import 'package:frontend/features/settings/services/settings_gateway.dart';

class FakePushPlatform implements PushPlatform {
  bool supportedValue = true;
  bool configuredValue = true;
  bool initializeValue = true;
  bool throwInitialize = false;
  PushAuthorization authorizationValue = PushAuthorization.authorized;
  PushAuthorization? requestedAuthorizationValue;
  String? token = 'push-token';
  int permissionRequests = 0;
  int tokenDeletes = 0;
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<PushIncomingMessage>.broadcast();
  final opened = StreamController<PushIncomingMessage>.broadcast();

  @override
  bool get supported => supportedValue;
  @override
  bool get configured => configuredValue;
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<PushIncomingMessage> get foregroundMessages => foreground.stream;
  @override
  Stream<PushIncomingMessage> get openedMessages => opened.stream;
  @override
  Future<bool> initialize() async {
    if (throwInitialize) throw StateError('init');
    return initializeValue;
  }

  @override
  Future<PushAuthorization> permissionStatus() async => authorizationValue;
  @override
  Future<PushAuthorization> requestPermission() async {
    permissionRequests++;
    authorizationValue = requestedAuthorizationValue ?? authorizationValue;
    return authorizationValue;
  }

  @override
  Future<String?> currentToken() async => token;
  @override
  Future<void> deleteToken() async {
    tokenDeletes++;
  }

  @override
  Future<PushIncomingMessage?> initialMessage() async => null;
}

class FakePushStore implements PushInstallationStore {
  String? serverId = 'installation-id';
  @override
  Future<String> installationKey(String userId) async => 'opaque-$userId';
  @override
  Future<String?> serverInstallationId(String userId) async => serverId;
  @override
  Future<void> writeServerInstallationId(
    String userId,
    String installationId,
  ) async {
    serverId = installationId;
  }
}

class FakePushGateway implements PushGateway {
  bool preference = false;
  bool failUpdate = false;
  bool failCleanup = false;
  bool failRegistration = false;
  final events = <String>[];
  final registeredTokens = <String>[];
  final readIds = <String>[];
  @override
  Future<bool> loadPushPreference() async => preference;
  @override
  Future<void> updatePushPreference(bool enabled) async {
    events.add('preference:$enabled');
    if (failUpdate) throw StateError('update');
    preference = enabled;
  }

  @override
  Future<String> ensureInstallation(String userId) async {
    events.add('ensure:$userId');
    return 'installation-id';
  }

  @override
  Future<void> registerToken(
    String installationId,
    String token, {
    bool enableAccountPush = false,
  }) async {
    events.add('register:$installationId:enable=$enableAccountPush');
    if (failRegistration) throw StateError('registration');
    registeredTokens.add(token);
  }

  @override
  Future<void> unregisterToken(String installationId) async {
    events.add('unregister:$installationId');
    if (failCleanup) throw StateError('cleanup');
  }

  @override
  Future<void> revokeInstallation(String installationId) async {
    events.add('revoke:$installationId');
    if (failCleanup) throw StateError('cleanup');
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    events.add('read:$notificationId');
    if (failCleanup) throw StateError('read');
    readIds.add(notificationId);
  }
}

class FakePushAuthService extends AuthService {
  bool loggedIn = true;
  Map<String, dynamic>? cachedUser = {'id': 'user-1'};
  Map<String, dynamic>? currentUser = {'id': 'user-1'};

  @override
  Future<bool> isLoggedIn() async => loggedIn;

  @override
  Future<Map<String, dynamic>?> getCachedCurrentUser() async => cachedUser;

  @override
  Future<Map<String, dynamic>> getCurrentUser() async {
    final value = currentUser;
    if (value == null) throw StateError('no user');
    return value;
  }
}

class FakeSettingsGateway implements SettingsGateway {
  @override
  Future<AccountDeletionRequest> cancelDeletionRequest() =>
      throw UnimplementedError();
  @override
  Future<AccountDeletionRequest?> loadDeletionRequest() async => null;
  @override
  Future<UserPreferences> loadPreferences() => throw UnimplementedError();
  @override
  Future<AccountDataExport> requestDataExport() => throw UnimplementedError();
  @override
  Future<AccountDeletionRequest> requestDeletion(String? reason) =>
      throw UnimplementedError();
  @override
  Future<UserPreferences> updatePreferences(Map<String, dynamic> changes) =>
      throw UnimplementedError();
}

class PendingLegalGateway implements LegalGateway {
  static const status = LegalStatus(
    type: 'terms_of_service',
    documentId: 'terms-v1',
    version: '1',
    requiresAcceptance: true,
    accepted: false,
  );
  static const document = LegalDocument(
    id: 'terms-v1',
    type: 'terms_of_service',
    version: '1',
    title: 'Conditions requises',
    content: 'Contenu',
    effectiveAt: null,
    requiresAcceptance: true,
  );

  @override
  Future<void> accept(LegalStatus status, String source) async {}
  @override
  Future<LegalDocument?> loadDocumentForAcceptance(LegalStatus status) async =>
      document;
  @override
  Future<LegalDocument?> loadPublicDocument(String type) async => document;
  @override
  Future<List<LegalStatus>> loadStatus() async => const [status];
}

void main() {
  late FakePushPlatform platform;
  late FakePushGateway gateway;
  late FakePushStore store;
  late FakePushAuthService auth;
  late PushLifecycleController controller;

  setUp(() {
    platform = FakePushPlatform();
    gateway = FakePushGateway();
    store = FakePushStore();
    auth = FakePushAuthService();
    controller = PushLifecycleController(
      pushPlatform: platform,
      pushGateway: gateway,
      installationStore: store,
      authService: auth,
    );
    controller.initialized = true;
    controller.activeUserId = 'user-1';
  });

  test('01 missing configuration does not enable push', () async {
    platform.configuredValue = false;
    expect(await controller.enableFromUserAction(), isFalse);
  });
  test('02 initialization failure is contained', () async {
    platform.throwInitialize = true;
    await controller.initialize();
    expect(controller.initialized, isFalse);
  });
  test('03 startup initialization requests no permission', () async {
    await controller.initialize();
    expect(platform.permissionRequests, 0);
  });
  test('04 unsupported platform exposes no availability', () {
    platform.supportedValue = false;
    expect(controller.available, isFalse);
  });
  test('05 configured mobile platform is available', () {
    expect(controller.available, isTrue);
  });
  test('06 enable permission request requires explicit action', () async {
    platform.authorizationValue = PushAuthorization.notDetermined;
    await controller.enableFromUserAction();
    expect(platform.permissionRequests, 1);
  });
  test('07 denied permission never claims enabled', () async {
    platform.authorizationValue = PushAuthorization.denied;
    expect(await controller.enableFromUserAction(), isFalse);
    expect(controller.preferenceEnabled, isFalse);
  });
  test('08 authorized permission registers installation and token', () async {
    expect(await controller.enableFromUserAction(), isTrue);
    expect(gateway.registeredTokens, ['push-token']);
  });
  test('09 enable updates only boolean push preference contract', () async {
    await controller.enableFromUserAction();
    expect(gateway.events.last, 'preference:true');
  });
  test('10 disable updates only boolean push preference contract', () async {
    await controller.disableFromUserAction();
    expect(gateway.events, ['preference:false']);
  });
  test('11 enable does not issue unrelated preference mutations', () async {
    await controller.enableFromUserAction();
    expect(
      gateway.events.where((event) => event.startsWith('preference:')).length,
      1,
    );
  });
  test('12 token refresh re-registers while enabled', () async {
    await controller.synchronizeAuthenticatedUser('user-1', true);
    platform.tokens.add('rotated');
    await Future<void>.delayed(Duration.zero);
    expect(gateway.registeredTokens, contains('rotated'));
  });
  test('13 token refresh is ignored while logged out', () async {
    await controller.synchronizeAuthenticatedUser('user-1', true);
    controller.activeUserId = null;
    platform.tokens.add('ignored');
    await Future<void>.delayed(Duration.zero);
    expect(gateway.registeredTokens, isNot(contains('ignored')));
  });
  test('14 token refresh is ignored while preference disabled', () async {
    await controller.synchronizeAuthenticatedUser('user-1', false);
    platform.tokens.add('ignored');
    await Future<void>.delayed(Duration.zero);
    expect(gateway.registeredTokens, isEmpty);
  });
  test('15 resume synchronizes authorized enabled device', () async {
    controller.preferenceEnabled = true;
    await controller.reconcileOnResume();
    expect(gateway.registeredTokens, ['push-token']);
  });
  test('16 revoked OS permission unregisters current server token', () async {
    controller.preferenceEnabled = true;
    platform.authorizationValue = PushAuthorization.denied;
    await controller.reconcileOnResume();
    expect(gateway.events, contains('unregister:installation-id'));
  });
  test(
    '17 current logout cleans server association before local token',
    () async {
      await controller.cleanupForLogout(allDevices: false);
      expect(gateway.events.take(2), [
        'unregister:installation-id',
        'revoke:installation-id',
      ]);
      expect(platform.tokenDeletes, 1);
    },
  );
  test('18 cleanup failure does not block logout cleanup completion', () async {
    gateway.failCleanup = true;
    await controller.cleanupForLogout(allDevices: false);
    expect(controller.activeUserId, isNull);
  });
  test(
    '19 logout-all leaves server-wide revoke to authoritative endpoint',
    () async {
      await controller.cleanupForLogout(allDevices: true);
      expect(gateway.events, isNot(contains('revoke:installation-id')));
    },
  );
  test('20 foreground message stream does not navigate itself', () async {
    final message = const PushIncomingMessage(data: {'route': '/admin'});
    final received = controller.foregroundMessages.first;
    platform.foreground.add(message);
    expect(await received, same(message));
  });
  test('21 foreground payload supports explicit open metadata', () async {
    final received = controller.foregroundMessages.first;
    platform.foreground.add(
      const PushIncomingMessage(title: 'Titre', data: {'type': 'task'}),
    );
    expect((await received).title, 'Titre');
  });
  test('22 push tap uses canonical resolver', () {
    expect(
      PushNavigationResolver.fromData({'type': 'task', 'related_id': '42'}),
      '/tasks/42',
    );
  });
  test('23 arbitrary remote route is ignored', () {
    expect(
      PushNavigationResolver.fromData({'type': 'unknown', 'route': '/admin'}),
      '/notifications',
    );
  });
  test('24 task destination maps safely', () {
    expect(
      PushNavigationResolver.resolve(type: 'task', relatedId: '1'),
      '/tasks/1',
    );
  });
  test('25 event destination maps safely', () {
    expect(
      PushNavigationResolver.resolve(type: 'event', relatedId: '2'),
      '/events/2',
    );
  });
  test('26 document destination maps safely', () {
    expect(
      PushNavigationResolver.resolve(type: 'document', relatedId: '3'),
      '/documents/3',
    );
  });
  test('27 unknown destination uses notifications fallback', () {
    expect(PushNavigationResolver.resolve(type: 'other'), '/notifications');
  });
  test('28 resolver returns internal paths for router RBAC enforcement', () {
    expect(PushNavigationResolver.resolve(type: 'finance'), '/finance');
  });
  test('29 mark-read targets exact notification ID', () async {
    await controller.markReadBestEffort('notification-7');
    expect(gateway.readIds, ['notification-7']);
  });
  test('30 mark-read failure does not break navigation flow', () async {
    gateway.failCleanup = true;
    await controller.markReadBestEffort('notification-8');
    expect(gateway.events, ['read:notification-8']);
  });
  test('31 opaque installation store API never receives FCM token', () async {
    await controller.enableFromUserAction();
    expect(await store.installationKey('user-1'), 'opaque-user-1');
  });
  test('32 notification center reuses canonical route resolver', () {
    final model = NotificationModel(
      id: 'n',
      userId: 'u',
      title: 't',
      type: 'project',
      isRead: false,
      relatedId: 'p',
    );
    expect(
      model.routePath,
      PushNavigationResolver.resolve(type: 'project', relatedId: 'p'),
    );
  });
  testWidgets('33 unsupported platform hides the push setting', (tester) async {
    platform.supportedValue = false;
    final settings =
        SettingsController(
            gateway: FakeSettingsGateway(),
            appearance: AppearanceController(),
            pushController: controller,
          )
          ..preferences = const UserPreferences(
            locale: 'fr',
            theme: 'system',
            inAppNotifications: true,
            emailNotifications: true,
            pushNotifications: false,
          );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(controller: settings)),
    );
    expect(find.byKey(const Key('push-notifications-toggle')), findsNothing);
  });
  testWidgets('34 supported mobile shows push without rendering its token', (
    tester,
  ) async {
    final settings =
        SettingsController(
            gateway: FakeSettingsGateway(),
            appearance: AppearanceController(),
            pushController: controller,
          )
          ..preferences = const UserPreferences(
            locale: 'fr',
            theme: 'system',
            inAppNotifications: true,
            emailNotifications: true,
            pushNotifications: false,
          );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(controller: settings)),
    );
    expect(find.byKey(const Key('push-notifications-toggle')), findsOneWidget);
    expect(find.text('push-token'), findsNothing);
  });
  testWidgets('35 legal acceptance gate blocks a private push destination', (
    tester,
  ) async {
    final privateRoute = PushNavigationResolver.resolve(type: 'finance');
    await tester.pumpWidget(
      MaterialApp(
        home: LegalAcceptanceGate(
          gateway: PendingLegalGateway(),
          child: Text(privateRoute),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(privateRoute), findsNothing);
    expect(find.text('J’accepte'), findsOneWidget);
  });

  test(
    '36 enable resolves an authenticated user before registration',
    () async {
      controller.activeUserId = null;
      expect(await controller.enableFromUserAction(), isTrue);
      expect(controller.activeUserId, 'user-1');
      expect(gateway.events, [
        'ensure:user-1',
        'register:installation-id:enable=true',
        'preference:true',
      ]);
    },
  );

  test(
    '37 unauthenticated enable does not request permission or patch',
    () async {
      controller.activeUserId = null;
      auth.loggedIn = false;
      expect(await controller.enableFromUserAction(), isFalse);
      expect(platform.permissionRequests, 0);
      expect(gateway.events, isEmpty);
    },
  );

  test('38 registration failure never patches preference true', () async {
    gateway.failRegistration = true;
    expect(await controller.enableFromUserAction(), isFalse);
    expect(gateway.events, isNot(contains('preference:true')));
  });

  test('39 unavailable token never patches preference true', () async {
    platform.token = null;
    expect(await controller.enableFromUserAction(), isFalse);
    expect(gateway.events, isEmpty);
  });

  testWidgets('40 second device can authorize without disabling account push', (
    tester,
  ) async {
    platform.authorizationValue = PushAuthorization.notDetermined;
    platform.requestedAuthorizationValue = PushAuthorization.authorized;
    controller.preferenceEnabled = true;
    controller.authorization = PushAuthorization.notDetermined;
    final settings =
        SettingsController(
            gateway: FakeSettingsGateway(),
            appearance: AppearanceController(),
            pushController: controller,
          )
          ..preferences = const UserPreferences(
            locale: 'fr',
            theme: 'system',
            inAppNotifications: true,
            emailNotifications: true,
            pushNotifications: true,
          );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(controller: settings)),
    );
    expect(find.byKey(const Key('authorize-push-device')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('authorize-push-device')),
    );
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(platform.permissionRequests, 1);
    expect(gateway.registeredTokens, ['push-token']);
    expect(gateway.events, isNot(contains('preference:false')));
    expect(gateway.events, isNot(contains('unregister:installation-id')));
    expect(controller.deviceSynchronized, isTrue);
  });

  test('41 push open waits for authenticated readiness', () {
    final gate = PushOpenReadinessGate();
    const initial = PushIncomingMessage(data: {'type': 'task'});
    expect(gate.receive(initial), isNull);
    expect(gate.resolve(authenticated: true), same(initial));
  });

  test('42 opened push during readiness is retained', () {
    final gate = PushOpenReadinessGate();
    const opened = PushIncomingMessage(data: {'type': 'event'});
    expect(gate.receive(opened), isNull);
    expect(gate.resolve(authenticated: true), same(opened));
  });

  test('43 invalid session discards a pending push open', () {
    final gate = PushOpenReadinessGate();
    const opened = PushIncomingMessage(data: {'type': 'finance'});
    gate.receive(opened);
    expect(gate.resolve(authenticated: false), isNull);
    expect(gate.receive(opened), isNull);
  });

  test('44 cleanup exception cannot prevent authentication logout', () async {
    var logoutCalled = false;
    await runLogoutWithPushCleanup(
      cleanup: () async => throw StateError('cleanup'),
      logout: () async => logoutCalled = true,
    );
    expect(logoutCalled, isTrue);
  });

  testWidgets('45 denied device state never claims synchronization', (
    tester,
  ) async {
    controller.authorization = PushAuthorization.denied;
    controller.preferenceEnabled = true;
    controller.deviceSynchronized = false;
    final settings =
        SettingsController(
            gateway: FakeSettingsGateway(),
            appearance: AppearanceController(),
            pushController: controller,
          )
          ..preferences = const UserPreferences(
            locale: 'fr',
            theme: 'system',
            inAppNotifications: true,
            emailNotifications: true,
            pushNotifications: true,
          );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(controller: settings)),
    );
    expect(
      find.text('Bloquées dans les réglages de l’appareil.'),
      findsOneWidget,
    );
    expect(
      find.text('Autorisées et synchronisées sur cet appareil.'),
      findsNothing,
    );
  });
}
