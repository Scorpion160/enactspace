import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_center_models.dart';
import '../models/event_model.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final EventReferenceData references;
  final VoidCallback onOpen;

  const EventCard({
    super.key,
    required this.event,
    required this.references,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scope =
        references.projectName(event.projectId) ??
        references.poleName(event.poleId);
    final places = event.maxParticipants == null
        ? '${event.registeredCount} inscrit(s)'
        : '${event.registeredCount} / ${event.maxParticipants} places';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(label: Text(event.typeLabel)),
                  const Spacer(),
                  if (event.currentUserRegistered)
                    const Chip(
                      avatar: Icon(Icons.check_circle_rounded, size: 17),
                      label: Text('Inscrit'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _Info(
                Icons.schedule_rounded,
                DateFormat('dd/MM/yyyy · HH:mm').format(event.startTime),
              ),
              if ((event.location ?? '').trim().isNotEmpty)
                _Info(Icons.location_on_outlined, event.location!),
              if (scope != null) _Info(Icons.account_tree_outlined, scope),
              _Info(Icons.groups_rounded, places),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (event.requiresRegistration)
                    const Chip(label: Text('Inscription requise')),
                  Chip(
                    label: Text(
                      event.attendanceEnabled
                          ? 'Présence activée'
                          : 'Présence non activée',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ouvrir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Info(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}
