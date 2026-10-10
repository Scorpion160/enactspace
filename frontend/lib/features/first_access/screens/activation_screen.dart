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
  bool requested = false, busy = false, obscure = true;
  String? message, error;
  @override
  void initState() {
    super.initState();
    service = widget.service ?? FirstAccessService();
  }

  @override
  void dispose() {
    for (final c in [identifier, code, password, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!requested) {
        final text = await service.requestActivation(identifier.text);
        if (mounted) {
          setState(() {
            requested = true;
            message = text;
          });
        }
      } else {
        await service.activate(identifier.text, code.text, password.text);
        await service.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Votre accès est prêt. Connectez-vous avec votre nouveau mot de passe.',
              ),
            ),
          );
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => context.go('/login')),
      title: const Text('Première connexion'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                  'Votre profil existe déjà ? Activez votre accès avec votre email ou votre nom d’utilisateur, puis choisissez votre propre mot de passe.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: identifier,
                  enabled: !busy && !requested,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email ou nom d’utilisateur',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Renseignez votre identifiant.'
                      : null,
                ),
                if (requested) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Code reçu par email',
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{8}$').hasMatch((v ?? '').trim())
                        ? null
                        : 'Saisissez les 8 chiffres du code.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Votre mot de passe',
                      helperText:
                          '15 caractères au moins : une phrase facile à retenir.',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        tooltip: obscure
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty || (v ?? '').length < 15
                        ? 'Choisissez au moins 15 caractères.'
                        : utf8.encode(v!).length > 72
                        ? 'Cette phrase est trop longue (72 octets maximum).'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                    ),
                    validator: (v) => v != password.text
                        ? 'Les mots de passe sont différents.'
                        : null,
                  ),
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
                        : () => setState(() {
                            requested = false;
                            message = null;
                            error = null;
                            code.clear();
                          }),
                    child: const Text(
                      'Changer d’identifiant ou demander un nouveau code',
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Votre adresse email manque ou a changé ? Contactez la SG pour vérifier votre identité et préparer votre accès. Ne créez pas un deuxième compte.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
