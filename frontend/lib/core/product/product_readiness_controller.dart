import 'package:flutter/foundation.dart';

import 'product_bootstrap_gateway.dart';
import 'product_bootstrap_models.dart';

enum ProductReadinessStatus {
  notApplicable,
  checking,
  allowed,
  maintenanceBlocked,
  updateBlocked,
  unavailable,
}

class ProductReadinessController extends ChangeNotifier {
  final ProductBootstrapGateway gateway;
  final DateTime Function() now;
  final Duration successfulCheckCooldown;
  final bool appliesToCurrentPlatform;

  ProductReadinessStatus _status;
  ProductBootstrap? _lastSuccessfulBootstrap;
  DateTime? _lastSuccessfulCheckAt;
  int _generation = 0;
  bool _inFlight = false;
  int? _optionalUpdatePresentedBuild;
  bool _disposed = false;

  ProductReadinessController({
    required this.gateway,
    DateTime Function()? now,
    this.successfulCheckCooldown = const Duration(minutes: 5),
    this.appliesToCurrentPlatform = true,
  }) : now = now ?? DateTime.now,
       _status = appliesToCurrentPlatform
           ? ProductReadinessStatus.checking
           : ProductReadinessStatus.notApplicable;

  factory ProductReadinessController.production() => ProductReadinessController(
    gateway: ApiProductBootstrapGateway(),
    appliesToCurrentPlatform: ProductReadinessPlatform.appliesToCurrentTarget,
  );

  ProductReadinessStatus get status => _status;
  ProductBootstrap? get lastSuccessfulBootstrap => _lastSuccessfulBootstrap;
  DateTime? get lastSuccessfulCheckAt => _lastSuccessfulCheckAt;
  bool get inFlight => _inFlight;
  bool get optionalUpdateAvailable =>
      _status == ProductReadinessStatus.allowed &&
      (_lastSuccessfulBootstrap?.updateAvailable ?? false) &&
      !(_lastSuccessfulBootstrap?.updateRequired ?? false) &&
      !(_lastSuccessfulBootstrap?.forceUpdate ?? false);

  Future<void> initialize() =>
      appliesToCurrentPlatform ? _check() : Future<void>.value();

  Future<void> retry() =>
      appliesToCurrentPlatform ? _check() : Future<void>.value();

  Future<void> onResume() async {
    if (!appliesToCurrentPlatform) return;
    final checkedAt = _lastSuccessfulCheckAt;
    if (_inFlight ||
        (checkedAt != null &&
            now().difference(checkedAt) < successfulCheckCooldown)) {
      return;
    }
    await _check();
  }

  ProductBootstrap? consumeOptionalUpdate() {
    final bootstrap = _lastSuccessfulBootstrap;
    final target = bootstrap?.currentBuildNumber;
    if (!optionalUpdateAvailable ||
        bootstrap == null ||
        target == null ||
        _optionalUpdatePresentedBuild == target) {
      return null;
    }
    _optionalUpdatePresentedBuild = target;
    return bootstrap;
  }

  Future<void> _check() async {
    if (!appliesToCurrentPlatform) return;
    final requestGeneration = ++_generation;
    _inFlight = true;
    if (_lastSuccessfulBootstrap == null) {
      _status = ProductReadinessStatus.checking;
    }
    _notify();
    try {
      final bootstrap = await gateway.fetch();
      if (!_isCurrent(requestGeneration)) return;
      _lastSuccessfulBootstrap = bootstrap;
      _lastSuccessfulCheckAt = now();
      _status = _statusFor(bootstrap);
    } catch (_) {
      if (!_isCurrent(requestGeneration)) return;
      if (_lastSuccessfulBootstrap == null) {
        _status = ProductReadinessStatus.unavailable;
      } else {
        _status = _statusFor(_lastSuccessfulBootstrap!);
      }
    } finally {
      if (_isCurrent(requestGeneration)) {
        _inFlight = false;
        _notify();
      }
    }
  }

  ProductReadinessStatus _statusFor(ProductBootstrap bootstrap) {
    if (bootstrap.maintenance.active) {
      return ProductReadinessStatus.maintenanceBlocked;
    }
    if (bootstrap.updateRequired || bootstrap.forceUpdate) {
      return ProductReadinessStatus.updateBlocked;
    }
    return ProductReadinessStatus.allowed;
  }

  bool _isCurrent(int requestGeneration) =>
      !_disposed && requestGeneration == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
