import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/push/push_lifecycle_controller.dart';
import '../../legal/models/legal_models.dart';
import '../../legal/services/legal_gateway.dart';

class LegalAcceptanceGate extends StatefulWidget {
  final Widget child;
  final LegalGateway? gateway;
  final Future<void> Function()? onLogout;
  final bool? testIsWeb;
  final TargetPlatform? testPlatform;

  const LegalAcceptanceGate({
    super.key,
    required this.child,
    this.gateway,
    this.onLogout,
    this.testIsWeb,
    this.testPlatform,
  });

  @override
  State<LegalAcceptanceGate> createState() => _LegalAcceptanceGateState();
}

class _LegalAcceptanceGateState extends State<LegalAcceptanceGate> {
  late final LegalGateway _gateway;
  bool _loading = true;
  bool _accepting = false;
  String? _error;
  LegalStatus? _pending;
  LegalDocument? _document;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiLegalGateway();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = await _gateway.loadStatus();
      final pending = statuses.where((item) => item.pending).firstOrNull;
      LegalDocument? document;
      if (pending != null) {
        document = await _gateway.loadDocumentForAcceptance(pending);
        if (document == null || !document.matchesStatus(pending)) {
          throw StateError('Version juridique requise indisponible');
        }
      }
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _document = document;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _pending = null;
          _document = null;
          _error = 'Impossible de vérifier les documents à accepter.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final pending = _pending;
    final document = _document;
    if (pending == null || _accepting) return;
    if (document == null || !document.matchesStatus(pending)) {
      setState(() {
        _pending = null;
        _document = null;
        _error = 'La version exacte du document n’est plus disponible.';
      });
      return;
    }
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await _gateway.accept(
        pending,
        legalAcceptanceSource(
          isWeb: widget.testIsWeb ?? kIsWeb,
          platform: widget.testPlatform ?? defaultTargetPlatform,
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'L’acceptation n’a pas pu être enregistrée. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _logout() async {
    try {
      await runLogoutWithPushCleanup(
        cleanup: () => PushLifecycleController.instance.cleanupForLogout(
          allDevices: false,
        ),
        logout: widget.onLogout ?? AuthService().logout,
      );
    } finally {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _pending == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Documents importants')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_pending == null) return widget.child;
    final document = _document!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Votre accord est requis'),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SelectionArea(
                child: ListView(
                  key: const Key('legal-gate-scroll'),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 6),
                                Text('Version ${document.version}'),
                                const Divider(height: 32),
                                SelectableText(document.content),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _error ??
                              'Lisez le document avant de confirmer votre accord.',
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: _accepting ? null : _accept,
                        child: Text(
                          _accepting ? 'Enregistrement…' : 'J’accepte',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
