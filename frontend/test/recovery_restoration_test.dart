import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_service.dart';
import 'package:frontend/features/documents/services/documents_service.dart';

class _TokenAuthService extends AuthService {
  @override
  Future<String?> getToken() async => 'test-token';

  @override
  Future<Map<String, dynamic>?> getCachedCurrentUser() async => {
    'id': 'member-1',
  };
}

class _DocumentsApi extends ApiClient {
  final dynamic payload;
  final bool offline;

  _DocumentsApi.online(this.payload) : offline = false;
  _DocumentsApi.offline() : payload = null, offline = true;

  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (offline) throw http.ClientException('offline');
    return payload;
  }
}

class _MemoryDocumentCache implements DocumentOfflineCacheStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
  @override
  Future<void> delete() async => value = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login remembers only the identifier in secure storage', () {
    final source = File(
      'lib/core/auth/login_preferences.dart',
    ).readAsStringSync();
    expect(source, contains('FlutterSecureStorage'));
    expect(source, contains('enactspace.auth.login_identifier'));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source.toLowerCase(), isNot(contains('password')));
  });

  test('documents remain listable from the secure offline cache', () async {
    final cache = _MemoryDocumentCache();
    final sample = [
      {
        'id': 'doc-1',
        'title': 'PV réunion mensuelle',
        'status': 'validated',
        'category': 'pv',
        'visibility': 'internal',
        'is_template': false,
        'is_official': true,
        'can_manage': false,
        'can_validate': false,
        'is_permanent': true,
      },
    ];
    final online = DocumentsService(
      authService: _TokenAuthService(),
      offlineCache: cache,
      apiClient: _DocumentsApi.online(sample),
    );
    expect((await online.getDocuments()).single.title, 'PV réunion mensuelle');
    expect(cache.value, isNotNull);

    final offline = DocumentsService(
      authService: _TokenAuthService(),
      offlineCache: cache,
      apiClient: _DocumentsApi.offline(),
    );
    final cached = await offline.getDocuments(search: 'réunion');
    expect(cached.single.id, 'doc-1');
    expect(offline.lastLoadUsedOfflineCache, isTrue);
  });

  test('restored public/auth UI contract stays in source', () {
    final login = File(
      'lib/features/auth/screens/login_screen.dart',
    ).readAsStringSync();
    expect(login, contains('Email ou nom d’utilisateur'));
    expect(login, contains('BiometricAuthenticator'));
    final biometrics = File(
      'lib/core/auth/biometric_authenticator.dart',
    ).readAsStringSync();
    expect(biometrics, contains('LocalAuthentication'));
    expect(biometrics, contains('biometricOnly: true'));
    expect(login, contains('_automaticBiometricAttempted'));
    expect(login, contains("'Créer un compte'"));
    expect(login, contains("'Je suis Alumni'"));
    expect(login, contains("_PublicDialogTitle('Mot de passe oublié')"));
    expect(login, contains("_PublicDialogTitle('Guide débutant')"));
    expect(login, isNot(contains('Photo de profil (lien)')));
    expect(login, isNot(contains("label: 'LinkedIn'")));
    expect(login, isNot(contains("labelText: 'Compétences clés'")));
    expect(login, contains('if (_isAlumni) ...['));
    expect(login, isNot(contains('Compte Enacteur / Enactrice')));
    expect(login, isNot(contains('Activer bient?t')));

    final recruitment = File(
      'lib/features/recruitment/widgets/public/public_recruitment_widgets.dart',
    ).readAsStringSync();
    expect(recruitment, isNot(contains('L’impact en mouvement')));
    expect(recruitment, isNot(contains('logo_enactus_esp.png')));
    expect(recruitment, isNot(contains('showHeader')));

    final secondaryDialogTitle = login.substring(
      login.indexOf('class _PublicDialogTitle'),
      login.indexOf('class _BrandMark'),
    );
    expect(secondaryDialogTitle, isNot(contains('_PublicInlineHeader')));

    final joinSection = login.substring(
      login.indexOf("'Rejoindre Enactus ESP'"),
      login.indexOf('class _JoinField'),
    );
    expect(joinSection, isNot(contains('_PublicInlineHeader')));
  });

  test('selectors share EnactSpace segmented and chip design', () {
    final theme = File('lib/core/theme/app_theme.dart').readAsStringSync();
    expect(theme, contains('segmentedButtonTheme:'));
    expect(theme, contains('chipTheme: _chipTheme'));
    for (final path in [
      'lib/features/attendance/screens/attendance_screen.dart',
      'lib/features/chat/screens/chat_screen.dart',
      'lib/features/documents/widgets/institutional_request_form.dart',
      'lib/features/events/screens/events_screen.dart',
      'lib/features/meetings/screens/meeting_detail_screen.dart',
      'lib/features/settings/screens/settings_screen.dart',
      'lib/features/tasks/screens/tasks_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('expandedInsets: EdgeInsets.zero'), reason: path);
      expect(source, contains('showSelectedIcon:'), reason: path);
    }
  });

  test(
    'gamification refresh is gesture based, not a visible refresh button',
    () {
      final source = File(
        'lib/features/gamification/screens/gamification_screen.dart',
      ).readAsStringSync();
      expect(source, contains('return RefreshIndicator('));
      expect(source, isNot(contains("label: Text('Actualiser')")));
    },
  );

  test('native biometric integration is configured once', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.USE_BIOMETRIC'));
    final activity = File(
      'android/app/src/main/kotlin/sn/enactusesp/enactspace/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('FlutterFragmentActivity'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(RegExp('NSFaceIDUsageDescription').allMatches(plist).length, 1);
  });
}
