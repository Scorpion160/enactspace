import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/first_access_service.dart';

class FirstAccessManagementScreen extends StatefulWidget {
  final FirstAccessService? service;
  const FirstAccessManagementScreen({super.key, this.service});
  @override
  State<FirstAccessManagementScreen> createState() =>
      _FirstAccessManagementScreenState();
}

class _FirstAccessManagementScreenState
    extends State<FirstAccessManagementScreen> {
  late final service = widget.service ?? FirstAccessService();
  List<Map<String, dynamic>> members = [];
  bool loading = true;
  String search = '', filter = 'all';
  String? error, busy;
  static const labels = {
    'all': 'Tous les membres',
    'contact_missing': 'Contact à compléter',
    'ready': 'Accès à activer',
    'profile_pending': 'Profil à compléter',
    'completed': 'Accueil terminé',
    'not_ready': 'Compte non disponible',
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await service.inventory();
      if (mounted) {
        setState(() {
          members = data;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Impossible de charger les premières connexions. Vérifiez votre accès et réessayez.';
        });
      }
    }
  }

  Future<void> contact(
    Map<String, dynamic> row, {
    bool recovery = false,
  }) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) =>
          _ContactPreparationDialog(row: row, recovery: recovery),
    );
    if (result == null || !mounted) return;
    await action(row, () async {
      if (recovery) {
        return service.recoverContact(
          row['id'].toString(),
          result['email']!,
          result['phone']!,
          result['note']!,
          row['email'].toString(),
        );
      }
      await service.contact(
        row['id'].toString(),
        result['email']!,
        result['phone']!,
      );
      return 'Contact enregistré.';
    });
  }

  Future<void> invite(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inviter ce membre'),
        content: Text(
          'Un code personnel sera préparé pour ${row['display_name']} à l’adresse ${row['email']}. Le membre choisira lui-même son mot de passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Préparer l’invitation'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await action(row, () => service.invite(row['id'].toString()));
    }
  }

  Future<void> action(
    Map<String, dynamic> row,
    Future<String> Function() perform,
  ) async {
    setState(() => busy = row['id'].toString());
    try {
      final message = await perform();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = members
        .where(
          (row) =>
              (filter == 'all' || row['state'] == filter) &&
              '${row['display_name']} ${row['email']} ${row['username']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/members')),
        title: const Text('Premières connexions'),
        actions: [
          IconButton(
            onPressed: busy == null ? load : null,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Préparez les accès un membre à la fois. Les comptes déjà utilisés conservent leur mot de passe. Un contact manquant doit être confirmé avant l’invitation.',
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rechercher un membre',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => search = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: filter,
                isExpanded: true,
                items: labels.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => filter = value ?? 'all'),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (error != null) ...[
                Text(error!),
                FilledButton(onPressed: load, child: const Text('Réessayer')),
              ] else if (visible.isEmpty)
                const Text('Aucun membre dans cette sélection.')
              else
                for (final row in visible)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['display_name'].toString(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(labels[row['state']] ?? 'Compte à vérifier'),
                          Text(
                            row['state'] == 'contact_missing'
                                ? 'Adresse à compléter'
                                : row['email'].toString(),
                          ),
                          Text('Identifiant : ${row['username']}'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    busy == null &&
                                        row['can_prepare_contact'] == true
                                    ? () => contact(row)
                                    : null,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Vérifier le contact'),
                              ),
                              if (row['can_prepare_recovery'] == true)
                                OutlinedButton.icon(
                                  onPressed: busy == null
                                      ? () => contact(row, recovery: true)
                                      : null,
                                  icon: const Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                  label: const Text('Récupérer l’accès'),
                                ),
                              FilledButton.icon(
                                onPressed:
                                    busy == null && row['can_invite'] == true
                                    ? () => invite(row)
                                    : null,
                                icon: const Icon(Icons.mail_outline),
                                label: Text(
                                  busy == row['id']
                                      ? 'Préparation…'
                                      : 'Inviter',
                                ),
                              ),
                            ],
                          ),
                        ],
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

class _ContactPreparationDialog extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool recovery;
  const _ContactPreparationDialog({required this.row, required this.recovery});
  @override
  State<_ContactPreparationDialog> createState() =>
      _ContactPreparationDialogState();
}

class _ContactPreparationDialogState extends State<_ContactPreparationDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController email;
  late final TextEditingController phone;
  final note = TextEditingController();
  bool verified = false;
  @override
  void initState() {
    super.initState();
    email = TextEditingController(
      text: widget.row['state'] == 'contact_missing'
          ? ''
          : widget.row['email']?.toString(),
    );
    phone = TextEditingController(text: widget.row['phone']?.toString());
  }

  @override
  void dispose() {
    email.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.recovery ? 'Récupérer un accès' : 'Préparer le contact'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.row['display_name'].toString()),
              const SizedBox(height: 12),
              const Text(
                'Vérifiez l’identité du membre et confirmez avec lui son adresse personnelle avant de l’enregistrer.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Adresse email'),
                validator: (value) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Renseignez une adresse email valide.',
              ),
              if (widget.recovery) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: note,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Vérification de l’identité',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 20
                      ? 'Décrivez la vérification réalisée.'
                      : null,
                ),
                CheckboxListTile(
                  value: verified,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) =>
                      setState(() => verified = value ?? false),
                  title: const Text(
                    'J’ai vérifié l’identité du membre. Je confirme la fermeture de ses anciennes sessions.',
                  ),
                ),
              ],
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (facultatif)',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: widget.recovery && !verified
            ? null
            : () {
                if (form.currentState!.validate() &&
                    (!widget.recovery || verified)) {
                  Navigator.pop(context, {
                    'email': email.text,
                    'phone': phone.text,
                    'note': note.text,
                  });
                }
              },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}
