import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/biometric_authenticator.dart';
import '../../../core/brand/brand_assets.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final AuthService? authService;
  final BiometricAuthenticator? biometrics;
  const SplashScreen({super.key, this.authService, this.biometrics});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AuthService _authService;
  late final BiometricAuthenticator _biometrics;
  bool _retry = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _biometrics = widget.biometrics ?? BiometricAuthenticator();
    unawaited(_continue());
  }

  Future<void> _continue() async {
    if (!mounted) return;
    setState(() => _retry = false);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    try {
      final hasSession = await _authService.isLoggedIn();
      final biometricAvailable = hasSession && await _biometrics.isAvailable();
      if (!mounted) return;
      if (biometricAvailable) {
        context.go('/login?unlock=1');
        return;
      }
      if (!hasSession) {
        context.go('/login');
        return;
      }
      final restored = await _authService.restoreSession();
      if (!mounted) return;
      context.go(restored ? '/dashboard' : '/login');
    } catch (_) {
      if (mounted) setState(() => _retry = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 520 || size.height < 680;
    final logoWidth = (size.width * 0.64).clamp(220.0, 420.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    BrandAssets.logoFull,
                    width: logoWidth,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: isCompact ? 18 : 28),
                  const Text(
                    'Gestion interne Enactus ESP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.softBlack,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_retry) ...[
                    const Text(
                      'Connexion temporairement indisponible. Votre session est conservée.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _continue,
                      child: const Text('Réessayer'),
                    ),
                  ] else
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
