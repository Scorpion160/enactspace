import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../services/internal_recruitment_gateway.dart';
import '../../services/recruitment_message.dart';
import 'human_assessment_editor.dart';

class CandidateReviewDialog extends StatefulWidget {
  final ApplicationModel application;
  final InternalRecruitmentGateway gateway;
  const CandidateReviewDialog({
    super.key,
    required this.application,
    required this.gateway,
  });

  @override
  State<CandidateReviewDialog> createState() => _CandidateReviewDialogState();
}

class _CandidateReviewDialogState extends State<CandidateReviewDialog> {
  Map<String, dynamic>? _assessment;
  final _comment = TextEditingController();
  String _recommendation = 'reserve';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final own = widget.application.myReview;
    _assessment = own?.criteriaAssessment;
    _comment.text = own?.comment ?? '';
    _recommendation = own?.recommendation ?? 'reserve';
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!isCompleteHumanAssessment(
      _assessment,
      widget.application.screeningRubric,
    )) {
      setState(
        () => _error =
            'Renseignez un niveau et un exemple pour chacun des cinq critères.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.createReview(
        applicationId: widget.application.id,
        criteriaAssessment: _assessment!,
        comment: _comment.text,
        recommendation: _recommendation,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = recruitmentMessage(
            error,
            fallback:
                'Votre avis n’a pas pu être enregistré. Réessayez dans quelques instants.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Évaluer la candidature'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chaque critère compte autant. Appuyez votre appréciation sur un exemple précis ; cet avis ne modifie pas le statut de la candidature.',
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.application.screeningRubric != null)
                HumanAssessmentEditor(
                  rubric: widget.application.screeningRubric!,
                  initialAssessment: _assessment,
                  enabled: !_saving,
                  onChanged: (value) => _assessment = value,
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _recommendation,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Avis du jury'),
                items: const [
                  DropdownMenuItem(
                    value: 'favorable',
                    child: Text('Favorable'),
                  ),
                  DropdownMenuItem(value: 'reserve', child: Text('Réservé')),
                  DropdownMenuItem(
                    value: 'defavorable',
                    child: Text('Défavorable'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _recommendation = value);
                        }
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comment,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Commentaire complémentaire (facultatif)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _saving || widget.application.screeningRubric == null
              ? null
              : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Enregistrement…' : 'Enregistrer mon avis'),
        ),
      ],
    ),
  );
}
