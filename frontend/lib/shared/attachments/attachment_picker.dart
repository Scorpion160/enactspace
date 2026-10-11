import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_service.dart';

class SelectedAttachment {
  final String name;
  final Uint8List bytes;
  const SelectedAttachment({required this.name, required this.bytes});
}

Future<SelectedAttachment?> pickAttachment({bool application = false}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: application
        ? ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'docx', 'odt']
        : [
            'pdf',
            'png',
            'jpg',
            'jpeg',
            'webp',
            'docx',
            'odt',
            'txt',
            'csv',
            'xlsx',
            'pptx',
            'ods',
            'odp',
            'zip',
          ],
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final limit = (application ? 10 : 20) * 1024 * 1024;
  if (file.size > limit) {
    throw Exception(
      'Le fichier dépasse la limite de ${application ? 10 : 20} Mo.',
    );
  }
  if (file.bytes == null || file.bytes!.isEmpty) {
    throw Exception('Ce fichier ne peut pas être lu. Choisissez-le à nouveau.');
  }
  return SelectedAttachment(name: file.name, bytes: file.bytes!);
}

class AttachmentPickerField extends StatelessWidget {
  final String label;
  final SelectedAttachment? value;
  final ValueChanged<SelectedAttachment?> onChanged;
  final bool enabled;
  final bool application;
  const AttachmentPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.application = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (value != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${value!.name} · ${(value!.bytes.length / 1024).ceil()} Ko',
                  style: const TextStyle(height: 1.5),
                ),
              ),
              IconButton(
                tooltip: 'Retirer le fichier',
                onPressed: enabled ? () => onChanged(null) : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              value == null ? 'Joindre un fichier' : 'Choisir un autre fichier',
            ),
            onPressed: !enabled
                ? null
                : () async {
                    try {
                      final picked = await pickAttachment(
                        application: application,
                      );
                      if (context.mounted && picked != null) onChanged(picked);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
          ),
        ),
        Text(
          application
              ? 'PDF, document ou image · 10 Mo maximum · facultatif'
              : 'Document ou image · 20 Mo maximum',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    ),
  );
}

class AttachmentService {
  final ApiClient api;
  final AuthService auth;
  AttachmentService({ApiClient? apiClient, AuthService? authService})
    : api = apiClient ?? ApiClient(requestTimeout: const Duration(seconds: 90)),
      auth = authService ?? AuthService();

  Future<Map<String, dynamic>> upload(
    String path,
    SelectedAttachment file, {
    Map<String, String> fields = const {},
  }) async {
    final token = await auth.getToken();
    if (token == null) {
      throw Exception('Connectez-vous pour joindre un fichier.');
    }
    final result = await api.postMultipart(
      path,
      token: token,
      bytes: file.bytes,
      fileName: file.name,
      fields: fields,
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> uploadImpact(
    String id,
    SelectedAttachment file,
  ) => upload(
    '/files/upload',
    file,
    fields: {
      'storage_scope': 'impact',
      'entity_type': 'impact_record',
      'entity_id': id,
      'visibility': 'private',
      'is_temporary': 'false',
    },
  );
}

class StoredAttachmentButton extends StatefulWidget {
  final String url;
  final String? fileName;
  final String? label;
  const StoredAttachmentButton({
    super.key,
    required this.url,
    this.fileName,
    this.label,
  });
  @override
  State<StoredAttachmentButton> createState() => _StoredAttachmentButtonState();
}

class _StoredAttachmentButtonState extends State<StoredAttachmentButton> {
  bool _busy = false;
  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final uri = Uri.parse(ApiClient.serverUrl).resolve(widget.url);
      if (!{'http', 'https'}.contains(uri.scheme)) {
        throw Exception('Le fichier ne peut pas être ouvert.');
      }
      if (uri.origin != Uri.parse(ApiClient.serverUrl).origin) {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Le document ne peut pas être ouvert.');
        }
        return;
      }
      final token = await AuthService().getToken();
      if (token == null) {
        throw Exception('Reconnectez-vous pour consulter le document.');
      }
      final api = ApiClient(requestTimeout: const Duration(seconds: 90));
      var name = widget.fileName;
      if (uri.path.startsWith('/api/files/') &&
          uri.path.endsWith('/download')) {
        final metadata = await api.get(
          uri.path.replaceFirst('/api', '').replaceFirst('/download', ''),
          token: token,
        );
        name ??= (metadata as Map)['original_filename']?.toString();
      }
      name ??= uri.pathSegments.lastOrNull ?? 'document';
      final bytes = Uint8List.fromList(
        await api.getBytes(uri.toString(), token: token),
      );
      if (!mounted) return;
      final isImage =
          bytes.length > 12 &&
          (bytes[0] == 0x89 ||
              (bytes[0] == 0xff && bytes[1] == 0xd8) ||
              String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP');
      if (isImage) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(title: Text(name!)),
              body: InteractiveViewer(
                maxScale: 4,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
          ),
        );
      } else {
        await FilePicker.platform.saveFile(
          dialogTitle: 'Enregistrer le document',
          fileName: name,
          bytes: bytes,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _open,
    icon: const Icon(Icons.description_outlined),
    label: Text(
      _busy
          ? 'Ouverture…'
          : widget.label ?? widget.fileName ?? 'Ouvrir la pièce jointe',
    ),
  );
}
