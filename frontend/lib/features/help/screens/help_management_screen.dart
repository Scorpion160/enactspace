import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/help_models.dart';
import '../models/managed_help_models.dart';
import '../services/help_gateway.dart';

String _helpError(Object error) => error is ApiException
    ? error.message
    : 'La modification n’a pas pu être confirmée. Actualisez puis réessayez.';
const ticketStatuses = {
  'open': 'Ouverte',
  'in_progress': 'En cours',
  'resolved': 'Résolue',
  'closed': 'Clôturée',
};
const feedbackStatuses = {
  'new': 'Reçu',
  'reviewed': 'Étudié',
  'planned': 'Prévu',
  'closed': 'Clôturé',
};
const _ticketNext = {
  'open': ['in_progress', 'resolved', 'closed'],
  'in_progress': ['open', 'resolved', 'closed'],
  'resolved': ['in_progress', 'closed'],
  'closed': ['open'],
};
const _feedbackNext = {
  'new': ['reviewed', 'planned', 'closed'],
  'reviewed': ['new', 'planned', 'closed'],
  'planned': ['reviewed', 'closed'],
  'closed': ['reviewed'],
};

class HelpManagementScreen extends StatefulWidget {
  final HelpManagementGateway? gateway;
  final String? currentUserId;
  const HelpManagementScreen({super.key, this.gateway, this.currentUserId});
  @override
  State<HelpManagementScreen> createState() => _HelpManagementScreenState();
}

class _HelpManagementScreenState extends State<HelpManagementScreen> {
  late final gateway = widget.gateway ?? ApiHelpGateway();
  List<SupportTicket> tickets = [];
  List<ManagedFeedback> feedback = [];
  bool loadingTickets = true,
      loadingFeedback = true,
      showFeedback = false,
      opening = false;
  String? ticketError, feedbackError, userId;
  String query = '', filter = 'all';
  @override
  void initState() {
    super.initState();
    userId = widget.currentUserId;
    load();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (userId != null) return;
    try {
      final user = await AuthService().getCachedCurrentUser();
      if (mounted) setState(() => userId = user?['id']?.toString());
    } catch (_) {}
  }

  Future<void> load() async {
    await Future.wait<void>([_loadTickets(), _loadFeedback()]);
  }

  Future<void> _loadTickets() async {
    setState(() {
      loadingTickets = true;
      ticketError = null;
    });
    try {
      final rows = await gateway.loadManagedTickets();
      if (mounted) setState(() => tickets = rows);
    } catch (e) {
      if (mounted) setState(() => ticketError = _helpError(e));
    } finally {
      if (mounted) setState(() => loadingTickets = false);
    }
  }

  Future<void> _loadFeedback() async {
    setState(() {
      loadingFeedback = true;
      feedbackError = null;
    });
    try {
      final rows = await gateway.loadManagedFeedback();
      if (mounted) setState(() => feedback = rows);
    } catch (e) {
      if (mounted) setState(() => feedbackError = _helpError(e));
    } finally {
      if (mounted) setState(() => loadingFeedback = false);
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openTicket(SupportTicket item) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final detail = await gateway.loadManagedTicket(item.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _ManagedTicketDialog(
          gateway: gateway,
          initial: detail,
          currentUserId: userId,
        ),
      );
      if (mounted) await _loadTickets();
    } catch (e) {
      if (mounted) message(_helpError(e));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> openFeedback(ManagedFeedback item) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final detail = await gateway.loadManagedFeedbackItem(item.feedback.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _ManagedFeedbackDialog(gateway: gateway, initial: detail),
      );
      if (mounted) await _loadFeedback();
    } catch (e) {
      if (mounted) message(_helpError(e));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = showFeedback ? feedbackStatuses : ticketStatuses;
    final items = tickets
        .where(
          (t) =>
              (filter == 'all' || t.status == filter) &&
              ('${t.subject} ${t.categoryLabel}').toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final remarks = feedback
        .where(
          (t) =>
              (filter == 'all' || t.feedback.status == filter) &&
              ('${t.feedback.message} ${t.feedback.categoryLabel}')
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    final loading = showFeedback ? loadingFeedback : loadingTickets,
        error = showFeedback ? feedbackError : ticketError;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des demandes et avis'),
        leading: BackButton(onPressed: () => context.go('/help')),
        actions: [
          IconButton(
            onPressed: opening ? null : load,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Lisez les demandes, prenez-les en charge et répondez aux membres. Les notes internes des avis restent réservées aux responsables.',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Demandes d’aide'),
                      selected: !showFeedback,
                      onSelected: (_) => setState(() {
                        showFeedback = false;
                        filter = 'all';
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Avis et suggestions'),
                      selected: showFeedback,
                      onSelected: (_) => setState(() {
                        showFeedback = true;
                        filter = 'all';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Rechercher',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (text) => setState(() => query = text),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('help-filter-$showFeedback'),
                  initialValue: filter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'État'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Tous les états'),
                    ),
                    for (final entry in labels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) => setState(() => filter = value ?? 'all'),
                ),
                const SizedBox(height: 16),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (error != null) ...[
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: load,
                    child: const Text('Réessayer'),
                  ),
                ] else if (showFeedback)
                  if (remarks.isEmpty)
                    const Text('Aucun avis dans cette sélection.')
                  else
                    for (final item in remarks)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${item.feedback.categoryLabel} · ${item.feedback.statusLabel}',
                          ),
                          subtitle: Text(
                            item.feedback.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: opening ? null : () => openFeedback(item),
                        ),
                      )
                else if (items.isEmpty)
                  const Text('Aucune demande dans cette sélection.')
                else
                  for (final item in items)
                    Card(
                      child: ListTile(
                        title: Text(item.subject),
                        subtitle: Text(
                          '${item.statusLabel} · Priorité ${item.priorityLabel.toLowerCase()}${item.assignedToId == null ? ' · À prendre en charge' : ' · Prise en charge'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: opening ? null : () => openTicket(item),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagedTicketDialog extends StatefulWidget {
  final HelpManagementGateway gateway;
  final SupportTicket initial;
  final String? currentUserId;
  const _ManagedTicketDialog({
    required this.gateway,
    required this.initial,
    this.currentUserId,
  });
  @override
  State<_ManagedTicketDialog> createState() => _ManagedTicketDialogState();
}

class _ManagedTicketDialogState extends State<_ManagedTicketDialog> {
  late SupportTicket ticket = widget.initial;
  late String status = ticket.status, priority = ticket.priority;
  final reply = TextEditingController();
  String key = const Uuid().v4();
  bool busy = false, needsRefresh = false;
  String? error;
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  void accept(SupportTicket updated) {
    ticket = updated.withMessages(
      updated.messages.isEmpty ? ticket.messages : updated.messages,
    );
    status = ticket.status;
    priority = ticket.priority;
    needsRefresh = false;
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final fresh = await widget.gateway.loadManagedTicket(ticket.id);
      if (mounted) setState(() => accept(fresh));
    } catch (e) {
      if (mounted) setState(() => error = _helpError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool assignment = false, String? assignee}) async {
    if (busy || needsRefresh) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.gateway.manageTicket(
        ticket.id,
        status: assignment ? null : status,
        priority: assignment ? null : priority,
        updateAssignment: assignment,
        assignedToId: assignee,
        expectedUpdatedAt: ticket.updatedAt,
      );
      if (mounted) setState(() => accept(updated));
    } catch (e) {
      if (mounted) setState(() => error = _helpError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send() async {
    if (busy) return;
    if (reply.text.trim().isEmpty) {
      setState(() => error = 'Écrivez une réponse avant de l’envoyer.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    bool sent = false;
    try {
      final message = await widget.gateway.replyAsManager(
        ticket.id,
        reply.text.trim(),
        clientRequestId: key,
      );
      sent = true;
      if (!mounted) return;
      setState(() {
        ticket = ticket.withMessages([...ticket.messages, message]);
        reply.clear();
        key = const Uuid().v4();
        needsRefresh = true;
      });
      final updated = await widget.gateway.loadManagedTicket(ticket.id);
      if (mounted) setState(() => accept(updated));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = sent
              ? 'Réponse envoyée. Actualisez la demande avant de modifier son suivi.'
              : _helpError(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(ticket.subject),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ticket.requesterName != null)
                Text(
                  ticket.requesterName!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('ticket-status-${ticket.status}'),
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'État de la demande',
                ),
                items: [
                  for (final code in [
                    ticket.status,
                    ...?_ticketNext[ticket.status],
                  ])
                    DropdownMenuItem(
                      value: code,
                      child: Text(ticketStatuses[code] ?? 'À vérifier'),
                    ),
                ],
                onChanged: busy || needsRefresh
                    ? null
                    : (value) =>
                          setState(() => status = value ?? ticket.status),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('ticket-priority-${ticket.priority}'),
                initialValue: priority,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Faible')),
                  DropdownMenuItem(value: 'normal', child: Text('Normale')),
                  DropdownMenuItem(value: 'high', child: Text('Élevée')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                ],
                onChanged: busy || needsRefresh
                    ? null
                    : (value) =>
                          setState(() => priority = value ?? ticket.priority),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        busy || needsRefresh || widget.currentUserId == null
                        ? null
                        : () => save(
                            assignment: true,
                            assignee: widget.currentUserId,
                          ),
                    child: const Text('Prendre en charge'),
                  ),
                  if (ticket.assignedToId != null)
                    TextButton(
                      onPressed: busy || needsRefresh
                          ? null
                          : () => save(assignment: true),
                      child: const Text('Libérer la prise en charge'),
                    ),
                ],
              ),
              const Divider(height: 28),
              for (final message in ticket.messages)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      message.message,
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('manager-ticket-reply'),
                controller: reply,
                enabled: !busy,
                maxLength: 10000,
                maxLines: 4,
                onChanged: (_) => key = const Uuid().v4(),
                decoration: const InputDecoration(
                  labelText: 'Réponse au membre',
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: busy ? null : send,
                    child: const Text('Envoyer la réponse'),
                  ),
                  TextButton(
                    onPressed: busy ? null : refresh,
                    child: const Text('Actualiser la demande'),
                  ),
                ],
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: busy || needsRefresh ? null : () => save(),
          child: Text(busy ? 'Enregistrement…' : 'Enregistrer le suivi'),
        ),
      ],
    ),
  );
}

class _ManagedFeedbackDialog extends StatefulWidget {
  final HelpManagementGateway gateway;
  final ManagedFeedback initial;
  const _ManagedFeedbackDialog({required this.gateway, required this.initial});
  @override
  State<_ManagedFeedbackDialog> createState() => _ManagedFeedbackDialogState();
}

class _ManagedFeedbackDialogState extends State<_ManagedFeedbackDialog> {
  late ManagedFeedback item = widget.initial;
  late String status = item.feedback.status;
  late final publicReply = TextEditingController(
    text: item.feedback.publicReply ?? '',
  );
  late final note = TextEditingController(text: item.adminNote ?? '');
  bool busy = false;
  String? error;
  @override
  void dispose() {
    publicReply.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    final expected = item.feedback.updatedAt;
    if (expected == null) {
      setState(
        () => error = 'Actualisez cet avis avant de modifier son suivi.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.gateway.manageFeedback(
        item.feedback.id,
        status: status,
        publicReply: publicReply.text.trim(),
        adminNote: note.text.trim(),
        expectedUpdatedAt: expected,
      );
      if (mounted) {
        setState(() {
          item = updated;
          status = updated.feedback.status;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _helpError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.gateway.loadManagedFeedbackItem(
        item.feedback.id,
      );
      if (mounted) {
        setState(() {
          item = updated;
          status = updated.feedback.status;
          publicReply.text = updated.feedback.publicReply ?? '';
          note.text = updated.adminNote ?? '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _helpError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(item.feedback.categoryLabel),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.feedback.message, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('feedback-status-${item.feedback.status}'),
                initialValue: status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'État de l’avis'),
                items: [
                  for (final code in [
                    item.feedback.status,
                    ...?_feedbackNext[item.feedback.status],
                  ])
                    DropdownMenuItem(
                      value: code,
                      child: Text(feedbackStatuses[code] ?? 'À vérifier'),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(
                        () => status = value ?? item.feedback.status,
                      ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('manager-feedback-public'),
                controller: publicReply,
                enabled: !busy,
                maxLength: 10000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Réponse visible par le membre',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('manager-feedback-internal'),
                controller: note,
                enabled: !busy,
                maxLength: 10000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note interne',
                  helperText: 'Réservée aux responsables du centre d’aide.',
                  helperMaxLines: 2,
                ),
              ),
              TextButton(
                onPressed: busy ? null : refresh,
                child: const Text('Actualiser l’avis'),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Enregistrement…' : 'Enregistrer le suivi'),
        ),
      ],
    ),
  );
}
