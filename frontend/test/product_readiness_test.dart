import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app_router.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/core/product/product_bootstrap_gateway.dart';
import 'package:frontend/core/product/product_bootstrap_models.dart';
import 'package:frontend/core/product/product_readiness_controller.dart';
import 'package:frontend/core/product/product_store_launcher.dart';
import 'package:frontend/features/product_readiness/product_readiness_gate.dart';

const _androidStore =
    'https://play.google.com/store/apps/details?id=sn.enactusesp.enactspace';
const _iosStore = 'https://apps.apple.com/sn/app/enactspace/id1234567890';

ProductBootstrap _bootstrap({
  bool configured = true,
  ProductMobilePlatform platform = ProductMobilePlatform.android,
  int currentBuild = 2,
  bool updateAvailable = false,
  bool updateRequired = false,
  bool forceUpdate = false,
  bool maintenance = false,
  String? maintenanceMessage,
  String? storeUrl = _androidStore,
}) {
  return ProductBootstrap(
    configured: configured,
    platform: platform,
    clientVersion: '1.0.0',
    clientBuildNumber: 1,
    currentVersion: configured ? '2.0.0' : null,
    currentBuildNumber: configured ? currentBuild : null,
    minimumSupportedVersion: updateRequired ? '2.0.0' : null,
    minimumSupportedBuildNumber: updateRequired ? currentBuild : null,
    updateAvailable: updateAvailable,
    updateRequired: updateRequired,
    forceUpdate: forceUpdate,
    storeUrl: configured ? storeUrl : null,
    maintenance: ProductMaintenanceDecision(
      active: maintenance,
      message: maintenanceMessage,
    ),
  );
}

class _FakeGateway implements ProductBootstrapGateway {
  final Future<ProductBootstrap> Function(int call) handler;
  int calls = 0;

  _FakeGateway(this.handler);

  @override
  Future<ProductBootstrap> fetch() => handler(++calls);
}

class _FakeLauncher implements ProductStoreLauncher {
  final bool result;
  int calls = 0;
  Uri? lastUri;

  _FakeLauncher({this.result = true});

  @override
  Future<bool> launch(Uri uri) async {
    calls++;
    lastUri = uri;
    return result;
  }
}

class _FakeClientInfo implements ProductClientInfoProvider {
  final ProductClientInfo value;
  const _FakeClientInfo(this.value);

  @override
  Future<ProductClientInfo> load() async => value;
}

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MountProbe extends StatefulWidget {
  static int mounts = 0;
  final String label;

  const _MountProbe(this.label);

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    _MountProbe.mounts++;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

Future<ProductReadinessController> _pumpGate(
  WidgetTester tester,
  _FakeGateway gateway, {
  ProductStoreLauncher? launcher,
  Widget child = const Text('CONTENU AUTORISÉ'),
  DateTime Function()? now,
}) async {
  final controller = ProductReadinessController(gateway: gateway, now: now);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: ProductReadinessGate(
        controller: controller,
        storeLauncher: launcher,
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Map<String, dynamic> _bootstrapJson({
  Object? configured = true,
  Object? platform = 'android',
  Object? clientVersion = '1.0.0',
  Object? clientBuild = 1,
  Object? currentVersion = '2.0.0',
  Object? currentBuild = 2,
  Object? updateAvailable = true,
  Object? updateRequired = false,
  Object? forceUpdate = false,
  Object? maintenance = const {'active': false, 'message': null},
}) => {
  'configured': configured,
  'platform': platform,
  'client_version': clientVersion,
  'client_build_number': clientBuild,
  'current_version': currentVersion,
  'current_build_number': currentBuild,
  'minimum_supported_version': null,
  'minimum_supported_build_number': null,
  'update_available': updateAvailable,
  'update_required': updateRequired,
  'force_update': forceUpdate,
  'store_url': _androidStore,
  'maintenance': maintenance,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('01 configured=false allows child', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(configured: false)),
    );
    expect(find.text('CONTENU AUTORISÉ'), findsOneWidget);
  });

  testWidgets('02 maintenance blocks child', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(maintenance: true)),
    );
    expect(find.text('CONTENU AUTORISÉ'), findsNothing);
    expect(find.text('Service temporairement indisponible'), findsOneWidget);
  });

  testWidgets('03 maintenance server message is displayed as plain text', (
    tester,
  ) async {
    const message = '<b>Intervention planifiée</b>';
    await _pumpGate(
      tester,
      _FakeGateway(
        (_) async => _bootstrap(maintenance: true, maintenanceMessage: message),
      ),
    );
    expect(find.text(message), findsOneWidget);
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('04 maintenance fallback message is used', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(maintenance: true)),
    );
    expect(
      find.text(
        'Nous effectuons une maintenance. Veuillez réessayer dans quelques instants.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('05 retry can recover from maintenance', (tester) async {
    final gateway = _FakeGateway(
      (call) async => call == 1 ? _bootstrap(maintenance: true) : _bootstrap(),
    );
    await _pumpGate(tester, gateway);
    await tester.tap(find.byKey(const Key('product-readiness-retry')));
    await tester.pumpAndSettle();
    expect(find.text('CONTENU AUTORISÉ'), findsOneWidget);
  });

  testWidgets('06 update_required blocks', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway(
        (_) async => _bootstrap(updateAvailable: true, updateRequired: true),
      ),
    );
    expect(find.text('Mise à jour requise'), findsOneWidget);
    expect(find.text('CONTENU AUTORISÉ'), findsNothing);
  });

  testWidgets('07 force_update blocks', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway(
        (_) async => _bootstrap(updateAvailable: true, forceUpdate: true),
      ),
    );
    expect(find.text('Mise à jour requise'), findsOneWidget);
  });

  testWidgets('08 required update has no Ignore or Continue action', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(forceUpdate: true)),
    );
    expect(find.text('Ignorer'), findsNothing);
    expect(find.text('Continuer'), findsNothing);
  });

  test('09 trusted Android Play URL recognized', () {
    expect(
      ProductStoreUrlValidator.trustedUri(
        '$_androidStore&hl=fr&gl=SN',
        ProductMobilePlatform.android,
      ),
      isNotNull,
    );
  });

  test('10 wrong Android package URL rejected', () {
    expect(
      ProductStoreUrlValidator.trustedUri(
        'https://play.google.com/store/apps/details?id=wrong.package',
        ProductMobilePlatform.android,
      ),
      isNull,
    );
  });

  test('11 wrong Android host and URL tricks rejected', () {
    for (final value in [
      'https://example.com/store/apps/details?id=sn.enactusesp.enactspace',
      'http://play.google.com/store/apps/details?id=sn.enactusesp.enactspace',
      'https://user@play.google.com/store/apps/details?id=sn.enactusesp.enactspace',
      'https://play.google.com/store/apps/details?id=sn.enactusesp.enactspace#x',
      'https://play.google.com/store/apps/details?id=sn.enactusesp.enactspace&next=x',
    ]) {
      expect(
        ProductStoreUrlValidator.trustedUri(
          value,
          ProductMobilePlatform.android,
        ),
        isNull,
        reason: value,
      );
    }
  });

  test('12 trusted iOS App Store URL recognized', () {
    expect(
      ProductStoreUrlValidator.trustedUri(_iosStore, ProductMobilePlatform.ios),
      isNotNull,
    );
  });

  test('13 wrong iOS host and malformed app paths rejected', () {
    for (final value in [
      'https://example.com/sn/app/enactspace/id1234567890',
      'https://apps.apple.com/sn/app/enactspace/not-an-id',
      'https://user@apps.apple.com/sn/app/enactspace/id1234567890',
      'https://apps.apple.com/sn/app/enactspace/id1234567890#x',
    ]) {
      expect(
        ProductStoreUrlValidator.trustedUri(value, ProductMobilePlatform.ios),
        isNull,
        reason: value,
      );
    }
  });

  testWidgets('14 missing forced-update URL remains blocked', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(forceUpdate: true, storeUrl: null)),
    );
    expect(find.text('Mise à jour requise'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsNothing);
    expect(find.text('CONTENU AUTORISÉ'), findsNothing);
  });

  testWidgets('15 invalid forced-update URL remains blocked', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway(
        (_) async =>
            _bootstrap(forceUpdate: true, storeUrl: 'https://example.com/app'),
      ),
    );
    expect(find.text('Mise à jour requise'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsNothing);
  });

  testWidgets('16 launch success invokes external launcher abstraction', (
    tester,
  ) async {
    final launcher = _FakeLauncher();
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(forceUpdate: true)),
      launcher: launcher,
    );
    await tester.tap(find.byKey(const Key('product-readiness-update')));
    await tester.pumpAndSettle();
    expect(launcher.calls, 1);
    expect(launcher.lastUri.toString(), _androidStore);
    expect(find.text('Mise à jour requise'), findsOneWidget);
  });

  testWidgets('17 launch failure remains blocked with safe feedback', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(forceUpdate: true)),
      launcher: _FakeLauncher(result: false),
    );
    await tester.tap(find.byKey(const Key('product-readiness-update')));
    await tester.pumpAndSettle();
    expect(find.text('Mise à jour requise'), findsOneWidget);
    expect(
      find.textContaining('Impossible d’ouvrir la boutique'),
      findsOneWidget,
    );
    expect(find.text('CONTENU AUTORISÉ'), findsNothing);
  });

  testWidgets('18 optional update does not block child', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(updateAvailable: true)),
    );
    expect(find.text('CONTENU AUTORISÉ'), findsOneWidget);
    expect(find.text('Une mise à jour est disponible'), findsOneWidget);
  });

  testWidgets('19 optional update prompt is dismissible', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(updateAvailable: true)),
    );
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.text('Une mise à jour est disponible'), findsNothing);
    expect(find.text('CONTENU AUTORISÉ'), findsOneWidget);
  });

  testWidgets('20 optional prompt appears once per target build and process', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      (_) async => _bootstrap(updateAvailable: true),
    );
    final controller = await _pumpGate(tester, gateway);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    await controller.retry();
    await tester.pumpAndSettle();
    expect(find.text('Une mise à jour est disponible'), findsNothing);
  });

  for (final entry in const {
    '21 cold-start timeout/network failure blocks': 'network details',
    '22 cold-start 5xx blocks': 'HTTP 503 database details',
    '23 cold-start 4xx blocks': 'HTTP 404 route details',
  }.entries) {
    testWidgets(entry.key, (tester) async {
      await _pumpGate(
        tester,
        _FakeGateway((_) async => throw StateError(entry.value)),
      );
      expect(find.text('Service temporairement indisponible'), findsOneWidget);
      expect(find.text('CONTENU AUTORISÉ'), findsNothing);
    });
  }

  test('24 malformed bootstrap blocks safely in strict parser', () {
    const requested = ProductClientInfo(
      platform: ProductMobilePlatform.android,
      version: '1.0.0',
      buildNumber: 1,
    );
    for (final json in [
      _bootstrapJson(configured: 'true'),
      _bootstrapJson(platform: 'ios'),
      _bootstrapJson(clientBuild: '1'),
      _bootstrapJson(maintenance: {'active': 'false'}),
    ]) {
      expect(
        () => ProductBootstrap.fromJson(json, requested: requested),
        throwsFormatException,
      );
    }
  });

  testWidgets('25 no raw technical error is rendered', (tester) async {
    await _pumpGate(
      tester,
      _FakeGateway(
        (_) async => throw StateError('HTTP 503 postgres api.internal.local'),
      ),
    );
    expect(find.textContaining('503'), findsNothing);
    expect(find.textContaining('postgres'), findsNothing);
    expect(find.textContaining('api.internal'), findsNothing);
  });

  test('26 bootstrap request sends no Authorization', () async {
    late http.Request request;
    final gateway = ApiProductBootstrapGateway(
      apiClient: ApiClient(
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(jsonEncode(_bootstrapJson()), 200);
        }),
      ),
      clientInfo: const _FakeClientInfo(
        ProductClientInfo(
          platform: ProductMobilePlatform.android,
          version: '1.0.0',
          buildNumber: 1,
        ),
      ),
    );
    await gateway.fetch();
    expect(
      request.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains('authorization')),
    );
  });

  test('27 request contains real injected platform/version/build', () async {
    late Uri requestUri;
    final gateway = ApiProductBootstrapGateway(
      apiClient: ApiClient(
        client: MockClient((request) async {
          requestUri = request.url;
          return http.Response(jsonEncode(_bootstrapJson()), 200);
        }),
      ),
      clientInfo: const _FakeClientInfo(
        ProductClientInfo(
          platform: ProductMobilePlatform.android,
          version: '1.0.0',
          buildNumber: 1,
        ),
      ),
    );
    await gateway.fetch();
    expect(requestUri.path, '/api/product/bootstrap');
    expect(requestUri.queryParameters, {
      'platform': 'android',
      'version': '1.0.0',
      'build_number': '1',
    });
  });

  testWidgets('28 ProductReadinessGate prevents private child mounting', (
    tester,
  ) async {
    _MountProbe.mounts = 0;
    final pending = Completer<ProductBootstrap>();
    final gateway = _FakeGateway((_) => pending.future);
    final controller = ProductReadinessController(gateway: gateway);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductReadinessGate(
          controller: controller,
          child: const _MountProbe('PRIVATE'),
        ),
      ),
    );
    await tester.pump();
    expect(_MountProbe.mounts, 0);
    pending.complete(_bootstrap());
    await tester.pumpAndSettle();
    expect(_MountProbe.mounts, 1);
  });

  for (final entry in const {
    '29 login is readiness-gated': '/login',
    '30 about is readiness-gated': '/about',
    '31 recruitment public route is readiness-gated': '/recruitment/apply',
  }.entries) {
    test(entry.key, () {
      expect(AppRouter.isProductReadinessExemptPath(entry.value), isFalse);
    });
  }

  test('32 /legal/privacy is exempt', () {
    expect(AppRouter.isProductReadinessExemptPath('/legal/privacy'), isTrue);
  });

  test('33 /legal/terms is exempt', () {
    expect(AppRouter.isProductReadinessExemptPath('/legal/terms'), isTrue);
  });

  testWidgets('34 direct deep-link child cannot mount while blocked', (
    tester,
  ) async {
    _MountProbe.mounts = 0;
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(maintenance: true)),
      child: const _MountProbe('DEEPLINK'),
    );
    expect(_MountProbe.mounts, 0);
  });

  testWidgets('35 allowing readiness reveals normal route child', (
    tester,
  ) async {
    _MountProbe.mounts = 0;
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap()),
      child: const _MountProbe('ROUTE AUTORISÉE'),
    );
    expect(find.text('ROUTE AUTORISÉE'), findsOneWidget);
    expect(_MountProbe.mounts, 1);
  });

  testWidgets('36 AppShell and push pathway cannot mount while blocked', (
    tester,
  ) async {
    _MountProbe.mounts = 0;
    await _pumpGate(
      tester,
      _FakeGateway((_) async => _bootstrap(forceUpdate: true)),
      child: const _MountProbe('APP SHELL PUSH CONSUMER'),
    );
    expect(_MountProbe.mounts, 0);
  });

  test('37 resume after cooldown rechecks', () async {
    var now = DateTime.utc(2026, 9, 9, 12);
    final gateway = _FakeGateway((_) async => _bootstrap());
    final controller = ProductReadinessController(
      gateway: gateway,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    now = now.add(const Duration(minutes: 6));
    await controller.onResume();
    expect(gateway.calls, 2);
  });

  test('38 resume before cooldown does not recheck', () async {
    var now = DateTime.utc(2026, 9, 9, 12);
    final gateway = _FakeGateway((_) async => _bootstrap());
    final controller = ProductReadinessController(
      gateway: gateway,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    now = now.add(const Duration(minutes: 4, seconds: 59));
    await controller.onResume();
    expect(gateway.calls, 1);
  });

  test('39 explicit retry bypasses cooldown', () async {
    final gateway = _FakeGateway((_) async => _bootstrap());
    final controller = ProductReadinessController(gateway: gateway);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.retry();
    expect(gateway.calls, 2);
  });

  test('40 transient resume failure preserves prior allowed state', () async {
    var now = DateTime.utc(2026, 9, 9, 12);
    final gateway = _FakeGateway(
      (call) async => call == 1 ? _bootstrap() : throw StateError('offline'),
    );
    final controller = ProductReadinessController(
      gateway: gateway,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    now = now.add(const Duration(minutes: 6));
    await controller.onResume();
    expect(controller.status, ProductReadinessStatus.allowed);
  });

  test('41 transient resume failure preserves maintenance block', () async {
    var now = DateTime.utc(2026, 9, 9, 12);
    final gateway = _FakeGateway(
      (call) async => call == 1
          ? _bootstrap(maintenance: true)
          : throw StateError('offline'),
    );
    final controller = ProductReadinessController(
      gateway: gateway,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    now = now.add(const Duration(minutes: 6));
    await controller.onResume();
    expect(controller.status, ProductReadinessStatus.maintenanceBlocked);
  });

  test(
    '42 transient resume failure preserves mandatory update block',
    () async {
      var now = DateTime.utc(2026, 9, 9, 12);
      final gateway = _FakeGateway(
        (call) async => call == 1
            ? _bootstrap(forceUpdate: true)
            : throw StateError('offline'),
      );
      final controller = ProductReadinessController(
        gateway: gateway,
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      now = now.add(const Duration(minutes: 6));
      await controller.onResume();
      expect(controller.status, ProductReadinessStatus.updateBlocked);
    },
  );

  test('43 stale async result cannot overwrite newer result', () async {
    final first = Completer<ProductBootstrap>();
    final second = Completer<ProductBootstrap>();
    final gateway = _FakeGateway(
      (call) => call == 1 ? first.future : second.future,
    );
    final controller = ProductReadinessController(gateway: gateway);
    addTearDown(controller.dispose);
    final initial = controller.initialize();
    final retry = controller.retry();
    second.complete(_bootstrap(maintenance: true));
    await retry;
    first.complete(_bootstrap());
    await initial;
    expect(controller.status, ProductReadinessStatus.maintenanceBlocked);
  });

  test(
    '44 configured=false is successful for resume cache semantics',
    () async {
      var now = DateTime.utc(2026, 9, 9, 12);
      final gateway = _FakeGateway(
        (call) async => call == 1
            ? _bootstrap(configured: false)
            : throw StateError('offline'),
      );
      final controller = ProductReadinessController(
        gateway: gateway,
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final checkedAt = controller.lastSuccessfulCheckAt;
      now = now.add(const Duration(minutes: 6));
      await controller.onResume();
      expect(controller.status, ProductReadinessStatus.allowed);
      expect(controller.lastSuccessfulCheckAt, checkedAt);
    },
  );

  test('45 readiness failure never clears AuthStorage session', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(secureStore: _MemorySecureStore());
    await storage.writeTokenPair(
      const AuthTokens(
        accessToken: 'access-value',
        refreshToken: 'refresh-value',
      ),
    );
    final controller = ProductReadinessController(
      gateway: _FakeGateway((_) async => throw StateError('offline')),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final pair = await storage.readTokenPair();
    expect(pair?.accessToken, 'access-value');
    expect(pair?.refreshToken, 'refresh-value');
  });

  test('46 non-mobile readiness is notApplicable', () {
    expect(
      ProductReadinessPlatform.applies(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      ProductReadinessPlatform.applies(
        isWeb: false,
        platform: TargetPlatform.iOS,
      ),
      isTrue,
    );
    expect(
      ProductReadinessPlatform.applies(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    for (final platform in const [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(
        ProductReadinessPlatform.applies(isWeb: false, platform: platform),
        isFalse,
        reason: platform.name,
      );
    }
    final controller = ProductReadinessController(
      gateway: _FakeGateway((_) async => _bootstrap()),
      appliesToCurrentPlatform: false,
    );
    expect(controller.status, ProductReadinessStatus.notApplicable);
    controller.dispose();
  });

  testWidgets('47 web/non-mobile gate mounts child immediately', (
    tester,
  ) async {
    _MountProbe.mounts = 0;
    final gateway = _FakeGateway((_) async => _bootstrap());
    final controller = ProductReadinessController(
      gateway: gateway,
      appliesToCurrentPlatform: false,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductReadinessGate(
          controller: controller,
          child: const _MountProbe('NON-MOBILE CHILD'),
        ),
      ),
    );
    expect(find.text('NON-MOBILE CHILD'), findsOneWidget);
    expect(_MountProbe.mounts, 1);
  });

  test('48 non-mobile path makes zero bootstrap gateway calls', () async {
    final gateway = _FakeGateway((_) async => _bootstrap());
    final controller = ProductReadinessController(
      gateway: gateway,
      appliesToCurrentPlatform: false,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.retry();
    expect(gateway.calls, 0);
    expect(controller.lastSuccessfulBootstrap, isNull);
  });

  test('49 non-mobile resume makes zero readiness gateway calls', () async {
    final gateway = _FakeGateway((_) async => _bootstrap());
    final controller = ProductReadinessController(
      gateway: gateway,
      appliesToCurrentPlatform: false,
    );
    addTearDown(controller.dispose);
    await controller.onResume();
    await controller.onResume();
    expect(gateway.calls, 0);
    expect(controller.lastSuccessfulCheckAt, isNull);
  });

  test('50 mobile Android and iOS behavior remains gated', () async {
    for (final platform in ProductMobilePlatform.values) {
      final gateway = _FakeGateway(
        (_) async => _bootstrap(
          platform: platform,
          maintenance: true,
          storeUrl: platform == ProductMobilePlatform.android
              ? _androidStore
              : _iosStore,
        ),
      );
      final controller = ProductReadinessController(
        gateway: gateway,
        appliesToCurrentPlatform: true,
      );
      await controller.initialize();
      expect(gateway.calls, 1, reason: platform.name);
      expect(
        controller.status,
        ProductReadinessStatus.maintenanceBlocked,
        reason: platform.name,
      );
      controller.dispose();
    }
  });
}
