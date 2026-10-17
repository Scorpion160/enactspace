import 'package:flutter/material.dart';
import '../models/academy_models.dart';
import '../services/academy_gateway.dart';

/// One quiz reader for the course page and the quick quizzes.
/// Only the server supplies results; a failed submission keeps the answers.
class AcademyQuizDialog extends StatefulWidget {
  final AcademyQuizModel quiz;
  final Future<AcademyQuizResult> Function(List<int>) submit;
  const AcademyQuizDialog({
    super.key,
    required this.quiz,
    required this.submit,
  });
  @override
  State<AcademyQuizDialog> createState() => _AcademyQuizDialogState();
}

class _AcademyQuizDialogState extends State<AcademyQuizDialog> {
  final Map<int, int> _answers = {};
  bool _saving = false;
  bool _queued = false;
  String? _error;
  AcademyQuizResult? _result;

  Future<void> _submit() async {
    if (_saving || _answers.length != widget.quiz.questions.length) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.submit(
        List.generate(widget.quiz.questions.length, (i) => _answers[i]!),
      );
      if (mounted) setState(() => _result = result);
    } on AcademyQuizQueuedException catch (error) {
      if (mounted) {
        setState(() {
          _queued = true;
          _error = error.toString();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'L’envoi n’a pas abouti. Tes réponses sont conservées ; tu peux réessayer. ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final questions = widget.quiz.questions;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(
        _result == null
            ? widget.quiz.title
            : _result!.passed
            ? 'Quiz réussi'
            : 'Encore un peu de pratique',
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Score : ${_result!.score.toStringAsFixed(0)} % · ${_result!.correctAnswers ?? 0} / ${_result!.total} réponses correctes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
              else
                Text(
                  '${questions.length} questions · environ ${widget.quiz.timeLimitMinutes} min. Choisis une réponse par question.',
                ),
              const SizedBox(height: 16),
              if (questions.isEmpty)
                const Text(
                  'Ce quiz n’a pas encore de questions. Reviens à la formation pour poursuivre les leçons.',
                ),
              for (var i = 0; i < questions.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${i + 1}. ${questions[i].question}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 12),
                        for (var j = 0; j < questions[i].choices.length; j++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Semantics(
                              selected: _answers[i] == j,
                              button: true,
                              child: InkWell(
                                onTap: _saving || _queued || _result != null
                                    ? null
                                    : () => setState(() => _answers[i] = j),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: _answers[i] == j
                                        ? colors.secondaryContainer
                                        : colors.surface,
                                    border: Border.all(
                                      color: _answers[i] == j
                                          ? colors.primary
                                          : colors.outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _answers[i] == j
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: _answers[i] == j
                                            ? colors.onSecondaryContainer
                                            : colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          questions[i].choices[j],
                                          style: TextStyle(
                                            color: _answers[i] == j
                                                ? colors.onSecondaryContainer
                                                : colors.onSurface,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_result != null &&
                            i < _result!.feedback.length) ...[
                          const Divider(height: 24),
                          Text(
                            'À retenir',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _result!.feedback[i]['explanation']?.toString() ??
                                '',
                            style: TextStyle(
                              color: colors.onSurface,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: _queued ? colors.onSurface : colors.error,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, _result),
          child: const Text('Fermer'),
        ),
        if (_result == null && !_queued)
          FilledButton.icon(
            onPressed:
                _saving ||
                    questions.isEmpty ||
                    _answers.length != questions.length
                ? null
                : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Envoi en cours' : 'Valider'),
          ),
        if (_result != null && !_result!.passed)
          FilledButton(
            onPressed: () => setState(() {
              _answers.clear();
              _result = null;
              _error = null;
            }),
            child: const Text('Réessayer'),
          ),
      ],
    );
  }
}
