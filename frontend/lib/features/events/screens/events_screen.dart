import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/auth/user_experience.dart';
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
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _type = 'all';
  String _period = 'upcoming';
  UserExperience? _userExperience;
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
      final userExperience = await _loadUserExperienceSafely();

      if (!mounted) return;
      setState(() {
        _events = events;
        _userExperience = userExperience;
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

  Future<UserExperience?> _loadUserExperienceSafely() async {
    try {
      final user = await _authService.getCurrentUser();
      return UserExperience.fromJson(user);
    } catch (_) {
      return null;
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

  void _replaceEvent(EventModel updated) {
    setState(() {
      _events = [
        for (final event in _events) event.id == updated.id ? updated : event,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _userExperience?.canCreateOperationalWork ?? false;

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
                        onCreate: canManage ? _openCreateSheet : null,
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
                        _EventsGrid(
                          events: _filteredEvents,
                          service: _service,
                          canManage: canManage,
                          onEventChanged: _replaceEvent,
                        ),
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
  final VoidCallback? onCreate;
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
  final VoidCallback? onCreate;
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
  final EventsService service;
  final bool canManage;
  final ValueChanged<EventModel> onEventChanged;

  const _EventsGrid({
    required this.events,
    required this.service,
    required this.canManage,
    required this.onEventChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 740
            ? 2
            : 1;

        const spacing = 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final event in events)
              SizedBox(
                width: itemWidth,
                child: _EventCard(
                  event: event,
                  service: service,
                  canManage: canManage,
                  onEventChanged: onEventChanged,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final EventsService service;
  final bool canManage;
  final ValueChanged<EventModel> onEventChanged;

  const _EventCard({
    required this.event,
    required this.service,
    required this.canManage,
    required this.onEventChanged,
  });

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
            const SizedBox(height: 16),
            _EventReadinessBar(event: event),
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
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showEventDetails(
                  context,
                  event,
                  service,
                  canManage,
                  onEventChanged,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Détail événement'),
              ),
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

class _EventReadinessBar extends StatelessWidget {
  final EventModel event;

  const _EventReadinessBar({required this.event});

  @override
  Widget build(BuildContext context) {
    final score = _eventReadinessScore(event);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Préparation',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$score/100',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppTheme.enactusYellow,
            ),
          ),
        ],
      ),
    );
  }
}

void _showEventDetails(
  BuildContext context,
  EventModel event,
  EventsService service,
  bool canManage,
  ValueChanged<EventModel> onEventChanged,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _EventDetailsSheet(
      event: event,
      service: service,
      canManage: canManage,
      onEventChanged: onEventChanged,
    ),
  );
}

class _EventDetailsSheet extends StatelessWidget {
  final EventModel event;
  final EventsService service;
  final bool canManage;
  final ValueChanged<EventModel> onEventChanged;

  const _EventDetailsSheet({
    required this.event,
    required this.service,
    required this.canManage,
    required this.onEventChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('dd/MM/yyyy HH:mm').format(event.startTime);
    final end = event.endTime == null
        ? 'Fin à préciser'
        : DateFormat('dd/MM/yyyy HH:mm').format(event.endTime!);
    final readiness = _eventReadinessScore(event);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.enactusYellow,
                        foregroundColor: AppTheme.softBlack,
                        child: Icon(_eventIcon(event.eventType)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${event.typeLabel} · préparation $readiness/100',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _EventDetailBlock(
                    icon: Icons.description_rounded,
                    title: 'Description',
                    body: _safeText(
                      event.description,
                      fallback: 'Description à compléter.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _EventMetricCard(
                        icon: Icons.schedule_rounded,
                        title: 'Début',
                        value: start,
                      ),
                      _EventMetricCard(
                        icon: Icons.event_available_rounded,
                        title: 'Fin',
                        value: end,
                      ),
                      _EventMetricCard(
                        icon: Icons.place_rounded,
                        title: 'Lieu',
                        value: _safeText(
                          event.location,
                          fallback: 'À préciser',
                        ),
                      ),
                      _EventMetricCard(
                        icon: Icons.payments_rounded,
                        title: 'Budget',
                        value: _money(event.budget),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EventActionPanel(event: event),
                  const SizedBox(height: 16),
                  _EventReportPanel(
                    event: event,
                    service: service,
                    canManage: canManage,
                    onEventChanged: onEventChanged,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EventDetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EventDetailBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.enactusYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _EventMetricCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 72).clamp(240.0, 360.0),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.enactusYellow,
                foregroundColor: AppTheme.softBlack,
                child: Icon(icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventActionPanel extends StatelessWidget {
  final EventModel event;

  const _EventActionPanel({required this.event});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (event.requiresRegistration)
          const _EventActionChip(
            icon: Icons.how_to_reg_rounded,
            label: 'Inscriptions',
          ),
        if (event.attendanceEnabled)
          const _EventActionChip(
            icon: Icons.fact_check_rounded,
            label: 'Présence liée',
          ),
        const _EventActionChip(
          icon: Icons.groups_rounded,
          label: 'Participants',
        ),
        const _EventActionChip(
          icon: Icons.description_rounded,
          label: 'Documents',
        ),
        const _EventActionChip(icon: Icons.payments_rounded, label: 'Budget'),
        const _EventActionChip(
          icon: Icons.notifications_active_rounded,
          label: 'Rappels',
        ),
      ],
    );
  }
}

class _EventActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }
}

class _EventReportPanel extends StatefulWidget {
  final EventModel event;
  final EventsService service;
  final bool canManage;
  final ValueChanged<EventModel> onEventChanged;

  const _EventReportPanel({
    required this.event,
    required this.service,
    required this.canManage,
    required this.onEventChanged,
  });

  @override
  State<_EventReportPanel> createState() => _EventReportPanelState();
}

class _EventReportPanelState extends State<_EventReportPanel> {
  late final TextEditingController _reportController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reportController = TextEditingController(
      text: widget.event.reportUrl?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _saveReport() async {
    setState(() => _saving = true);

    try {
      final updated = await widget.service.updateEvent(
        eventId: widget.event.id,
        reportUrl: _reportController.text,
      );

      widget.onEventChanged(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport événement mis à jour.')),
      );
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
    final event = widget.event;
    final hasReport = _reportController.text.trim().isNotEmpty;
    final items = [
      if (hasReport)
        'Rapport disponible et rattaché à la fiche événement.'
      else
        'Rapport après événement à produire.',
      if (event.attendanceEnabled)
        'Présence liée à consolider avec les participants présents.',
      'Budget réel, documents, photos et synthèse impact à relier.',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suivi après événement',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.enactusYellow,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _reportController,
            enabled: widget.canManage,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Lien du rapport ou dossier preuves',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(
                Icons.link_rounded,
                color: AppTheme.enactusYellow,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.enactusYellow),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: !widget.canManage || _saving ? null : _saveReport,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Enregistrer le suivi'),
            ),
          ),
        ],
      ),
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
      if (_endTime != null && !_endTime!.isAfter(_startTime)) {
        _endTime = null;
      }
    });
  }

  Future<void> _pickEndTime() async {
    final initialEnd = _endTime ?? _startTime.add(const Duration(hours: 2));
    final date = await showDatePicker(
      context: context,
      initialDate: initialEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialEnd),
    );
    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!selected.isAfter(_startTime)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit être après le début.')),
      );
      return;
    }

    setState(() => _endTime = selected);
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(
                        _endTime == null
                            ? 'Ajouter une fin'
                            : 'Fin ${DateFormat('dd/MM/yyyy HH:mm').format(_endTime!)}',
                      ),
                    ),
                    if (_endTime != null)
                      IconButton.filledTonal(
                        tooltip: 'Retirer la fin',
                        onPressed: () => setState(() => _endTime = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
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

int _eventReadinessScore(EventModel event) {
  var score = 20;

  if ((event.description ?? '').trim().length >= 40) score += 15;
  if ((event.location ?? '').trim().isNotEmpty) score += 10;
  if (event.endTime != null) score += 10;
  if (event.budget > 0) score += 10;
  if (event.maxParticipants != null && event.maxParticipants! > 0) score += 10;
  if (event.requiresRegistration) score += 10;
  if (event.attendanceEnabled) score += 10;
  if ((event.reportUrl ?? '').trim().isNotEmpty) score += 15;

  return score.clamp(0, 100);
}

IconData _eventIcon(String eventType) {
  switch (eventType) {
    case 'training':
      return Icons.school_rounded;
    case 'competition':
      return Icons.emoji_events_rounded;
    case 'field_trip':
      return Icons.terrain_rounded;
    case 'travel':
      return Icons.flight_takeoff_rounded;
    case 'campaign':
      return Icons.campaign_rounded;
    case 'presentation':
      return Icons.slideshow_rounded;
    case 'social':
      return Icons.diversity_3_rounded;
    default:
      return Icons.event_available_rounded;
  }
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
