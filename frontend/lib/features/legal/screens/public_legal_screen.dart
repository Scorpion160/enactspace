import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/legal_models.dart';
import '../services/legal_gateway.dart';

class PublicLegalScreen extends StatefulWidget {
  final String documentType;
  final LegalGateway? gateway;

  const PublicLegalScreen({
    super.key,
    required this.documentType,
    this.gateway,
  });

  @override
  State<PublicLegalScreen> createState() => _PublicLegalScreenState();
}

class _PublicLegalScreenState extends State<PublicLegalScreen> {
  late LegalGateway _gateway;
  LegalDocument? _document;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiLegalGateway();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublicLegalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentType != widget.documentType ||
        oldWidget.gateway != widget.gateway) {
      _gateway = widget.gateway ?? ApiLegalGateway();
      _document = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final document = await _gateway.loadPublicDocument(widget.documentType);
      if (mounted) setState(() => _document = document);
    } catch (_) {
      if (mounted) {
        setState(() {
          _document = null;
          _error =
              'Impossible de charger ce document. Réessayez dans un instant.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _fallbackTitle => widget.documentType == 'privacy_policy'
      ? 'Politique de confidentialité'
      : 'Conditions d’utilisation';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_document?.title ?? _fallbackTitle),
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/about'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _CenteredState(
        icon: Icons.cloud_off_rounded,
        message: _error!,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      );
    }
    final document = _document;
    if (document == null) {
      return const _CenteredState(
        icon: Icons.description_outlined,
        message: 'Aucun document actif n’est disponible pour le moment.',
      );
    }
    return SelectionArea(
      child: ListView(
        key: const Key('legal-document-scroll'),
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
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version ${document.version}${_effectiveSuffix(document)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 32),
                      SelectableText(
                        document.content,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _effectiveSuffix(LegalDocument document) {
    if (document.effectiveAt == null) return '';
    return ' · applicable le ${DateFormat('dd/MM/yyyy', 'fr_FR').format(document.effectiveAt!.toLocal())}';
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _CenteredState({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    ),
  );
}
