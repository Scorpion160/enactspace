import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/brand/brand_assets.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    unawaited(_continue());
  }

  Future<void> _continue() async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final loggedIn = await _authService.isLoggedIn();
    if (!mounted) return;
    context.go(loggedIn ? '/dashboard' : '/login');
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
