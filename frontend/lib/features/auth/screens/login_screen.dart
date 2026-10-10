import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/academic/esp_academic_catalog.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/biometric_authenticator.dart';
import '../../../core/auth/login_preferences.dart';
import '../../../core/brand/brand_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/app_components.dart';

class LoginScreen extends StatefulWidget {
  final AuthService? authService;
  final BiometricAuthenticator? biometrics;
  const LoginScreen({super.key, this.authService, this.biometrics});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthService _authService;
  late final BiometricAuthenticator _biometrics;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _automaticBiometricAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _biometrics = widget.biometrics ?? BiometricAuthenticator();
    _prepareRememberedLogin();
  }

  Future<void> _prepareRememberedLogin() async {
    final remembered = await LoginPreferences.readIdentifier();
    final hasSession = await _authService.isLoggedIn();
    final supported = await _biometrics.isAvailable();
    final cached = remembered == null && hasSession
        ? await _authService.getCachedCurrentUser()
        : null;
    final identifier = remembered ?? cached?['email']?.toString();
    if (!mounted) return;
    setState(() {
      if (_emailController.text.isEmpty && identifier != null) {
        _emailController.text = identifier;
      }
      _biometricAvailable = hasSession && supported;
    });
    if (_biometricAvailable && !_automaticBiometricAttempted) {
      _automaticBiometricAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading) _loginWithBiometrics();
      });
    }
  }

  Future<void> _loginWithBiometrics() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authenticated = await _biometrics.authenticate();
      if (!authenticated) {
        if (mounted) {
          setState(
            () => _error =
                'Déverrouillage annulé. Réessaie avec la biométrie ou utilise ton mot de passe.',
          );
        }
        return;
      }
      final restored = await _authService.restoreSession();
      if (!mounted) return;
      if (restored) {
        context.go('/dashboard');
      } else {
        setState(() {
          _biometricAvailable = false;
          _error =
              'La session sécurisée a expiré. Connecte-toi une fois avec ton mot de passe.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Authentification biométrique indisponible. Utilise ton mot de passe.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      final identifier = _emailController.text.trim();
      await _authService.login(
        identifier: identifier,
        password: _passwordController.text,
      );
      await LoginPreferences.rememberIdentifier(identifier);

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
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    final content = Row(
        children: [
          if (isWide) Expanded(flex: 4, child: _BrandPanel()),
          Expanded(
            flex: 5,
            child: _LoginPanel(
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: _obscurePassword,
              loading: _loading,
              biometricAvailable: _biometricAvailable,
              error: _error,
              showMobileBrand: !isWide,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              onLogin: _login,
              onBiometric: _loginWithBiometrics,
            ),
          ),
        ],
    );
    if (!isWide) return Scaffold(body: content);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/heritage/niaguiss-2025-demonstration.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.centerLeft,
            excludeFromSemantics: true,
            errorBuilder: (_, error, stackTrace) =>
                const ColoredBox(color: AppTheme.softBlack),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x880F1820), Color(0xE60F1820)],
              ),
            ),
          ),
          Theme(data: AppTheme.darkTheme, child: content),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BrandMark(size: 88, onDark: true),
                    SizedBox(height: 20),
                    Text('Enactus ESP',
                      style: TextStyle(color: AppTheme.enactusYellow,
                        fontSize: 22, fontWeight: FontWeight.w700)),
                    SizedBox(height: 14),
                    Text('Ensemble, donnons\nvie aux idées.',
                      style: TextStyle(color: Colors.white, fontSize: 38,
                        fontWeight: FontWeight.w800, height: 1.15)),
                    SizedBox(height: 16),
                    Text('Apprendre, entreprendre et agir avec les communautés.',
                      style: TextStyle(color: Colors.white, fontSize: 17,
                        height: 1.5)),
                    SizedBox(height: 20),
                    Text('Une équipe. Des projets. Un impact partagé.',
                      style: TextStyle(color: AppTheme.enactusYellow,
                        fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoginPanel extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final bool biometricAvailable;
  final String? error;
  final bool showMobileBrand;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback onBiometric;

  const _LoginPanel({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.biometricAvailable,
    required this.error,
    required this.showMobileBrand,
    required this.onTogglePassword,
    required this.onLogin,
    required this.onBiometric,
  });

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _ForgotPasswordDialog());
  }

  void _showJoinRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => const _JoinEnactusSheet(),
    );
  }

  void _showGuideDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _BeginnerGuideDialog());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.sizeOf(context).width >= 600 ? 20 : 16,
            20,
            28,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width >= 600 ? 620 : 500,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showMobileBrand) ...[
                  const _MobileBrandHeader(),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).width >= 600 ? 18 : 14,
                  ),
                ],
                AppDataCard(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 420 ? 16 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bienvenue sur EnactSpace',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Connecte-toi avec ton email ou ton nom d’utilisateur.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant',
                          hintText: 'Email ou nom d’utilisateur',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        onSubmitted: (_) => loading ? null : onLogin(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: onTogglePassword,
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
                      ),
                      SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () => _showForgotPasswordDialog(context),
                          child: Text('Mot de passe oublié ?'),
                        ),
                      ),
                      SizedBox(height: 14),
                      if (error != null) ...[
                        _ErrorBanner(message: error!),
                        SizedBox(height: 14),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.enactusYellow,
                          foregroundColor: AppTheme.softBlack,
                        ),
                        onPressed: loading ? null : onLogin,
                        icon: loading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.login_rounded),
                        label: Text('Se connecter'),
                      ),
                      if (biometricAvailable) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('biometric_unlock'),
                          onPressed: loading ? null : onBiometric,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Déverrouiller avec la biométrie'),
                        ),
                      ],
                      SizedBox(height: 12),
                      const _LoginSectionLabel('Autres accès'),
                      SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () => _showJoinRequestSheet(context),
                        icon: Icon(Icons.person_add_alt_1_rounded),
                        label: Text('Créer un compte'),
                      ),
                      SizedBox(height: 10),
                      const Divider(height: 1),
                      SizedBox(height: 8),
                      const _LoginSectionLabel('Premiers pas et aide'),
                      SizedBox(height: 8),
                      _LoginSupportActions(
                        onGuide: () => _showGuideDialog(context),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      const _LoginSectionLabel('Rejoindre Enactus ESP'),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go('/recruitment/apply'),
                            icon: const Icon(Icons.how_to_reg_rounded),
                            label: const Text('Postuler'),
                          ),
                          TextButton.icon(
                            onPressed: () => context.go('/application-tracking'),
                            icon: const Icon(Icons.route_rounded),
                            label: const Text('Suivre ma candidature'),
                          ),
                        ],
                      ),
                    ],
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
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LoginSupportActions extends StatelessWidget {
  final VoidCallback onGuide;

  const _LoginSupportActions({
    required this.onGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/activate'),
          icon: const Icon(Icons.key_outlined),
          label: const Text('Première connexion'),
        ),
        TextButton.icon(
          onPressed: () => context.push('/help-guide'),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Guide et FAQ'),
        ),

        TextButton.icon(
          onPressed: onGuide,
          icon: Icon(Icons.explore_rounded),
          label: Text('Guide débutant'),
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
      title: const _PublicDialogTitle('Mot de passe oublié'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Un code OTP sera envoyé à ton email avant de définir le nouveau mot de passe.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
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
                SizedBox(height: 14),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Code OTP',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      tooltip: _obscurePassword
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14),
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
                SizedBox(height: 14),
                _ErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Fermer'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : (_codeSent ? _confirmReset : _sendCode),
          icon: _loading
              ? SizedBox(
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
  const _JoinEnactusSheet();

  @override
  State<_JoinEnactusSheet> createState() => _JoinEnactusSheetState();
}

class _JoinEnactusSheetState extends State<_JoinEnactusSheet> {
  final AuthService _authService = AuthService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _levelController = TextEditingController();
  final _promotionController = TextEditingController();
  final _joinYearController = TextEditingController();

  bool _isAlumni = false;
  String? _gender;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _levelController.dispose();
    _promotionController.dispose();
    _joinYearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final requiredFields = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _departmentController.text.trim(),
      _levelController.text.trim(),
      _gender ?? '',
    ];
    if (requiredFields.any((value) => value.isEmpty)) {
      setState(
        () => _error =
            'Prénom, nom, nom d’utilisateur, genre, email, téléphone, département et niveau sont obligatoires.',
      );
      return;
    }
    if (_isAlumni &&
        [
          _departmentController.text.trim(),
          _promotionController.text.trim(),
          _joinYearController.text.trim(),
        ].any((value) => value.isEmpty)) {
      setState(
        () => _error =
            'Pour un Alumni, département, année d’entrée et année d’arrivée dans Enactus ESP sont obligatoires.',
      );
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(
        () => _error = 'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    final joinYear = _joinYearController.text.trim().isEmpty
        ? null
        : int.tryParse(_joinYearController.text.trim());
    if (_joinYearController.text.trim().isNotEmpty && joinYear == null) {
      setState(
        () => _error = 'L’année d’entrée dans Enactus doit être valide.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.submitJoinRequest(
        profileType: _isAlumni ? 'alumni' : 'enacteur',
        gender: _gender!,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        enactusJoinYear: _isAlumni ? joinYear : null,
        department: _departmentController.text.trim(),
        level: _levelController.text.trim(),
        promotion: _isAlumni ? _promotionController.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compte créé. Vous pourrez vous connecter après validation.',
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
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Rejoindre Enactus ESP',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Le compte reste en attente jusqu’à validation par les responsables autorisés.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 18),
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      value: _isAlumni,
                      onChanged: _loading
                          ? null
                          : (value) => setState(() => _isAlumni = value),
                      title: Text(
                        'Je suis Alumni',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Active cette option si ton parcours Enactus ESP est déjà terminé.',
                      ),
                    ),
                    SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Genre *',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'homme', child: Text('Homme')),
                        DropdownMenuItem(value: 'femme', child: Text('Femme')),
                        DropdownMenuItem(
                          value: 'non_precise',
                          child: Text('Préfère ne pas préciser'),
                        ),
                      ],
                      validator: (value) =>
                          value == null ? 'Champ obligatoire' : null,
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _gender = value);
                              }
                            },
                    ),
                    SizedBox(height: 12),
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
                              controller: _usernameController,
                              label: 'Nom d’utilisateur *',
                              icon: Icons.alternate_email_rounded,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _emailController,
                              label: 'Email *',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              width: fieldWidth,
                            ),
                            _JoinField(
                              controller: _phoneController,
                              label: 'Téléphone *',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              width: fieldWidth,
                            ),
                            _JoinChoiceField(
                              controller: _departmentController,
                              label: 'Département ESP *',
                              icon: Icons.account_balance_outlined,
                              width: fieldWidth,
                              options: espAcademicDepartments,
                            ),
                            _JoinChoiceField(
                              controller: _levelController,
                              label: 'Niveau d’études *',
                              icon: Icons.school_outlined,
                              width: fieldWidth,
                              options: espAcademicLevels,
                            ),
                            if (_isAlumni) ...[
                              _JoinField(
                                controller: _promotionController,
                                label: 'Promotion (année d’entrée à l’ESP) *',
                                icon: Icons.groups_3_outlined,
                                keyboardType: TextInputType.number,
                                width: fieldWidth,
                              ),
                              _JoinField(
                                controller: _joinYearController,
                                label: 'Année d’arrivée dans Enactus ESP *',
                                icon: Icons.calendar_month_outlined,
                                keyboardType: TextInputType.number,
                                width: fieldWidth,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          tooltip: _obscurePassword
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    if (_error != null) ...[
                      SizedBox(height: 14),
                      _ErrorBanner(message: _error!),
                    ],
                    SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text('Annuler'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.send_rounded),
                            label: Text('Envoyer'),
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

class _JoinChoiceField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final double width;
  final List<String> options;

  const _JoinChoiceField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.width,
    required this.options,
  });

  @override
  State<_JoinChoiceField> createState() => _JoinChoiceFieldState();
}

class _JoinChoiceFieldState extends State<_JoinChoiceField> {
  @override
  Widget build(BuildContext context) {
    final current = widget.controller.text.trim();
    return SizedBox(
      width: widget.width,
      child: DropdownButtonFormField<String>(
        initialValue: widget.options.contains(current) ? current : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
        ),
        items: [
          for (final option in widget.options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) => setState(() {
          widget.controller.text = value ?? '';
        }),
      ),
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
      title: const _PublicDialogTitle('Guide débutant'),
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
                    style: TextStyle(fontWeight: FontWeight.w800),
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
          icon: Icon(Icons.check_rounded),
          label: Text('Compris'),
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

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) => const _PublicInlineHeader();
}

class _PublicInlineHeader extends StatelessWidget {
  const _PublicInlineHeader();

  @override
  Widget build(BuildContext context) {
    final scaledBodySize = MediaQuery.textScalerOf(context).scale(16);
    final showLabel = scaledBodySize < 24;
    return Row(
      children: [
        Image.asset(
          BrandAssets.logoFull,
          width: 112,
          height: 46,
          fit: BoxFit.contain,
        ),
        if (showLabel) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'EnactSpace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ],
    );
  }
}

class _PublicDialogTitle extends StatelessWidget {
  final String title;
  const _PublicDialogTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;
  final bool onDark;

  const _BrandMark({required this.size, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Image.asset(
          onDark ? BrandAssets.logoMonoWhite : BrandAssets.logoFull,
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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}
