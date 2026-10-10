import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/ui/app_back_button.dart';
import '../services/team_years_gateway.dart';

class TeamYearsScreen extends StatefulWidget {
  final TeamYearsGateway? gateway;
  const TeamYearsScreen({super.key, this.gateway});
  @override
  State<TeamYearsScreen> createState() => _TeamYearsScreenState();
}

class _TeamYearsScreenState extends State<TeamYearsScreen> {
  late final TeamYearsGateway gateway;
  List<Map<String, dynamic>> years = [];
  bool loading = true, managing = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? ApiTeamYearsGateway();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final allowed = await gateway.canManage();
      final rows = await gateway.loadYears();
      if (mounted) {
        setState(() {
          managing = allowed;
          years = rows;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Impossible de charger les années. Réessayez dans un instant.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> openYear(Map<String, dynamic> year) async {
    final current = years.where((row) => row['is_current'] == true).firstOrNull;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ouvrir ${year['name']} ?'),
        content: const Text(
          'L’année précédente rejoindra l’historique. Les tâches ouvertes, les équipes et les projets restent accessibles. Chaque membre confirmera son cursus pour la nouvelle année ; aucun passage Alumni n’est automatique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ouvrir l’année'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await gateway.activateYear(
        year['id'].toString(),
        current?['id']?.toString(),
      );
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'L’ouverture n’a pas abouti. Actualisez les années et vérifiez leurs dates avant de réessayer.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> create() async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewYearDialog(),
    );
    if (values == null || !mounted) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await gateway.createYear(values);
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'L’année n’a pas pu être créée. Vérifiez son nom et ses dates, puis réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(fallbackPath: '/settings'),
      title: const Text('Années de l’équipe'),
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Un nouveau chapitre, un historique conservé',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'L’année courante donne un repère aux activités et aux confirmations académiques. Les travaux des années précédentes restent consultables et les tâches ouvertes gardent leur suivi.',
                  ),
                  const SizedBox(height: 16),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: saving ? null : load,
                      child: const Text('Réessayer'),
                    ),
                  ],
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (managing)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          key: const Key('create-team-year'),
                          onPressed: saving ? null : create,
                          icon: const Icon(Icons.add),
                          label: const Text('Préparer une année'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (years.isEmpty)
                      const Text('Aucune année n’est encore configurée.'),
                    for (final year in years)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                year['name']?.toString() ?? 'Année',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                year['is_current'] == true
                                    ? 'Année courante'
                                    : year['archived'] == true
                                    ? 'Historique'
                                    : 'En préparation',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_date(year['start_date'])} → ${_date(year['end_date'])}',
                              ),
                              if (managing &&
                                  year['is_current'] != true &&
                                  year['archived'] != true) ...[
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: saving
                                      ? null
                                      : () => openYear(year),
                                  child: const Text('Ouvrir cette année'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/settings/academic'),
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Mon profil académique'),
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

String _date(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? 'Fin non définie'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _NewYearDialog extends StatefulWidget {
  const _NewYearDialog();
  @override
  State<_NewYearDialog> createState() => _NewYearDialogState();
}

class _NewYearDialogState extends State<_NewYearDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  DateTime? start, end;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> pick(bool first) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: (first ? start : end) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() {
        if (first) {
          start = date;
        } else {
          end = date;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Préparer une année'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Créez d’abord l’année, puis ouvrez-la lorsque l’équipe est prête.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’année',
                  hintText: 'Année 2026-2027',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Indiquez le nom de l’année.',
              ),
              FormField<DateTime>(
                validator: (_) =>
                    start == null ? 'Choisissez une date de début.' : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => pick(true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        start == null
                            ? 'Date de début'
                            : 'Début : ${_date(start.toString())}',
                      ),
                    ),
                    if (field.errorText != null)
                      Text(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              FormField<DateTime>(
                validator: (_) =>
                    end != null && start != null && !end!.isAfter(start!)
                    ? 'La fin doit suivre le début.'
                    : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => pick(false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        end == null
                            ? 'Date de fin (facultatif)'
                            : 'Fin : ${_date(end.toString())}',
                      ),
                    ),
                    if (field.errorText != null)
                      Text(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
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
        onPressed: () {
          if (!form.currentState!.validate()) {
            return;
          }
          Navigator.pop(context, <String, dynamic>{
            'name': name.text.trim(),
            'start_date': start!.toIso8601String().split('T').first,
            'end_date': end?.toIso8601String().split('T').first,
            'is_current': false,
          });
        },
        child: const Text('Créer l’année'),
      ),
    ],
  );
}
