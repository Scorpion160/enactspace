import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/first_access_service.dart';

/// Server-backed prerequisite before legal consent and the private app shell.
class FirstAccessGate extends StatefulWidget {
  final Widget child;
  final FirstAccessService? service;
  const FirstAccessGate({super.key, required this.child, this.service});
  @override
  State<FirstAccessGate> createState() => _FirstAccessGateState();
}

class _FirstAccessGateState extends State<FirstAccessGate> {
  late final FirstAccessService service =
      widget.service ?? FirstAccessService();
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  Map<String, dynamic> data = {}, departments = {};
  String? department, cursus, level, gender, error;
  bool loading = true,
      saving = false,
      allowed = false,
      welcome = true,
      tour = false;
  bool get alumni => data['profile_type'] == 'alumni';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!await service.needsOnboarding()) {
        if (mounted) {
          setState(() {
            allowed = true;
            loading = false;
          });
        }
        return;
      }
      final status = await service.status();
      final catalog = await service.catalog();
      if (!mounted) return;
      for (final key in [
        'first_name',
        'last_name',
        'phone',
        'enactus_join_year',
        'graduation_year',
        'specialty',
        'promotion',
        'bio',
      ]) {
        fields.putIfAbsent(key, () => TextEditingController()).text =
            status[key]?.toString() ?? '';
      }
      final choices = Map<String, dynamic>.from(catalog['departments'] as Map);
      setState(() {
        data = status;
        departments = choices;
        gender = ['homme', 'femme'].contains(status['gender'])
            ? status['gender'] as String
            : null;
        department = choices.containsKey(status['department'])
            ? status['department'] as String
            : null;
        cursus = courses.contains(status['cursus'])
            ? status['cursus'] as String
            : null;
        level = levels.contains(status['study_level'])
            ? status['study_level'] as String
            : null;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Impossible de préparer votre accueil. Vérifiez votre connexion et réessayez.';
        });
      }
    }
  }

  List<String> get courses => department == null
      ? []
      : (departments[department] as Map).keys.cast<String>().toList();
  List<String> get levels => department == null || cursus == null
      ? []
      : List<String>.from((departments[department] as Map)[cursus] as List);
  Future<void> complete() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await service.complete({
        for (final entry in fields.entries)
          entry.key:
              ['enactus_join_year', 'graduation_year'].contains(entry.key)
              ? int.tryParse(entry.value.text.trim())
              : entry.value.text.trim(),
        'academic_year_id': data['academic_year_id'],
        'gender': gender,
        'department': department,
        'cursus': cursus,
        'study_level': level,
      });
      if (mounted) {
        setState(() {
          tour = true;
          saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Widget field(
    String key,
    String label, {
    bool required = true,
    int max = 100,
    bool year = false,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(key),
        controller: fields[key],
        enabled: !saving,
        keyboardType: year
            ? TextInputType.number
            : key == 'phone'
            ? TextInputType.phone
            : TextInputType.text,
        maxLength: max,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Ce champ est nécessaire.';
          if (year && text.isNotEmpty) {
            final number = int.tryParse(text);
            if (number == null ||
                number < 1900 ||
                number > DateTime.now().year) {
              return 'Renseignez une année valide.';
            }
          }
          if (key == 'phone' &&
              !RegExp(r'^\+?[0-9 ()-]{6,30}$').hasMatch(text)) {
            return 'Renseignez un numéro de téléphone valide.';
          }
          if (key == 'phone' && RegExp(r'[0-9]').allMatches(text).length < 6) {
            return 'Renseignez un numéro de téléphone valide.';
          }
          return null;
        },
      ),
    );
  }

  Widget choice(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged:
            saving ||
                (data['academic_year_confirmed'] == true &&
                    {
                      'Département ESP',
                      'Cursus',
                      'Niveau actuel',
                    }.contains(label))
            ? null
            : changed,
        validator: (value) => value == null ? 'Choisissez une option.' : null,
      ),
    );
  }

  Future<void> logout() async {
    await service.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (allowed) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Bienvenue dans EnactSpace'),
          actions: [
            IconButton(
              tooltip: 'Besoin d’aide ?',
              onPressed: saving ? null : () => context.push('/welcome-help'),
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              tooltip: 'Se déconnecter',
              onPressed: saving ? null : logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (error != null) ...[
                        Text(
                          error!,
                          style: TextStyle(color: scheme.error, height: 1.5),
                        ),
                        if (fields.isEmpty)
                          FilledButton(
                            onPressed: load,
                            child: const Text('Réessayer'),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (fields.isNotEmpty && welcome && !tour) ...[
                        if (data['contact_ready'] == false)
                          const Text(
                            'Votre adresse email doit être confirmée avec la SG avant de poursuivre. Si le compte a déjà été utilisé, un administrateur préparera sa récupération après vérification de votre identité.',
                            style: TextStyle(height: 1.5),
                          ),
                        Icon(
                          Icons.waving_hand_outlined,
                          size: 64,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Votre équipe, vos projets, votre espace.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          alumni
                              ? 'Votre expérience compte toujours. Retrouvez la vie de Enactus ESP, partagez vos conseils et accompagnez les nouvelles générations.'
                              : 'Enactus ESP réunit des étudiants qui passent à l’action pour améliorer les conditions de vie grâce à l’entrepreneuriat social. Ici, vous pourrez apprendre, contribuer et suivre les projets de votre équipe.',
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Vérifiez d’abord vos informations. Votre profil vous suivra sur le téléphone et sur le web.',
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: data['contact_ready'] == false
                              ? null
                              : () => setState(() => welcome = false),
                          child: const Text('Compléter mon profil'),
                        ),
                      ] else if (tour) ...[
                        Text(
                          'Vous avez votre place ici.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        for (final item in [
                          (
                            Icons.school_outlined,
                            'Apprendre à votre rythme',
                            'Commencez dans Academy pour découvrir Enactus ESP, puis progressez vers les méthodes et les outils de l’entrepreneuriat social.',
                          ),
                          (
                            Icons.auto_stories_outlined,
                            'Découvrir notre histoire',
                            'Les archives et les projets vous font rencontrer les initiatives, les voyages et les personnes qui ont construit Enactus ESP.',
                          ),
                          (
                            Icons.groups_outlined,
                            'Contribuer avec votre équipe',
                            alumni
                                ? 'Retrouvez les alumni, proposez votre aide et échangez avec les membres dans les espaces auxquels votre profil donne accès.'
                                : 'Retrouvez vos pôles, vos projets et vos tâches. Faites avancer votre travail et échangez avec les responsables lorsque vous avez besoin d’aide.',
                          ),
                        ])
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(item.$1, color: scheme.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.$2,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.$3,
                                    style: const TextStyle(height: 1.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => setState(() => allowed = true),
                          child: const Text('Entrer dans mon espace'),
                        ),
                      ] else if (fields.isNotEmpty)
                        Form(
                          key: form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Faisons connaissance',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Compte : ${data['email']}\nIdentifiant : ${data['username']}',
                                style: const TextStyle(height: 1.5),
                              ),
                              const SizedBox(height: 24),
                              field('first_name', 'Prénom'),
                              field('last_name', 'Nom'),
                              field('phone', 'Téléphone', max: 30),
                              choice('Genre', gender, [
                                'homme',
                                'femme',
                              ], (value) => setState(() => gender = value)),
                              field(
                                'enactus_join_year',
                                'Année d’entrée dans Enactus ESP',
                                year: true,
                                max: 4,
                              ),
                              if (data['academic_year_name'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    data['academic_year_confirmed'] == true
                                        ? 'Votre parcours pour ${data['academic_year_name']} est déjà confirmé et sera conservé.'
                                        : 'Votre niveau sera confirmé pour ${data['academic_year_name']}.',
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ),
                              choice(
                                'Département ESP',
                                department,
                                departments.keys.toList(),
                                (value) => setState(() {
                                  department = value;
                                  cursus = null;
                                  level = null;
                                }),
                              ),
                              if (!alumni) ...[
                                choice(
                                  'Cursus',
                                  cursus,
                                  courses,
                                  (value) => setState(() {
                                    cursus = value;
                                    level = null;
                                  }),
                                ),
                                choice(
                                  'Niveau actuel',
                                  level,
                                  levels,
                                  (value) => setState(() => level = value),
                                ),
                              ] else
                                field(
                                  'graduation_year',
                                  'Année de fin d’études',
                                  year: true,
                                  max: 4,
                                ),
                              field(
                                'specialty',
                                'Spécialité (facultatif)',
                                required: false,
                                max: 150,
                              ),
                              field(
                                'promotion',
                                'Promotion (facultatif)',
                                required: false,
                              ),
                              field(
                                'bio',
                                'Quelques mots sur vous (facultatif)',
                                required: false,
                                max: 5000,
                                lines: 4,
                              ),
                              TextButton(
                                onPressed: saving ? null : load,
                                child: const Text(
                                  'Actualiser les informations',
                                ),
                              ),
                              const Text(
                                'Vous pourrez actualiser vos informations depuis votre profil.',
                                style: TextStyle(height: 1.5),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: saving ? null : complete,
                                child: Text(
                                  saving
                                      ? 'Enregistrement…'
                                      : 'Enregistrer mon profil',
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
    );
  }
}
