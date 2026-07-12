import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/tags/tag.dart';

import '../../../core/theme/app_theme.dart';
import '../models/attendance_nfc_model.dart';
import '../models/attendance_qr_model.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_service.dart';

class AttendanceNfcCheckInScreen extends StatefulWidget {
  final AttendanceSessionModel session;

  const AttendanceNfcCheckInScreen({super.key, required this.session});

  @override
  State<AttendanceNfcCheckInScreen> createState() =>
      _AttendanceNfcCheckInScreenState();
}

class _AttendanceNfcCheckInScreenState
    extends State<AttendanceNfcCheckInScreen> {
  final AttendanceService _attendanceService = AttendanceService();

  bool _nfcAvailable = false;
  bool _listening = false;
  bool _processing = false;
  bool _paused = false;
  String? _error;
  AttendanceQrStatusModel? _status;
  AttendanceNfcCheckInResultModel? _lastResult;
  final List<AttendanceNfcCheckInResultModel> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_listening) {
      NfcManager.instance.stopSession();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      final status = await _attendanceService.getQrStatus(widget.session.id);
      if (!mounted) return;
      setState(() {
        _nfcAvailable = availability == NfcAvailability.enabled;
        _status = status;
        _error = null;
      });
      if (_nfcAvailable && widget.session.status == 'open') {
        unawaited(_startListening());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startListening() async {
    if (_listening || _processing || _paused || !_nfcAvailable) return;
    setState(() {
      _listening = true;
      _error = null;
    });
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        if (_processing) return;
        await NfcManager.instance.stopSession();
        if (!mounted) return;
        setState(() {
          _listening = false;
          _processing = true;
        });
        await _submitTag(_tagPayload(tag));
      },
    );
  }

  Future<void> _submitTag(String tagPayload) async {
    try {
      final result = await _attendanceService.nfcCheckIn(
        sessionId: widget.session.id,
        tagPayload: tagPayload,
      );
      final status = await _attendanceService.getQrStatus(widget.session.id);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _history.insert(0, result);
        if (_history.length > 8) _history.removeLast();
        _status = status;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        if (!_paused) {
          Timer(const Duration(milliseconds: 900), () {
            if (mounted) unawaited(_startListening());
          });
        }
      }
    }
  }

  Future<void> _togglePause() async {
    setState(() => _paused = !_paused);
    if (_paused && _listening) {
      await NfcManager.instance.stopSession();
      if (mounted) setState(() => _listening = false);
    } else if (!_paused) {
      await _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 820;

    return Scaffold(
      appBar: AppBar(title: const Text('Pointage NFC')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(width < 560 ? 14 : 24),
          children: [
            _NfcReaderHeader(
              sessionTitle: widget.session.title,
              nfcAvailable: _nfcAvailable,
              listening: _listening,
              paused: _paused,
              processing: _processing,
              onPause: _togglePause,
              onRefresh: _load,
            ),
            const SizedBox(height: 18),
            if (_error != null)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.error_rounded,
                    color: Colors.red.shade700,
                  ),
                  title: Text(_error!),
                ),
              ),
            if (_error != null) const SizedBox(height: 18),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _NfcCounters(status: _status)),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _NfcResultPanel(
                      lastResult: _lastResult,
                      history: _history,
                    ),
                  ),
                ],
              )
            else ...[
              _NfcCounters(status: _status),
              const SizedBox(height: 18),
              _NfcResultPanel(lastResult: _lastResult, history: _history),
            ],
          ],
        ),
      ),
    );
  }
}

class _NfcReaderHeader extends StatelessWidget {
  final String sessionTitle;
  final bool nfcAvailable;
  final bool listening;
  final bool paused;
  final bool processing;
  final Future<void> Function() onPause;
  final Future<void> Function() onRefresh;

  const _NfcReaderHeader({
    required this.sessionTitle,
    required this.nfcAvailable,
    required this.listening,
    required this.paused,
    required this.processing,
    required this.onPause,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.enactusYellow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.nfc_rounded, color: AppTheme.softBlack),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _readerStatusLabel(
                        nfcAvailable: nfcAvailable,
                        listening: listening,
                        paused: paused,
                        processing: processing,
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualiser'),
              ),
              ElevatedButton.icon(
                onPressed: nfcAvailable ? onPause : null,
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(paused ? 'Reprendre' : 'Pause'),
              ),
            ],
          );

          if (constraints.maxWidth >= 700) {
            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 16),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [content, const SizedBox(height: 16), actions],
          );
        },
      ),
    );
  }
}

class _NfcCounters extends StatelessWidget {
  final AttendanceQrStatusModel? status;

  const _NfcCounters({required this.status});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Scannes', status?.scannedCount ?? 0, Icons.fact_check_rounded),
      ('Presents', status?.presentCount ?? 0, Icons.check_circle_rounded),
      ('Retards', status?.lateCount ?? 0, Icons.schedule_rounded),
      ('Restants', status?.remainingCount ?? 0, Icons.pending_actions_rounded),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            return Container(
              constraints: const BoxConstraints(minWidth: 120),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.enactusYellow.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$3),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(item.$1),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NfcResultPanel extends StatelessWidget {
  final AttendanceNfcCheckInResultModel? lastResult;
  final List<AttendanceNfcCheckInResultModel> history;

  const _NfcResultPanel({required this.lastResult, required this.history});

  @override
  Widget build(BuildContext context) {
    final result = lastResult;
    final success = result?.success == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              success ? Icons.verified_rounded : Icons.nfc_rounded,
              size: 52,
              color: success ? Colors.green.shade700 : AppTheme.softBlack,
            ),
            const SizedBox(height: 10),
            Text(
              result?.memberDisplayName ?? 'Approchez un badge',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              result?.message ??
                  'Le lecteur reste pret pour le prochain badge.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Historique recent',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Text('Aucun pointage NFC pour le moment.')
            else
              ...history.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.success
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    color: item.success
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                  title: Text(item.memberDisplayName ?? item.result),
                  subtitle: Text(item.message),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _tagPayload(NfcTag tag) {
  final androidTag = NfcTagAndroid.from(tag);
  if (androidTag != null) {
    return androidTag.id
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
  return tag.hashCode.toString();
}

String _readerStatusLabel({
  required bool nfcAvailable,
  required bool listening,
  required bool paused,
  required bool processing,
}) {
  if (!nfcAvailable) return 'NFC indisponible sur cet appareil.';
  if (processing) return 'Pointage en cours...';
  if (paused) return 'Lecture NFC en pause.';
  if (listening) return 'Approchez un badge NFC.';
  return 'Lecteur pret.';
}
