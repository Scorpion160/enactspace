import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../models/attendance_qr_model.dart';

class QrAttendanceSection extends StatelessWidget {
  final AttendanceQrTokenModel? token;
  final AttendanceQrStatusModel? status;
  final List<AttendanceQrAuditLogModel> auditLogs;
  final bool loading;
  final String? error;
  final String? auditError;
  final bool isOpen;
  final Future<void> Function() onGenerate;
  final Future<void> Function() onRefresh;

  const QrAttendanceSection({
    super.key,
    required this.token,
    required this.status,
    required this.auditLogs,
    required this.loading,
    required this.error,
    required this.auditError,
    required this.isOpen,
    required this.onGenerate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expected = status?.expectedCount ?? 0;
    final scanned = status?.scannedCount ?? 0;
    final progress = expected == 0 ? 0.0 : (scanned / expected).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final qrSize = isWide ? 220.0 : 190.0;
            final qrBlock = _QrPreview(
              token: token,
              loading: loading,
              isOpen: isOpen,
              size: qrSize,
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.enactusYellow.withAlpha(55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppTheme.softBlack,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pointage QR',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isOpen
                      ? 'QR dynamique pret. Les compteurs se mettent a jour automatiquement.'
                      : 'Ouvrez la session pour activer le pointage QR.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    color: AppTheme.enactusYellow,
                    backgroundColor: Colors.black12,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QrMetric(label: 'Scannes', value: scanned),
                    _QrMetric(
                      label: 'Presents',
                      value: status?.presentCount ?? 0,
                    ),
                    _QrMetric(label: 'Retards', value: status?.lateCount ?? 0),
                    _QrMetric(
                      label: 'Restants',
                      value: status?.remainingCount ?? 0,
                    ),
                  ],
                ),
                if (status?.lastScanAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Dernier scan: ${_formatShortTime(status!.lastScanAt!)}'
                    ' (${_scanStatusLabel(status!.lastScanStatus)})',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (error != null && error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (auditError != null && auditError!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    auditError!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: loading || !isOpen ? null : onGenerate,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: Text(token == null ? 'Generer QR' : 'Renouveler'),
                    ),
                    OutlinedButton.icon(
                      onPressed: loading ? null : onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _QrAuditTrail(logs: auditLogs.take(6).toList()),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  qrBlock,
                  const SizedBox(width: 20),
                  Expanded(child: details),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.center, child: qrBlock),
                const SizedBox(height: 18),
                details,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QrAuditTrail extends StatelessWidget {
  final List<AttendanceQrAuditLogModel> logs;

  const _QrAuditTrail({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 18),
              SizedBox(width: 8),
              Text('Journal QR', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const Text(
              'Aucun scan QR pour le moment.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_auditIcon(log), color: _auditColor(log), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _auditLabel(log),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_formatShortTime(log.createdAt)}'
                            '${log.userId == null ? '' : ' • ${_shortUserId(log.userId!)}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  final AttendanceQrTokenModel? token;
  final bool loading;
  final bool isOpen;
  final double size;

  const _QrPreview({
    required this.token,
    required this.loading,
    required this.isOpen,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasToken = token != null && token!.token.isNotEmpty;

    return Container(
      width: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasToken)
              QrImageView(
                data: token!.token,
                version: QrVersions.auto,
                gapless: true,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppTheme.softBlack,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppTheme.softBlack,
                ),
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOpen ? Icons.qr_code_2_rounded : Icons.lock_rounded,
                    color: Colors.black38,
                    size: 52,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isOpen ? 'QR non genere' : 'Session fermee',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            if (loading)
              Container(
                color: Colors.white.withAlpha(210),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _QrMetric extends StatelessWidget {
  final String label;
  final int value;

  const _QrMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.enactusYellow.withAlpha(35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.enactusYellow.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatShortTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

IconData _auditIcon(AttendanceQrAuditLogModel log) {
  switch (log.result ?? log.action) {
    case 'present':
    case 'late':
      return Icons.verified_rounded;
    case 'already_recorded':
      return Icons.done_all_rounded;
    case 'attendance_qr_token_generated':
      return Icons.qr_code_2_rounded;
    default:
      return Icons.info_rounded;
  }
}

Color _auditColor(AttendanceQrAuditLogModel log) {
  switch (log.result ?? log.action) {
    case 'present':
      return Colors.green.shade700;
    case 'late':
      return Colors.orange.shade800;
    case 'expired_token':
    case 'invalid_token':
    case 'not_eligible':
    case 'rate_limited':
      return Colors.red.shade700;
    default:
      return AppTheme.softBlack;
  }
}

String _auditLabel(AttendanceQrAuditLogModel log) {
  if (log.action == 'attendance_qr_token_generated') {
    return 'QR genere';
  }
  switch (log.result) {
    case 'present':
      return 'Presence enregistree';
    case 'late':
      return 'Retard enregistre';
    case 'already_recorded':
      return 'Pointage deja effectue';
    case 'expired_token':
      return 'QR expire';
    case 'invalid_token':
      return 'QR invalide';
    case 'not_eligible':
      return 'Membre non attendu';
    case 'rate_limited':
      return 'Tentatives limitees';
    case 'session_closed':
      return 'Session fermee';
    case 'qr_disabled':
      return 'Pointage QR desactive';
    default:
      return log.result ?? log.action;
  }
}

String _shortUserId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

String _scanStatusLabel(String? value) {
  switch (value) {
    case 'present':
      return 'present';
    case 'late':
      return 'retard';
    case 'absent':
      return 'absent';
    default:
      return value ?? 'scan';
  }
}
