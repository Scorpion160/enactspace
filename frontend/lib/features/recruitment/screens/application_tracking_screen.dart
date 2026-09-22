import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/application_status_presentation.dart';
import '../models/application_tracking_model.dart';
import '../services/public_recruitment_gateway.dart';
import '../widgets/public/public_recruitment_widgets.dart';

class ApplicationTrackingScreen extends StatefulWidget {
  final PublicRecruitmentGateway? gateway;

  const ApplicationTrackingScreen({super.key, this.gateway});

  @override
  State<ApplicationTrackingScreen> createState() =>
      _ApplicationTrackingScreenState();
}

class _ApplicationTrackingScreenState extends State<ApplicationTrackingScreen> {
  late final PublicRecruitmentGateway _gateway;
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  ApplicationTrackingModel? _tracking;
  bool _loading = false;
  TrackingErrorKind? _error;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? RecruitmentPublicGateway();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _gateway.trackApplication(
        code: _codeController.text,
        email: _emailController.text,
      );
      if (mounted) setState(() => _tracking = result);
    } on PublicRecruitmentFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _tracking = null;
        _error = switch (error.kind) {
          PublicRecruitmentFailureKind.notFound => TrackingErrorKind.notFound,
          PublicRecruitmentFailureKind.network => TrackingErrorKind.network,
          PublicRecruitmentFailureKind.server => TrackingErrorKind.server,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _tracking = null;
          _error = TrackingErrorKind.server;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PublicRecruitmentShell(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
          vertical: 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final form = TrackingSearchForm(
                  codeController: _codeController,
                  emailController: _emailController,
                  loading: _loading,
                  error: _error,
                  onSearch: _search,
                );
                final result = _tracking == null
                    ? const _TrackingIntroduction()
                    : TrackingResultView(tracking: _tracking!);
                if (constraints.maxWidth < 860) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [form, const SizedBox(height: 20), result],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: form),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: result),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

enum TrackingErrorKind { notFound, network, server }

class TrackingSearchForm extends StatefulWidget {
  final TextEditingController codeController;
  final TextEditingController emailController;
  final bool loading;
  final TrackingErrorKind? error;
  final VoidCallback onSearch;

  const TrackingSearchForm({
    super.key,
    required this.codeController,
    required this.emailController,
    required this.loading,
    required this.error,
    required this.onSearch,
  });

  @override
  State<TrackingSearchForm> createState() => _TrackingSearchFormState();
}

class _TrackingSearchFormState extends State<TrackingSearchForm> {
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    if (_formKey.currentState?.validate() == true) widget.onSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Suivre ma candidature',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Saisis le code reçu après l’envoi et la même adresse e-mail.',
                style: TextStyle(color: AppTheme.secondaryText, height: 1.5),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: widget.codeController,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code de suivi',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  final code = value?.trim() ?? '';
                  if (code.isEmpty) return 'Indique ton code de suivi.';
                  if (code.length < 8) return 'Ce code semble incomplet.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: widget.emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail de candidature',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Indique ton adresse e-mail.';
                  final parts = email.split('@');
                  if (parts.length != 2 || !parts.last.contains('.')) {
                    return 'Vérifie le format de l’adresse e-mail.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!widget.loading) _submit();
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Code perdu ? Consulte le message affiché après ton envoi. Aucun mécanisme de récupération automatique n’est disponible actuellement.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 14),
                _TrackingError(kind: widget.error!),
              ],
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label: 'Consulter ma candidature',
                child: FilledButton.icon(
                  onPressed: widget.loading ? null : _submit,
                  icon: widget.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(
                    widget.loading
                        ? 'Recherche en cours…'
                        : 'Consulter ma candidature',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  final TrackingErrorKind kind;
  const _TrackingError({required this.kind});

  @override
  Widget build(BuildContext context) {
    final message = switch (kind) {
      TrackingErrorKind.notFound =>
        'Aucune candidature ne correspond à ce code et à cette adresse e-mail.',
      TrackingErrorKind.network =>
        'La connexion semble interrompue. Vérifie ton accès internet puis réessaie.',
      TrackingErrorKind.server =>
        'Le suivi est momentanément indisponible. Réessaie dans quelques instants.',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrackingIntroduction extends StatelessWidget {
  const _TrackingIntroduction();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_rounded, color: AppTheme.enactusYellow, size: 44),
          SizedBox(height: 18),
          Text(
            'Ton parcours candidat, simplement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Consulte l’avancement de ton dossier sans créer de compte. Les mises à jour importantes apparaîtront ici.',
            style: TextStyle(color: Colors.white70, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class TrackingResultView extends StatelessWidget {
  final ApplicationTrackingModel tracking;
  const TrackingResultView({super.key, required this.tracking});

  @override
  Widget build(BuildContext context) {
    final presentation = ApplicationStatusPresentation.fromStatus(
      tracking.status,
    );
    return Semantics(
      container: true,
      label: 'Statut de la candidature, ${presentation.title}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(presentation.icon, size: 38, color: AppTheme.softBlack),
              const SizedBox(height: 12),
              Text(
                presentation.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                presentation.explanation,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                tracking.campaignTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                tracking.candidateName,
                style: const TextStyle(color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 6),
              Semantics(
                label: 'Code de suivi ${tracking.trackingCode}',
                child: SelectableText('Code : ${tracking.trackingCode}'),
              ),
              const SizedBox(height: 24),
              ApplicationTimeline(tracking: tracking),
              const SizedBox(height: 18),
              _InformationPanel(
                title: 'Prochaine étape',
                text: presentation.nextAction,
                icon: Icons.arrow_forward_rounded,
              ),
              if (tracking.hasInterviewDetails) ...[
                const SizedBox(height: 12),
                _InformationPanel(
                  title: 'Ton entretien',
                  text: tracking.interviewDetails!.trim(),
                  icon: Icons.event_available_outlined,
                ),
              ],
              if (tracking.candidateMessage?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _InformationPanel(
                  title: 'Message de l’équipe',
                  text: tracking.candidateMessage!.trim(),
                  icon: Icons.mark_email_read_outlined,
                ),
              ],
              if (tracking.hasFinalResult) ...[
                const SizedBox(height: 12),
                _InformationPanel(
                  title: 'Décision',
                  text: tracking.finalResult!.trim(),
                  icon: Icons.flag_outlined,
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Dernière mise à jour : ${_formatDate(tracking.updatedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => context.go('/recruitment/apply'),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Voir les campagnes ouvertes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationPanel extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  const _InformationPanel({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppTheme.enactusYellow.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime? value) {
  if (value == null) return 'non disponible';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} à $hour:$minute';
}
