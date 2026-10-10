import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/app_components.dart';
import '../models/attendance_qr_model.dart';
import '../services/attendance_service.dart';

class AttendanceQrScannerScreen extends StatefulWidget {
  const AttendanceQrScannerScreen({super.key});

  @override
  State<AttendanceQrScannerScreen> createState() =>
      _AttendanceQrScannerScreenState();
}

class _AttendanceQrScannerScreenState extends State<AttendanceQrScannerScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _manualTokenController = TextEditingController();

  bool _processing = false;
  AttendanceQrScanResultModel? _lastResult;
  String? _error;

  @override
  void dispose() {
    _manualTokenController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_processing) return;
    final token = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (token == null) return;

    await _submitToken(token);
  }

  Future<void> _submitToken(String token) async {
    if (token.trim().isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
      _lastResult = null;
    });

    try {
      await _scannerController.stop();
      final result = await _attendanceService.scanQrToken(token.trim());
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _lastResult = null;
      _error = null;
    });
    await _scannerController.start();
  }

  Future<void> _openManualEntry() async {
    final token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Saisie QR',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _manualTokenController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Token QR',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
              ),
              SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_manualTokenController.text),
                icon: Icon(Icons.check_rounded),
                label: Text('Valider'),
              ),
            ],
          ),
        );
      },
    );

    if (token != null) {
      await _submitToken(token);
      _manualTokenController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 780;

    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner presence'),
        actions: [
          IconButton(
            tooltip: 'Lampe',
            onPressed: () => _scannerController.toggleTorch(),
            icon: Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            tooltip: 'Camera',
            onPressed: () => _scannerController.switchCamera(),
            icon: Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AppResponsiveContainer(
          child: Padding(
            padding: EdgeInsets.all(width < 560 ? 14 : 24),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildScannerCard()),
                      SizedBox(width: 20),
                      Expanded(flex: 4, child: _buildResultCard()),
                    ],
                  )
                : ListView(
                    children: [
                      _buildScannerCard(),
                      SizedBox(height: 18),
                      _buildResultCard(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerCard() {
    return AppDataCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(title: 'Pointage de présence'),
          SizedBox(height: 6),
          Text(
            'Le QR signé permet d’identifier automatiquement la session concernée.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleCapture,
                    errorBuilder: (context, error) {
                      return ColoredBox(
                        color: AppTheme.softBlack,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.videocam_off_rounded,
                                  color: AppTheme.enactusYellow,
                                  size: 44,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Caméra indisponible',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Autorisez la caméra ou utilisez la saisie du code QR.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                                SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: _processing
                                      ? null
                                      : _openManualEntry,
                                  icon: Icon(Icons.keyboard_rounded),
                                  label: Text('Saisir un code'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: AppTheme.enactusYellow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _ScannerFrame(processing: _processing),
                ],
              ),
            ),
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _processing ? null : _scanAgain,
                icon: Icon(Icons.qr_code_scanner_rounded),
                label: Text('Scanner'),
              ),
              OutlinedButton.icon(
                onPressed: _processing ? null : _openManualEntry,
                icon: Icon(Icons.keyboard_rounded),
                label: Text('Saisie'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult;
    final success = result?.success == true;
    final icon = success ? Icons.check_circle_rounded : Icons.info_rounded;
    final color = success ? Colors.green.shade700 : AppTheme.softBlack;
    final message = result?.message ?? _error ?? 'Placez le QR dans le cadre.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: success
                  ? Colors.green.withAlpha(35)
                  : AppTheme.enactusYellow.withAlpha(55),
              child: Icon(icon, color: color, size: 40),
            ),
            SizedBox(height: 14),
            Text(
              success ? 'Presence enregistree' : 'Pointage QR',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _error == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.red.shade700,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (result?.attendanceStatus != null) ...[
              SizedBox(height: 14),
              Center(
                child: Chip(
                  avatar: Icon(
                    success ? Icons.verified_rounded : Icons.schedule_rounded,
                    size: 16,
                  ),
                  label: Text(_attendanceStatusLabel(result!.attendanceStatus)),
                  backgroundColor: AppTheme.enactusYellow.withAlpha(45),
                ),
              ),
            ],
            SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _processing ? null : _scanAgain,
              icon: Icon(Icons.refresh_rounded),
              label: Text('Nouveau scan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  final bool processing;

  const _ScannerFrame({required this.processing});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.enactusYellow, width: 3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          if (processing)
            Container(
              color: Colors.black.withAlpha(140),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.enactusYellow),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: AppTheme.enactusYellow,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _attendanceStatusLabel(String? value) {
  switch (value) {
    case 'present':
      return 'Present';
    case 'late':
      return 'Retard';
    case 'already_recorded':
      return 'Deja pointe';
    default:
      return value ?? 'Pointage';
  }
}
