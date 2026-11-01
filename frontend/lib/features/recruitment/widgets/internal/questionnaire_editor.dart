import '../recruitment_workspace.dart';
import 'package:flutter/material.dart';
import '../../models/recruitment_question_model.dart';

class RecruitmentQuestionnaireEditor extends StatefulWidget {
  final List<RecruitmentApplicationQuestion> questions;
  final ValueChanged<List<RecruitmentApplicationQuestion>> onChanged;
  const RecruitmentQuestionnaireEditor({
    super.key,
    required this.questions,
    required this.onChanged,
  });
  @override
  State<RecruitmentQuestionnaireEditor> createState() =>
      _RecruitmentQuestionnaireEditorState();
}

class _RecruitmentQuestionnaireEditorState
    extends State<RecruitmentQuestionnaireEditor> {
  List<RecruitmentApplicationQuestion> get questions => widget.questions;
  ValueChanged<List<RecruitmentApplicationQuestion>> get onChanged =>
      widget.onChanged;
  String? _selected;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 1120 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return _editor(context);
      }
      final selected =
          questions.where((q) => q.id == _selected).firstOrNull ??
          questions.firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RecruitmentNotice(
            'Les questions déjà reçues restent conservées dans chaque dossier. Les modifications s’appliquent aux nouvelles candidatures.',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 240,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '${questions.length} questions',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        for (var i = 0; i < questions.length; i++)
                          ListTile(
                            selected: selected?.id == questions[i].id,
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text(
                              questions[i].label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              questions[i].section == 'motivation'
                                  ? 'Motivations'
                                  : 'Disponibilités',
                            ),
                            onTap: () =>
                                setState(() => _selected = questions[i].id),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _editor(context, selectedId: selected?.id),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Aperçu candidat',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        RecruitmentQuestionnairePreview(
                          questions: selected == null ? const [] : [selected],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _editor(BuildContext context, {String? selectedId}) => Column(
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
        if (selectedId == null || selectedId == questions[i].id)
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
                    minLines: 2,
                    maxLines: 3,
                    key: ValueKey('question-hint-${questions[i].id}'),
                    decoration: const InputDecoration(
                      labelText: 'Aide à la réponse — facultative',
                    ),
                    onChanged: (v) =>
                        _replace(i, questions[i].copyWith(hint: v)),
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
            : () {
                final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
                _selected = id;
                onChanged([
                  ...questions,
                  RecruitmentApplicationQuestion(
                    id: id,
                    label: 'Nouvelle question',
                  ),
                ]);
              },
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

class RecruitmentQuestionnairePreview extends StatelessWidget {
  final List<RecruitmentApplicationQuestion> questions;
  const RecruitmentQuestionnairePreview({super.key, required this.questions});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final section in [
        ('motivation', 'Motivations'),
        ('availability', 'Disponibilités'),
      ])
        if (questions.any((q) => q.section == section.$1)) ...[
          Text(
            section.$2,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final q in questions.where((q) => q.section == section.$1))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${q.label}${q.required ? ' *' : ' · Facultatif'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (q.hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        q.hint,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: Container(
                      height: 68,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      if (questions.isEmpty)
        const Text('Aucune question personnalisée pour cette campagne.'),
    ],
  );
}
