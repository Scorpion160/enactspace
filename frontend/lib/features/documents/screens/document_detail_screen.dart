import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document_center_models.dart';
import '../models/document_model.dart';
import '../services/documents_gateway.dart';
import '../widgets/document_form_dialog.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;
  final DocumentsGateway? gateway;
  const DocumentDetailScreen({
    super.key,
    required this.documentId,
    this.gateway,
  });
  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late final DocumentsGateway _gateway =
      widget.gateway ?? ApiDocumentsGateway();
  DocumentModel? _document;
  DocumentReferenceData _references = const DocumentReferenceData();
  bool _loading = true, _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _gateway.loadDocument(widget.documentId),
        _gateway.loadReferences(),
      ]);
      if (mounted) {
        setState(() {
          _document = values[0] as DocumentModel;
          _references = values[1] as DocumentReferenceData;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _msg(error);
        });
      }
    }
  }

  Future<void> _edit() async {
    final result = await showDocumentFormDialog(
      context,
      gateway: _gateway,
      references: _references,
      document: _document,
    );
    if (result == null || !mounted) return;
    await _mutate(
      () => _gateway.updateDocument(
        _document!.id,
        result.draft,
        replaceFile: result.replaceFile,
      ),
    );
  }

  Future<void> _mutate(Future<DocumentModel> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final updated = await action();
      if (mounted) setState(() => _document = updated);
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _confirmValidate() async {
    final ok = await _confirm('Valider ce document comme document officiel ?');
    if (ok) await _mutate(() => _gateway.validate(_document!.id));
  }

  Future<void> _reject() async {
    final updated = await showDialog<DocumentModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _RejectDialog(gateway: _gateway, documentId: _document!.id),
    );
    if (updated != null && mounted) setState(() => _document = updated);
  }

  Future<void> _archive() async {
    final ok = await _confirm('Archiver ce document ?');
    if (ok) await _mutate(() => _gateway.archive(_document!.id));
  }

  Future<void> _delete() async {
    final ok = await _confirm('Supprimer définitivement ce document ?');
    if (!ok) return;
    try {
      await _gateway.deleteDocument(_document!.id);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openFile() async {
    final uri = Uri.tryParse(_document!.fileUrl ?? '');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _notice('Le fichier ne peut pas être ouvert.', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _document == null) {
      return Scaffold(
        body: Center(child: Text(_error ?? 'Document introuvable.')),
      );
    }
    final doc = _document!;
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche document')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        Chip(label: Text(doc.statusLabel)),
                        Chip(label: Text(doc.visibilityLabel)),
                        if (doc.isOfficial)
                          const Chip(
                            avatar: Icon(Icons.verified_rounded, size: 17),
                            label: Text('Officiel'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      doc.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              if (doc.canManage)
                OutlinedButton.icon(
                  onPressed: _acting ? null : _edit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier document'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            'Résumé',
            Icons.description_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.description?.trim().isNotEmpty == true
                      ? doc.description!
                      : 'Aucune description.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Datum('Catégorie', doc.categoryLabel),
                    _Datum('Statut', doc.statusLabel),
                    _Datum('Visibilité', doc.visibilityLabel),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            'Fichier',
            Icons.attach_file_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName(doc.fileUrl) ?? doc.fileTypeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (doc.fileUrl != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Télécharger'),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Le fichier est stocké dans EnactSpace.'),
                  ),
              ],
            ),
          ),
          _Section(
            'Périmètre',
            Icons.account_tree_rounded,
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Datum('Pôle', _references.poleName(doc.poleId) ?? 'Non lié'),
                _Datum(
                  'Projet',
                  _references.projectName(doc.projectId) ?? 'Non lié',
                ),
                _Datum(
                  'Événement',
                  _references.eventName(doc.eventId) ?? 'Non lié',
                ),
                if (doc.seasonId != null)
                  _Datum(
                    'Saison',
                    _references.seasonName(doc.seasonId) ??
                        'Référence indisponible',
                  ),
              ],
            ),
          ),
          _Section(
            'Validation',
            Icons.verified_user_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Datum('Officiel', doc.isOfficial ? 'Oui' : 'Non'),
                    _Datum('Permanent', doc.isPermanent ? 'Oui' : 'Non'),
                    if (doc.validatedBy != null)
                      _Datum('Validé par', doc.validatedBy!),
                    if (doc.validatedAt != null)
                      _Datum('Date de validation', _date(doc.validatedAt!)),
                    if (doc.rejectedBy != null)
                      _Datum('Rejeté par', doc.rejectedBy!),
                    if (doc.rejectedAt != null)
                      _Datum('Date du rejet', _date(doc.rejectedAt!)),
                    if (doc.expiresAt != null)
                      _Datum('Expiration', _date(doc.expiresAt!)),
                  ],
                ),
                if (doc.rejectionReason?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Motif du rejet : ${doc.rejectionReason}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    if (doc.canManage &&
                        (doc.status == 'draft' || doc.status == 'rejected'))
                      OutlinedButton.icon(
                        onPressed: _acting
                            ? null
                            : () => _mutate(() => _gateway.submit(doc.id)),
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Soumettre'),
                      ),
                    if (doc.canValidate && !doc.isValidated)
                      FilledButton.icon(
                        onPressed: _acting ? null : _confirmValidate,
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Valider'),
                      ),
                    if (doc.canValidate && doc.isValidated)
                      OutlinedButton.icon(
                        onPressed: _acting
                            ? null
                            : () => _mutate(() => _gateway.unvalidate(doc.id)),
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Retirer la validation'),
                      ),
                    if (doc.canValidate && !doc.isRejected)
                      OutlinedButton.icon(
                        onPressed: _acting ? null : _reject,
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Rejeter'),
                      ),
                    if (doc.canValidate && doc.status != 'archived')
                      OutlinedButton.icon(
                        onPressed: _acting ? null : _archive,
                        icon: const Icon(Icons.archive_rounded),
                        label: const Text('Archiver'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            'Métadonnées',
            Icons.info_outline_rounded,
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (doc.uploadedBy != null)
                  _Datum('Déposé par', doc.uploadedBy!),
                _Datum(
                  'Créé le',
                  doc.createdAt == null
                      ? 'Non disponible'
                      : _date(doc.createdAt!),
                ),
                if (doc.updatedAt != null)
                  _Datum('Mis à jour le', _date(doc.updatedAt!)),
                if (doc.isTemplate) const _Datum('Modèle', 'Oui'),
              ],
            ),
          ),
          if (doc.canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('delete-document'),
                onPressed: _acting ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer document'),
              ),
            ),
        ],
      ),
    );
  }

  void _notice(String message, bool error) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

class _RejectDialog extends StatefulWidget {
  final DocumentsGateway gateway;
  final String documentId;
  const _RejectDialog({required this.gateway, required this.documentId});
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Le motif est obligatoire.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final value = await widget.gateway.reject(
        widget.documentId,
        _reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, value);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = _msg(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rejeter le document'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('rejection-reason'),
          controller: _reason,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Motif obligatoire'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const Key('confirm-rejection'),
        onPressed: _submitting ? null : _submit,
        child: const Text('Rejeter'),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(this.title, this.icon, this.child);
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _Datum extends StatelessWidget {
  final String label, value;
  const _Datum(this.label, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

String? _fileName(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url);
  return uri == null || uri.pathSegments.isEmpty
      ? null
      : Uri.decodeComponent(uri.pathSegments.last);
}

String _date(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : DateFormat('dd/MM/yyyy HH:mm').format(parsed);
}

String _msg(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
