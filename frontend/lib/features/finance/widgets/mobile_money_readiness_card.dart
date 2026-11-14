import 'package:flutter/material.dart';

import '../services/finance_service.dart';

/// Configuration diagnostics only; never creates an invoice or marks a fee paid.
/// Restricted to finance managers by the parent screen and backend permission.
class MobileMoneyReadinessCard extends StatefulWidget {
  final FinanceService financeService;

  const MobileMoneyReadinessCard({
    super.key,
    required this.financeService,
  });

  @override
  State<MobileMoneyReadinessCard> createState() =>
      _MobileMoneyReadinessCardState();
}

class _MobileMoneyReadinessCardState extends State<MobileMoneyReadinessCard> {
  late Future<Map<String, dynamic>> _readiness;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _readiness = widget.financeService.getMobileMoneyReadiness();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      key: const Key('mobile-money-readiness-card'),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Vérification des paiements en ligne'),
        subtitle: const Text('PayDunya · Wave et Orange Money · contrôle sans transaction'),
        trailing: IconButton(
          tooltip: 'Actualiser le diagnostic',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(_reload),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _readiness,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              final data = snapshot.data;
              if (data == null || snapshot.hasError) {
                return Text(
                  'Le diagnostic est indisponible. Vérifiez que l’API et '
                  'les droits d’administration sont à jour.',
                  style: TextStyle(color: colors.error),
                );
              }

              final liveReady = data['ready_for_live_test'] == true;
              final configurationReady = data['configuration_ready'] == true;
              final mode = data['mode']?.toString() ?? 'inconnu';
              final channels = (data['allowed_channels'] as List? ?? [])
                  .map((value) => value.toString())
                  .join(' · ');
              final blockers = (data['blocking_checks'] as List? ?? [])
                  .map((value) => value.toString())
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(
                      liveReady
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: liveReady ? colors.primary : colors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        liveReady
                            ? 'Configuration prête pour un essai réel encadré'
                            : configurationReady
                                ? 'Configuration de test détectée — pas de débit réel'
                                : 'Configuration incomplète — paiement réel à ne pas lancer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text('Mode : $mode · Prestataire : ${data['provider']}'),
                  Text('Canaux : ${channels.isEmpty ? 'aucun' : channels}'),
                  Text('Rapprochement : ${data['reconciliation_enabled'] == true ? 'activé' : 'désactivé'}'),
                  if (blockers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final reason in blockers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 17, color: colors.error),
                          const SizedBox(width: 8),
                          Expanded(child: Text(reason)),
                        ]),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Ce contrôle ne réalise aucun paiement et ne garantit '
                    'pas que le compte marchand est activé. Pour le premier '
                    'essai réel, confirmer les frais du prestataire, le '
                    'montant et le compte payeur, puis vérifier la confirmation '
                    'PayDunya, le reçu et l’affectation à la cotisation.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
