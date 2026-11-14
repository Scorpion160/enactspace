import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/first_access_service.dart';

class ActivationScreen extends StatefulWidget {
  final FirstAccessService? service;

  const ActivationScreen({super.key, this.service});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  late final FirstAccessService service;
  final form = GlobalKey<FormState>();

  final identifier = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();

  final codeFocus = FocusNode();
  final passwordFocus = FocusNode();
  final confirmationFocus = FocusNode();

  bool requested = false;
  bool busy = false;
  bool obscurePassword = true;
  bool obscureConfirmation = true;

  String? message;
  String? error;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? FirstAccessService();
  }

  @override
  void dispose() {
    for (final controller in [identifier, code, password, confirmation]) {
      controller.dispose();
    }
    for (final focus in [codeFocus, passwordFocus, confirmationFocus]) {
      focus.dispose();
    }
    super.dispose();
  }

  void toggleVisibility({required bool isConfirmation}) {
    final controller = isConfirmation ? confirmation : password;
    final focus = isConfirmation ? confirmationFocus : passwordFocus;
    final selection = controller.selection;

    setState(() {
      if (isConfirmation) {
        obscureConfirmation = !obscureConfirmation;
      } else {
        obscurePassword = !obscurePassword;
      }
    });

    focus.requestFocus();
    if (selection.isValid) {
      controller.selection = selection;
    }
  }

  Future<void> submit() async {
    if (busy || !(form.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });

    try {
      if (!requested) {
        final text = await service.requestActivation(identifier.text);
        if (!mounted) {
          return;
        }

        setState(() {
          requested = true;
          message = text;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            codeFocus.requestFocus();
          }
        });
      } else {
        await service.activate(identifier.text, code.text, password.text);
        await service.logout();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Votre accès est prêt. Connectez-vous avec votre nouveau mot de passe.',
            ),
          ),
        );
        context.go('/login');
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget passwordField({required bool isConfirmation}) {
    final controller = isConfirmation ? confirmation : password;
    final focus = isConfirmation ? confirmationFocus : passwordFocus;
    final hidden = isConfirmation ? obscureConfirmation : obscurePassword;

    return TextFormField(
      key: ValueKey(
        isConfirmation ? 'activation-confirmation' : 'activation-password',
      ),
      controller: controller,
      focusNode: focus,
      readOnly: busy,
      obscureText: hidden,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: isConfirmation
          ? TextInputAction.done
          : TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: true,
      autofillHints: const [AutofillHints.newPassword],
      onFieldSubmitted: (_) {
        if (isConfirmation) {
          submit();
        } else {
          confirmationFocus.requestFocus();
        }
      },
      decoration: InputDecoration(
        labelText: isConfirmation
            ? 'Confirmer le mot de passe'
            : 'Votre mot de passe',
        helperText: isConfirmation
            ? null
            : 'Utilisez une phrase personnelle facile à retenir, '
                  'd’au moins 8 caractères.',
        helperMaxLines: 3,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          tooltip: hidden
              ? 'Afficher le mot de passe'
              : 'Masquer le mot de passe',
          onPressed: busy
              ? null
              : () => toggleVisibility(isConfirmation: isConfirmation),
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) {
        final text = value ?? '';

        if (isConfirmation) {
          return text != password.text
              ? 'Les mots de passe sont différents.'
              : null;
        }
        if (text.trim().isEmpty || text.length < 8) {
          return 'Choisissez au moins 8 caractères.';
        }
        if (utf8.encode(text).length > 72) {
          return 'Cette phrase est trop longue (72 octets maximum).';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: const Text('Première connexion'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.key_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Votre place vous attend',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Votre profil existe déjà ? Activez votre accès avec '
                      'votre email ou votre nom d’utilisateur, puis choisissez '
                      'votre propre mot de passe.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: identifier,
                      enabled: !busy && !requested,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Email ou nom d’utilisateur',
                      ),
                      onFieldSubmitted: (_) => submit(),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Renseignez votre identifiant.'
                          : null,
                    ),
                    if (requested) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: code,
                        focusNode: codeFocus,
                        readOnly: busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'Code reçu par email',
                        ),
                        onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                        validator: (value) =>
                            RegExp(r'^\d{8}$').hasMatch((value ?? '').trim())
                            ? null
                            : 'Saisissez les 8 chiffres du code.',
                      ),
                      const SizedBox(height: 12),
                      passwordField(isConfirmation: false),
                      const SizedBox(height: 16),
                      passwordField(isConfirmation: true),
                    ],
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(message!, style: const TextStyle(height: 1.5)),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy
                            ? 'Veuillez patienter…'
                            : requested
                            ? 'Créer mon mot de passe'
                            : 'Recevoir mon code',
                      ),
                    ),
                    if (requested)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  requested = false;
                                  message = null;
                                  error = null;
                                  code.clear();
                                });
                              },
                        child: const Text(
                          'Changer d’identifiant ou demander un nouveau code',
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'Votre adresse email manque ou a changé ? Contactez '
                      'la SG pour vérifier votre identité et préparer votre '
                      'accès. Ne créez pas un deuxième compte.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
