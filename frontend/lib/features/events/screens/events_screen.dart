import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../models/event_model.dart';
import '../services/events_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventsService _service = EventsService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _type = 'all';
  String _period = 'upcoming';
  List<EventModel> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await _service.getEvents();

      if (!mounted) return;
      setState(() {
        _events = events;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<EventModel> get _filteredEvents {
    final query = _searchController.text.trim().toLowerCase();

    return _events.where((event) {
      final matchesType = _type == 'all' || event.eventType == _type;
      final matchesPeriod =
          _period == 'all' ||
          (_period == 'upcoming' && event.isUpcoming) ||
          (_period == 'past' && !event.isUpcoming);
      final matchesSearch =
          query.isEmpty ||
          event.title.toLowerCase().contains(query) ||
          (event.location ?? '').toLowerCase().contains(query) ||
          (event.description ?? '').toLowerCase().contains(query);

      return matchesType && matchesPeriod && matchesSearch;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CreateEventSheet(service: _service),
    );

    if (created == true) {
      await _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 560 ? 14.0 : 24.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              28,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    children: [
                      _EventsHeader(
                        total: _events.length,
                        upcoming: _events
                            .where((event) => event.isUpcoming)
                            .length,
                        onCreate: _openCreateSheet,
                        onRefresh: _loadEvents,
                      ),
                      const SizedBox(height: 18),
                      _EventsToolbar(
                        searchController: _searchController,
                        type: _type,
                        period: _period,
                        onSearchChanged: (_) => setState(() {}),
                        onTypeChanged: (value) => setState(() => _type = value),
                        onPeriodChanged: (value) =>
                            setState(() => _period = value),
                      ),
                      const SizedBox(height: 22),
                      if (_loading)
                        const _LoadingCard()
                      else if (_error != null)
                        _ErrorCard(message: _error!, onRetry: _loadEvents)
                      else if (_filteredEvents.isEmpty)
                        const _EmptyEventsCard()
                      else
                        _EventsGrid(events: _filteredEvents),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventsHeader extends StatelessWidget {
  final int total;
  final int upcoming;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _EventsHeader({
    required this.total,
    required this.upcoming,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(28),
      ),
      child: isWide
          ? Row(
              children: [
                const _HeaderIcon(),
                const SizedBox(width: 18),
                Expanded(
                  child: _HeaderText(total: total, upcoming: upcoming),
                ),
                const SizedBox(width: 18),
                _HeaderActions(onCreate: onCreate, onRefresh: onRefresh),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderIcon(),
                const SizedBox(height: 18),
                _HeaderText(total: total, upcoming: upcoming),
                const SizedBox(height: 18),
                _HeaderActions(onCreate: onCreate, onRefresh: onRefresh),
              ],
            ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.event_available_rounded,
        color: AppTheme.softBlack,
        size: 36,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final int total;
  final int upcoming;

  const _HeaderText({required this.total, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Événements',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Réunions, formations, campagnes et temps forts du club.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderChip(label: '$total événement(s)'),
            _HeaderChip(label: '$upcoming à venir'),
          ],
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _HeaderActions({required this.onCreate, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
        ElevatedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer'),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;

  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}

class _EventsToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String type;
  final String period;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onPeriodChanged;

  const _EventsToolbar({
    required this.searchController,
    required this.type,
    required this.period,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchWidth = constraints.maxWidth >= 760
                ? 360.0
                : constraints.maxWidth;
            final filterWidth = constraints.maxWidth >= 520
                ? 220.0
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un événement',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: filterWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: period,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Période'),
                    items: const [
                      DropdownMenuItem(
                        value: 'upcoming',
                        child: Text('À venir'),
                      ),
                      DropdownMenuItem(value: 'past', child: Text('Passés')),
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                    ],
                    onChanged: (value) {
                      if (value != null) onPeriodChanged(value);
                    },
                  ),
                ),
                SizedBox(
                  width: filterWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: _eventTypeItems(includeAll: true),
                    onChanged: (value) {
                      if (value != null) onTypeChanged(value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventsGrid extends StatelessWidget {
  final List<EventModel> events;

  const _EventsGrid({required this.events});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 740
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: count == 1 ? 1.55 : 1.08,
          ),
          itemBuilder: (context, index) => _EventCard(event: events[index]),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy').format(event.startTime);
    final time = DateFormat('HH:mm').format(event.startTime);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.enactusYellow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: AppTheme.softBlack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$date • $time',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EventChip(
                  icon: Icons.category_rounded,
                  label: event.typeLabel,
                ),
                if (event.location != null && event.location!.trim().isNotEmpty)
                  _EventChip(
                    icon: Icons.place_rounded,
                    label: event.location!.trim(),
                  ),
                if (event.requiresRegistration)
                  const _EventChip(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Inscription',
                  ),
                if (event.attendanceEnabled)
                  const _EventChip(
                    icon: Icons.fact_check_rounded,
                    label: 'Pointage',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _safeText(
                event.description,
                fallback: 'Aucune description renseignée.',
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.4),
            ),
            const Spacer(),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.payments_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _money(event.budget),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (event.maxParticipants != null)
                  Text(
                    '${event.maxParticipants} place(s)',
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.14),
      side: BorderSide(color: AppTheme.enactusYellow.withValues(alpha: 0.34)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _CreateEventSheet extends StatefulWidget {
  final EventsService service;

  const _CreateEventSheet({required this.service});

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController(text: '0');
  final _maxParticipantsController = TextEditingController();

  String _eventType = 'meeting';
  DateTime _startTime = DateTime.now().add(const Duration(days: 1));
  DateTime? _endTime;
  bool _requiresRegistration = false;
  bool _attendanceEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await widget.service.createEvent(
        title: _titleController.text,
        description: _descriptionController.text,
        eventType: _eventType,
        location: _locationController.text,
        startTime: _startTime,
        endTime: _endTime,
        budget:
            double.tryParse(
              _budgetController.text.trim().replaceAll(' ', ''),
            ) ??
            0,
        maxParticipants: int.tryParse(_maxParticipantsController.text.trim()),
        requiresRegistration: _requiresRegistration,
        attendanceEnabled: _attendanceEnabled,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Créer un événement',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le titre est obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _eventType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: _eventTypeItems(includeAll: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _eventType = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    prefixIcon: Icon(Icons.place_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickStartTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(_startTime),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Budget',
                    suffixText: 'FCFA',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _maxParticipantsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Places max',
                    prefixIcon: Icon(Icons.groups_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _requiresRegistration,
                  onChanged: (value) {
                    setState(() => _requiresRegistration = value);
                  },
                  title: const Text('Inscription requise'),
                ),
                SwitchListTile(
                  value: _attendanceEnabled,
                  onChanged: (value) {
                    setState(() => _attendanceEnabled = value);
                  },
                  title: const Text('Pointage activé'),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Créer l’événement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement des événements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEventsCard extends StatelessWidget {
  const _EmptyEventsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Text(
            'Aucun événement ne correspond aux filtres actuels.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> _eventTypeItems({required bool includeAll}) {
  return [
    if (includeAll) const DropdownMenuItem(value: 'all', child: Text('Tous')),
    const DropdownMenuItem(value: 'meeting', child: Text('Réunion')),
    const DropdownMenuItem(value: 'training', child: Text('Formation')),
    const DropdownMenuItem(value: 'competition', child: Text('Compétition')),
    const DropdownMenuItem(value: 'field_trip', child: Text('Terrain')),
    const DropdownMenuItem(value: 'travel', child: Text('Voyage')),
    const DropdownMenuItem(value: 'lab_test', child: Text('Test chimie')),
    const DropdownMenuItem(value: 'workshop_test', child: Text('Test atelier')),
    const DropdownMenuItem(value: 'campaign', child: Text('Campagne')),
    const DropdownMenuItem(value: 'presentation', child: Text('Présentation')),
    const DropdownMenuItem(value: 'social', child: Text('Social')),
    const DropdownMenuItem(value: 'interclub', child: Text('Interclubs')),
    const DropdownMenuItem(value: 'yendoutu', child: Text('Yendoutu')),
  ];
}

String _safeText(String? value, {required String fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return value.trim();
}

String _money(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();

  for (int i = 0; i < rounded.length; i++) {
    final reverseIndex = rounded.length - i;
    buffer.write(rounded[i]);

    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} FCFA';
}
