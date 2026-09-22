import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/product/product_bootstrap_models.dart';
import '../../core/product/product_readiness_controller.dart';
import '../../core/product/product_store_launcher.dart';
import 'maintenance_screen.dart';
import 'update_required_screen.dart';

class ProductReadinessGate extends StatefulWidget {
  final Widget child;
  final ProductReadinessController? controller;
  final ProductStoreLauncher? storeLauncher;

  const ProductReadinessGate({
    super.key,
    required this.child,
    this.controller,
    this.storeLauncher,
  });

  @override
  State<ProductReadinessGate> createState() => _ProductReadinessGateState();
}

class _ProductReadinessGateState extends State<ProductReadinessGate>
    with WidgetsBindingObserver {
  late ProductReadinessController _controller;
  late bool _ownsController;
  late ProductStoreLauncher _storeLauncher;
  bool _launching = false;
  bool _launchFailed = false;

  @override
  void initState() {
    super.initState();
    _setDependencies();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.initialize());
  }

  @override
  void didUpdateWidget(covariant ProductReadinessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      if (_ownsController) _controller.dispose();
      _setDependencies();
      _launchFailed = false;
      unawaited(_controller.initialize());
    } else if (!identical(oldWidget.storeLauncher, widget.storeLauncher)) {
      _storeLauncher =
          widget.storeLauncher ?? const ExternalProductStoreLauncher();
    }
  }

  void _setDependencies() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ProductReadinessController.production();
    _storeLauncher =
        widget.storeLauncher ?? const ExternalProductStoreLauncher();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.onResume());
    }
  }

  Future<void> _retry() async {
    setState(() => _launchFailed = false);
    await _controller.retry();
  }

  Future<void> _launchRequired(Uri uri) async {
    setState(() {
      _launching = true;
      _launchFailed = false;
    });
    var launched = false;
    try {
      launched = await _storeLauncher.launch(uri);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() {
      _launching = false;
      _launchFailed = !launched;
    });
  }

  void _scheduleOptionalUpdate(ProductBootstrap bootstrap) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _controller.status != ProductReadinessStatus.allowed) {
        return;
      }
      final uri = ProductStoreUrlValidator.trustedUri(
        bootstrap.storeUrl,
        bootstrap.platform,
      );
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Une mise à jour est disponible'),
          content: const Text(
            'Une nouvelle version d’EnactSpace est disponible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Plus tard'),
            ),
            if (uri != null)
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  var launched = false;
                  try {
                    launched = await _storeLauncher.launch(uri);
                  } catch (_) {
                    launched = false;
                  }
                  if (!mounted || launched) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Impossible d’ouvrir la boutique pour le moment.',
                      ),
                    ),
                  );
                },
                child: const Text('Mettre à jour'),
              ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bootstrap = _controller.lastSuccessfulBootstrap;
        switch (_controller.status) {
          case ProductReadinessStatus.notApplicable:
            return widget.child;
          case ProductReadinessStatus.checking:
            return const _ProductCheckingScreen();
          case ProductReadinessStatus.unavailable:
            return MaintenanceScreen(
              message:
                  'EnactSpace ne peut pas vérifier la disponibilité du service. Veuillez réessayer.',
              checking: _controller.inFlight,
              onRetry: _retry,
              onPrivacy: () => context.go('/legal/privacy'),
              onTerms: () => context.go('/legal/terms'),
            );
          case ProductReadinessStatus.maintenanceBlocked:
            final serverMessage = bootstrap?.maintenance.message?.trim();
            return MaintenanceScreen(
              message: serverMessage == null || serverMessage.isEmpty
                  ? 'Nous effectuons une maintenance. Veuillez réessayer dans quelques instants.'
                  : serverMessage,
              checking: _controller.inFlight,
              onRetry: _retry,
              onPrivacy: () => context.go('/legal/privacy'),
              onTerms: () => context.go('/legal/terms'),
            );
          case ProductReadinessStatus.updateBlocked:
            final uri = bootstrap == null
                ? null
                : ProductStoreUrlValidator.trustedUri(
                    bootstrap.storeUrl,
                    bootstrap.platform,
                  );
            return UpdateRequiredScreen(
              storeUri: uri,
              onUpdate: uri == null ? null : () => _launchRequired(uri),
              onRetry: _retry,
              checking: _controller.inFlight,
              launching: _launching,
              launchFailed: _launchFailed,
            );
          case ProductReadinessStatus.allowed:
            final optional = _controller.consumeOptionalUpdate();
            if (optional != null) _scheduleOptionalUpdate(optional);
            return widget.child;
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }
}

class _ProductCheckingScreen extends StatelessWidget {
  const _ProductCheckingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                BrandAssets.icon512,
                width: 88,
                height: 88,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.hub_rounded, size: 64),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Vérification du service…'),
            ],
          ),
        ),
      ),
    );
  }
}
