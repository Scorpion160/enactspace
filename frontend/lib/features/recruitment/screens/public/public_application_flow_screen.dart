import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
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
  String? _gender;

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
    firstName: _text('firstName'),
    lastName: _text('lastName'),
    email: _text('email'),
    gender: _gender,
    phone: _optional('phone'),
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
    preferredPole: _optional('preferredPole'),
    projectInterest: _optional('projectInterest'),
    associativeExperience: _optional('associativeExperience'),
    availability: _optional('availability'),
    publicComment: _optional('publicComment'),
    cvUrl: _optional('cvUrl'),
    motivationLetterUrl: _optional('motivationLetterUrl'),
    attachmentUrl: _optional('attachmentUrl'),
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
    });
    try {
      final application = await _gateway.submitApplication(_draft());
      if (mounted) setState(() => _submitted = application);
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitError =
              'La candidature n’a pas pu être envoyée. Vérifie ta connexion puis réessaie.';
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
        backPath: '/recruitment/apply',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_campaignFailed || _campaign == null) {
      return PublicRecruitmentShell(
        backPath: '/recruitment/apply',
        child: PublicRecruitmentErrorState(onRetry: _loadCampaign),
      );
    }
    if (_submitted != null) {
      return PublicRecruitmentShell(
        backPath: null,
        child: ApplicationSuccessView(
          campaignTitle: _campaign!.title,
          email: _text('email'),
          trackingCode: _submitted!.publicTrackingCode,
        ),
      );
    }

    return PublicRecruitmentShell(
      backPath: '/recruitment/apply',
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
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
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
        'Téléphone — facultatif',
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
      ),
      DropdownButtonFormField<String>(
        initialValue: _gender,
        decoration: const InputDecoration(labelText: 'Genre — facultatif'),
        items: const [
          DropdownMenuItem(value: 'femme', child: Text('Femme')),
          DropdownMenuItem(value: 'homme', child: Text('Homme')),
          DropdownMenuItem(
            value: 'non_precise',
            child: Text('Préfère ne pas préciser'),
          ),
        ],
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
          _field('studyLevel', 'Formation ou niveau d’études', required: true),
          _field('department', 'Département ou filière', required: true),
        ],
      ),
      _field('className', 'Classe ou promotion — facultatif'),
      _longField(
        'associativeExperience',
        'Expérience associative — facultatif',
        'Tu peux citer une responsabilité, un projet ou une expérience bénévole.',
      ),
      _ResponsiveFields(
        children: [
          _field('preferredPole', 'Pôle préféré — facultatif'),
          _field('projectInterest', 'Projet d’intérêt — facultatif'),
        ],
      ),
    ],
  );

  Widget _motivationStep() => _StepBody(
    introduction:
        'Prends le temps de nous raconter ce qui te motive. Tes réponses restent en place si tu reviens en arrière.',
    children: [
      _longField(
        'motivation',
        'Pourquoi souhaites-tu rejoindre Enactus ESP ?',
        'Parle de ton envie d’agir, d’apprendre ou de contribuer.',
        required: true,
      ),
      _longField(
        'knownEnactusFrom',
        'Comment as-tu découvert Enactus ?',
        'Un événement, une personne, les réseaux sociaux…',
      ),
      _longField(
        'enactusKnowledge',
        'Que connais-tu du mouvement Enactus ?',
        'Explique simplement avec tes propres mots.',
      ),
      _longField(
        'contribution',
        'Quelle contribution souhaites-tu apporter ?',
        'Compétences, énergie, idées ou expérience.',
      ),
      _longField(
        'projectIdeas',
        'As-tu une idée de projet ?',
        'Une piste suffit, elle n’a pas besoin d’être finalisée.',
      ),
      _longField(
        'leadershipProfile',
        'Comment travailles-tu avec une équipe ?',
        'Décris ta manière d’écouter, décider et avancer.',
      ),
      _longField(
        'otherClubs',
        'Autres engagements — facultatif',
        'Clubs, associations ou activités personnelles.',
      ),
    ],
  );

  Widget _availabilityStep() => _StepBody(
    introduction:
        'L’engagement demande de la régularité. Indique honnêtement ce qui est possible pour toi.',
    children: [
      _longField(
        'availability',
        'Quelles sont tes disponibilités ?',
        'Jours, horaires et périodes importantes de ton calendrier.',
        required: true,
      ),
      _longField(
        'publicComment',
        'Contraintes ou précision — facultatif',
        'Ajoute ici une information utile pour comprendre ta disponibilité.',
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.enactusYellow.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Text(
          'L’équipe recherche un engagement réaliste et régulier. Il ne s’agit pas d’être disponible tout le temps.',
          style: TextStyle(height: 1.5),
        ),
      ),
    ],
  );

  Widget _documentsStep() => _StepBody(
    introduction:
        'Ajoute un lien accessible vers ton document, par exemple depuis ton espace de stockage en ligne.',
    children: [
      _field(
        'cvUrl',
        'Lien vers le CV — facultatif',
        keyboardType: TextInputType.url,
        validator: _urlValidator,
      ),
      _field(
        'motivationLetterUrl',
        'Lien vers la lettre de motivation — facultatif',
        keyboardType: TextInputType.url,
        validator: _urlValidator,
      ),
      _field(
        'attachmentUrl',
        'Lien vers un document complémentaire — facultatif',
        keyboardType: TextInputType.url,
        validator: _urlValidator,
      ),
      const Text(
        'Les documents sont facultatifs. Vérifie que les liens peuvent être consultés par l’équipe.',
        style: TextStyle(color: AppTheme.secondaryText, height: 1.5),
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
          _text('preferredPole'),
        ],
        onEdit: () => setState(() => _step = 1),
      ),
      ApplicationReviewSection(
        title: 'Motivations',
        lines: [
          _text('motivation'),
          _text('contribution'),
          _text('projectIdeas'),
        ],
        onEdit: () => setState(() => _step = 2),
      ),
      ApplicationReviewSection(
        title: 'Disponibilités',
        lines: [_text('availability'), _text('publicComment')],
        onEdit: () => setState(() => _step = 3),
      ),
      ApplicationReviewSection(
        title: 'Documents',
        lines: [
          _text('cvUrl'),
          _text('motivationLetterUrl'),
          _text('attachmentUrl'),
        ],
        onEdit: () => setState(() => _step = 4),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        onChanged: (value) => setState(() => _confirmed = value == true),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('J’ai vérifié les informations de ma candidature.'),
        subtitle: const Text('L’envoi sera définitif pour cette campagne.'),
      ),
      if (_submitError != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            _submitError!,
            style: const TextStyle(
              color: AppTheme.error,
              fontWeight: FontWeight.w700,
            ),
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

  String? _urlValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      return 'Utilise un lien complet commençant par http:// ou https://.';
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
        style: const TextStyle(color: AppTheme.secondaryText, height: 1.5),
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
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppTheme.border)),
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
                  label: const Text('Retour'),
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
                  label: const Text('Suivant'),
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
