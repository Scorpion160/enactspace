import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/application_model.dart';
import '../../models/candidate_conversion_model.dart';
import '../../models/application_status_presentation.dart';
import '../../services/internal_recruitment_gateway.dart';

class CandidateIntegrationSection extends StatefulWidget {
  final ApplicationModel application;
  final String campaignTitle;
  final InternalRecruitmentGateway gateway;
  final Future<void> Function()? onCompleted;

  const CandidateIntegrationSection({
    super.key,
    required this.application,
    required this.campaignTitle,
    required this.gateway,
    this.onCompleted,
  });

  @override
  State<CandidateIntegrationSection> createState() =>
      _CandidateIntegrationSectionState();
}

class _CandidateIntegrationSectionState
    extends State<CandidateIntegrationSection> {
  CandidateConversionResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final alreadyLinked = application.isConverted || _lastResult != null;
    final canPrepare =
        application.status == 'accepted' &&
        application.canConvert &&
        !alreadyLinked;

    return Card(
      key: const Key('candidate-integration-section'),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Intégration dans EnactSpace',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _IntegrationLine(
              label: 'Candidature',
              value: ApplicationStatusPresentation.fromStatus(
                application.status,
              ).title,
            ),
            _IntegrationLine(
              label: 'Compte',
              value: alreadyLinked ? 'Déjà membre' : 'À créer ou à réactiver',
            ),
            const SizedBox(height: 8),
            const Text(
              'L’intégration crée ou active un compte membre. Elle reste '
              'strictement séparée de la décision de recrutement.',
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 12),
              _ConversionFeedback(
                message:
                    'Intégration terminée : ${_lastResult!.operationLabel}.',
              ),
            ],
            if (canPrepare) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('candidate-integration-prepare'),
                  onPressed: _open,
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: const Text('Préparer l’intégration'),
                ),
              ),
            ] else if (!alreadyLinked && !application.canConvert) ...[
              const SizedBox(height: 10),
              const Text(
                'L’intégration est réservée aux responsables autorisés par le '
                'serveur.',
                style: TextStyle(color: AppTheme.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open() async {
    final result = await showDialog<CandidateConversionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CandidateConversionDialog(
        application: widget.application,
        campaignTitle: widget.campaignTitle,
        gateway: widget.gateway,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _lastResult = result);
    await widget.onCompleted?.call();
  }
}

class CandidateConversionDialog extends StatefulWidget {
  final ApplicationModel application;
  final String campaignTitle;
  final InternalRecruitmentGateway gateway;

  const CandidateConversionDialog({
    super.key,
    required this.application,
    required this.campaignTitle,
    required this.gateway,
  });

  @override
  State<CandidateConversionDialog> createState() =>
      _CandidateConversionDialogState();
}

class _CandidateConversionDialogState extends State<CandidateConversionDialog> {
  final _assignmentFormKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  CandidateConversionCatalog? _catalog;
  CandidateConversionResult? _result;
  Object? _catalogError;
  String? _submitError;
  String _profileType = 'enacteur';
  String? _corePoleId;
  String? _projectId;
  final Set<String> _supportPoleIds = {};
  int _step = 0;
  bool _loadingCatalog = true;
  bool _obscurePassword = true;
  bool _confirmed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final gender = (widget.application.gender ?? '').trim().toLowerCase();
    _profileType = gender.startsWith('f') || gender.contains('femme')
        ? 'enactrice'
        : 'enacteur';
    _loadCatalog();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final catalog = await widget.gateway.loadConversionCatalog();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _catalogError = error);
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 500 ? 10 : 24,
        vertical: 18,
      ),
      title: Text(
        result == null
            ? 'Intégrer ce candidat dans EnactSpace'
            : 'Intégration terminée',
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _assignmentFormKey,
          child: SingleChildScrollView(
            key: const Key('candidate-conversion-scroll'),
            child: result == null ? _buildFlow() : _buildResult(result),
          ),
        ),
      ),
      actions: result == null ? _buildActions() : _buildResultActions(result),
    );
  }

  Widget _buildFlow() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Étape ${_step + 1} sur 3',
        key: const Key('candidate-conversion-step'),
        style: const TextStyle(
          color: AppTheme.secondaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: (_step + 1) / 3),
      const SizedBox(height: 18),
      switch (_step) {
        0 => CandidateConversionSummary(
          application: widget.application,
          campaignTitle: widget.campaignTitle,
        ),
        1 => CandidateAssignmentStep(
          catalog: _catalog,
          loading: _loadingCatalog,
          error: _catalogError,
          profileType: _profileType,
          corePoleId: _corePoleId,
          projectId: _projectId,
          supportPoleIds: _supportPoleIds,
          passwordController: _password,
          obscurePassword: _obscurePassword,
          onRetry: _loadCatalog,
          onProfileChanged: (value) => setState(() => _profileType = value),
          onCorePoleChanged: (value) => setState(() => _corePoleId = value),
          onProjectChanged: (value) => setState(() => _projectId = value),
          onSupportPoleChanged: (id, selected) => setState(() {
            selected ? _supportPoleIds.add(id) : _supportPoleIds.remove(id);
          }),
          onPasswordVisibilityChanged: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        _ => CandidateConversionReview(
          application: widget.application,
          campaignTitle: widget.campaignTitle,
          profileLabel: _profileLabel,
          corePole: _corePoleName,
          supportPoles: _supportPoleNames,
          project: _projectName,
          confirmed: _confirmed,
          sending: _sending,
          onConfirmed: (value) => setState(() => _confirmed = value),
        ),
      },
      if (_submitError != null) ...[
        const SizedBox(height: 12),
        _ConversionFeedback(message: _submitError!, isError: true),
      ],
    ],
  );

  List<Widget> _buildActions() => [
    TextButton(
      onPressed: _sending
          ? null
          : () {
              if (_step == 0) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _step--;
                  _submitError = null;
                });
              }
            },
      child: Text(_step == 0 ? 'Retour' : 'Précédent'),
    ),
    if (_step < 2)
      FilledButton(
        key: const Key('candidate-conversion-next'),
        onPressed: _sending ? null : _next,
        child: const Text('Continuer'),
      )
    else
      FilledButton(
        key: const Key('candidate-conversion-submit'),
        onPressed: _sending || !_confirmed ? null : _submit,
        child: _sending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Finaliser l’intégration'),
      ),
  ];

  List<Widget> _buildResultActions(CandidateConversionResult result) => [
    FilledButton(
      key: const Key('candidate-conversion-close-result'),
      onPressed: () => Navigator.of(context).pop(result),
      child: const Text('Fermer'),
    ),
  ];

  void _next() {
    if (_step == 1) {
      if (_loadingCatalog || _catalogError != null || _catalog == null) return;
      if (!_assignmentFormKey.currentState!.validate()) return;
    }
    setState(() {
      _step++;
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    if (_sending || !_confirmed) return;
    setState(() {
      _sending = true;
      _submitError = null;
    });
    try {
      final result = await widget.gateway.convertCandidate(
        CandidateConversionRequest(
          applicationId: widget.application.id,
          password: _password.text.trim(),
          profileType: _profileType,
          corePoleId: _corePoleId,
          supportPoleIds: _supportPoleIds.toList(),
          projectId: _projectId,
        ),
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = _humanConversionError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String get _profileLabel =>
      _profileType == 'enactrice' ? 'Enactrice' : 'Enacteur';

  String get _corePoleName {
    for (final pole in _catalog?.poles ?? const []) {
      if (pole.id == _corePoleId) return pole.name;
    }
    return 'Aucun pôle cœur';
  }

  List<String> get _supportPoleNames =>
      _catalog?.poles
          .where((pole) => _supportPoleIds.contains(pole.id))
          .map((pole) => pole.name)
          .toList() ??
      const [];

  String get _projectName {
    for (final project in _catalog?.projects ?? const []) {
      if (project.id == _projectId) return project.name;
    }
    return 'Aucun projet';
  }

  Widget _buildResult(CandidateConversionResult result) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const _ConversionFeedback(
        message: 'Le compte membre a été intégré avec succès.',
      ),
      const SizedBox(height: 16),
      _IntegrationLine(label: 'Membre', value: widget.application.fullName),
      _IntegrationLine(label: 'Résultat', value: result.operationLabel),
      _IntegrationLine(label: 'Profil', value: result.profileLabel),
      _IntegrationLine(label: 'Pôle cœur', value: _corePoleName),
      _IntegrationLine(label: 'Projet', value: _projectName),
      const SizedBox(height: 12),
      const Text(
        'Aucun mot de passe n’est conservé ni affiché dans ce résultat.',
        style: TextStyle(color: AppTheme.secondaryText),
      ),
    ],
  );
}

class CandidateConversionSummary extends StatelessWidget {
  final ApplicationModel application;
  final String campaignTitle;

  const CandidateConversionSummary({
    super.key,
    required this.application,
    required this.campaignTitle,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Résumé du candidat',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Cette opération crée un compte ou active et relie un compte existant.',
      ),
      const SizedBox(height: 14),
      _IntegrationLine(label: 'Identité', value: application.fullName),
      _IntegrationLine(label: 'E-mail', value: application.email),
      _IntegrationLine(
        label: 'Téléphone',
        value: _available(application.phone),
      ),
      _IntegrationLine(label: 'Campagne', value: campaignTitle),
      _IntegrationLine(label: 'Candidature', value: application.statusLabel),
      _IntegrationLine(
        label: 'Pôle préféré',
        value: _available(application.preferredPole),
      ),
      _IntegrationLine(
        label: 'Projet d’intérêt',
        value: _available(application.projectInterest),
      ),
      _IntegrationLine(
        label: 'Parcours',
        value:
            '${_available(application.department)} · ${_available(application.studyLevel)}',
      ),
    ],
  );
}

class CandidateAssignmentStep extends StatelessWidget {
  final CandidateConversionCatalog? catalog;
  final bool loading;
  final Object? error;
  final String profileType;
  final String? corePoleId;
  final String? projectId;
  final Set<String> supportPoleIds;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onRetry;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<String?> onCorePoleChanged;
  final ValueChanged<String?> onProjectChanged;
  final void Function(String id, bool selected) onSupportPoleChanged;
  final VoidCallback onPasswordVisibilityChanged;

  const CandidateAssignmentStep({
    super.key,
    required this.catalog,
    required this.loading,
    required this.error,
    required this.profileType,
    required this.corePoleId,
    required this.projectId,
    required this.supportPoleIds,
    required this.passwordController,
    required this.obscurePassword,
    required this.onRetry,
    required this.onProfileChanged,
    required this.onCorePoleChanged,
    required this.onProjectChanged,
    required this.onSupportPoleChanged,
    required this.onPasswordVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Chargement des pôles et projets…'),
            ],
          ),
        ),
      );
    }
    if (error != null || catalog == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ConversionFeedback(
            message: 'Impossible de charger les pôles et projets.',
            isError: true,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }
    final corePoles = catalog!.poles.where((pole) => pole.isCorePole).toList();
    final supportPoles = catalog!.poles
        .where((pole) => pole.isSupportPole)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Affectations et accès initial',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const _IntegrationLine(
          label: 'Rôle attribué',
          value: 'Membre EnactSpace',
        ),
        const Text(
          'Le serveur attribue le rôle membre de base. Le profil ci-dessous '
          'adapte uniquement la présentation du membre.',
          style: TextStyle(color: AppTheme.secondaryText),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: const Key('candidate-conversion-profile'),
          initialValue: profileType,
          decoration: const InputDecoration(labelText: 'Profil membre'),
          items: const [
            DropdownMenuItem(value: 'enacteur', child: Text('Enacteur')),
            DropdownMenuItem(value: 'enactrice', child: Text('Enactrice')),
          ],
          onChanged: (value) {
            if (value != null) onProfileChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('candidate-conversion-core-pole'),
          initialValue: corePoleId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Pôle cœur'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Aucun pôle cœur'),
            ),
            ...corePoles.map(
              (pole) =>
                  DropdownMenuItem(value: pole.id, child: Text(pole.name)),
            ),
          ],
          onChanged: onCorePoleChanged,
        ),
        if (supportPoles.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Pôles support',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pole in supportPoles)
                FilterChip(
                  label: Text(pole.name),
                  selected: supportPoleIds.contains(pole.id),
                  onSelected: (selected) =>
                      onSupportPoleChanged(pole.id, selected),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('candidate-conversion-project'),
          initialValue: projectId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Projet'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Aucun projet'),
            ),
            ...catalog!.projects.map(
              (project) => DropdownMenuItem(
                value: project.id,
                child: Text(project.name),
              ),
            ),
          ],
          onChanged: onProjectChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('candidate-conversion-password'),
          controller: passwordController,
          obscureText: obscurePassword,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Mot de passe initial',
            helperText: '8 caractères minimum. Il ne sera pas réaffiché.',
            suffixIcon: IconButton(
              key: const Key('candidate-conversion-password-visibility'),
              onPressed: onPasswordVisibilityChanged,
              tooltip: obscurePassword
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) => (value ?? '').trim().length < 8
              ? 'Le mot de passe doit contenir au moins 8 caractères.'
              : null,
        ),
      ],
    );
  }
}

class CandidateConversionReview extends StatelessWidget {
  final ApplicationModel application;
  final String campaignTitle;
  final String profileLabel;
  final String corePole;
  final List<String> supportPoles;
  final String project;
  final bool confirmed;
  final bool sending;
  final ValueChanged<bool> onConfirmed;

  const CandidateConversionReview({
    super.key,
    required this.application,
    required this.campaignTitle,
    required this.profileLabel,
    required this.corePole,
    required this.supportPoles,
    required this.project,
    required this.confirmed,
    required this.sending,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Vérification finale',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      _IntegrationLine(label: 'Candidat', value: application.fullName),
      _IntegrationLine(label: 'E-mail', value: application.email),
      _IntegrationLine(label: 'Campagne', value: campaignTitle),
      const _IntegrationLine(label: 'Rôle', value: 'Membre EnactSpace'),
      _IntegrationLine(label: 'Profil', value: profileLabel),
      _IntegrationLine(label: 'Pôle cœur', value: corePole),
      _IntegrationLine(
        label: 'Pôles support',
        value: supportPoles.isEmpty ? 'Aucun' : supportPoles.join(', '),
      ),
      _IntegrationLine(label: 'Projet', value: project),
      const _IntegrationLine(
        label: 'Opération attendue',
        value: 'Création ou activation d’un compte existant',
      ),
      const SizedBox(height: 10),
      const _ConversionNotice(),
      const SizedBox(height: 10),
      CheckboxListTile(
        key: const Key('candidate-conversion-confirmation'),
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: sending ? null : (value) => onConfirmed(value ?? false),
        title: const Text(
          'Je confirme les affectations et l’ouverture de l’accès EnactSpace.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ],
  );
}

class _ConversionNotice extends StatelessWidget {
  const _ConversionNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.enactusYellow.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'Cette opération est distincte de la décision de recrutement.',
      style: TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class _ConversionFeedback extends StatelessWidget {
  final String message;
  final bool isError;

  const _ConversionFeedback({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : Colors.green.shade700;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .28)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message, style: TextStyle(color: color)),
      ),
    );
  }
}

class _IntegrationLine extends StatelessWidget {
  final String label;
  final String value;

  const _IntegrationLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
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

String _available(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? 'Non renseigné' : normalized;
}

String _humanConversionError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  final normalized = raw.toLowerCase();
  if (normalized.contains('doit être acceptée') ||
      normalized.contains('doit etre acceptee')) {
    return 'La candidature doit être retenue avant l’intégration.';
  }
  if (normalized.contains('permission') || normalized.contains('réservée')) {
    return 'Vous n’avez pas la permission de finaliser cette intégration.';
  }
  if (normalized.contains('déjà actif') ||
      normalized.contains('deja actif') ||
      normalized.contains('already active')) {
    return 'Un membre actif utilise déjà cette adresse e-mail.';
  }
  if (normalized.contains('mot de passe')) {
    return 'Le mot de passe initial doit contenir au moins 8 caractères.';
  }
  if (normalized.contains('pôle introuvable') ||
      normalized.contains('pole introuvable')) {
    return 'Le pôle sélectionné n’est plus disponible.';
  }
  if (normalized.contains('projet introuvable')) {
    return 'Le projet sélectionné n’est plus disponible.';
  }
  if (normalized.contains('network') ||
      normalized.contains('réseau') ||
      normalized.contains('socket')) {
    return 'Le réseau est indisponible. Vérifiez la connexion puis réessayez.';
  }
  return raw.isEmpty
      ? 'Impossible de finaliser l’intégration. Réessayez.'
      : raw;
}
