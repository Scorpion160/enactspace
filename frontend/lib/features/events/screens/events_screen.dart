import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/event_center_models.dart';
import '../models/event_model.dart';
import '../services/events_gateway.dart';
import '../widgets/event_form_dialog.dart';
import '../widgets/event_widgets.dart';

class EventsScreen extends StatefulWidget {
  final EventsGateway? gateway;
  const EventsScreen({super.key, this.gateway});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventsGateway _gateway = widget.gateway ?? ApiEventsGateway();
  final _search = TextEditingController();
  List<EventModel> _events = const [];
  EventReferenceData _references = const EventReferenceData();
  EventCenterPeriod _period = EventCenterPeriod.upcoming;
  String _type = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eventsFuture = _gateway.loadEvents();
      final referencesFuture = _gateway.loadReferences().catchError(
        (_) => const EventReferenceData(),
      );
      final results = await Future.wait([eventsFuture, referencesFuture]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<EventModel>;
        _references = results[1] as EventReferenceData;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _message(error);
        });
      }
    }
  }

  List<EventModel> get _visibleEvents {
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final values = _events.where((event) {
      final periodMatches = switch (_period) {
        EventCenterPeriod.upcoming => !event.startTime.isBefore(now),
        EventCenterPeriod.past => event.startTime.isBefore(now),
        EventCenterPeriod.all => true,
      };
      return periodMatches &&
          (_type == 'all' || event.eventType == _type) &&
          (query.isEmpty ||
              event.title.toLowerCase().contains(query) ||
              (event.location ?? '').toLowerCase().contains(query) ||
              event.typeLabel.toLowerCase().contains(query));
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    return values;
  }

  Future<void> _create() async {
    final draft = await showEventFormDialog(context, references: _references);
    if (draft == null || !mounted) return;
    try {
      final created = await _gateway.createEvent(draft);
      if (!mounted) return;
      setState(() => _events = [created, ..._events]);
      _notice('Événement créé.');
    } catch (error) {
      if (mounted) _notice(_message(error), error: true);
    }
  }

  void _open(EventModel event) =>
      context.push('/events/${event.id}', extra: _gateway);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 28,
                  24,
                  compact ? 16 : 28,
                  14,
                ),
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
                                'Événements',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Retrouvez les rendez-vous du club et vos inscriptions.',
                              ),
                            ],
                          ),
                        ),
                        if (_references.canCreate)
                          FilledButton.icon(
                            key: const Key('create-event'),
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              compact ? 'Créer' : 'Créer un événement',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'Rechercher un événement',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<EventCenterPeriod>(
                          segments: const [
                            ButtonSegment(
                              value: EventCenterPeriod.upcoming,
                              label: Text('À venir'),
                            ),
                            ButtonSegment(
                              value: EventCenterPeriod.past,
                              label: Text('Passés'),
                            ),
                            ButtonSegment(
                              value: EventCenterPeriod.all,
                              label: Text('Tous'),
                            ),
                          ],
                          selected: {_period},
                          onSelectionChanged: (values) =>
                              setState(() => _period = values.first),
                        ),
                        SizedBox(
                          width: compact ? double.infinity : 240,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _type,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Tous les types'),
                              ),
                              DropdownMenuItem(
                                value: 'meeting',
                                child: Text('Réunion'),
                              ),
                              DropdownMenuItem(
                                value: 'training',
                                child: Text('Formation'),
                              ),
                              DropdownMenuItem(
                                value: 'competition',
                                child: Text('Compétition'),
                              ),
                              DropdownMenuItem(
                                value: 'field_trip',
                                child: Text('Terrain'),
                              ),
                              DropdownMenuItem(
                                value: 'campaign',
                                child: Text('Campagne'),
                              ),
                              DropdownMenuItem(
                                value: 'presentation',
                                child: Text('Présentation'),
                              ),
                              DropdownMenuItem(
                                value: 'social',
                                child: Text('Social'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _type = value!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: _StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Chargement impossible',
                  message: _error!,
                  action: _load,
                ),
              )
            else if (_visibleEvents.isEmpty)
              const SliverFillRemaining(
                child: _StateMessage(
                  icon: Icons.event_busy_rounded,
                  title: 'Aucun événement',
                  message:
                      'Modifiez la période ou les filtres pour élargir la recherche.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 28,
                  4,
                  compact ? 16 : 28,
                  32,
                ),
                sliver: compact
                    ? SliverList.builder(
                        itemCount: _visibleEvents.length,
                        itemBuilder: (context, index) => SizedBox(
                          height: 460,
                          child: EventCard(
                            event: _visibleEvents[index],
                            references: _references,
                            onOpen: () => _open(_visibleEvents[index]),
                          ),
                        ),
                      )
                    : SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 430,
                              mainAxisExtent: 450,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: _visibleEvents.length,
                        itemBuilder: (context, index) => EventCard(
                          event: _visibleEvents[index],
                          references: _references,
                          onOpen: () => _open(_visibleEvents[index]),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _notice(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        ),
      );
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? action;
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: action, child: const Text('Réessayer')),
          ],
        ],
      ),
    ),
  );
}

String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
