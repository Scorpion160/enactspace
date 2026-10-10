import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../../../shared/attachments/attachment_picker.dart';

import '../../../../core/academic/esp_academic_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
import '../../models/recruitment_question_model.dart';
import '../../models/public_application_draft.dart';
import '../../models/recruitment_campaign_model.dart';
import '../../services/public_recruitment_gateway.dart';
import '../../widgets/public/public_recruitment_widgets.dart';

class PublicApplicationFlowScreen extends StatefulWidget {
  final String campaignId;
  final RecruitmentCampaignModel? campaign;
  final PublicRecruitmentGateway? gateway;

  const PublicApplicationFlowScreen({
    super.key,
    required this.campaignId,
    this.campaign,
    this.gateway,
  });

  @override
  State<PublicApplicationFlowScreen> createState() =>
      _PublicApplicationFlowScreenState();
}

class _PublicApplicationFlowScreenState
    extends State<PublicApplicationFlowScreen> {
  static const _stepTitles = [
    'Ton identité',
    'Ton parcours',
    'Tes motivations',
    'Tes disponibilités',
    'Tes documents',
    'Vérification',
  ];

  late final PublicRecruitmentGateway _gateway;
  final _formKeys = List.generate(6, (_) => GlobalKey<FormState>());
  final _controllers = <String, TextEditingController>{};
  RecruitmentCampaignModel? _campaign;
  ApplicationModel? _submitted;
  int _step = 0;
  bool _campaignLoading = true;
  bool _campaignFailed = false;
  bool _submitting = false;
  bool _confirmed = false;
  String? _submitError;
  PublicRecruitmentFailureKind? _submitFailureKind;
  String? _gender;
  SelectedAttachment? _cvFile, _motivationLetterFile, _attachmentFile;

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? RecruitmentPublicGateway();
    _campaign = widget.campaign;
    if (_campaign != null) {
      _campaignLoading = false;
    } else {
      _loadCampaign();
    }
  }

  Future<void> _loadCampaign() async {
    setState(() {
      _campaignLoading = true;
      _campaignFailed = false;
    });
    try {
      final campaigns = await _gateway.loadCampaigns();
      RecruitmentCampaignModel? selected;
      for (final campaign in campaigns) {
        if (campaign.id == widget.campaignId) selected = campaign;
      }
      if (!mounted) return;
      if (selected == null) {
        setState(() {
          _campaignLoading = false;
          _campaignFailed = true;
        });
      } else {
        setState(() {
          _campaign = selected;
          _campaignLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _campaignLoading = false;
          _campaignFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(String key) => _controller(key).text.trim();
  String? _optional(String key) => _text(key).isEmpty ? null : _text(key);

  PublicApplicationDraft _draft() => PublicApplicationDraft(
    campaignId: widget.campaignId,
    questionnaireAnswers: {
      for (final q in _campaign!.applicationQuestions)
        q.id: _text(_questionKey(q)),
    },
    questionnaireVersion: _campaign!.questionnaireVersion,
    firstName: _text('firstName'),
    lastName: _text('lastName'),
    email: _text('email'),
    gender: _gender,
    phone: _text('phone'),
    department: _optional('department'),
    studyLevel: _optional('studyLevel'),
    className: _optional('className'),
    motivation: _optional('motivation'),
    knownEnactusFrom: _optional('knownEnactusFrom'),
    enactusKnowledge: _optional('enactusKnowledge'),
    otherClubs: _optional('otherClubs'),
    contribution: _optional('contribution'),
    projectIdeas: _optional('projectIdeas'),
    leadershipProfile: _optional('leadershipProfile'),
    associativeExperience: _optional('associativeExperience'),
    availability: _optional('availability'),
    publicComment: _optional('publicComment'),
    cvFile: _cvFile,
    motivationLetterFile: _motivationLetterFile,
    attachmentFile: _attachmentFile,
  );

  void _next() {
    final form = _formKeys[_step].currentState;
    if (form != null && !form.validate()) return;
    if (_step < 5) setState(() => _step += 1);
  }

  void _back() {
    if (_step > 0) setState(() => _step -= 1);
  }

  Future<void> _submit() async {
    if (!_confirmed || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
      _submitFailureKind = null;
    });
    try {
      final application = await _gateway.submitApplication(_draft());
      if (mounted) setState(() => _submitted = application);
    } on PublicRecruitmentFailure catch (error) {
      if (error.kind == PublicRecruitmentFailureKind.questionnaireChanged) {
        var campaigns = <RecruitmentCampaignModel>[];
        try {
          campaigns = await _gateway.loadCampaigns();
        } catch (_) {}
        if (mounted) {
          setState(() {
            for (final campaign in campaigns) {
              if (campaign.id == _campaign?.id) _campaign = campaign;
            }
            _step = 2;
            _confirmed = false;
            _submitError =
                'Le questionnaire a été mis à jour. Relis les questions avant de confirmer ta candidature.';
          });
        }
      } else if (mounted) {
        setState(() {
          _submitFailureKind = error.kind;
          _submitError = error.submissionMessage;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitError = const PublicRecruitmentFailure(
            PublicRecruitmentFailureKind.server,
          ).submissionMessage;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_campaignLoading) {
      return const PublicRecruitmentShell(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_campaignFailed || _campaign == null) {
      return PublicRecruitmentShell(
        child: PublicRecruitmentErrorState(onRetry: _loadCampaign),
      );
    }
    if (_submitted != null) {
      return PublicRecruitmentShell(
        child: ApplicationSuccessView(
          campaignTitle: _campaign!.title,
          email: _text('email'),
          trackingCode: _submitted!.publicTrackingCode,
        ),
      );
    }

    return PublicRecruitmentShell(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Form(
                    key: _formKeys[_step],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _campaign!.title,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ApplicationStepHeader(
                          currentStep: _step + 1,
                          totalSteps: 6,
                          title: _stepTitles[_step],
                        ),
                        const SizedBox(height: 26),
                        _buildStep(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _NavigationBar(
            step: _step,
            submitting: _submitting,
            canSubmit: _confirmed,
            onBack: _back,
            onNext: _next,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    0 => _identityStep(),
    1 => _pathStep(),
    2 => _motivationStep(),
    3 => _availabilityStep(),
    4 => _documentsStep(),
    _ => _reviewStep(),
  };

  Widget _identityStep() => _StepBody(
    introduction:
        'Commençons par les informations qui permettront de te contacter.',
    children: [
      _ResponsiveFields(
        children: [
          _field(
            'firstName',
            'Prénom',
            required: true,
            autofillHints: const [AutofillHints.givenName],
          ),
          _field(
            'lastName',
            'Nom',
            required: true,
            autofillHints: const [AutofillHints.familyName],
          ),
        ],
      ),
      _field(
        'email',
        'Adresse e-mail',
        required: true,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        validator: _emailValidator,
      ),
      _field(
        'phone',
        'Téléphone',
        required: true,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
      ),
      DropdownButtonFormField<String>(
        key: const ValueKey('field-gender'),
        initialValue: _gender,
        decoration: const InputDecoration(labelText: 'Genre *'),
        items: const [
          DropdownMenuItem(value: 'femme', child: Text('Femme')),
          DropdownMenuItem(value: 'homme', child: Text('Homme')),
          DropdownMenuItem(
            value: 'non_precise',
            child: Text('Préfère ne pas préciser'),
          ),
        ],
        validator: (value) => value == null ? 'Champ obligatoire' : null,
        onChanged: (value) => setState(() => _gender = value),
      ),
    ],
  );

  Widget _pathStep() => _StepBody(
    introduction:
        'Présente ton parcours avec les mots que tu utilises au quotidien.',
    children: [
      _ResponsiveFields(
        children: [
          _choiceField('studyLevel', 'Niveau d’études *', espAcademicLevels),
          _choiceField(
            'department',
            'Département ESP *',
            espAcademicDepartments,
          ),
        ],
      ),
      _field('className', 'Classe ou promotion — facultatif'),
      _longField(
        'associativeExperience',
        'Expérience associative — facultatif',
        'Tu peux citer une responsabilité, un projet ou une expérience bénévole.',
      ),
      if (!_campaign!.applicationQuestions.any(
        (q) => q.legacyField == 'known_enactus_from',
      ))
        _longField(
          'knownEnactusFrom',
          'Comment as-tu connu Enactus ESP ?',
          'Un ami, les réseaux sociaux, un événement, un cours… raconte-nous.',
        ),
    ],
  );

  String _questionKey(RecruitmentApplicationQuestion question) {
    const legacy = {
      'motivation': 'motivation',
      'known_enactus_from': 'knownEnactusFrom',
      'enactus_knowledge': 'enactusKnowledge',
      'other_clubs': 'otherClubs',
      'contribution': 'contribution',
      'project_ideas': 'projectIdeas',
      'leadership_profile': 'leadershipProfile',
      'availability': 'availability',
      'public_comment': 'publicComment',
      'associative_experience': 'associativeExperience',
    };
    return legacy[question.legacyField] ?? 'question-${question.id}';
  }

  Widget _questionStep(String section, String introduction) {
    final questions = _campaign!.applicationQuestions
        .where((q) => q.section == section)
        .toList();
    return _StepBody(
      introduction: introduction,
      children: [
        if (questions.isEmpty)
          const Text(
            'Cette campagne ne demande pas de réponse dans cette rubrique.',
          ),
        for (final q in questions)
          _longField(_questionKey(q), q.label, q.hint, required: q.required),
        if (section == 'availability')
          const Text(
            'Décris un engagement réaliste. Tes études et tes contraintes personnelles comptent aussi.',
            style: TextStyle(height: 1.5),
          ),
      ],
    );
  }

  Widget _motivationStep() => _questionStep(
    'motivation',
    'Parle-nous de toi et de ce qui te donne envie d’agir. Tes réponses restent en place si tu reviens en arrière.',
  );

  Widget _availabilityStep() => _questionStep(
    'availability',
    'Explique la place que tu peux donner à l’équipe, aux rencontres et aux missions de terrain.',
  );

  Widget _documentsStep() => _StepBody(
    introduction:
        'Une réalisation, une expérience ou un CV peut compléter ton histoire. Joins directement tes documents ; ils seront transmis avec ta candidature à l’équipe recrutement.',
    children: [
      AttachmentPickerField(
        label: 'Ton CV',
        value: _cvFile,
        application: true,
        enabled: !_submitting,
        onChanged: (file) => setState(() => _cvFile = file),
      ),
      AttachmentPickerField(
        label: 'Ta lettre de motivation',
        value: _motivationLetterFile,
        application: true,
        enabled: !_submitting,
        onChanged: (file) => setState(() => _motivationLetterFile = file),
      ),
      AttachmentPickerField(
        label: 'Une réalisation ou un document complémentaire',
        value: _attachmentFile,
        application: true,
        enabled: !_submitting,
        onChanged: (file) => setState(() => _attachmentFile = file),
      ),
      const Text(
        'Ces documents sont facultatifs. Tes réponses suffisent pour postuler. Les pièces jointes restent accessibles à l’équipe habilitée.',
        style: TextStyle(height: 1.5),
      ),
    ],
  );

  Widget _reviewStep() => _StepBody(
    introduction:
        'Relis tes informations avant l’envoi. Rien ne sera envoyé automatiquement.',
    children: [
      ApplicationReviewSection(
        title: 'Campagne',
        lines: [_campaign!.title],
        onEdit: () => setState(() => _step = 0),
      ),
      ApplicationReviewSection(
        title: 'Identité',
        lines: [
          '${_text('firstName')} ${_text('lastName')}',
          _text('email'),
          _text('phone'),
        ],
        onEdit: () => setState(() => _step = 0),
      ),
      ApplicationReviewSection(
        title: 'Parcours',
        lines: [
          _text('studyLevel'),
          _text('department'),
          _text('className'),
          if (!_campaign!.applicationQuestions.any(
            (q) => q.legacyField == 'known_enactus_from',
          ))
            'Découverte d’Enactus ESP : ${_text('knownEnactusFrom').isEmpty ? 'Non renseigné' : _text('knownEnactusFrom')}',
        ],
        onEdit: () => setState(() => _step = 1),
      ),
      ApplicationReviewSection(
        title: 'Motivations',
        lines: [
          for (final q in _campaign!.applicationQuestions.where(
            (q) => q.section == 'motivation',
          ))
            '${q.label}\n${_text(_questionKey(q)).isEmpty ? 'Non renseigné' : _text(_questionKey(q))}',
        ],
        onEdit: () => setState(() => _step = 2),
      ),
      ApplicationReviewSection(
        title: 'Disponibilités',
        lines: [
          for (final q in _campaign!.applicationQuestions.where(
            (q) => q.section == 'availability',
          ))
            '${q.label}\n${_text(_questionKey(q)).isEmpty ? 'Non renseigné' : _text(_questionKey(q))}',
        ],
        onEdit: () => setState(() => _step = 3),
      ),
      ApplicationReviewSection(
        title: 'Documents',
        lines: [
          _cvFile?.name ?? 'CV : aucun fichier joint',
          _motivationLetterFile?.name ?? 'Lettre : aucun fichier joint',
          _attachmentFile?.name ??
              'Document complémentaire : aucun fichier joint',
        ],
        onEdit: () => setState(() => _step = 4),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        onChanged: (value) => setState(() => _confirmed = value == true),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('J’ai vérifié les informations de ma candidature.'),
        subtitle: Text('L’envoi sera définitif pour cette campagne.'),
      ),
      if (_submitError != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _submitError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              if (_submitFailureKind ==
                  PublicRecruitmentFailureKind.duplicateApplication) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const ValueKey('duplicate-application-tracking'),
                  onPressed: () => context.push('/recruitment/track'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer,
                  ),
                  icon: const Icon(Icons.track_changes_rounded),
                  label: const Text('Suivre ma candidature'),
                ),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: ValueKey('field-$key'),
      controller: _controller(key),
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ?? (required ? (value) => _required(value, label) : null),
    );
  }

  Widget _choiceField(String key, String label, List<String> options) {
    final controller = _controller(key);
    final current = controller.text.trim();
    return DropdownButtonFormField<String>(
      key: ValueKey('field-$key'),
      initialValue: options.contains(current) ? current : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) => controller.text = value ?? '',
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Ce champ est nécessaire pour continuer.'
          : null,
    );
  }

  Widget _longField(
    String key,
    String label,
    String help, {
    bool required = false,
  }) {
    return TextFormField(
      key: ValueKey('field-$key'),
      controller: _controller(key),
      minLines: 4,
      maxLines: 7,
      maxLength: 1200,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        alignLabelWithHint: true,
      ),
      validator: required ? (value) => _required(value, label) : null,
    );
  }

  String? _required(String? value, String label) =>
      value?.trim().isEmpty ?? true
      ? 'Ce champ est nécessaire pour continuer.'
      : null;

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Indique ton adresse e-mail pour continuer.';
    final parts = email.split('@');
    if (parts.length != 2 || !parts.last.contains('.')) {
      return 'Vérifie le format de l’adresse e-mail.';
    }
    return null;
  }
}

class _StepBody extends StatelessWidget {
  final String introduction;
  final List<Widget> children;
  const _StepBody({required this.introduction, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        introduction,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 22),
      for (var index = 0; index < children.length; index++) ...[
        children[index],
        if (index < children.length - 1) const SizedBox(height: 18),
      ],
      const SizedBox(height: 24),
    ],
  );
}

class _ResponsiveFields extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveFields({required this.children});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 680) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1) const SizedBox(height: 18),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index < children.length - 1) const SizedBox(width: 18),
        ],
      ],
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final int step;
  final bool submitting;
  final bool canSubmit;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  const _NavigationBar({
    required this.step,
    required this.submitting,
    required this.canSubmit,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
      12,
      MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Row(
          children: [
            if (step > 0)
              Semantics(
                button: true,
                label: 'Retour à l’étape précédente',
                child: OutlinedButton.icon(
                  onPressed: submitting ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text('Retour'),
                ),
              ),
            const Spacer(),
            if (step < 5)
              Semantics(
                button: true,
                label: 'Passer à l’étape suivante',
                child: FilledButton.icon(
                  key: const ValueKey('application-next'),
                  onPressed: onNext,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Suivant'),
                ),
              )
            else
              Semantics(
                button: true,
                label: 'Envoyer ma candidature',
                child: FilledButton.icon(
                  key: const ValueKey('application-submit'),
                  onPressed: canSubmit && !submitting ? onSubmit : null,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    submitting ? 'Envoi en cours…' : 'Envoyer ma candidature',
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
