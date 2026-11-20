import '../recruitment_style.dart';
import 'package:flutter/material.dart';

import '../../services/recruitment_campaign_tools.dart';
import '../../services/recruitment_message.dart';

class JuryTeamsSection extends StatefulWidget {
  final String campaignId;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> members;
  final bool canManage;
  final bool busy;
  final RecruitmentCampaignTools tools;
  final Future<void> Function() onChanged;
  final Future<void> Function(String)? onOpenApplication;
  const JuryTeamsSection({
    super.key,
    required this.campaignId,
    required this.teams,
    required this.members,
    required this.canManage,
    required this.tools,
    required this.onChanged,
    this.busy = false,
    this.onOpenApplication,
  });
  @override
  State<JuryTeamsSection> createState() => _JuryTeamsSectionState();
}

class _JuryTeamsSectionState extends State<JuryTeamsSection> {
  Future<void> _edit({
    Map<String, dynamic>? team,
    bool everyone = false,
  }) async {
    var name = everyone
        ? 'Jury unique'
        : team?['name']?.toString() ?? 'Équipe ${widget.teams.length + 1}';
    final selected = everyone
        ? widget.members
              .where((row) => row['active'] == true)
              .map((row) => row['id'].toString())
              .toSet()
        : (team?['members'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => row['id'].toString())
              .toSet();
    var active = team?['active'] != false;
    var saving = false;
    String? error;
    await showRecruitmentDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              team == null ? 'Constituer une équipe' : 'Modifier l’équipe',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: name,
                      onChanged: (value) => name = value,
                      enabled: !saving,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l’équipe',
                        hintText: 'Jury unique, Équipe A…',
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Équipe active'),
                      subtitle: const Text(
                        'Une équipe en pause garde ses entretiens et son historique.',
                      ),
                      value: active,
                      onChanged: saving
                          ? null
                          : (value) => update(() => active = value),
                    ),
                    const Text(
                      'Choisis les enacteurs et alumni déjà sélectionnés pour cette campagne.',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: saving
                            ? null
                            : () => update(() {
                                selected
                                  ..clear()
                                  ..addAll(
                                    widget.members
                                        .where((row) => row['active'] == true)
                                        .map((row) => row['id'].toString()),
                                  );
                              }),
                        child: const Text(
                          'Sélectionner tous les membres disponibles',
                        ),
                      ),
                    ),
                    for (final member in widget.members.where(
                      (row) =>
                          row['active'] == true || selected.contains(row['id']),
                    ))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(member['id']),
                        title: Text(member['name'].toString()),
                        subtitle: member['active'] == true
                            ? null
                            : const Text(
                                'Indisponible : à retirer de la composition active',
                              ),
                        onChanged: saving
                            ? null
                            : (value) => update(() {
                                if (value == true && member['active'] == true) {
                                  selected.add(member['id'].toString());
                                } else {
                                  selected.remove(member['id'].toString());
                                }
                              }),
                      ),
                    if (team != null)
                      const Text(
                        'Les entretiens déjà prévus resteront visibles et seront à actualiser si la composition change.',
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Retour'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.trim().isEmpty || selected.isEmpty) {
                          update(
                            () => error =
                                'Indique un nom et choisis au moins un membre.',
                          );
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await widget.tools.saveJuryTeam(widget.campaignId, {
                            'name': name.trim(),
                            'member_ids': selected.toList(),
                            'active': active,
                            if (team != null) 'revision': team['revision'],
                          }, teamId: team?['id']?.toString());
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (failure) {
                          if (context.mounted) {
                            update(() {
                              saving = false;
                              error = recruitmentMessage(
                                failure,
                                fallback:
                                    'Cette équipe n’a pas pu être enregistrée.',
                              );
                            });
                          }
                        }
                      },
                child: Text(
                  saving ? 'Enregistrement…' : 'Enregistrer l’équipe',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Les équipes d’entretien',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Une seule équipe pour recevoir les candidats ensemble, ou plusieurs équipes en parallèle : à toi de choisir. Les créneaux se règlent pour chaque candidat.',
      ),
      if (widget.canManage)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: widget.busy ? null : () => _edit(),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Créer une équipe'),
              ),
              OutlinedButton.icon(
                onPressed: widget.busy
                    ? null
                    : () => _edit(
                        everyone: true,
                        team: widget.teams
                            .where((row) => row['name'] == 'Jury unique')
                            .firstOrNull,
                      ),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Réunir tout le jury'),
              ),
            ],
          ),
        ),
      if (widget.teams.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Aucune équipe constituée pour le moment.'),
        ),
      for (final team in widget.teams)
        Card(
          child: ExpansionTile(
            key: ValueKey('jury-team-${team['id']}-${team['revision']}'),
            leading: Icon(
              team['active'] == true
                  ? Icons.groups_outlined
                  : Icons.pause_circle_outline,
            ),
            title: Text(team['name'].toString()),
            subtitle: Text(
              '${(team['members'] as List).length} membre(s) · ${(team['interviews'] as List? ?? const []).length} entretien(s) à venir · ${team['active'] != true
                  ? 'En pause'
                  : team['available'] == true
                  ? 'Disponible'
                  : 'Composition à revoir'}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final person in (team['members'] as List).whereType<Map>())
                ListTile(
                  dense: true,
                  leading: Icon(
                    person['active'] == true
                        ? Icons.person_outline
                        : Icons.person_off_outlined,
                  ),
                  title: Text(person['name'].toString()),
                ),
              if (widget.canManage)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: widget.busy ? null : () => _edit(team: team),
                    child: const Text('Modifier cette équipe'),
                  ),
                ),
              for (final app
                  in (team['interviews'] as List? ?? const []).whereType<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(app['name'].toString()),
                  subtitle: Text(
                    '${app['interview_at'].toString().replaceAll('T', ' ').replaceAll('Z', '')} · Dakar${app['needs_update'] == true ? '\nComposition à actualiser' : ''}',
                  ),
                  trailing: widget.onOpenApplication == null
                      ? null
                      : const Icon(Icons.arrow_forward),
                  onTap: widget.onOpenApplication == null || widget.busy
                      ? null
                      : () async {
                          await widget.onOpenApplication!(
                            app['application_id'].toString(),
                          );
                          if (mounted) await widget.onChanged();
                        },
                ),
            ],
          ),
        ),
      if (widget.teams.where((row) => row['active'] == true).length > 1 &&
          widget.canManage)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Pour travailler en jury unique, conserve une équipe active et mets les autres en pause. Les entretiens concernés resteront à réattribuer.',
          ),
        ),
      const SizedBox(height: 22),
    ],
  );
}
