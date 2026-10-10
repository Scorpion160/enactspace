import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
import '../../about/services/app_info_provider.dart';
import '../widgets/help_guide_panel.dart';

import '../models/help_models.dart';
import '../services/help_gateway.dart';

class HelpScreen extends StatefulWidget {
  final HelpGateway? gateway;
  final UserExperience? user;
  final AppInfoProvider? appInfoProvider;

  const HelpScreen({super.key, this.gateway, this.user, this.appInfoProvider});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late final HelpGateway _gateway;
  AppInfo? _appInfo;
  List<SupportTicket> _tickets = const [];
  List<ProductFeedback> _feedback = const [];
  bool _ticketsLoading = true;
  bool _feedbackLoading = true;
  String? _ticketsError;
  String? _feedbackError;
  bool _canManage = false, _creatingTicket = false, _creatingFeedback = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? ApiHelpGateway();
    _load();
    _loadCapabilities();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      _appInfo = await (widget.appInfoProvider ?? PackageAppInfoProvider())
          .load();
    } catch (_) {
      // Optional diagnostics must never block a member's suggestion.
    }
  }

  Future<void> _loadCapabilities() async {
    if (widget.user != null) {
      setState(() => _canManage = widget.user!.canManageMembers);
      return;
    }
    try {
      final data = await AuthService().getCachedCurrentUser();
      if (mounted && data != null) {
        setState(
          () => _canManage = UserExperience.fromJson(data).canManageMembers,
        );
      }
    } catch (_) {
      /* The backend remains the authority for staff access. */
    }
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
    if (_creatingTicket) return;
    setState(() => _creatingTicket = true);
    try {
      final sent = await showDialog<bool>(
        context: context,
        builder: (context) => _TicketDialog(
          onSubmit: (request) async {
            await _gateway.createTicket(
              subject: request.subject,
              category: request.category,
              priority: request.priority,
              message: request.message,
              clientRequestId: request.clientRequestId,
            );
          },
        ),
      );
      if (sent == true && mounted) {
        await _loadTickets();
        if (mounted) _message('Votre demande a été envoyée.');
      }
    } finally {
      if (mounted) setState(() => _creatingTicket = false);
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
          onReply: (message, key) =>
              _gateway.replyToTicket(detail.id, message, clientRequestId: key),
          onRefresh: () => _gateway.loadTicket(detail.id),
        ),
      );
      await _loadTickets();
    } catch (_) {
      if (mounted) _message('Impossible d’ouvrir cette demande.');
    }
  }

  Future<void> _createFeedback() async {
    if (_creatingFeedback) return;
    setState(() => _creatingFeedback = true);
    final info =
        _appInfo; // Keep diagnostics stable across retries of this form.
    try {
      final sent = await showDialog<bool>(
        context: context,
        builder: (context) => _FeedbackDialog(
          onSubmit: (request) async {
            final platform = kIsWeb
                ? 'web'
                : switch (defaultTargetPlatform) {
                    TargetPlatform.android => 'android',
                    TargetPlatform.iOS => 'ios',
                    _ => null,
                  };
            await _gateway.createFeedback(
              category: request.category,
              message: request.message,
              rating: request.rating,
              clientRequestId: request.clientRequestId,
              platform: platform,
              appVersion: info?.version,
              buildNumber: int.tryParse(info?.buildNumber ?? ''),
            );
          },
        ),
      );
      if (sent == true && mounted) {
        await _loadFeedback();
        if (mounted) _message('Merci, votre avis a été envoyé.');
      }
    } finally {
      if (mounted) setState(() => _creatingFeedback = false);
    }
  }

  Future<void> _openFeedback(ProductFeedback item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.categoryLabel),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.statusLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(item.message, style: const TextStyle(height: 1.6)),
                if (item.rating != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Note : ${item.rating}/5'),
                  ),
                const Divider(height: 28),
                Text(
                  item.publicReply?.isNotEmpty == true
                      ? item.publicReply!
                      : 'Votre remarque est enregistrée. Les réponses de l’équipe apparaîtront ici.',
                  style: const TextStyle(height: 1.6),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/help-guide'),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Guide d’utilisation et FAQ'),
                        ),
                        if (_canManage)
                          FilledButton.icon(
                            onPressed: () => context.push('/help/manage'),
                            icon: const Icon(Icons.inbox_outlined),
                            label: const Text('Traiter les demandes et avis'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _HelpSection(
                      title: 'Questions fréquentes',
                      icon: Icons.quiz_outlined,
                      child: Column(
                        children: [
                          _FaqTile(
                            question: 'Comment gérer mes notifications ?',
                            answer: helpQuestions[7].answer,
                          ),
                          _FaqTile(
                            question:
                                'Comment obtenir une copie de mes données ?',
                            answer: helpQuestions[8].answer,
                          ),
                          _FaqTile(
                            question:
                                'La suppression du compte est-elle immédiate ?',
                            answer: helpQuestions[9].answer,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HelpSection(
                      title: 'Mes demandes d’aide',
                      icon: Icons.support_agent_rounded,
                      trailing: FilledButton.icon(
                        onPressed: _creatingTicket ? null : _createTicket,
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
                        onPressed: _creatingFeedback ? null : _createFeedback,
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
                                    title: Text(
                                      '${item.categoryLabel} · ${item.statusLabel}',
                                    ),
                                    onTap: () => _openFeedback(item),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
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
  final Future<SupportMessage> Function(String message, String key) onReply;
  final Future<SupportTicket> Function()? onRefresh;

  const _TicketDetailDialog({
    required this.ticket,
    required this.onReply,
    this.onRefresh,
  });

  @override
  State<_TicketDetailDialog> createState() => _TicketDetailDialogState();
}

class _TicketDetailDialogState extends State<_TicketDetailDialog> {
  final _reply = TextEditingController();
  late SupportTicket _ticket = widget.ticket;
  late final List<SupportMessage> _messages = [...widget.ticket.messages];
  String _replyKey = const Uuid().v4();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (_sending || !_ticket.canReply) return;
    if (text.isEmpty) {
      setState(() => _error = 'Écrivez votre réponse avant de l’envoyer.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await widget.onReply(text, _replyKey);
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _reply.clear();
        _replyKey = const Uuid().v4();
      });
      if (widget.onRefresh != null) {
        try {
          final fresh = await widget.onRefresh!();
          if (mounted) {
            setState(() {
              _ticket = fresh;
              _messages
                ..clear()
                ..addAll(fresh.messages);
            });
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Réponse envoyée. Actualisez la demande pour retrouver son suivi.',
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Votre réponse n’a pas pu être envoyée.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: Text(widget.ticket.subject),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${_ticket.categoryLabel} · ${_ticket.statusLabel}'),
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
              if (_ticket.canReply) ...[
                TextField(
                  key: const Key('ticket-reply-field'),
                  controller: _reply,
                  enabled: !_sending,
                  maxLength: 10000,
                  onChanged: (_) => _replyKey = const Uuid().v4(),
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Votre réponse'),
                ),
                if (_error != null) Text(_error!),
              ] else
                const Text(
                  'Ce ticket est fermé. Les réponses sont désactivées.',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        if (_ticket.canReply)
          FilledButton(
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'Envoi…' : 'Répondre'),
          ),
      ],
    ),
  );
}

class _TicketDialog extends StatefulWidget {
  final Future<void> Function(_TicketDraft) onSubmit;
  const _TicketDialog({required this.onSubmit});
  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController(), _message = TextEditingController();
  String _category = 'general', _priority = 'normal', _key = const Uuid().v4();
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _changed() => _key = const Uuid().v4();
  Future<void> _submit() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _TicketDraft(
          _subject.text.trim(),
          _category,
          _priority,
          _message.text.trim(),
          _key,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Votre demande n’a pas pu être confirmée. Votre texte est conservé ; réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: const Text('Nouvelle demande'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _subject,
                  enabled: !_sending,
                  maxLength: 200,
                  onChanged: (_) => _changed(),
                  decoration: const InputDecoration(labelText: 'Sujet'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Donnez un sujet à votre demande.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
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
                  onChanged: _sending
                      ? null
                      : (v) => setState(() {
                          _category = v ?? 'general';
                          _changed();
                        }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Priorité'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Faible')),
                    DropdownMenuItem(value: 'normal', child: Text('Normale')),
                    DropdownMenuItem(value: 'high', child: Text('Élevée')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                  ],
                  onChanged: _sending
                      ? null
                      : (v) => setState(() {
                          _priority = v ?? 'normal';
                          _changed();
                        }),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Décrivez les étapes, le résultat attendu et ce qui se produit. Ne partagez jamais de mot de passe ou de code.',
                  style: TextStyle(height: 1.5),
                ),
                TextFormField(
                  controller: _message,
                  enabled: !_sending,
                  maxLength: 10000,
                  maxLines: 5,
                  onChanged: (_) => _changed(),
                  decoration: const InputDecoration(labelText: 'Votre message'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Décrivez votre demande.'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: Text(_sending ? 'Envoi…' : 'Envoyer'),
        ),
      ],
    ),
  );
}

class _FeedbackDialog extends StatefulWidget {
  final Future<void> Function(_FeedbackDraft) onSubmit;
  const _FeedbackDialog({required this.onSubmit});
  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _category = 'idea', _key = const Uuid().v4();
  int? _rating;
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _FeedbackDraft(_category, _message.text.trim(), _rating, _key),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Votre avis n’a pas pu être confirmé. Votre texte est conservé ; réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: const Text('Donner mon avis'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
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
                  onChanged: _sending
                      ? null
                      : (v) => setState(() {
                          _category = v ?? 'other';
                          _key = const Uuid().v4();
                        }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _rating,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sans note'),
                    ),
                    for (var value = 1; value <= 5; value++)
                      DropdownMenuItem<int?>(
                        value: value,
                        child: Text('$value / 5'),
                      ),
                  ],
                  onChanged: _sending
                      ? null
                      : (v) => setState(() {
                          _rating = v;
                          _key = const Uuid().v4();
                        }),
                ),
                const SizedBox(height: 12),
                Text(
                  _category == 'bug'
                      ? 'Indiquez l’écran, les étapes, le résultat attendu et le problème observé. Aucun mot de passe ni code personnel.'
                      : 'Expliquez votre idée et ce qu’elle apporterait à l’équipe.',
                  style: const TextStyle(height: 1.5),
                ),
                TextFormField(
                  key: const Key('feedback-message-field'),
                  controller: _message,
                  enabled: !_sending,
                  maxLength: 10000,
                  maxLines: 5,
                  onChanged: (_) => _key = const Uuid().v4(),
                  decoration: const InputDecoration(labelText: 'Votre avis'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Écrivez votre remarque.'
                      : null,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: Text(_sending ? 'Envoi…' : 'Envoyer'),
        ),
      ],
    ),
  );
}

class _TicketDraft {
  final String subject, category, priority, message, clientRequestId;
  const _TicketDraft(
    this.subject,
    this.category,
    this.priority,
    this.message,
    this.clientRequestId,
  );
}

class _FeedbackDraft {
  final String category, message, clientRequestId;
  final int? rating;
  const _FeedbackDraft(
    this.category,
    this.message,
    this.rating,
    this.clientRequestId,
  );
}
