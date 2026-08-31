import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/event_center_models.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import '../services/events_gateway.dart';
import '../widgets/event_form_dialog.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final EventsGateway? gateway;
  const EventDetailScreen({super.key, required this.eventId, this.gateway});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventsGateway _gateway = widget.gateway ?? ApiEventsGateway();
  EventModel? _event;
  EventReferenceData _references = const EventReferenceData();
  List<EventParticipantModel>? _participants;
  bool _loading = true;
  bool _acting = false;
  bool _loadingParticipants = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _gateway.loadEvent(widget.eventId),
        _gateway.loadReferences().catchError((_) => const EventReferenceData()),
      ]);
      if (!mounted) return;
      setState(() {
        _event = values[0] as EventModel;
        _references = values[1] as EventReferenceData;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _msg(error);
        });
      }
    }
  }

  Future<void> _registration() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final event = _event!;
      final updated = event.currentUserRegistered
          ? await _gateway.unregister(event.id)
          : await _gateway.register(event.id);
      if (mounted) setState(() => _event = updated);
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _loadParticipants() async {
    if (_participants != null || _loadingParticipants) return;
    setState(() => _loadingParticipants = true);
    try {
      final values = await _gateway.loadParticipants(_event!.id);
      if (mounted) setState(() => _participants = values);
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
    if (mounted) setState(() => _loadingParticipants = false);
  }

  Future<void> _edit() async {
    final draft = await showEventFormDialog(
      context,
      references: _references,
      event: _event,
    );
    if (draft == null || !mounted) return;
    setState(() => _acting = true);
    try {
      final updated = await _gateway.updateEvent(_event!.id, draft);
      if (mounted) setState(() => _event = updated);
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _attendance() async {
    try {
      await _gateway.createAttendanceSession(_event!);
      if (mounted) _notice('Session de présence créée.', false);
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’événement ?'),
        content: const Text(
          'L’événement et ses inscriptions seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _gateway.deleteEvent(_event!.id);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) _notice(_msg(error), true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _event == null) {
      return Scaffold(
        body: Center(child: Text(_error ?? 'Événement introuvable.')),
      );
    }
    final event = _event!;
    final scope =
        _references.projectName(event.projectId) ??
        _references.poleName(event.poleId) ??
        'Tout le club';
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche événement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(label: Text(event.typeLabel)),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if ((event.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(event.description!),
                    ],
                  ],
                ),
              ),
              if (event.canManage)
                OutlinedButton.icon(
                  onPressed: _acting ? null : _edit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier événement'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Résumé',
            icon: Icons.event_note_rounded,
            child: Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                _Datum('Type', event.typeLabel),
                _Datum(
                  'Lieu',
                  event.location?.trim().isNotEmpty == true
                      ? event.location!
                      : 'Non renseigné',
                ),
                _Datum(
                  'Début',
                  DateFormat('dd/MM/yyyy HH:mm').format(event.startTime),
                ),
                _Datum(
                  'Fin',
                  event.endTime == null
                      ? 'Non renseignée'
                      : DateFormat('dd/MM/yyyy HH:mm').format(event.endTime!),
                ),
                if (event.budget > 0)
                  _Datum('Budget', '${event.budget.toStringAsFixed(0)} FCFA'),
                _Datum('Périmètre', scope),
                _Datum(
                  'Capacité',
                  event.maxParticipants == null
                      ? 'Sans limite annoncée'
                      : '${event.registeredCount} / ${event.maxParticipants}',
                ),
                _Datum(
                  'Inscription',
                  event.requiresRegistration ? 'Requise' : 'Non requise',
                ),
                _Datum(
                  'Présence',
                  event.attendanceEnabled ? 'Activée' : 'Non activée',
                ),
              ],
            ),
          ),
          _Section(
            title: 'Inscription',
            icon: Icons.how_to_reg_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.currentUserRegistered
                      ? 'Vous êtes inscrit à cet événement.'
                      : '${event.registeredCount} personne(s) inscrite(s).',
                ),
                const SizedBox(height: 12),
                if (event.requiresRegistration)
                  FilledButton.icon(
                    key: const Key('event-registration-action'),
                    onPressed: _acting ? null : _registration,
                    icon: Icon(
                      event.currentUserRegistered
                          ? Icons.person_remove_rounded
                          : Icons.person_add_rounded,
                    ),
                    label: Text(
                      event.currentUserRegistered
                          ? 'Se désinscrire'
                          : 'S’inscrire',
                    ),
                  )
                else
                  const Text('Aucune inscription préalable n’est requise.'),
              ],
            ),
          ),
          if (event.canManage)
            _Section(
              title: 'Participants',
              icon: Icons.groups_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_participants == null)
                    OutlinedButton.icon(
                      key: const Key('load-event-participants'),
                      onPressed: _loadingParticipants
                          ? null
                          : _loadParticipants,
                      icon: const Icon(Icons.groups_rounded),
                      label: const Text('Afficher les participants'),
                    ),
                  if (_loadingParticipants)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  if (_participants != null && _participants!.isEmpty)
                    const Text('Aucun participant inscrit.'),
                  if (_participants != null)
                    ..._participants!.map(
                      (participant) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: participant.photoUrl == null
                              ? null
                              : NetworkImage(participant.photoUrl!),
                          child: participant.photoUrl == null
                              ? Text(_initials(participant.displayName))
                              : null,
                        ),
                        title: Text(participant.displayName),
                        subtitle: Text(
                          '${participant.email}\nInscrit le ${DateFormat('dd/MM/yyyy').format(participant.registeredAt)}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          _Section(
            title: 'Présence',
            icon: Icons.fact_check_rounded,
            child: event.attendanceEnabled
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('La présence est activée pour cet événement.'),
                      if (event.canManage) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _attendance,
                          icon: const Icon(Icons.add_task_rounded),
                          label: const Text('Créer la session de présence'),
                        ),
                      ],
                    ],
                  )
                : const Text('Présence non activée'),
          ),
          _Section(
            title: 'Rapport',
            icon: Icons.description_rounded,
            child: Text(
              event.reportUrl?.trim().isNotEmpty == true
                  ? event.reportUrl!
                  : 'Aucun rapport disponible.',
            ),
          ),
          if (event.canManage)
            _Section(
              title: 'Gestion',
              icon: Icons.admin_panel_settings_rounded,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modifier événement'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('delete-event'),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Supprimer événement'),
                  ),
                ],
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

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });
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
  final String label;
  final String value;
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

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join()
    .toUpperCase();
String _msg(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
