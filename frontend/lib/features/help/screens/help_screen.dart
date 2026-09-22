import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/help_models.dart';
import '../services/help_gateway.dart';

class HelpScreen extends StatefulWidget {
  final HelpGateway? gateway;

  const HelpScreen({super.key, this.gateway});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late final HelpGateway _gateway;
  List<SupportTicket> _tickets = const [];
  List<ProductFeedback> _feedback = const [];
  bool _ticketsLoading = true;
  bool _feedbackLoading = true;
  String? _ticketsError;
  String? _feedbackError;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiHelpGateway();
    _load();
  }

  Future<void> _load() async {
    await Future.wait<void>([_loadTickets(), _loadFeedback()]);
  }

  Future<void> _loadTickets() async {
    setState(() {
      _ticketsLoading = true;
      _ticketsError = null;
    });
    try {
      final tickets = await _gateway.loadTickets();
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } catch (_) {
      if (mounted) {
        setState(
          () => _ticketsError = 'Impossible de charger vos demandes d’aide.',
        );
      }
    } finally {
      if (mounted) setState(() => _ticketsLoading = false);
    }
  }

  Future<void> _loadFeedback() async {
    setState(() {
      _feedbackLoading = true;
      _feedbackError = null;
    });
    try {
      final feedback = await _gateway.loadFeedback();
      if (!mounted) return;
      setState(() => _feedback = feedback);
    } catch (_) {
      if (mounted) {
        setState(() => _feedbackError = 'Impossible de charger vos avis.');
      }
    } finally {
      if (mounted) setState(() => _feedbackLoading = false);
    }
  }

  Future<void> _createTicket() async {
    final request = await showDialog<_TicketDraft>(
      context: context,
      builder: (context) => const _TicketDialog(),
    );
    if (request == null) return;
    try {
      await _gateway.createTicket(
        subject: request.subject,
        category: request.category,
        priority: request.priority,
        message: request.message,
      );
      await _loadTickets();
      if (mounted) _message('Votre demande a été envoyée.');
    } catch (_) {
      if (mounted) _message('Impossible d’envoyer votre demande.');
    }
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    try {
      final detail = await _gateway.loadTicket(ticket.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _TicketDetailDialog(
          ticket: detail,
          onReply: (message) => _gateway.replyToTicket(detail.id, message),
        ),
      );
      await _loadTickets();
    } catch (_) {
      if (mounted) _message('Impossible d’ouvrir cette demande.');
    }
  }

  Future<void> _createFeedback() async {
    final request = await showDialog<_FeedbackDraft>(
      context: context,
      builder: (context) => const _FeedbackDialog(),
    );
    if (request == null) return;
    try {
      await _gateway.createFeedback(
        category: request.category,
        message: request.message,
        rating: request.rating,
      );
      await _loadFeedback();
      if (mounted) _message('Merci, votre avis a été envoyé.');
    } catch (_) {
      if (mounted) _message('Impossible d’envoyer votre avis.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const Key('help-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Centre d’aide',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Trouvez une réponse ou échangez avec l’équipe Enactus ESP.',
                    ),
                    const SizedBox(height: 20),
                    const _HelpSection(
                      title: 'Questions fréquentes',
                      icon: Icons.quiz_outlined,
                      child: Column(
                        children: [
                          _FaqTile(
                            question: 'Comment gérer mes notifications ?',
                            answer:
                                'Ouvrez Réglages pour choisir les alertes dans l’application et par e-mail.',
                          ),
                          _FaqTile(
                            question:
                                'Comment obtenir une copie de mes données ?',
                            answer:
                                'Dans Réglages, choisissez « Exporter mes données », puis confirmez la copie.',
                          ),
                          _FaqTile(
                            question:
                                'La suppression du compte est-elle immédiate ?',
                            answer:
                                'Non. Vous envoyez une demande dont vous pouvez suivre l’état et annuler tant qu’elle est en attente.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HelpSection(
                      title: 'Mes demandes d’aide',
                      icon: Icons.support_agent_rounded,
                      trailing: FilledButton.icon(
                        onPressed: _createTicket,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nouvelle demande'),
                      ),
                      child: _ticketsLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _ticketsError != null
                          ? _RetryState(
                              message: _ticketsError!,
                              onRetry: _loadTickets,
                            )
                          : _tickets.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text('Aucun ticket pour le moment.'),
                            )
                          : Column(
                              children: [
                                for (final ticket in _tickets)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.confirmation_number_outlined,
                                    ),
                                    title: Text(ticket.subject),
                                    subtitle: Text(
                                      '${ticket.categoryLabel} · ${ticket.statusLabel} · Priorité ${ticket.priorityLabel.toLowerCase()}',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () => _openTicket(ticket),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    _HelpSection(
                      title: 'Mes avis',
                      icon: Icons.rate_review_outlined,
                      trailing: OutlinedButton.icon(
                        onPressed: _createFeedback,
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('Donner mon avis'),
                      ),
                      child: _feedbackLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text('Chargement de vos avis…'),
                                  ],
                                ),
                              ),
                            )
                          : _feedbackError != null
                          ? _RetryState(
                              message: _feedbackError!,
                              onRetry: _loadFeedback,
                            )
                          : _feedback.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text('Aucun avis envoyé pour le moment.'),
                            )
                          : Column(
                              children: [
                                for (final item in _feedback)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.feedback_outlined,
                                    ),
                                    title: Text(item.categoryLabel),
                                    subtitle: Text(
                                      '${item.message}${item.rating == null ? '' : ' · ${item.rating}/5'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _HelpSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(question),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Align(alignment: Alignment.centerLeft, child: Text(answer)),
      ),
    ],
  );
}

class _RetryState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _RetryState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ],
    ),
  );
}

class _TicketDetailDialog extends StatefulWidget {
  final SupportTicket ticket;
  final Future<SupportMessage> Function(String message) onReply;

  const _TicketDetailDialog({required this.ticket, required this.onReply});

  @override
  State<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<_TicketDetailDialog> {
  final _reply = TextEditingController();
  late final List<SupportMessage> _messages = [...widget.ticket.messages];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending || !widget.ticket.canReply) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await widget.onReply(text);
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _reply.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Votre réponse n’a pas pu être envoyée.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.ticket.subject),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.ticket.categoryLabel} · ${widget.ticket.statusLabel}',
            ),
            const Divider(height: 28),
            if (_messages.isEmpty)
              const Text('Aucun message.')
            else
              for (final message in _messages)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.message),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'fr_FR',
                          ).format(message.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 14),
            if (widget.ticket.canReply) ...[
              TextField(
                key: const Key('ticket-reply-field'),
                controller: _reply,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Votre réponse'),
              ),
              if (_error != null) Text(_error!),
            ] else
              const Text('Ce ticket est fermé. Les réponses sont désactivées.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
      if (widget.ticket.canReply)
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Envoi…' : 'Répondre'),
        ),
    ],
  );
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog();

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  String _priority = 'normal';

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _TicketDraft(
        subject: _subject.text.trim(),
        category: _category,
        priority: _priority,
        message: _message.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle demande'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Sujet'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: const [
              DropdownMenuItem(
                value: 'general',
                child: Text('Question générale'),
              ),
              DropdownMenuItem(value: 'account', child: Text('Compte')),
              DropdownMenuItem(value: 'access', child: Text('Accès')),
              DropdownMenuItem(
                value: 'technical',
                child: Text('Problème technique'),
              ),
              DropdownMenuItem(value: 'billing', child: Text('Paiement')),
              DropdownMenuItem(value: 'other', child: Text('Autre')),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? 'general'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Élevée')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ],
            onChanged: (value) => setState(() => _priority = value ?? 'normal'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Votre message'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Envoyer')),
    ],
  );
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _message = TextEditingController();
  String _category = 'idea';
  int? _rating;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (_message.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _FeedbackDraft(
        category: _category,
        message: _message.text.trim(),
        rating: _rating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Donner mon avis'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Type d’avis'),
            items: const [
              DropdownMenuItem(value: 'bug', child: Text('Problème')),
              DropdownMenuItem(value: 'idea', child: Text('Idée')),
              DropdownMenuItem(
                value: 'usability',
                child: Text('Facilité d’utilisation'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Autre')),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'other'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _rating,
            decoration: const InputDecoration(labelText: 'Note (facultatif)'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sans note'),
              ),
              for (var value = 1; value <= 5; value++)
                DropdownMenuItem<int?>(value: value, child: Text('$value / 5')),
            ],
            onChanged: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('feedback-message-field'),
            controller: _message,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Votre avis'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Envoyer')),
    ],
  );
}

class _TicketDraft {
  final String subject;
  final String category;
  final String priority;
  final String message;

  const _TicketDraft({
    required this.subject,
    required this.category,
    required this.priority,
    required this.message,
  });
}

class _FeedbackDraft {
  final String category;
  final String message;
  final int? rating;

  const _FeedbackDraft({
    required this.category,
    required this.message,
    required this.rating,
  });
}
