import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
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
  LegalDocument? _offlineDocument;
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
      _offlineDocument = null;
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
      if (document == null) throw StateError('Aucune version publiée');
      if (mounted) setState(() => _document = document);
    } catch (_) {
      try {
        final filename = widget.documentType == 'privacy_policy'
            ? 'privacy_policy_v1.md'
            : 'terms_of_use_v1.md';
        final content = await rootBundle.loadString('assets/legal/$filename');
        if (mounted) {
          setState(
            () => _offlineDocument = LegalDocument(
              id: 'offline-v1',
              type: widget.documentType,
              version: '1.0',
              title: _fallbackTitle,
              content: content,
              effectiveAt: DateTime(2026, 9, 29),
              requiresAcceptance: true,
            ),
          );
        }
      } catch (_) {
        if (mounted) setState(() => _error = 'Document indisponible.');
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
    final document = _document ?? _offlineDocument;
    return Scaffold(
      appBar: AppBar(
        title: Text(document?.title ?? _fallbackTitle),
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
    final document = _document ?? _offlineDocument;
    if (document == null) {
      return const _CenteredState(
        icon: Icons.description_outlined,
        message: 'Aucun document actif n’est disponible pour le moment.',
      );
    }
    final offline = _document == null && _offlineDocument != null;
    return SelectionArea(
      child: ListView(
        key: const Key('legal-document-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: _LegalDocumentCard(document: document, offline: offline),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentCard extends StatelessWidget {
  final LegalDocument document;
  final bool offline;

  const _LegalDocumentCard({required this.document, required this.offline});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 20 : 28),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.enactusYellow.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppTheme.enactusYellow,
                      ),
                    ),
                    _OfficialBadge(offline: offline),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  document.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version ${document.version}${_effectiveSuffix(document)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (offline) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Copie officielle embarquée — disponible hors connexion',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 32,
              compact ? 22 : 30,
              compact ? 20 : 32,
              compact ? 28 : 36,
            ),
            child: _LegalContent(content: document.content),
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

class _OfficialBadge extends StatelessWidget {
  final bool offline;

  const _OfficialBadge({required this.offline});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.16),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            offline ? Icons.offline_pin_rounded : Icons.verified_rounded,
            size: 17,
            color: colors.onSurface,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Document officiel · Validé par Enactus ESP',
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  final String content;

  const _LegalContent({required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    var afterHeading = false;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        widgets.add(SizedBox(height: afterHeading ? 6 : 10));
        afterHeading = false;
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              _clean(line.substring(3)),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        );
        afterHeading = true;
        continue;
      }
      if (line.startsWith('# ')) {
        widgets.add(
          Text(
            _clean(line.substring(2)),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        );
        afterHeading = true;
        continue;
      }
      if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.enactusYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _clean(line.substring(2)),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      widgets.add(
        Text(
          _clean(line),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.62,
            color: colors.onSurface,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  String _clean(String value) => value.replaceAll('**', '').replaceAll('`', '');
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
