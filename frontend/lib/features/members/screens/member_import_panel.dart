import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../models/member_import_model.dart';
import '../services/members_service.dart';

class MemberImportPanel extends StatefulWidget {
  final MembersService membersService;

  const MemberImportPanel({super.key, required this.membersService});

  @override
  State<MemberImportPanel> createState() => _MemberImportPanelState();
}

class _MemberImportPanelState extends State<MemberImportPanel> {
  PlatformFile? _file;
  MemberImportReport? _previewReport;
  MemberImportReport? _finalReport;
  bool _updateExisting = false;
  bool _loading = false;
  String? _error;

  List<int>? get _fileBytes => _file?.bytes;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    final selected = result?.files.single;
    if (selected == null) return;

    setState(() {
      _file = selected;
      _previewReport = null;
      _finalReport = null;
      _error = null;
    });
  }

  Future<void> _loadTemplate() async {
    await _run(() async {
      final content = await widget.membersService.downloadImportTemplate();
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modele CSV copie dans le presse-papiers.'),
        ),
      );
    });
  }

  Future<void> _preview() async {
    final bytes = _fileBytes;
    if (_file == null || bytes == null) {
      setState(() => _error = 'Aucun fichier selectionne.');
      return;
    }

    await _run(() async {
      final report = await widget.membersService.previewImport(
        bytes: bytes,
        fileName: _file!.name,
        updateExisting: _updateExisting,
      );
      if (!mounted) return;
      setState(() {
        _previewReport = report;
        _finalReport = null;
      });
    });
  }

  Future<void> _apply() async {
    final bytes = _fileBytes;
    final report = _previewReport;
    if (_file == null || bytes == null || report == null || report.hasErrors) {
      setState(() {
        _error = 'Import impossible : corrigez les erreurs avant de continuer.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer definitivement ?'),
        content: Text(
          '${report.validRows} ligne(s) seront traitees. '
          'Cette action modifiera les comptes membres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      final finalReport = await widget.membersService.applyImport(
        bytes: bytes,
        fileName: _file!.name,
        updateExisting: _updateExisting,
      );
      if (!mounted) return;
      setState(() => _finalReport = finalReport);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _previewReport != null && !_previewReport!.hasErrors;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Import des membres',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ImportActions(
                fileName: _file?.name,
                loading: _loading,
                updateExisting: _updateExisting,
                onUpdateExistingChanged: (value) {
                  setState(() {
                    _updateExisting = value;
                    _previewReport = null;
                    _finalReport = null;
                  });
                },
                onTemplate: _loadTemplate,
                onPickFile: _pickFile,
                onPreview: _preview,
                onApply: canApply ? _apply : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  icon: Icons.error_outline_rounded,
                  color: Colors.red.shade700,
                  title: 'Action impossible',
                  messages: [_error!],
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
              if (_previewReport != null) ...[
                const SizedBox(height: 16),
                _ReportSection(
                  title: 'Apercu',
                  report: _previewReport!,
                  allowPreviewRows: true,
                ),
              ],
              if (_finalReport != null) ...[
                const SizedBox(height: 16),
                _ReportSection(
                  title: 'Rapport final',
                  report: _finalReport!,
                  allowPreviewRows: false,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ImportActions extends StatelessWidget {
  final String? fileName;
  final bool loading;
  final bool updateExisting;
  final ValueChanged<bool> onUpdateExistingChanged;
  final VoidCallback onTemplate;
  final VoidCallback onPickFile;
  final VoidCallback onPreview;
  final VoidCallback? onApply;

  const _ImportActions({
    required this.fileName,
    required this.loading,
    required this.updateExisting,
    required this.onUpdateExistingChanged,
    required this.onTemplate,
    required this.onPickFile,
    required this.onPreview,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName ?? 'Aucun fichier selectionne.',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: updateExisting,
              onChanged: loading ? null : onUpdateExistingChanged,
              title: const Text('Mettre a jour les comptes existants'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : onTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Modele CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : onPickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Choisir CSV'),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : onPreview,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Apercu'),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : onApply,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Importer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final MemberImportReport report;
  final bool allowPreviewRows;

  const _ReportSection({
    required this.title,
    required this.report,
    required this.allowPreviewRows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _SummaryGrid(report: report),
        if (report.hasErrors) ...[
          const SizedBox(height: 12),
          _MessageCard(
            icon: Icons.error_rounded,
            color: Colors.red.shade700,
            title: 'Erreurs',
            messages: report.errors.map((issue) => issue.label).toList(),
          ),
        ],
        if (report.hasWarnings) ...[
          const SizedBox(height: 12),
          _MessageCard(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            title: 'Avertissements',
            messages: report.warnings.map((issue) => issue.label).toList(),
          ),
        ],
        if (allowPreviewRows && report.preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...report.preview.take(8).map((item) => _PreviewMemberCard(item)),
        ],
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final MemberImportReport report;

  const _SummaryGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 760 ? 4 : 2;
    final items = [
      ('Lignes', report.totalRows, Icons.table_rows_rounded),
      ('Valides', report.validRows, Icons.check_circle_rounded),
      ('Erreurs', report.errorRows, Icons.error_rounded),
      ('Warnings', report.warningRows, Icons.warning_rounded),
      ('Doublons', report.duplicates, Icons.copy_rounded),
      ('Crees', report.createdUsers, Icons.person_add_alt_rounded),
      ('Maj', report.updatedUsers, Icons.manage_accounts_rounded),
      (
        'Affectations',
        report.poleLinks + report.projectLinks,
        Icons.hub_rounded,
      ),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.enactusYellow.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(item.$3, color: AppTheme.softBlack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${item.$2}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> messages;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...messages
                .take(12)
                .map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(message, overflow: TextOverflow.ellipsis),
                  ),
                ),
            if (messages.length > 12)
              Text('+${messages.length - 12} autre(s) element(s).'),
          ],
        ),
      ),
    );
  }
}

class _PreviewMemberCard extends StatelessWidget {
  final MemberImportPreviewItem item;

  const _PreviewMemberCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.softBlack,
          foregroundColor: AppTheme.enactusYellow,
          child: Text('${item.row}'),
        ),
        title: Text(item.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            item.email,
            item.corePole,
            item.project,
            item.roles.join(', '),
          ].where((value) => value != null && value.isNotEmpty).join(' - '),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
