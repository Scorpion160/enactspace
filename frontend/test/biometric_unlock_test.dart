import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/core/auth/biometric_authenticator.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/splash/screens/splash_screen.dart';

class _Auth extends AuthService {
  final bool session;
  bool valid;
  int restores = 0;
  _Auth({this.session = true, this.valid = true});
  @override
  Future<bool> isLoggedIn() async => session;
  @override
  Future<Map<String, dynamic>?> getCachedCurrentUser() async => {
    'email': 'test@example.test',
  };
  @override
  Future<bool> restoreSession() async {
    restores++;
    return valid;
  }
}

class _Biometrics extends BiometricAuthenticator {
  bool available;
  bool accepted;
  int attempts = 0;
  _Biometrics({this.available = true, this.accepted = false});
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<bool> authenticate() async {
    attempts++;
    return accepted;
  }
}

GoRouter _router(_Auth auth, _Biometrics bio, {bool splash = false}) =>
    GoRouter(
      initialLocation: splash ? '/splash' : '/login?unlock=1',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => SplashScreen(authService: auth, biometrics: bio),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginScreen(authService: auth, biometrics: bio),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Session ouverte')),
        ),
      ],
    );
void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  testWidgets(
    'saved session offers biometrics without a remembered identifier and cancellation stays on login',
    (tester) async {
      final auth = _Auth();
      final bio = _Biometrics();
      final router = _router(auth, bio);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(bio.attempts, 1);
      expect(auth.restores, 0);
      expect(find.byKey(const Key('biometric_unlock')), findsOneWidget);
      expect(find.text('Session ouverte'), findsNothing);
      bio.accepted = true;
      await tester.ensureVisible(find.byKey(const Key('biometric_unlock')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('biometric_unlock')));
      await tester.pumpAndSettle();
      expect(bio.attempts, 2);
      expect(auth.restores, 1);
      expect(find.text('Session ouverte'), findsOneWidget);
    },
  );
  testWidgets('biometric success does not open an expired session', (
    tester,
  ) async {
    final auth = _Auth(valid: false);
    final bio = _Biometrics(accepted: true);
    final router = _router(auth, bio);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('La session sécurisée a expiré'),
      findsOneWidget,
    );
    expect(find.text('Session ouverte'), findsNothing);
    expect(find.byKey(const Key('biometric_unlock')), findsNothing);
  });
  testWidgets(
    'no saved session means password login without biometric attempt',
    (tester) async {
      final auth = _Auth(session: false);
      final bio = _Biometrics();
      final router = _router(auth, bio);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(bio.attempts, 0);
      expect(find.byKey(const Key('biometric_unlock')), findsNothing);
    },
  );
  testWidgets(
    'cold start requests biometrics for a saved session even without an identifier preference',
    (tester) async {
      final auth = _Auth();
      final bio = _Biometrics();
      final router = _router(auth, bio, splash: true);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(bio.attempts, 1);
      expect(auth.restores, 0);
      expect(find.text('Session ouverte'), findsNothing);
    },
  );
  testWidgets(
    'device without biometrics restores its existing session normally',
    (tester) async {
      final auth = _Auth();
      final bio = _Biometrics(available: false);
      final router = _router(auth, bio, splash: true);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(bio.attempts, 0);
      expect(auth.restores, 1);
      expect(find.text('Session ouverte'), findsOneWidget);
    },
  );
}
