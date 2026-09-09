import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/appearance_controller.dart';
import '../../../core/push/push_lifecycle_controller.dart';
import '../../../core/push/push_platform.dart';
import '../controllers/settings_controller.dart';
import '../models/settings_models.dart';
import '../services/settings_gateway.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsController? controller;
  final AuthService? authService;

  const SettingsScreen({super.key, this.controller, this.authService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;
  late final AuthService _authService;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        SettingsController(
          gateway: ApiSettingsGateway(),
          appearance: AppearanceController.instance,
        );
    _authService = widget.authService ?? AuthService();
    _controller.addListener(_refresh);
    if (_controller.preferences == null) _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _exportData() async {
    try {
      final export = await _controller.exportData();
      if (!mounted) return;
      final copy = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Copie de vos données prête'),
          content: Text(
            'Une copie de vos données EnactSpace a été générée${_generatedSuffix(export)}. '
            'Elle peut contenir des informations sensibles. Ne la copiez que sur un appareil de confiance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Fermer'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copier le contenu'),
            ),
          ],
        ),
      );
      if (copy != true) return;
      await Clipboard.setData(
        ClipboardData(
          text: const JsonEncoder.withIndent('  ').convert(export.payload),
        ),
      );
      if (mounted) _message('La copie a été placée dans le presse-papiers.');
    } catch (_) {
      if (mounted) _message('Impossible de générer la copie de vos données.');
    }
  }

  String _generatedSuffix(AccountDataExport export) {
    final generated = DateTime.tryParse(export.generatedAt ?? '');
    if (generated == null) return '';
    return ' le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(generated.toLocal())}';
  }

  Future<void> _requestDeletion() async {
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander la suppression du compte ?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action envoie une demande à Enactus ESP. Votre compte ne sera pas supprimé immédiatement.',
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => reason = value,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Raison (facultatif)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await _controller.requestDeletion(reason);
    if (mounted && success) _message('Votre demande a bien été envoyée.');
  }

  Future<void> _cancelDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text(
          'La demande de suppression en attente sera annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder la demande'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await _controller.cancelDeletion();
    if (mounted && success) _message('La demande a été annulée.');
  }

  Future<void> _logout({required bool all}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          all ? 'Déconnecter tous mes appareils ?' : 'Se déconnecter ?',
        ),
        content: Text(
          all
              ? 'Vous devrez vous reconnecter sur chaque appareil.'
              : 'Vous serez déconnecté de cet appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await runLogoutWithPushCleanup(
        cleanup: () =>
            PushLifecycleController.instance.cleanupForLogout(allDevices: all),
        logout: all ? _authService.logoutAll : _authService.logout,
      );
    } catch (_) {
      // Existing AuthService guarantees local logout completion.
    }
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _controller.preferences;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          key: const Key('settings-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Réglages',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personnalisez EnactSpace et gérez votre compte.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (_controller.error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _controller.error!),
                    ],
                    if (_controller.loading && preferences == null) ...[
                      const SizedBox(height: 32),
                      const Center(child: CircularProgressIndicator()),
                    ] else ...[
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Apparence',
                        icon: Icons.palette_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thème'),
                            const SizedBox(height: 10),
                            SegmentedButton<AppAppearance>(
                              segments: const [
                                ButtonSegment(
                                  value: AppAppearance.system,
                                  icon: Icon(Icons.brightness_auto_rounded),
                                  label: Text('Système'),
                                ),
                                ButtonSegment(
                                  value: AppAppearance.light,
                                  icon: Icon(Icons.light_mode_rounded),
                                  label: Text('Clair'),
                                ),
                                ButtonSegment(
                                  value: AppAppearance.dark,
                                  icon: Icon(Icons.dark_mode_rounded),
                                  label: Text('Sombre'),
                                ),
                              ],
                              selected: {_controller.appearance.appearance},
                              onSelectionChanged: _controller.saving
                                  ? null
                                  : (values) =>
                                        _controller.setTheme(values.first),
                            ),
                            const Divider(height: 32),
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.language_rounded),
                              title: Text('Langue'),
                              subtitle: Text('Français'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Notifications',
                        icon: Icons.notifications_outlined,
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Dans l’application'),
                              subtitle: const Text(
                                'Afficher les nouvelles alertes EnactSpace.',
                              ),
                              value: preferences?.inAppNotifications ?? true,
                              onChanged: _controller.saving
                                  ? null
                                  : _controller.setInAppNotifications,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Par e-mail'),
                              subtitle: const Text(
                                'Recevoir les informations importantes par e-mail.',
                              ),
                              value: preferences?.emailNotifications ?? true,
                              onChanged: _controller.saving
                                  ? null
                                  : _controller.setEmailNotifications,
                            ),
                            if (_controller.push.platform.supported &&
                                !_controller.push.available)
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Notifications push'),
                                subtitle: Text(
                                  'Indisponibles sur cette version.',
                                ),
                              ),
                            if (_controller.push.available)
                              SwitchListTile(
                                key: const Key('push-notifications-toggle'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Notifications push'),
                                subtitle: Text(
                                  (preferences?.pushNotifications ?? false)
                                      ? 'Activées pour votre compte.'
                                      : 'Désactivées pour votre compte.',
                                ),
                                value: preferences?.pushNotifications ?? false,
                                onChanged: _controller.saving
                                    ? null
                                    : (value) async {
                                        final success = await _controller
                                            .setPushNotifications(value);
                                        if (mounted &&
                                            !success &&
                                            _controller.error != null) {
                                          _message(_controller.error!);
                                        }
                                      },
                              ),
                            if (_controller.push.available &&
                                (preferences?.pushNotifications ?? false))
                              ListTile(
                                key: const Key('push-current-device-state'),
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Cet appareil'),
                                subtitle: Text(
                                  _controller.push.authorization ==
                                          PushAuthorization.notDetermined
                                      ? 'Cet appareil n’est pas encore autorisé.'
                                      : _controller.push.authorization ==
                                            PushAuthorization.denied
                                      ? 'Bloquées dans les réglages de l’appareil.'
                                      : _controller.push.deviceSynchronized
                                      ? 'Autorisées et synchronisées sur cet appareil.'
                                      : 'Autorisation accordée, synchronisation en attente.',
                                ),
                                trailing:
                                    _controller.push.authorization ==
                                        PushAuthorization.notDetermined
                                    ? FilledButton(
                                        key: const Key('authorize-push-device'),
                                        onPressed: _controller.saving
                                            ? null
                                            : () async {
                                                final success =
                                                    await _controller
                                                        .setPushNotifications(
                                                          true,
                                                        );
                                                if (mounted &&
                                                    !success &&
                                                    _controller.error != null) {
                                                  _message(_controller.error!);
                                                }
                                              },
                                        child: const Text(
                                          'Autoriser sur cet appareil',
                                        ),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Compte et confidentialité',
                        icon: Icons.manage_accounts_outlined,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.download_rounded),
                              title: const Text('Exporter mes données'),
                              subtitle: const Text(
                                'Générer une copie à consulter ou copier.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _exportData,
                            ),
                            if (_controller.deletionRequest
                                case final request?) ...[
                              _DeletionStatusTile(
                                request: request,
                                onCancel: request.canCancel
                                    ? _cancelDeletion
                                    : null,
                              ),
                              if (request.canRequestAgain)
                                _DeletionRequestTile(
                                  title: 'Envoyer une nouvelle demande',
                                  onTap: _requestDeletion,
                                ),
                            ] else
                              _DeletionRequestTile(
                                title: 'Demander la suppression de mon compte',
                                onTap: _requestDeletion,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Sécurité',
                        icon: Icons.security_rounded,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.logout_rounded),
                              title: const Text('Déconnecter cet appareil'),
                              onTap: () => _logout(all: false),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.phonelink_erase_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              title: const Text(
                                'Déconnecter tous mes appareils',
                              ),
                              onTap: () => _logout(all: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Aide et informations',
                        icon: Icons.help_outline_rounded,
                        child: Column(
                          children: [
                            _LinkTile(label: 'Centre d’aide', path: '/help'),
                            _LinkTile(
                              label: 'Politique de confidentialité',
                              path: '/legal/privacy',
                            ),
                            _LinkTile(
                              label: 'Conditions d’utilisation',
                              path: '/legal/terms',
                            ),
                            _LinkTile(label: 'À propos', path: '/about'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _LinkTile extends StatelessWidget {
  final String label;
  final String path;

  const _LinkTile({required this.label, required this.path});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(path),
  );
}

class _DeletionStatusTile extends StatelessWidget {
  final AccountDeletionRequest request;
  final VoidCallback? onCancel;

  const _DeletionStatusTile({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.pending_actions_rounded),
    title: const Text('Demande de suppression'),
    subtitle: Text('État : ${request.statusLabel}'),
    trailing: onCancel == null
        ? null
        : TextButton(onPressed: onCancel, child: const Text('Annuler')),
  );
}

class _DeletionRequestTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _DeletionRequestTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      Icons.person_remove_outlined,
      color: Theme.of(context).colorScheme.error,
    ),
    title: Text(title),
    subtitle: const Text('Envoyer une demande, sans suppression immédiate.'),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
