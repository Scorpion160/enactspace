import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../models/application_status_presentation.dart';

typedef CandidateStatusCallback = Future<void> Function(String status);
typedef CandidateInterviewCallback =
    Future<void> Function({
      required DateTime interviewAt,
      String? location,
      String? link,
      String? jury,
      String? note,
    });

class CandidateActionsSection extends StatelessWidget {
  final ApplicationModel application;
  final String campaignTitle;
  final int reviewCount;
  final double? reviewAverage;
  final CandidateStatusCallback onStatusChange;
  final CandidateInterviewCallback onInterview;
  final String? feedback;

  const CandidateActionsSection({
    super.key,
    required this.application,
    required this.campaignTitle,
    required this.reviewCount,
    required this.reviewAverage,
    required this.onStatusChange,
    required this.onInterview,
    this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = _allowedTransitions(application);
    final actions = <Widget>[
      if (allowed.contains('under_review'))
        _ActionButton(
          key: const Key('candidate-action-under-review'),
          icon: Icons.manage_search_rounded,
          label: 'Passer en étude',
          onPressed: () => _showStatusDialog(
            context,
            targetStatus: 'under_review',
            kind: CandidateDecisionKind.standard,
          ),
        ),
      if (allowed.contains('interview_scheduled') ||
          application.status == 'interview_scheduled')
        _ActionButton(
        key: const Key('candidate-action-interview'),
        icon: Icons.event_available_rounded,
        label: application.status == 'interview_scheduled'
            ? 'Modifier l’entretien'
            : 'Planifier un entretien',
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => CandidateInterviewDialog(
            application: application,
            onConfirm: onInterview,
          ),
        ),
      ),
      if (allowed.contains('waiting_list'))
        _ActionButton(
          key: const Key('candidate-action-waiting-list'),
          icon: Icons.hourglass_top_rounded,
          label: 'Placer en liste d’attente',
          onPressed: () => _showStatusDialog(
            context,
            targetStatus: 'waiting_list',
            kind: CandidateDecisionKind.standard,
          ),
        ),
      if (allowed.contains('accepted'))
        _ActionButton(
          key: const Key('candidate-action-accept'),
          icon: Icons.check_circle_outline_rounded,
          label: 'Accepter la candidature',
          onPressed: () => _showStatusDialog(
            context,
            targetStatus: 'accepted',
            kind: CandidateDecisionKind.acceptance,
          ),
        ),
      if (allowed.contains('rejected'))
        _ActionButton(
          key: const Key('candidate-action-reject'),
          icon: Icons.person_off_outlined,
          label: 'Ne pas retenir la candidature',
          onPressed: () => _showStatusDialog(
            context,
            targetStatus: 'rejected',
            kind: CandidateDecisionKind.rejection,
          ),
        ),
      if (allowed.contains('cancelled'))
        _ActionButton(
          key: const Key('candidate-action-close'),
          icon: Icons.archive_outlined,
          label: 'Clôturer la candidature',
          onPressed: () => _showStatusDialog(
            context,
            targetStatus: 'cancelled',
            kind: CandidateDecisionKind.closure,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choisissez une action puis vérifiez son résumé avant confirmation. '
          'Aucun changement n’est envoyé à la sélection.',
        ),
        if (feedback != null) ...[
          const SizedBox(height: 12),
          CandidateActionFeedback(message: feedback!),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
        const SizedBox(height: 10),
        Text(
          'La conversion en utilisateur reste une action séparée.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static Set<String> _allowedTransitions(ApplicationModel application) {
    if (application.convertedUserId != null) return const {};
    return switch (application.status) {
      'submitted' => const {'under_review', 'cancelled'},
      'under_review' => const {
        'interview_scheduled', 'waiting_list', 'accepted', 'rejected', 'cancelled',
      },
      'interview_scheduled' => const {
        'under_review', 'waiting_list', 'accepted', 'rejected', 'cancelled',
      },
      'waiting_list' => const {
        'interview_scheduled', 'accepted', 'rejected', 'cancelled',
      },
      _ => const {},
    };
  }

  Future<void> _showStatusDialog(
    BuildContext context, {
    required String targetStatus,
    required CandidateDecisionKind kind,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CandidateDecisionDialog(
      application: application,
      campaignTitle: campaignTitle,
      reviewCount: reviewCount,
      reviewAverage: reviewAverage,
      targetStatus: targetStatus,
      kind: kind,
      onConfirm: () => onStatusChange(targetStatus),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

enum CandidateDecisionKind { standard, acceptance, rejection, closure }

class CandidateDecisionDialog extends StatefulWidget {
  final ApplicationModel application;
  final String campaignTitle;
  final int reviewCount;
  final double? reviewAverage;
  final String targetStatus;
  final CandidateDecisionKind kind;
  final Future<void> Function() onConfirm;

  const CandidateDecisionDialog({
    super.key,
    required this.application,
    required this.campaignTitle,
    required this.reviewCount,
    required this.reviewAverage,
    required this.targetStatus,
    required this.kind,
    required this.onConfirm,
  });

  @override
  State<CandidateDecisionDialog> createState() =>
      _CandidateDecisionDialogState();
}

class _CandidateDecisionDialogState extends State<CandidateDecisionDialog> {
  bool _confirmed = false;
  bool _sending = false;
  String? _error;

  bool get _reinforced =>
      widget.kind == CandidateDecisionKind.rejection ||
      widget.kind == CandidateDecisionKind.closure;

  String get _title => switch (widget.kind) {
    CandidateDecisionKind.acceptance => 'Retenir cette candidature ?',
    CandidateDecisionKind.rejection => 'Ne pas retenir cette candidature ?',
    CandidateDecisionKind.closure => 'Clôturer cette candidature ?',
    CandidateDecisionKind.standard =>
      widget.targetStatus == 'waiting_list'
          ? 'Placer en liste d’attente ?'
          : 'Changer le statut de la candidature ?',
  };

  String get _confirmLabel => switch (widget.kind) {
    CandidateDecisionKind.acceptance => 'Retenir la candidature',
    CandidateDecisionKind.rejection => 'Confirmer la décision',
    CandidateDecisionKind.closure => 'Confirmer la clôture',
    CandidateDecisionKind.standard => 'Confirmer',
  };

  @override
  Widget build(BuildContext context) {
    final current = ApplicationStatusPresentation.fromStatus(
      widget.application.status,
    ).title;
    final target = ApplicationStatusPresentation.fromStatus(
      widget.targetStatus,
    ).title;
    final reference = widget.application.trackingCode ?? widget.application.id;

    return AlertDialog(
      title: Text(_title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogLine('Candidat', widget.application.fullName),
            _DialogLine('Référence', reference),
            _DialogLine('Campagne', widget.campaignTitle),
            _DialogLine('Statut actuel', current),
            _DialogLine('Nouveau statut', target),
            if (widget.kind == CandidateDecisionKind.acceptance) ...[
              _DialogLine(
                'Moyenne officielle',
                widget.reviewAverage == null
                    ? 'Non disponible'
                    : '${widget.reviewAverage!.toStringAsFixed(1)}/20',
              ),
              _DialogLine(
                'Évaluations',
                '${widget.reviewCount} enregistrée${widget.reviewCount > 1 ? 's' : ''}',
              ),
              const Text(
                'Cette action marque le dossier comme retenu sans convertir '
                'automatiquement la personne en utilisateur.',
              ),
            ] else if (widget.kind == CandidateDecisionKind.rejection)
              const Text(
                'Cette décision est sensible. Vérifiez le dossier avant de '
                'marquer la candidature comme non retenue.',
              )
            else if (widget.kind == CandidateDecisionKind.closure)
              const Text(
                'Le dossier sera marqué comme clôturé. Cette action est '
                'distincte d’un rejet.',
              )
            else
              const Text(
                'Le dossier sera actualisé après confirmation de ce changement.',
              ),
            if (_reinforced) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const Key('candidate-decision-confirmation'),
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: _sending
                    ? null
                    : (value) => setState(() => _confirmed = value ?? false),
                title: const Text(
                  'Je confirme avoir vérifié le dossier avant cette décision.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              CandidateActionFeedback(message: _error!, isError: true),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const Key('candidate-decision-submit'),
          onPressed: _sending || (_reinforced && !_confirmed) ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_confirmLabel),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _humanError(error, 'Impossible d’appliquer cette décision.');
      });
    }
  }
}

class CandidateInterviewDialog extends StatefulWidget {
  final ApplicationModel application;
  final CandidateInterviewCallback onConfirm;

  const CandidateInterviewDialog({
    super.key,
    required this.application,
    required this.onConfirm,
  });

  @override
  State<CandidateInterviewDialog> createState() =>
      _CandidateInterviewDialogState();
}

class _CandidateInterviewDialogState extends State<CandidateInterviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _link;
  late final TextEditingController _jury;
  late final TextEditingController _note;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.application.interviewAt?.toLocal();
    _date = TextEditingController(
      text: existing == null
          ? ''
          : '${existing.day.toString().padLeft(2, '0')}/${existing.month.toString().padLeft(2, '0')}/${existing.year}',
    );
    _time = TextEditingController(
      text: existing == null
          ? ''
          : '${existing.hour.toString().padLeft(2, '0')}:${existing.minute.toString().padLeft(2, '0')}',
    );
    _location = TextEditingController(
      text: widget.application.interviewLocation ?? '',
    );
    _link = TextEditingController(text: widget.application.interviewLink ?? '');
    _jury = TextEditingController(text: widget.application.interviewJury ?? '');
    _note = TextEditingController(text: widget.application.interviewNote ?? '');
  }

  @override
  void dispose() {
    for (final controller in [_date, _time, _location, _link, _jury, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modifying = widget.application.interviewAt != null;
    return AlertDialog(
      title: Text(modifying ? 'Modifier l’entretien' : 'Planifier l’entretien'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('candidate-interview-date'),
                controller: _date,
                enabled: !_sending,
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  hintText: 'JJ/MM/AAAA',
                ),
                validator: (_) => _parseInterviewDateTime() == null
                    ? 'Saisissez une date et une heure valides.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('candidate-interview-time'),
                controller: _time,
                enabled: !_sending,
                decoration: const InputDecoration(
                  labelText: 'Heure *',
                  hintText: 'HH:mm',
                ),
                validator: (_) => _parseInterviewDateTime() == null
                    ? 'Saisissez une date et une heure valides.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('candidate-interview-location'),
                controller: _location,
                enabled: !_sending,
                decoration: const InputDecoration(labelText: 'Lieu'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('candidate-interview-link'),
                controller: _link,
                enabled: !_sending,
                decoration: const InputDecoration(labelText: 'Lien'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('candidate-interview-jury'),
                controller: _jury,
                enabled: !_sending,
                decoration: const InputDecoration(labelText: 'Jury'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('candidate-interview-note'),
                controller: _note,
                enabled: !_sending,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Informations complémentaires',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                CandidateActionFeedback(message: _error!, isError: true),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const Key('candidate-interview-submit'),
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  modifying ? 'Modifier l’entretien' : 'Planifier l’entretien',
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final interviewAt = _parseInterviewDateTime();
    if (interviewAt == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onConfirm(
        interviewAt: interviewAt,
        location: _optional(_location.text),
        link: _optional(_link.text),
        jury: _optional(_jury.text),
        note: _optional(_note.text),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _humanError(error, 'Impossible de planifier cet entretien.');
      });
    }
  }

  DateTime? _parseInterviewDateTime() {
    final dateParts = _date.text.trim().split('/');
    final timeParts = _time.text.trim().split(':');
    if (dateParts.length != 3 || timeParts.length != 2) return null;
    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if ([day, month, year, hour, minute].contains(null) ||
        hour! < 0 ||
        hour > 23 ||
        minute! < 0 ||
        minute > 59) {
      return null;
    }
    final result = DateTime(year!, month!, day!, hour, minute);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
    return result;
  }
}

class CandidateActionFeedback extends StatelessWidget {
  final String message;
  final bool isError;

  const CandidateActionFeedback({
    super.key,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : Colors.green.shade700;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _DialogLine extends StatelessWidget {
  final String label;
  final String value;

  const _DialogLine(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _humanError(Object error, String fallback) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  return raw.isEmpty ? fallback : raw;
}
