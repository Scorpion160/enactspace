import 'package:flutter/material.dart';

import '../../members/models/member_model.dart';
import '../models/document_center_models.dart';
import '../models/institutional_document_models.dart';
import '../services/institutional_documents_gateway.dart';

class InstitutionalRequestFormResult {
  final Map<String, dynamic> payload;
  final String? poleId;
  final String? projectId;
  final String? eventId;
  final String? seasonId;

  const InstitutionalRequestFormResult({
    required this.payload,
    this.poleId,
    this.projectId,
    this.eventId,
    this.seasonId,
  });
}

Future<InstitutionalRequestFormResult?> showInstitutionalRequestFormDialog(
  BuildContext context, {
  required InstitutionalDocumentsGateway gateway,
  required InstitutionalTemplateModel template,
  InstitutionalDocumentRequestModel? request,
}) {
  return showDialog<InstitutionalRequestFormResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: InstitutionalRequestForm(
          gateway: gateway,
          template: template,
          request: request,
        ),
      ),
    ),
  );
}

class InstitutionalRequestForm extends StatefulWidget {
  final InstitutionalDocumentsGateway gateway;
  final InstitutionalTemplateModel template;
  final InstitutionalDocumentRequestModel? request;

  const InstitutionalRequestForm({
    super.key,
    required this.gateway,
    required this.template,
    this.request,
  });

  @override
  State<InstitutionalRequestForm> createState() =>
      _InstitutionalRequestFormState();
}

class _InstitutionalRequestFormState extends State<InstitutionalRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _singleUsers = {};
  final Map<String, Set<String>> _multiUsers = {};

  DocumentReferenceData _references = const DocumentReferenceData();
  List<MemberModel> _members = const [];
  bool _loading = true;
  String? _loadError;
  String? _poleId;
  String? _projectId;
  String? _eventId;
  String? _seasonId;
  String _optionalScope = 'none';

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    _poleId = request?.poleId;
    _projectId = request?.projectId;
    _eventId = request?.eventId;
    _seasonId = request?.seasonId;
    if (_poleId != null) {
      _optionalScope = 'pole';
    } else if (_projectId != null) {
      _optionalScope = 'project';
    }
    _initializeFieldValues();
    _loadReferences();
  }

  void _initializeFieldValues() {
    final payload = widget.request?.payload ?? const <String, dynamic>{};
    for (final field in widget.template.fields) {
      final value = payload[field.name];
      if (field.type == 'user') {
        _singleUsers[field.name] = value?.toString();
      } else if (field.type == 'users') {
        _multiUsers[field.name] = value is List
            ? value.map((item) => item.toString()).toSet()
            : <String>{};
      } else {
        _controllers[field.name] = TextEditingController(
          text: _serializeFieldValue(field.type, value),
        );
      }
    }
  }

  Future<void> _loadReferences() async {
    try {
      final values = await Future.wait([
        widget.gateway.loadReferences(),
        widget.gateway.loadMembers(),
      ]);
      if (!mounted) return;
      setState(() {
        _references = values[0] as DocumentReferenceData;
        _members = values[1] as List<MemberModel>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _message(error);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.request == null
                          ? widget.template.label
                          : 'Modifier — ${widget.template.label}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.template.approvalLabel} • v${widget.template.version}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _retry)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _scopeSection(),
                      if (widget.template.scope != 'club')
                        const SizedBox(height: 18),
                      ...widget.template.fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _field(field),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Les données saisies seront intégrées au modèle institutionnel. La référence officielle n’est attribuée qu’après les validations requises.',
                        style: Theme.of(context).textTheme.bodySmall,
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(widget.request == null ? 'Créer le brouillon' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scopeSection() {
    final template = widget.template;
    if (template.scope == 'club') return const SizedBox.shrink();

    final veillePoles = _references.poles.where((pole) {
      if (!template.isVeilleOnly) return true;
      return pole.name.toLowerCase().contains('veille');
    }).toList();

    if (template.requiresPole) {
      return DropdownButtonFormField<String>(
        initialValue: _valueIfPresent(_poleId, veillePoles.map((p) => p.id)),
        decoration: InputDecoration(
          labelText: template.isVeilleOnly ? 'Pôle Veille *' : 'Pôle *',
          prefixIcon: const Icon(Icons.groups_2_outlined),
        ),
        items: veillePoles
            .map(
              (pole) => DropdownMenuItem(
                value: pole.id,
                child: Text(pole.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _poleId = value),
        validator: (value) => value == null ? 'Sélectionnez un pôle.' : null,
      );
    }

    if (template.requiresProject) {
      return DropdownButtonFormField<String>(
        initialValue: _valueIfPresent(
          _projectId,
          _references.projects.map((project) => project.id),
        ),
        decoration: const InputDecoration(
          labelText: 'Projet *',
          prefixIcon: Icon(Icons.work_outline_rounded),
        ),
        items: _references.projects
            .map(
              (project) => DropdownMenuItem(
                value: project.id,
                child: Text(project.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _projectId = value),
        validator: (value) => value == null ? 'Sélectionnez un projet.' : null,
      );
    }

    if (template.hasOptionalScope) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Périmètre du document',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'none', label: Text('Club')),
              ButtonSegment(value: 'pole', label: Text('Pôle')),
              ButtonSegment(value: 'project', label: Text('Projet')),
            ],
            selected: {_optionalScope},
            onSelectionChanged: (values) {
              final value = values.first;
              setState(() {
                _optionalScope = value;
                if (value != 'pole') _poleId = null;
                if (value != 'project') _projectId = null;
              });
            },
          ),
          const SizedBox(height: 10),
          if (_optionalScope == 'pole')
            DropdownButtonFormField<String>(
              initialValue: _valueIfPresent(
                _poleId,
                _references.poles.map((pole) => pole.id),
              ),
              decoration: const InputDecoration(labelText: 'Pôle'),
              items: _references.poles
                  .map(
                    (pole) => DropdownMenuItem(
                      value: pole.id,
                      child: Text(pole.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _poleId = value),
              validator: (value) =>
                  _optionalScope == 'pole' && value == null
                  ? 'Sélectionnez un pôle.'
                  : null,
            ),
          if (_optionalScope == 'project')
            DropdownButtonFormField<String>(
              initialValue: _valueIfPresent(
                _projectId,
                _references.projects.map((project) => project.id),
              ),
              decoration: const InputDecoration(labelText: 'Projet'),
              items: _references.projects
                  .map(
                    (project) => DropdownMenuItem(
                      value: project.id,
                      child: Text(project.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _projectId = value),
              validator: (value) =>
                  _optionalScope == 'project' && value == null
                  ? 'Sélectionnez un projet.'
                  : null,
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _field(InstitutionalFieldModel field) {
    switch (field.type) {
      case 'user':
        return DropdownButtonFormField<String>(
          initialValue: _valueIfPresent(
            _singleUsers[field.name],
            _members.map((member) => member.id),
          ),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _label(field),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
          items: _members
              .map(
                (member) => DropdownMenuItem(
                  value: member.id,
                  child: Text(member.displayName),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _singleUsers[field.name] = value),
          validator: (value) => field.required && value == null
              ? 'Ce champ est obligatoire.'
              : null,
        );
      case 'users':
        return _multiUserField(field);
      case 'date':
        return _pickerField(field, _pickDate, Icons.calendar_today_outlined);
      case 'time':
        return _pickerField(field, _pickTime, Icons.schedule_outlined);
      case 'datetime':
        return _pickerField(
          field,
          _pickDateTime,
          Icons.event_available_outlined,
        );
      default:
        return _textField(field);
    }
  }

  Widget _multiUserField(InstitutionalFieldModel field) {
    final selected = _multiUsers[field.name] ?? <String>{};
    final names = _members
        .where((member) => selected.contains(member.id))
        .map((member) => member.displayName)
        .toList();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _chooseMembers(field),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _label(field),
          prefixIcon: const Icon(Icons.group_outlined),
          errorText: field.required && selected.isEmpty
              ? 'Sélectionnez au moins un membre.'
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                names.isEmpty ? 'Sélectionner des membres' : names.join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _pickerField(
    InstitutionalFieldModel field,
    Future<void> Function(InstitutionalFieldModel field) picker,
    IconData icon,
  ) {
    return TextFormField(
      controller: _controllers[field.name],
      readOnly: true,
      onTap: () => picker(field),
      decoration: InputDecoration(
        labelText: _label(field),
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: 'Effacer',
          onPressed: () => setState(() => _controllers[field.name]?.clear()),
          icon: const Icon(Icons.clear_rounded),
        ),
      ),
      validator: (value) => field.required && (value == null || value.trim().isEmpty)
          ? 'Ce champ est obligatoire.'
          : null,
    );
  }

  Widget _textField(InstitutionalFieldModel field) {
    final structured = {
      'list',
      'structured_list',
      'action_list',
      'vote_list',
      'decision_list',
      'route_list',
    }.contains(field.type);
    final rich = field.type == 'rich_text' || structured;
    return TextFormField(
      controller: _controllers[field.name],
      keyboardType: field.type == 'number'
          ? TextInputType.number
          : field.type == 'email'
          ? TextInputType.emailAddress
          : field.type == 'phone'
          ? TextInputType.phone
          : rich
          ? TextInputType.multiline
          : TextInputType.text,
      minLines: rich ? 3 : 1,
      maxLines: rich ? 7 : 1,
      decoration: InputDecoration(
        labelText: _label(field),
        alignLabelWithHint: rich,
        helperText: _helper(field.type),
      ),
      validator: (value) => field.required && (value == null || value.trim().isEmpty)
          ? 'Ce champ est obligatoire.'
          : null,
    );
  }

  String _label(InstitutionalFieldModel field) =>
      field.required ? '${field.label} *' : field.label;

  String? _helper(String type) {
    switch (type) {
      case 'list':
        return 'Un élément par ligne.';
      case 'structured_list':
      case 'decision_list':
        return 'Une ligne par élément : Titre | Détails';
      case 'action_list':
        return 'Action | Responsable | Échéance (AAAA-MM-JJ) | Statut';
      case 'vote_list':
        return 'Résolution | Pour | Contre | Abstention';
      case 'route_list':
        return 'Départ | Arrivée | Distance en km';
      default:
        return null;
    }
  }

  Future<void> _pickDate(InstitutionalFieldModel field) async {
    final current = DateTime.tryParse(_controllers[field.name]?.text ?? '');
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      _controllers[field.name]?.text = _dateOnly(selected);
    }
  }

  Future<void> _pickTime(InstitutionalFieldModel field) async {
    final raw = _controllers[field.name]?.text ?? '';
    final parts = raw.split(':');
    final initial = parts.length >= 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? TimeOfDay.now().hour,
            minute: int.tryParse(parts[1]) ?? TimeOfDay.now().minute,
          )
        : TimeOfDay.now();
    final selected = await showTimePicker(context: context, initialTime: initial);
    if (selected != null && mounted) {
      _controllers[field.name]?.text =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickDateTime(InstitutionalFieldModel field) async {
    final current = DateTime.tryParse(_controllers[field.name]?.text ?? '');
    final dateValue = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (dateValue == null || !mounted) return;
    final timeValue = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (timeValue == null || !mounted) return;
    final value = DateTime(
      dateValue.year,
      dateValue.month,
      dateValue.day,
      timeValue.hour,
      timeValue.minute,
    );
    _controllers[field.name]?.text = value.toIso8601String();
  }

  Future<void> _chooseMembers(InstitutionalFieldModel field) async {
    final selected = Set<String>.from(_multiUsers[field.name] ?? const <String>{});
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(field.label),
          content: SizedBox(
            width: 520,
            height: 430,
            child: ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                return CheckboxListTile(
                  value: selected.contains(member.id),
                  title: Text(member.displayName),
                  subtitle: Text(member.primaryRoleLabel),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selected.add(member.id);
                      } else {
                        selected.remove(member.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _multiUsers[field.name] = result);
    }
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;
    final missingMulti = widget.template.fields.any(
      (field) =>
          field.type == 'users' &&
          field.required &&
          (_multiUsers[field.name]?.isEmpty ?? true),
    );
    if (!valid || missingMulti) {
      setState(() {});
      return;
    }

    final payload = <String, dynamic>{};
    for (final field in widget.template.fields) {
      if (field.type == 'user') {
        final value = _singleUsers[field.name];
        if (value != null && value.isNotEmpty) payload[field.name] = value;
      } else if (field.type == 'users') {
        final values = _multiUsers[field.name]?.toList() ?? const <String>[];
        if (values.isNotEmpty) payload[field.name] = values;
      } else {
        final raw = _controllers[field.name]?.text.trim() ?? '';
        if (raw.isNotEmpty) {
          payload[field.name] = _parseFieldValue(field.type, raw);
        }
      }
    }

    Navigator.of(context).pop(
      InstitutionalRequestFormResult(
        payload: payload,
        poleId: _poleId,
        projectId: _projectId,
        eventId: _eventId,
        seasonId: _seasonId,
      ),
    );
  }

  dynamic _parseFieldValue(String type, String raw) {
    switch (type) {
      case 'number':
        return num.tryParse(raw) ?? raw;
      case 'list':
        return _lines(raw);
      case 'structured_list':
      case 'decision_list':
        return _lines(raw).map((line) {
          final parts = _parts(line);
          return {
            'title': parts.isNotEmpty ? parts[0] : line,
            'details': parts.length > 1 ? parts.sublist(1).join(' | ') : '',
          };
        }).toList();
      case 'action_list':
        return _lines(raw).map((line) {
          final parts = _parts(line);
          return {
            'action': _part(parts, 0),
            'responsible': _part(parts, 1),
            'deadline': _part(parts, 2),
            'status': _part(parts, 3, 'À faire'),
          };
        }).toList();
      case 'vote_list':
        return _lines(raw).map((line) {
          final parts = _parts(line);
          return {
            'title': _part(parts, 0),
            'for': int.tryParse(_part(parts, 1, '0')) ?? 0,
            'against': int.tryParse(_part(parts, 2, '0')) ?? 0,
            'abstain': int.tryParse(_part(parts, 3, '0')) ?? 0,
          };
        }).toList();
      case 'route_list':
        return _lines(raw).map((line) {
          final parts = _parts(line);
          return {
            'from': _part(parts, 0),
            'to': _part(parts, 1),
            'distance': _part(parts, 2),
          };
        }).toList();
      default:
        return raw;
    }
  }

  String _serializeFieldValue(String type, dynamic value) {
    if (value == null) return '';
    if (value is! List) return value.toString();
    switch (type) {
      case 'structured_list':
      case 'decision_list':
        return value.map((item) {
          if (item is! Map) return item.toString();
          return '${item['title'] ?? item['name'] ?? item['label'] ?? ''} | ${item['details'] ?? item['description'] ?? item['decision'] ?? ''}';
        }).join('\n');
      case 'action_list':
        return value.map((item) {
          if (item is! Map) return item.toString();
          return '${item['action'] ?? item['title'] ?? ''} | ${item['responsible'] ?? item['owner'] ?? ''} | ${item['deadline'] ?? item['due_date'] ?? ''} | ${item['status'] ?? ''}';
        }).join('\n');
      case 'vote_list':
        return value.map((item) {
          if (item is! Map) return item.toString();
          return '${item['title'] ?? item['resolution'] ?? ''} | ${item['for'] ?? 0} | ${item['against'] ?? 0} | ${item['abstain'] ?? 0}';
        }).join('\n');
      case 'route_list':
        return value.map((item) {
          if (item is! Map) return item.toString();
          return '${item['from'] ?? ''} | ${item['to'] ?? ''} | ${item['distance'] ?? ''}';
        }).join('\n');
      default:
        return value.map((item) => item.toString()).join('\n');
    }
  }

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  List<String> _parts(String line) =>
      line.split('|').map((part) => part.trim()).toList();

  String _part(List<String> parts, int index, [String fallback = '']) =>
      index < parts.length && parts[index].isNotEmpty ? parts[index] : fallback;

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String? _valueIfPresent(String? value, Iterable<String> options) {
    if (value == null || value.isEmpty) return null;
    return options.contains(value) ? value : null;
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _loadReferences();
  }

  String _message(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}
