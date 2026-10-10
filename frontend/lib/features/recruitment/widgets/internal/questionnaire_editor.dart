import 'package:flutter/material.dart';
import '../../models/recruitment_question_model.dart';

class RecruitmentQuestionnaireEditor extends StatelessWidget {
  final List<RecruitmentApplicationQuestion> questions;
  final ValueChanged<List<RecruitmentApplicationQuestion>> onChanged;
  const RecruitmentQuestionnaireEditor({
    super.key,
    required this.questions,
    required this.onChanged,
  });
  void _replace(int index, RecruitmentApplicationQuestion value) {
    final next = List<RecruitmentApplicationQuestion>.of(questions);
    next[index] = value;
    onChanged(next);
  }

  void _move(int index, int delta) {
    final next = List<RecruitmentApplicationQuestion>.of(questions);
    final value = next.removeAt(index);
    next.insert(index + delta, value);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 20),
      Text(
        'Questionnaire des candidats',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Ajoute, retire, reformule et réordonne les questions de cette campagne. Les dossiers déjà reçus gardent leurs questions et leurs réponses d’origine.',
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < questions.length; i++)
        Card(
          key: ValueKey('question-editor-${questions[i].id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  initialValue: questions[i].label,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  key: ValueKey('question-label-${questions[i].id}'),
                  decoration: InputDecoration(labelText: 'Question ${i + 1}'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Écris un libellé pour cette question.'
                      : null,
                  onChanged: (v) =>
                      _replace(i, questions[i].copyWith(label: v)),
                ),
                TextFormField(
                  initialValue: questions[i].hint,
                  maxLength: 500,
                  key: ValueKey('question-hint-${questions[i].id}'),
                  decoration: const InputDecoration(
                    labelText: 'Aide à la réponse — facultative',
                  ),
                  onChanged: (v) => _replace(i, questions[i].copyWith(hint: v)),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: questions[i].section,
                  decoration: const InputDecoration(
                    labelText: 'Étape du formulaire',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'motivation',
                      child: Text('Motivations'),
                    ),
                    DropdownMenuItem(
                      value: 'availability',
                      child: Text('Disponibilités'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      _replace(i, questions[i].copyWith(section: v));
                    }
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: questions[i].required,
                  title: const Text('Réponse obligatoire'),
                  onChanged: (v) =>
                      _replace(i, questions[i].copyWith(required: v)),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Monter la question',
                      onPressed: i == 0 ? null : () => _move(i, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Descendre la question',
                      onPressed: i == questions.length - 1
                          ? null
                          : () => _move(i, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    TextButton.icon(
                      onPressed: () => onChanged(
                        questions
                            .where((q) => q.id != questions[i].id)
                            .toList(),
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Retirer la question'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        key: const Key('add-application-question'),
        onPressed: questions.length >= 40
            ? null
            : () => onChanged([
                ...questions,
                RecruitmentApplicationQuestion(
                  id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                  label: 'Nouvelle question',
                ),
              ]),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une question'),
      ),
      TextButton(
        onPressed: () => onChanged(List.of(defaultRecruitmentQuestions)),
        child: const Text('Reprendre le questionnaire Enactus ESP'),
      ),
    ],
  );
}
