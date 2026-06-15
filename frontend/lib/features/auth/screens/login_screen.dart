import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;

    return Scaffold(
      body: Row(
        children: [
          if (isWide) const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 4,
            child: _LoginPanel(
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: _obscurePassword,
              loading: _loading,
              error: _error,
              showMobileBrand: !isWide,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              onLogin: _login,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.softBlack,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final padding = compact ? 34.0 : 52.0;
            final logoSize = compact ? 126.0 : 164.0;
            final minPanelHeight = (constraints.maxHeight - (padding * 2))
                .clamp(0.0, double.infinity)
                .toDouble();

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minPanelHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BrandMark(size: logoSize),
                        SizedBox(height: compact ? 24 : 34),
                        const Text(
                          'Enactus ESP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'EnactSpace',
                          style: TextStyle(
                            color: AppTheme.enactusYellow,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Le QG numérique des Enacteurs: annonces, tâches, '
                          'présences, documents, finance, projets et vie de '
                          'communauté.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _BrandPill(
                              icon: Icons.forum_rounded,
                              label: 'Fil social',
                            ),
                            _BrandPill(
                              icon: Icons.task_alt_rounded,
                              label: 'Tâches',
                            ),
                            _BrandPill(
                              icon: Icons.groups_2_rounded,
                              label: 'Communauté',
                            ),
                            _BrandPill(
                              icon: Icons.notifications_rounded,
                              label: 'Alertes',
                            ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 28 : 44),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: AppTheme.enactusYellow,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connexion sécurisée, accès par rôle et '
                                'expérience pensée pour mobile, tablette et web.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final String? error;
  final bool showMobileBrand;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  const _LoginPanel({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.showMobileBrand,
    required this.onTogglePassword,
    required this.onLogin,
  });

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _ForgotPasswordDialog());
  }

  void _showJoinRequestSheet(
    BuildContext context, {
    String profileType = 'enacteur',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _JoinEnactusSheet(initialProfileType: profileType),
    );
  }

  void _showRecruitmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _RecruitmentAccessDialog(
        onStart: () => _showJoinRequestSheet(context, profileType: 'enacteur'),
      ),
    );
  }

  void _showGuideDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _BeginnerGuideDialog());
  }

  void _showBiometricDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _BiometricSetupDialog());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showMobileBrand) ...[
                  const _MobileBrandHeader(),
                  const SizedBox(height: 22),
                ],
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(
                      MediaQuery.sizeOf(context).width < 420 ? 20 : 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Connexion EnactSpace',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accède à ton espace Enactus ESP avec ton compte validé.',
                          style: TextStyle(color: Colors.black54, height: 1.4),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          onSubmitted: (_) => loading ? null : onLogin(),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: onTogglePassword,
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: loading
                                ? null
                                : () => _showForgotPasswordDialog(context),
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (error != null) ...[
                          _ErrorBanner(message: error!),
                          const SizedBox(height: 14),
                        ],
                        ElevatedButton.icon(
                          onPressed: loading ? null : onLogin,
                          icon: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Se connecter'),
                        ),
                        const SizedBox(height: 20),
                        const _LoginSectionLabel('Nouveau sur Enactus ESP ?'),
                        const SizedBox(height: 10),
                        _AccountRequestActions(
                          loading: loading,
                          onJoinEnacteur: () => _showJoinRequestSheet(context),
                          onJoinAlumni: () => _showJoinRequestSheet(
                            context,
                            profileType: 'alumni',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _LoginSupportActions(
                          onRecruitment: () => _showRecruitmentDialog(context),
                          onGuide: () => _showGuideDialog(context),
                          onBiometric: () => _showBiometricDialog(context),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.enactusYellow.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Les nouveaux comptes sont validés par les responsables autorisés avant accès complet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginSectionLabel extends StatelessWidget {
  final String label;

  const _LoginSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AccountRequestActions extends StatelessWidget {
  final bool loading;
  final VoidCallback onJoinEnacteur;
  final VoidCallback onJoinAlumni;

  const _AccountRequestActions({
    required this.loading,
    required this.onJoinEnacteur,
    required this.onJoinAlumni,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 430;
        final buttonWidth = twoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: buttonWidth,
              child: OutlinedButton.icon(
                onPressed: loading ? null : onJoinEnacteur,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Rejoindre Enactus ESP'),
              ),
            ),
            SizedBox(
              width: buttonWidth,
              child: OutlinedButton.icon(
                onPressed: loading ? null : onJoinAlumni,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Rejoindre comme Alumni'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoginSupportActions extends StatelessWidget {
  final VoidCallback onRecruitment;
  final VoidCallback onGuide;
  final VoidCallback onBiometric;

  const _LoginSupportActions({
    required this.onRecruitment,
    required this.onGuide,
    required this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: onRecruitment,
          icon: const Icon(Icons.how_to_reg_rounded),
          label: const Text('Candidature recrutement'),
        ),
        TextButton.icon(
          onPressed: onGuide,
          icon: const Icon(Icons.explore_rounded),
          label: const Text('Guide débutant'),
        ),
        TextButton.icon(
          onPressed: onBiometric,
          icon: const Icon(Icons.fingerprint_rounded),
          label: const Text('Biométrie'),
        ),
      ],
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || email.length < 6) {
      setState(() => _error = 'Renseigne une adresse email valide.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final debugOtp = await _authService.requestPasswordResetOtp(email: email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debugOtp == null
                ? 'Si ce compte existe, un code OTP a été préparé.'
                : 'Code OTP de test: $debugOtp',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmReset() async {
    if (_otpController.text.trim().length < 4) {
      setState(() => _error = 'Entre le code OTP reçu par email.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(
        () => _error =
            'Le nouveau mot de passe doit faire au moins 8 caractères.',
      );
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.confirmPasswordReset(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Réinitialiser le mot de passe'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Un code OTP sera envoyé à ton email avant de définir le nouveau mot de passe.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_codeSent,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Code OTP',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : (_codeSent ? _confirmReset : _sendCode),
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_codeSent ? Icons.check_rounded : Icons.mail_rounded),
          label: Text(_codeSent ? 'Valider' : 'Envoyer le code'),
        ),
      ],
    );
  }
}

class _JoinEnactusSheet extends StatefulWidget {
  final String initialProfileType;

  const _JoinEnactusSheet({required this.initialProfileType});

  @override
  State<_JoinEnactusSheet> createState() => _JoinEnactusSheetState();
}

class _JoinEnactusSheetState extends State<_JoinEnactusSheet> {
  final AuthService _authService = AuthService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _photoController = TextEditingController();
  final _departmentController = TextEditingController();
  final _levelController = TextEditingController();
  final _promotionController = TextEditingController();
  final _skillsController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _motivationController = TextEditingController();

  late String _profileType;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profileType = widget.initialProfileType;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _photoController.dispose();
    _departmentController.dispose();
    _levelController.dispose();
    _promotionController.dispose();
    _skillsController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final requiredFields = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _emailController.text.trim(),
      _departmentController.text.trim(),
    ];

    if (requiredFields.any((value) => value.isEmpty)) {
      setState(() => _error = 'Complète au moins identité, email et filière.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final temporaryPassword = await _authService.submitJoinRequest(
        profileType: _profileType,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: _photoController.text.trim(),
        department: _departmentController.text.trim(),
        level: _levelController.text.trim(),
        promotion: _promotionController.text.trim(),
        skills: _skillsController.text.trim(),
        linkedinUrl: _linkedinController.text.trim(),
        githubUrl: _githubController.text.trim(),
        portfolioUrl: _portfolioController.text.trim(),
        motivation: _motivationController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            temporaryPassword == null
                ? 'Demande envoyée. Validation par les responsables autorisés.'
                : 'Demande envoyée. Mot de passe test: $temporaryPassword',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Rejoindre Enactus ESP',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Le compte reste en attente jusqu’à validation par les responsables autorisés.',
                      style: TextStyle(color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'enacteur',
                          label: Text('Enacteur'),
                          icon: Icon(Icons.school_rounded),
                        ),
                        ButtonSegment(
                          value: 'alumni',
                          label: Text('Alumni'),
                          icon: Icon(Icons.workspace_premium_rounded),
                        ),
                      ],
                      selected: {_profileType},
                      onSelectionChanged: (values) {
                        setState(() => _profileType = values.first);
                      },
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 560;
                        final fieldWidth = twoColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _JoinField(
                              controller: _firstNameController,
                              label: 'Prénom',
                              icon: Icons.badge_outlined,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _lastNameController,
                              label: 'Nom',
                              icon: Icons.badge_outlined,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _phoneController,
                              label: 'Téléphone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _photoController,
                              label: 'Photo de profil (lien)',
                              icon: Icons.add_a_photo_outlined,
                              keyboardType: TextInputType.url,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _departmentController,
                              label: 'Filière / école',
                              icon: Icons.account_balance_outlined,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _levelController,
                              label: _profileType == 'alumni'
                                  ? 'Dernier niveau'
                                  : 'Niveau',
                              icon: Icons.timeline_rounded,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _promotionController,
                              label: 'Promotion',
                              icon: Icons.groups_3_outlined,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _linkedinController,
                              label: 'LinkedIn',
                              icon: Icons.link_rounded,
                              keyboardType: TextInputType.url,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _githubController,
                              label: 'GitHub',
                              icon: Icons.code_rounded,
                              keyboardType: TextInputType.url,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _portfolioController,
                              label: 'Portfolio',
                              icon: Icons.language_rounded,
                              keyboardType: TextInputType.url,
                              width: fieldWidth,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _skillsController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Compétences clés',
                        prefixIcon: Icon(Icons.auto_awesome_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _motivationController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Motivation / expérience Enactus',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: const Text('Envoyer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JoinField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final double width;
  final TextInputType? keyboardType;

  const _JoinField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.width,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class _RecruitmentAccessDialog extends StatelessWidget {
  final VoidCallback onStart;

  const _RecruitmentAccessDialog({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Candidature recrutement'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ce parcours permettra aux candidats de postuler sans compte quand une campagne est active.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              SizedBox(height: 14),
              _RecruitmentStep(
                icon: Icons.campaign_rounded,
                title: 'Campagne active',
                body: 'Le pôle Veille publie les besoins RH validés.',
              ),
              _RecruitmentStep(
                icon: Icons.assignment_ind_rounded,
                title: 'Formulaire candidat',
                body:
                    'Identité, niveau, motivation, compétences et disponibilité.',
              ),
              _RecruitmentStep(
                icon: Icons.visibility_off_rounded,
                title: 'Anonymisation possible',
                body:
                    'Les évaluateurs peuvent travailler avec des codes candidat.',
              ),
              _RecruitmentStep(
                icon: Icons.mark_email_read_rounded,
                title: 'Suivi et emails',
                body:
                    'Statut, entretien, acceptation ou refus seront notifiés.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onStart();
          },
          icon: const Icon(Icons.how_to_reg_rounded),
          label: const Text('Démarrer'),
        ),
      ],
    );
  }
}

class _RecruitmentStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _RecruitmentStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.enactusYellow.withValues(alpha: 0.2),
        foregroundColor: AppTheme.softBlack,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(body),
    );
  }
}

class _BeginnerGuideDialog extends StatelessWidget {
  const _BeginnerGuideDialog();

  @override
  Widget build(BuildContext context) {
    const items = [
      _GuideItem(
        icon: Icons.dynamic_feed_rounded,
        title: 'Fil d’actualité',
        body:
            'Suis les annonces officielles, réactions, commentaires et posts épinglés.',
      ),
      _GuideItem(
        icon: Icons.chat_bubble_rounded,
        title: 'Chat interne',
        body:
            'Discute en privé, par pôle, projet ou groupe avec médias et messages importants.',
      ),
      _GuideItem(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Travail d’équipe',
        body:
            'Retrouve tâches, présences, documents, projets, événements et objectifs.',
      ),
      _GuideItem(
        icon: Icons.privacy_tip_rounded,
        title: 'Accès adapté',
        body:
            'L’interface change selon ton rôle: Enacteur, Alumni, EnacChef, Financier ou Admin.',
      ),
    ];

    return AlertDialog(
      title: const Text('Guide débutant'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in items) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.enactusYellow.withValues(
                      alpha: 0.22,
                    ),
                    foregroundColor: AppTheme.softBlack,
                    child: Icon(item.icon),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(item.body),
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Compris'),
        ),
      ],
    );
  }
}

class _GuideItem {
  final IconData icon;
  final String title;
  final String body;

  const _GuideItem({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _BiometricSetupDialog extends StatelessWidget {
  const _BiometricSetupDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Déverrouillage biométrique'),
      content: const Text(
        'L’écran est prêt pour Face ID, empreinte et déverrouillage mobile. '
        'La dépendance native sera ajoutée lors du branchement mobile final.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Plus tard'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.fingerprint_rounded),
          label: const Text('Activer bientôt'),
        ),
      ],
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _BrandMark(size: 96),
        SizedBox(height: 14),
        Text(
          'Enactus ESP',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 4),
        Text(
          'EnactSpace',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.softBlack,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Espace interne des Enacteurs',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;

  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.10),
        child: Image.asset(
          'assets/img/logo_enactus_esp.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppTheme.enactusYellow,
              child: Icon(
                Icons.groups_2_rounded,
                size: size * 0.56,
                color: AppTheme.softBlack,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BrandPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.enactusYellow, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}
