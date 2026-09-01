// ignore_for_file: curly_braces_in_flow_control_structures, use_null_aware_elements

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/impact_record_models.dart';
import '../services/impact_gateway.dart';

class ImpactRecordsScreen extends StatefulWidget {
  final ImpactGateway? gateway;
  const ImpactRecordsScreen({super.key, this.gateway});
  @override
  State<ImpactRecordsScreen> createState() => _ImpactRecordsScreenState();
}

class _ImpactRecordsScreenState extends State<ImpactRecordsScreen> {
  late final ImpactGateway gateway;
  List<ImpactRecordModel>? records;
  String? error;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? ApiImpactGateway();
    load();
  }

  Future<void> load() async {
    setState(() {
      error = null;
    });
    try {
      final value = await gateway.getRecords();
      if (mounted) setState(() => records = value);
    } catch (e) {
      if (mounted) setState(() => error = _msg(e));
    }
  }

  Future<void> create() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordFormDialog(gateway: gateway),
    );
    if (ok == true) await load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fiches Impact',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Mesures consolidées, indicateurs et preuves serveur.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle fiche Impact'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (error != null)
          _Error(message: error!, retry: load)
        else if (records == null)
          const Center(child: CircularProgressIndicator())
        else if (records!.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text('Aucune fiche Impact disponible.'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final r in records!)
                  SizedBox(
                    width: c.maxWidth >= 900
                        ? (c.maxWidth - 14) / 2
                        : c.maxWidth,
                    child: Card(
                      child: InkWell(
                        onTap: () => context.go(
                          '/impact/records/${r.id}',
                          extra: gateway,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(label: Text(r.statusLabel)),
                                  if (r.canValidate)
                                    const Chip(
                                      label: Text('Validation autorisée'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                r.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _value(r.summary),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      '${r.directBeneficiaries} directs',
                                    ),
                                  ),
                                  Chip(label: Text('${r.reach} portée')),
                                  Chip(label: Text('${r.sdgs.length} ODD')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class ImpactRecordDetailScreen extends StatefulWidget {
  final String recordId;
  final ImpactGateway? gateway;
  const ImpactRecordDetailScreen({
    super.key,
    required this.recordId,
    this.gateway,
  });
  @override
  State<ImpactRecordDetailScreen> createState() =>
      _ImpactRecordDetailScreenState();
}

class _ImpactRecordDetailScreenState extends State<ImpactRecordDetailScreen> {
  late final ImpactGateway gateway;
  ImpactRecordModel? record;
  List<ImpactMetricModel>? metrics;
  List<ImpactEvidenceModel>? evidence;
  String? error;
  bool loading = true;
  bool action = false;
  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? ApiImpactGateway();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await gateway.getRecord(widget.recordId);
      if (mounted) setState(() => record = value);
    } catch (e) {
      if (mounted) setState(() => error = _msg(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadMetrics() async {
    try {
      final value = await gateway.getMetrics(widget.recordId);
      if (mounted) setState(() => metrics = value);
    } catch (e) {
      _snack(_msg(e));
    }
  }

  Future<void> loadEvidence() async {
    try {
      final value = await gateway.getEvidence(widget.recordId);
      if (mounted) setState(() => evidence = value);
    } catch (e) {
      _snack(_msg(e));
    }
  }

  Future<void> validate() async {
    if (action) return;
    setState(() => action = true);
    try {
      await gateway.validateRecord(widget.recordId);
      await load();
    } catch (e) {
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => action = false);
    }
  }

  Future<void> reject() async {
    final reason = await _reason(context, 'Rejeter la fiche Impact');
    if (reason == null) return;
    if (action) return;
    setState(() => action = true);
    try {
      await gateway.rejectRecord(widget.recordId, reason);
      await load();
    } catch (e) {
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => action = false);
    }
  }

  void _snack(String m) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null)
      return Center(
        child: _Error(message: error!, retry: load),
      );
    final r = record!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 700
                    ? double.infinity
                    : 650,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text(r.statusLabel)),
                        if (r.canManage)
                          const Chip(label: Text('Gestion autorisée')),
                        if (r.canValidate)
                          const Chip(label: Text('Validation autorisée')),
                      ],
                    ),
                    Text(
                      r.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (r.canManage)
                    OutlinedButton.icon(
                      onPressed: () =>
                          showDialog<bool>(
                            context: context,
                            builder: (_) =>
                                _RecordFormDialog(gateway: gateway, record: r),
                          ).then((v) {
                            if (v == true) load();
                          }),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Modifier'),
                    ),
                  if (r.canValidate)
                    FilledButton.icon(
                      onPressed: action ? null : validate,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Valider'),
                    ),
                  if (r.canValidate)
                    OutlinedButton.icon(
                      onPressed: action ? null : reject,
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Rejeter'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            'Résumé',
            Icons.description_rounded,
            Wrap(
              spacing: 28,
              runSpacing: 16,
              children: [
                _Datum('Projet', r.projectId),
                _Datum('Saison', r.seasonId ?? 'Non renseignée'),
                _Datum('Population cible', _value(r.targetPopulation)),
                _Datum(
                  'ODD',
                  r.sdgs.isEmpty ? 'À documenter' : r.sdgs.join(', '),
                ),
                SizedBox(width: 500, child: Text(_value(r.summary))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            'People · Planet · Prosperity',
            Icons.insights_rounded,
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _Datum('Bénéficiaires directs', '${r.directBeneficiaries}'),
                _Datum('Bénéficiaires indirects', '${r.indirectBeneficiaries}'),
                _Datum('Portée', '${r.reach}'),
                _Datum('Vies impactées', '${r.livesImpacted}'),
                _Datum('Emplois créés', '${r.jobsCreated}'),
                _Datum('Revenus', '${r.revenueGenerated} FCFA'),
                _Datum('Profit / surplus', '${r.profitOrSurplus} FCFA'),
                _Datum('Économies', '${r.costSavings} FCFA'),
                _Datum('Arbres', '${r.treesPlanted}'),
                _Datum('Déchets réduits', '${r.wasteReduced} kg'),
                _Datum('Eau économisée', '${r.waterSaved} litres'),
                _Datum('CO₂ réduit', '${r.co2Reduced} kg'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            'Méthode et projection',
            Icons.science_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Problème', style: _label),
                Text(_value(r.problemStatement)),
                const SizedBox(height: 10),
                Text('Solution', style: _label),
                Text(_value(r.solutionSummary)),
                const SizedBox(height: 10),
                Text('Méthodologie', style: _label),
                Text(_value(r.methodology)),
                const SizedBox(height: 10),
                Text('Projection 12 mois', style: _label),
                Text(_value(r.projectionNext12Months)),
                const SizedBox(height: 10),
                Text('Notes de preuves', style: _label),
                Text(_value(r.evidenceNotes)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LazyBlock(
            title: 'Indicateurs',
            icon: Icons.query_stats_rounded,
            loaded: metrics != null,
            onLoad: loadMetrics,
            onCreate: r.canManage
                ? () =>
                      showDialog<bool>(
                        context: context,
                        builder: (_) =>
                            _MetricDialog(gateway: gateway, recordId: r.id),
                      ).then((v) {
                        if (v == true) loadMetrics();
                      })
                : null,
            child: metrics == null
                ? null
                : Column(
                    children: [
                      for (final m in metrics!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.title),
                          subtitle: Text(
                            '${m.categoryLabel} · ${m.value} ${m.unitLabel} · ${m.statusLabel}${m.rejectionReason == null ? '' : ' · ${m.rejectionReason}'}',
                          ),
                          trailing: r.canValidate
                              ? PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'validate')
                                      await gateway.validateMetric(m.id);
                                    else {
                                      final reason = await _reason(
                                        context,
                                        'Rejeter l’indicateur',
                                      );
                                      if (reason != null)
                                        await gateway.rejectMetric(
                                          m.id,
                                          reason,
                                        );
                                    }
                                    await loadMetrics();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'validate',
                                      child: Text('Valider'),
                                    ),
                                    PopupMenuItem(
                                      value: 'reject',
                                      child: Text('Rejeter'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _LazyBlock(
            title: 'Preuves',
            icon: Icons.attach_file_rounded,
            loaded: evidence != null,
            onLoad: loadEvidence,
            onCreate: r.canManage
                ? () =>
                      showDialog<bool>(
                        context: context,
                        builder: (_) => _EvidenceDialog(
                          gateway: gateway,
                          recordId: r.id,
                          metrics: metrics ?? const [],
                        ),
                      ).then((v) {
                        if (v == true) loadEvidence();
                      })
                : null,
            child: evidence == null
                ? null
                : Column(
                    children: [
                      for (final e in evidence!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.title),
                          subtitle: Text(
                            '${e.categoryLabel} · ${e.statusLabel}${e.rejectionReason == null ? '' : ' · ${e.rejectionReason}'}',
                          ),
                          trailing: r.canValidate
                              ? PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'validate')
                                      await gateway.validateEvidence(e.id);
                                    else {
                                      final reason = await _reason(
                                        context,
                                        'Rejeter la preuve',
                                      );
                                      if (reason != null)
                                        await gateway.rejectEvidence(
                                          e.id,
                                          reason,
                                        );
                                    }
                                    await loadEvidence();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'validate',
                                      child: Text('Valider'),
                                    ),
                                    PopupMenuItem(
                                      value: 'reject',
                                      child: Text('Rejeter'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordFormDialog extends StatefulWidget {
  final ImpactGateway gateway;
  final ImpactRecordModel? record;
  const _RecordFormDialog({required this.gateway, this.record});
  @override
  State<_RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<_RecordFormDialog> {
  late final Map<String, TextEditingController> c;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    c = {
      for (final key in const [
        'project_id',
        'season_id',
        'title',
        'summary',
        'problem_statement',
        'solution_summary',
        'target_population',
        'direct_beneficiaries',
        'indirect_beneficiaries',
        'reach',
        'jobs_created',
        'revenue_generated',
        'profit_or_surplus',
        'cost_savings',
        'lives_impacted',
        'trees_planted',
        'waste_reduced',
        'water_saved',
        'co2_reduced',
        'sdgs',
        'evidence_notes',
        'methodology',
        'projection_next_12_months',
      ])
        key: TextEditingController(text: _recordValue(r, key)),
    };
  }

  @override
  void dispose() {
    for (final v in c.values) v.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    final data = <String, dynamic>{
      for (final e in c.entries) e.key: _fieldValue(e.key, e.value.text),
    };
    try {
      if (widget.record == null)
        await widget.gateway.createRecord(data);
      else
        await widget.gateway.updateRecord(widget.record!.id, data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = _msg(e);
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.record == null
          ? 'Nouvelle fiche Impact'
          : 'Modifier la fiche Impact',
    ),
    content: SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final e in c.entries)
              SizedBox(
                width:
                    e.key.contains('summary') ||
                        e.key.contains('statement') ||
                        e.key.contains('methodology') ||
                        e.key.contains('notes') ||
                        e.key.contains('projection')
                    ? 690
                    : 330,
                child: TextField(
                  controller: e.value,
                  minLines:
                      e.key.contains('summary') ||
                          e.key.contains('statement') ||
                          e.key.contains('methodology')
                      ? 2
                      : 1,
                  maxLines:
                      e.key.contains('summary') ||
                          e.key.contains('statement') ||
                          e.key.contains('methodology')
                      ? 4
                      : 1,
                  decoration: InputDecoration(labelText: _fieldLabel(e.key)),
                ),
              ),
            if (error != null)
              SizedBox(
                width: 690,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Enregistrement…' : 'Enregistrer'),
      ),
    ],
  );
}

class _MetricDialog extends StatefulWidget {
  final ImpactGateway gateway;
  final String recordId;
  const _MetricDialog({required this.gateway, required this.recordId});
  @override
  State<_MetricDialog> createState() => _MetricDialogState();
}

class _MetricDialogState extends State<_MetricDialog> {
  final title = TextEditingController(),
      value = TextEditingController(),
      source = TextEditingController(),
      method = TextEditingController(),
      file = TextEditingController();
  String category = 'social', unit = 'personnes';
  bool busy = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvel indicateur'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            DropdownButtonFormField(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items:
                  const [
                        'social',
                        'economique',
                        'environmental',
                        'formation',
                        'sensibilisation',
                        'autre',
                      ]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(impactCategoryLabel(v)),
                        ),
                      )
                      .toList(),
              onChanged: (v) => category = v!,
            ),
            DropdownButtonFormField(
              initialValue: unit,
              decoration: const InputDecoration(labelText: 'Unité'),
              items:
                  const [
                        'personnes',
                        'FCFA',
                        'emplois',
                        'arbres',
                        'kg',
                        'litres',
                        'pourcentage',
                        'autre',
                      ]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(impactUnitLabel(v)),
                        ),
                      )
                      .toList(),
              onChanged: (v) => unit = v!,
            ),
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: 'Valeur'),
            ),
            TextField(
              controller: source,
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            TextField(
              controller: method,
              decoration: const InputDecoration(
                labelText: 'Note méthodologique',
              ),
            ),
            TextField(
              controller: file,
              decoration: const InputDecoration(
                labelText: 'Fichier de preuve existant',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                await widget.gateway.createMetric(widget.recordId, {
                  'title': title.text,
                  'category': category,
                  'unit': unit,
                  'value': double.tryParse(value.text) ?? 0,
                  'source': source.text,
                  'methodology_note': method.text,
                  'evidence_file_id': file.text.isEmpty ? null : file.text,
                });
                if (context.mounted) Navigator.pop(context, true);
              },
        child: const Text('Créer'),
      ),
    ],
  );
}

class _EvidenceDialog extends StatefulWidget {
  final ImpactGateway gateway;
  final String recordId;
  final List<ImpactMetricModel> metrics;
  const _EvidenceDialog({
    required this.gateway,
    required this.recordId,
    required this.metrics,
  });
  @override
  State<_EvidenceDialog> createState() => _EvidenceDialogState();
}

class _EvidenceDialogState extends State<_EvidenceDialog> {
  final title = TextEditingController(),
      description = TextEditingController(),
      file = TextEditingController();
  String category = 'autre';
  String? metric;
  bool busy = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle preuve'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Titre'),
          ),
          TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          DropdownButtonFormField(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items:
                const [
                      'social',
                      'economique',
                      'environmental',
                      'formation',
                      'sensibilisation',
                      'autre',
                    ]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(impactCategoryLabel(v)),
                      ),
                    )
                    .toList(),
            onChanged: (v) => category = v!,
          ),
          DropdownButtonFormField<String?>(
            initialValue: metric,
            decoration: const InputDecoration(labelText: 'Indicateur lié'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Aucun')),
              for (final m in widget.metrics)
                DropdownMenuItem(value: m.id, child: Text(m.title)),
            ],
            onChanged: (v) => metric = v,
          ),
          TextField(
            controller: file,
            decoration: const InputDecoration(labelText: 'Fichier existant'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                await widget.gateway.createEvidence(widget.recordId, {
                  'title': title.text,
                  'description': description.text,
                  'category': category,
                  'metric_id': metric,
                  'file_id': file.text.isEmpty ? null : file.text,
                });
                if (context.mounted) Navigator.pop(context, true);
              },
        child: const Text('Créer'),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(this.title, this.icon, this.child);
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _LazyBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool loaded;
  final VoidCallback onLoad;
  final VoidCallback? onCreate;
  final Widget? child;
  const _LazyBlock({
    required this.title,
    required this.icon,
    required this.loaded,
    required this.onLoad,
    required this.onCreate,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => _Section(
    title,
    icon,
    Column(
      children: [
        Row(
          children: [
            if (!loaded)
              FilledButton.icon(
                onPressed: onLoad,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Charger'),
              ),
            const Spacer(),
            if (onCreate != null)
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Nouveau ${title.toLowerCase() == 'preuves' ? 'preuve' : 'indicateur'}',
                ),
              ),
          ],
        ),
        if (child != null) child!,
      ],
    ),
  );
}

class _Datum extends StatelessWidget {
  final String l, v;
  const _Datum(this.l, this.v);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l, style: Theme.of(context).textTheme.labelMedium),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const _Error({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _reason(BuildContext context, String title) async {
  final c = TextEditingController();
  final v = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        minLines: 3,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Motif obligatoire'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => c.text.trim().isEmpty
              ? null
              : Navigator.pop(context, c.text.trim()),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
  c.dispose();
  return v;
}

String _recordValue(ImpactRecordModel? r, String k) {
  if (r == null) return '';
  return switch (k) {
    'project_id' => r.projectId,
    'season_id' => r.seasonId ?? '',
    'title' => r.title,
    'summary' => r.summary ?? '',
    'problem_statement' => r.problemStatement ?? '',
    'solution_summary' => r.solutionSummary ?? '',
    'target_population' => r.targetPopulation ?? '',
    'direct_beneficiaries' => '${r.directBeneficiaries}',
    'indirect_beneficiaries' => '${r.indirectBeneficiaries}',
    'reach' => '${r.reach}',
    'jobs_created' => '${r.jobsCreated}',
    'revenue_generated' => '${r.revenueGenerated}',
    'profit_or_surplus' => '${r.profitOrSurplus}',
    'cost_savings' => '${r.costSavings}',
    'lives_impacted' => '${r.livesImpacted}',
    'trees_planted' => '${r.treesPlanted}',
    'waste_reduced' => '${r.wasteReduced}',
    'water_saved' => '${r.waterSaved}',
    'co2_reduced' => '${r.co2Reduced}',
    'sdgs' => r.sdgs.join(', '),
    'evidence_notes' => r.evidenceNotes ?? '',
    'methodology' => r.methodology ?? '',
    'projection_next_12_months' => r.projectionNext12Months ?? '',
    _ => '',
  };
}

dynamic _fieldValue(String k, String v) {
  if (const [
    'direct_beneficiaries',
    'indirect_beneficiaries',
    'reach',
    'jobs_created',
    'lives_impacted',
    'trees_planted',
  ].contains(k))
    return int.tryParse(v) ?? 0;
  if (const [
    'revenue_generated',
    'profit_or_surplus',
    'cost_savings',
    'waste_reduced',
    'water_saved',
    'co2_reduced',
  ].contains(k))
    return double.tryParse(v) ?? 0;
  if (k == 'sdgs')
    return v
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  return v.trim().isEmpty ? null : v.trim();
}

String _fieldLabel(String k) => k
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
String _value(String? v) =>
    v == null || v.trim().isEmpty ? 'À documenter' : v.trim();
String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');
const _label = TextStyle(fontWeight: FontWeight.w900);
