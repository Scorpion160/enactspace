// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../services/academic_profile_service.dart';

class AcademicProfileScreen extends StatefulWidget {
  final AcademicProfileService? service;
  const AcademicProfileScreen({super.key, this.service});

  @override
  State<AcademicProfileScreen> createState() => _AcademicProfileScreenState();
}

class _AcademicProfileScreenState extends State<AcademicProfileScreen> {
  late final AcademicProfileService service;
  final specialty = TextEditingController();
  final promotion = TextEditingController();
  Map<String, Map<String, List<String>>> catalog = {};
  Map<String, dynamic>? profile;
  String? department;
  String? cursus;
  String? level;
  String? error;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? AcademicProfileService();
    load();
  }

  @override
  void dispose() {
    specialty.dispose();
    promotion.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final choices = await service.catalog();
      final current = await service.profile();
      if (!mounted) return;
      final selectedDepartment = current['department']?.toString();
      final selectedCursus = current['cursus']?.toString();
      final selectedLevel = current['level']?.toString();
      setState(() {
        catalog = choices;
        profile = current;
        department = choices.containsKey(selectedDepartment)
            ? selectedDepartment
            : null;
        cursus = choices[department]?.containsKey(selectedCursus) == true
            ? selectedCursus
            : null;
        level = choices[department]?[cursus]?.contains(selectedLevel) == true
            ? selectedLevel
            : null;
        specialty.text = current['specialty']?.toString() ?? '';
        promotion.text = current['promotion']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'La confirmation n’a pas abouti. Actualisez votre profil et réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> confirm() async {
    if (department == null || cursus == null || level == null || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await service.confirm({
        'season_id': profile?['current_season_id'],
        'department': department,
        'cursus': cursus,
        'level': level,
        'specialty': specialty.text.trim(),
        'promotion': promotion.text.trim(),
      });
      if (!mounted) return;
      setState(() => profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil académique confirmé pour cette année.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'La confirmation n’a pas abouti. Actualisez votre profil et réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cursuses = catalog[department] ?? const <String, List<String>>{};
    final levels = cursuses[cursus] ?? const <String>[];
    final confirmed = profile?['confirmed_current_season'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil académique')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Confirmez votre cursus pour l’année en cours.'),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null && catalog.isEmpty)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else ...[
              if (!confirmed && profile?['suggested_next_level'] != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: Text(
                      'Niveau suivant : ${profile!['suggested_next_level']}',
                    ),
                    subtitle: const Text(
                      'Choisissez votre niveau réel : passage, redoublement ou changement de cursus.',
                    ),
                  ),
                ),
              if (confirmed)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('Profil confirmé'),
                    subtitle: Text(
                      'La prochaine confirmation sera possible à la nouvelle année.',
                    ),
                  ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: department,
                decoration: const InputDecoration(labelText: 'Département'),
                items: catalog.keys
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: confirmed
                    ? null
                    : (value) => setState(() {
                        department = value;
                        cursus = null;
                        level = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: cursus,
                decoration: const InputDecoration(labelText: 'Cursus'),
                items: cursuses.keys
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: confirmed
                    ? null
                    : (value) => setState(() {
                        cursus = value;
                        level = null;
                      }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: level,
                decoration: const InputDecoration(labelText: 'Niveau'),
                items: levels
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: confirmed
                    ? null
                    : (value) => setState(() => level = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specialty,
                enabled: !confirmed,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Spécialité (facultatif)',
                ),
              ),
              TextField(
                controller: promotion,
                enabled: !confirmed,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Promotion (facultatif)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    confirmed ||
                        saving ||
                        department == null ||
                        cursus == null ||
                        level == null
                    ? null
                    : confirm,
                child: Text(
                  saving ? 'Confirmation…' : 'Confirmer pour cette année',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
