import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/user_experience.dart';
import '../models/document_center_models.dart';
import '../models/institutional_document_models.dart';
import '../services/documents_gateway.dart';
import '../services/institutional_documents_gateway.dart';
import '../widgets/institutional_request_form.dart';
import 'documents_screen.dart';

class InstitutionalDocumentsHubScreen extends StatefulWidget {
  final DocumentsGateway? documentsGateway;
  final InstitutionalDocumentsGateway? institutionalGateway;

  const InstitutionalDocumentsHubScreen({
    super.key,
    this.documentsGateway,
    this.institutionalGateway,
  });

  @override
  State<InstitutionalDocumentsHubScreen> createState() =>
      _InstitutionalDocumentsHubScreenState();
}

class _InstitutionalDocumentsHubScreenState
    extends State<InstitutionalDocumentsHubScreen>
    with SingleTickerProviderStateMixin {
  late final DocumentsGateway _documentsGateway =
      widget.documentsGateway ?? ApiDocumentsGateway();
  late final InstitutionalDocumentsGateway _institutionalGateway =
      widget.institutionalGateway ??
      ApiInstitutionalDocumentsGateway(documentsGateway: _documentsGateway);
  late final TabController _tabs = TabController(length: 3, vsync: this);
  int _requestRefreshVersion = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _requestCreated() {
    setState(() => _requestRefreshVersion++);
    _tabs.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            elevation: 0,
            child: SafeArea(
              bottom: false,
              child: TabBar(
                controller: _tabs,
                isScrollable: MediaQuery.sizeOf(context).width < 560,
                tabs: const [
                  Tab(icon: Icon(Icons.folder_outlined), text: 'Bibliothèque'),
                  Tab(icon: Icon(Icons.approval_outlined), text: 'Demandes'),
                  Tab(icon: Icon(Icons.post_add_outlined), text: 'Créer un document'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                DocumentsScreen(gateway: _documentsGateway),
                _InstitutionalRequestsPanel(
                  key: ValueKey(_requestRefreshVersion),
                  gateway: _institutionalGateway,
                ),
                _InstitutionalCreatePanel(
                  gateway: _institutionalGateway,
                  onCreated: _requestCreated,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstitutionalCreatePanel extends StatefulWidget {
  final InstitutionalDocumentsGateway gateway;
  final VoidCallback onCreated;

  const _InstitutionalCreatePanel({
    required this.gateway,
    required this.onCreated,
  });

  @override
  State<_InstitutionalCreatePanel> createState() =>
      _InstitutionalCreatePanelState();
}

class _InstitutionalCreatePanelState extends State<_InstitutionalCreatePanel> {
  List<InstitutionalTemplateModel> _templates = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await widget.gateway.loadTemplates();
      if (!mounted) return;
      setState(() {
        _templates = values;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _msg(error);
      });
    }
  }

  Future<void> _start(InstitutionalTemplateModel template) async {
    if (_saving || !template.canCreate) return;
    final result = await showInstitutionalRequestFormDialog(
      context,
      gateway: widget.gateway,
      template: template,
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.gateway.createRequest(
        template: template,
        payload: result.payload,
        poleId: result.poleId,
        projectId: result.projectId,
        eventId: result.eventId,
        seasonId: result.seasonId,
      );
      if (!mounted) return;
      _notice('Brouillon créé. Vous pouvez maintenant le relire puis le soumettre.');
      widget.onCreated();
    } catch (error) {
      if (mounted) _notice(_msg(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _PanelError(message: _error!, onRetry: _load);
    }

    final allowed = _templates.where((template) => template.canCreate).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Créer un document institutionnel',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sélectionnez un modèle. Les modèles affichés dépendent de vos responsabilités dans Enactus ESP.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Empowering our society is our priority',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (allowed.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucun modèle institutionnel n’est disponible pour votre rôle actuel.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 430,
                  mainAxisExtent: 240,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: allowed.length,
                itemBuilder: (context, index) {
                  final template = allowed[index];
                  return _TemplateCard(
                    template: template,
                    busy: _saving,
                    onTap: () => _start(template),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _notice(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final InstitutionalTemplateModel template;
  final bool busy;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(_templateIcon(template.code)),
                  ),
                  const Spacer(),
                  Chip(label: Text(template.referencePrefix)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                template.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                template.approvalLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _visibilityLabel(template.visibility),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstitutionalRequestsPanel extends StatefulWidget {
  final InstitutionalDocumentsGateway gateway;

  const _InstitutionalRequestsPanel({
    super.key,
    required this.gateway,
  });

  @override
  State<_InstitutionalRequestsPanel> createState() =>
      _InstitutionalRequestsPanelState();
}

class _InstitutionalRequestsPanelState
    extends State<_InstitutionalRequestsPanel> {
  List<InstitutionalDocumentRequestModel> _requests = const [];
  Map<String, InstitutionalTemplateModel> _templates = const {};
  DocumentReferenceData _references = const DocumentReferenceData();
  UserExperience? _currentUser;
  bool _rendererAvailable = false;
  bool _loading = true;
  String? _error;
  String _status = 'all';
  String _template = 'all';
  String? _busyId;

  bool get _canGenerate =>
      _currentUser?.isAdmin == true ||
      _currentUser?.isSecretary == true ||
      _currentUser?.isTeamLeader == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.gateway.loadTemplates(),
        widget.gateway.loadRequests(
          status: _status,
          templateCode: _template,
        ),
        widget.gateway.loadReferences(),
        widget.gateway.loadCurrentUser(),
        widget.gateway.rendererAvailable(),
      ]);
      if (!mounted) return;
      final templates = values[0] as List<InstitutionalTemplateModel>;
      setState(() {
        _templates = {for (final item in templates) item.code: item};
        _requests = values[1] as List<InstitutionalDocumentRequestModel>;
        _references = values[2] as DocumentReferenceData;
        _currentUser = values[3] as UserExperience?;
        _rendererAvailable = values[4] as bool;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _msg(error);
      });
    }
  }

  Future<void> _perform(
    InstitutionalDocumentRequestModel request,
    Future<InstitutionalDocumentRequestModel> Function() action,
    String success,
  ) async {
    setState(() => _busyId = request.id);
    try {
      final updated = await action();
      if (!mounted) return;
      _replace(updated);
      _notice(success);
    } catch (error) {
      if (mounted) _notice(_msg(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _replace(InstitutionalDocumentRequestModel updated) {
    setState(() {
      _requests = _requests
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
  }

  Future<void> _edit(InstitutionalDocumentRequestModel request) async {
    final template = _templates[request.templateCode];
    if (template == null) return;
    final result = await showInstitutionalRequestFormDialog(
      context,
      gateway: widget.gateway,
      template: template,
      request: request,
    );
    if (result == null || !mounted) return;
    await _perform(
      request,
      () => widget.gateway.updateRequest(
        request: request,
        payload: result.payload,
        poleId: result.poleId,
        projectId: result.projectId,
        eventId: result.eventId,
        seasonId: result.seasonId,
      ),
      'Brouillon mis à jour.',
    );
  }

  Future<void> _reject(InstitutionalDocumentRequestModel request) async {
    final reason = await _askText(
      title: 'Demander une correction / rejeter',
      label: 'Motif',
      minLength: 3,
    );
    if (reason == null || !mounted) return;
    await _perform(
      request,
      () => widget.gateway.reject(request.id, reason),
      'La demande a été renvoyée pour correction.',
    );
  }

  Future<void> _cancel(InstitutionalDocumentRequestModel request) async {
    final confirmed = await _confirm(
      'Annuler cette demande ?',
      'Cette action arrête le workflow de cette demande.',
    );
    if (!confirmed || !mounted) return;
    await _perform(
      request,
      () => widget.gateway.cancel(request.id),
      'Demande annulée.',
    );
  }

  Future<void> _generate(InstitutionalDocumentRequestModel request) async {
    setState(() => _busyId = request.id);
    try {
      final result = await widget.gateway.generate(request.id);
      if (!mounted) return;
      _replace(result.request);
      _notice(
        result.alreadyGenerated
            ? 'Le PDF officiel existait déjà.'
            : 'PDF officiel généré et archivé.',
      );
    } catch (error) {
      if (mounted) _notice(_msg(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _PanelError(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Demandes institutionnelles',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Brouillons, validation SG, approbation Team Leader et génération des PDF officiels.',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualiser',
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (_canGenerate && !_rendererAvailable) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: const Text('Moteur PDF indisponible'),
                        subtitle: const Text(
                          'Les validations restent possibles, mais pdflatex doit être installé sur le backend avant la génération.',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 245,
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: 'Statut'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Tous les statuts')),
                            DropdownMenuItem(value: 'draft', child: Text('Brouillons')),
                            DropdownMenuItem(value: 'pending_sg_validation', child: Text('À valider par le SG')),
                            DropdownMenuItem(value: 'pending_approval', child: Text('À approuver par le TL')),
                            DropdownMenuItem(value: 'validated', child: Text('Validés')),
                            DropdownMenuItem(value: 'generated', child: Text('PDF générés')),
                            DropdownMenuItem(value: 'rejected', child: Text('À corriger')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Annulés')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _status = value);
                            _load();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          value: _templates.containsKey(_template) ? _template : 'all',
                          decoration: const InputDecoration(labelText: 'Type de document'),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('Tous les modèles')),
                            ..._templates.values.map(
                              (template) => DropdownMenuItem(
                                value: template.code,
                                child: Text(template.label),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _template = value);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_requests.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Aucune demande pour ces filtres.')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
              sliver: SliverList.separated(
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _requestCard(_requests[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _requestCard(InstitutionalDocumentRequestModel request) {
    final busy = _busyId == request.id;
    final theme = Theme.of(context);
    final scope = _scopeLabel(request);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Icon(_templateIcon(request.templateCode))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.templateLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (request.officialReference != null)
                        Text(
                          request.officialReference!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (scope != null)
                        Text(scope, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(request: request),
              ],
            ),
            if (request.rejectionReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Correction demandée : ${request.rejectionReason}'),
              ),
            ],
            const SizedBox(height: 12),
            if (busy) const LinearProgressIndicator(),
            if (!busy)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (request.canEdit)
                    OutlinedButton.icon(
                      onPressed: () => _edit(request),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifier'),
                    ),
                  if (request.canSubmit)
                    FilledButton.icon(
                      onPressed: () => _perform(
                        request,
                        () => widget.gateway.submit(request.id),
                        'Demande soumise.',
                      ),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Soumettre'),
                    ),
                  if (request.canSgValidate)
                    FilledButton.icon(
                      onPressed: () => _perform(
                        request,
                        () => widget.gateway.sgValidate(request.id),
                        'Validation SG enregistrée.',
                      ),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Valider SG'),
                    ),
                  if (request.canApprove)
                    FilledButton.icon(
                      onPressed: () => _perform(
                        request,
                        () => widget.gateway.approve(request.id),
                        'Approbation Team Leader enregistrée.',
                      ),
                      icon: const Icon(Icons.approval_outlined),
                      label: const Text('Approuver'),
                    ),
                  if (request.canSgValidate || request.canApprove)
                    OutlinedButton.icon(
                      onPressed: () => _reject(request),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Demander correction'),
                    ),
                  if (request.isValidated && _canGenerate)
                    FilledButton.icon(
                      onPressed: _rendererAvailable ? () => _generate(request) : null,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Générer le PDF'),
                    ),
                  if (request.generatedDocumentId != null)
                    FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '/documents/${request.generatedDocumentId}',
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Ouvrir le document'),
                    ),
                  if (request.canCancel)
                    TextButton.icon(
                      onPressed: () => _cancel(request),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String? _scopeLabel(InstitutionalDocumentRequestModel request) {
    if (request.poleId != null) {
      return _references.poleName(request.poleId) ?? 'Pôle lié';
    }
    if (request.projectId != null) {
      return _references.projectName(request.projectId) ?? 'Projet lié';
    }
    return null;
  }

  Future<String?> _askText({
    required String title,
    required String label,
    int minLength = 1,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= minLength) Navigator.pop(context, value);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Non'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Oui'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _notice(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final InstitutionalDocumentRequestModel request;
  const _StatusChip({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = switch (request.status) {
      'generated' => Colors.green,
      'validated' => Colors.teal,
      'pending_sg_validation' || 'pending_approval' => Colors.orange,
      'rejected' => Colors.red,
      'cancelled' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(request.statusLabel),
    );
  }
}

class _PanelError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PanelError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

IconData _templateIcon(String code) {
  if (code.startsWith('pv_')) return Icons.groups_outlined;
  switch (code) {
    case 'autorisation_parentale_voyage':
      return Icons.family_restroom_outlined;
    case 'demande_rse':
      return Icons.handshake_outlined;
    case 'demande_bus':
      return Icons.directions_bus_outlined;
    case 'notification_renvoi':
      return Icons.gavel_outlined;
    default:
      return Icons.description_outlined;
  }
}

String _visibilityLabel(String visibility) {
  switch (visibility) {
    case 'pole_only':
      return 'Visible par le pôle concerné';
    case 'project_only':
      return 'Visible par le projet concerné';
    case 'enacchef_only':
      return 'Réservé aux Enac’Chefs';
    case 'private':
      return 'Document privé';
    case 'internal':
      return 'Document interne';
    default:
      return visibility;
  }
}

String _msg(Object error) {
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
