import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_center_models.dart';
import '../models/event_model.dart';

Future<EventMutationDraft?> showEventFormDialog(
  BuildContext context, {
  required EventReferenceData references,
  EventModel? event,
}) => showDialog<EventMutationDraft>(
  context: context,
  barrierDismissible: false,
  builder: (_) => EventFormDialog(references: references, event: event),
);

class EventFormDialog extends StatefulWidget {
  final EventReferenceData references;
  final EventModel? event;
  const EventFormDialog({super.key, required this.references, this.event});

  @override
  State<EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.event?.description ?? '',
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.event?.location ?? '',
  );
  late final TextEditingController _budget = TextEditingController(
    text: widget.event?.budget.toString() ?? '0',
  );
  late final TextEditingController _capacity = TextEditingController(
    text: widget.event?.maxParticipants?.toString() ?? '',
  );
  late final TextEditingController _report = TextEditingController(
    text: widget.event?.reportUrl ?? '',
  );
  late String _type = widget.event?.eventType ?? 'meeting';
  late DateTime _start =
      widget.event?.startTime ?? DateTime.now().add(const Duration(days: 1));
  DateTime? _end;
  String? _poleId;
  String? _projectId;
  late bool _registration = widget.event?.requiresRegistration ?? true;
  late bool _attendance = widget.event?.attendanceEnabled ?? true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _end = widget.event?.endTime;
    _poleId = widget.event?.poleId;
    _projectId = widget.event?.projectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _budget.dispose();
    _capacity.dispose();
    _report.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final base = start ? _start : (_end ?? _start);
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _submit() {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_end != null && _end!.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fin doit être postérieure au début.')),
      );
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      EventMutationDraft(
        seasonId: widget.event?.seasonId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        eventType: _type,
        location: _location.text.trim(),
        startTime: _start,
        endTime: _end,
        poleId: _poleId,
        projectId: _projectId,
        budget: double.tryParse(_budget.text.replaceAll(',', '.')) ?? 0,
        maxParticipants: int.tryParse(_capacity.text),
        requiresRegistration: _registration,
        attendanceEnabled: _attendance,
        reportUrl: _report.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    final poles = editing
        ? widget.references.poles
        : widget.references.creatablePoles;
    final projects = editing
        ? widget.references.projects
        : widget.references.creatableProjects;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        editing ? 'Modifier l’événement' : 'Créer un événement',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Annuler',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('event-title'),
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Titre *'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Titre obligatoire'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: const Key('event-type'),
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Type *'),
                        items:
                            const {
                                  'meeting': 'Réunion',
                                  'training': 'Formation',
                                  'competition': 'Compétition',
                                  'field_trip': 'Terrain',
                                  'campaign': 'Campagne',
                                  'presentation': 'Présentation',
                                  'social': 'Social',
                                }.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) => setState(() => _type = value!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(labelText: 'Lieu'),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 315,
                            child: _DateField(
                              label: 'Début *',
                              value: _start,
                              onTap: () => _pick(true),
                            ),
                          ),
                          SizedBox(
                            width: 315,
                            child: _DateField(
                              label: 'Fin',
                              value: _end,
                              onTap: () => _pick(false),
                              onClear: _end == null
                                  ? null
                                  : () => setState(() => _end = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        key: const Key('event-pole'),
                        initialValue: _poleId,
                        decoration: const InputDecoration(labelText: 'Pôle'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Aucun pôle'),
                          ),
                          ...poles.map(
                            (pole) => DropdownMenuItem(
                              value: pole.id,
                              child: Text(pole.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _poleId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        key: const Key('event-project'),
                        initialValue: _projectId,
                        decoration: const InputDecoration(labelText: 'Projet'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Aucun projet'),
                          ),
                          ...projects.map(
                            (project) => DropdownMenuItem(
                              value: project.id,
                              child: Text(project.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _projectId = value),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 315,
                            child: TextFormField(
                              controller: _budget,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Budget',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 315,
                            child: TextFormField(
                              controller: _capacity,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Capacité maximale',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inscription requise'),
                        value: _registration,
                        onChanged: (value) =>
                            setState(() => _registration = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Présence activée'),
                        value: _attendance,
                        onChanged: (value) =>
                            setState(() => _attendance = value),
                      ),
                      if (editing)
                        TextFormField(
                          controller: _report,
                          decoration: const InputDecoration(
                            labelText: 'Lien du rapport',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const Key('event-submit'),
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        editing ? 'Enregistrer' : 'Créer l’événement',
                      ),
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateField({
    required this.label,
    this.value,
    required this.onTap,
    this.onClear,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: onClear == null
            ? const Icon(Icons.calendar_month_rounded)
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
              ),
      ),
      child: Text(
        value == null
            ? 'Non définie'
            : DateFormat('dd/MM/yyyy HH:mm').format(value!),
      ),
    ),
  );
}
