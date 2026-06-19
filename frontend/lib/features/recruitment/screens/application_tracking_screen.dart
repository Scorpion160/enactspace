import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/application_tracking_model.dart';
import '../services/recruitment_service.dart';

class ApplicationTrackingScreen extends StatefulWidget {
  const ApplicationTrackingScreen({super.key});

  @override
  State<ApplicationTrackingScreen> createState() =>
      _ApplicationTrackingScreenState();
}

class _ApplicationTrackingScreenState extends State<ApplicationTrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _emailController = TextEditingController();
  final _service = RecruitmentService();

  bool _loading = false;
  String? _error;
  ApplicationTrackingModel? _tracking;

  @override
  void dispose() {
    _referenceController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tracking = await _service.trackApplication(
        applicationId: _referenceController.text,
        email: _emailController.text,
      );
      if (!mounted) return;
      setState(() => _tracking = tracking);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tracking = null;
        _error = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = constraints.maxWidth < 560 ? 16.0 : 32.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(onBack: () => context.go('/login')),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFormCard()),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _tracking == null
                                  ? const _TrackingWelcome()
                                  : _TrackingResult(tracking: _tracking!),
                            ),
                          ],
                        )
                      else ...[
                        _buildFormCard(),
                        const SizedBox(height: 18),
                        if (_tracking == null)
                          const _TrackingWelcome()
                        else
                          _TrackingResult(tracking: _tracking!),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard() {
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Utilisez la référence reçue après votre inscription et le même email.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _referenceController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Référence de candidature',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  final reference = value?.trim() ?? '';
                  if (reference.isEmpty) return 'Référence obligatoire.';
                  if (reference.length < 30) return 'Référence invalide.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email de candidature',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email obligatoire.';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Email invalide.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_loading) _track();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loading ? null : _track,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(_loading ? 'Recherche...' : 'Afficher mon suivi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Retour à la connexion',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Image.asset(
          'assets/img/logo_enactus_esp.png',
          width: 74,
          height: 54,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Espace candidat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _TrackingWelcome extends StatelessWidget {
  const _TrackingWelcome();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.route_rounded, color: AppTheme.enactusYellow, size: 42),
          SizedBox(height: 18),
          Text(
            'Votre parcours, sans compte membre',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Consultez uniquement l’avancement de votre dossier. L’accès aux espaces internes sera ouvert après acceptation et validation du compte.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TrackingResult extends StatelessWidget {
  final ApplicationTrackingModel tracking;

  const _TrackingResult({required this.tracking});

  static const _steps = [
    ('Dossier reçu', Icons.inbox_rounded),
    ('Présélection', Icons.fact_check_rounded),
    ('Entretien', Icons.record_voice_over_rounded),
    ('Décision', Icons.verified_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Icon(Icons.how_to_reg_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracking.campaignTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        tracking.statusLabel,
                        style: const TextStyle(
                          color: AppTheme.softBlack,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            for (var index = 0; index < _steps.length; index++)
              _TrackingStep(
                title: _steps[index].$1,
                icon: _steps[index].$2,
                active: index <= tracking.currentStep,
                isLast: index == _steps.length - 1,
                rejected: tracking.status == 'rejected' && index == 3,
              ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.enactusYellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prochaine étape',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(tracking.nextStep),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Dernière mise à jour : ${_formatDate(tracking.updatedAt)}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (tracking.accountCreated) ...[
              const SizedBox(height: 12),
              const Chip(
                avatar: Icon(Icons.person_rounded, size: 18),
                label: Text('Compte EnactSpace créé'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool active;
  final bool isLast;
  final bool rejected;

  const _TrackingStep({
    required this.title,
    required this.icon,
    required this.active,
    required this.isLast,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final color = rejected
        ? Colors.red.shade700
        : active
        ? AppTheme.softBlack
        : Colors.grey.shade400;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: active
                  ? rejected
                        ? Colors.red.shade50
                        : AppTheme.enactusYellow
                  : Colors.grey.shade100,
              foregroundColor: color,
              child: Icon(icon, size: 19),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: active ? AppTheme.enactusYellow : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              rejected ? 'Candidature non retenue' : title,
              style: TextStyle(
                color: color,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
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
