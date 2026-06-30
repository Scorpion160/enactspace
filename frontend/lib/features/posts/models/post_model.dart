import '../../../core/api/api_client.dart';

class PostModel {
  final String id;
  final String authorId;
  final String? title;
  final String content;
  final String postType;
  final String? poleId;
  final String? projectId;
  final String? eventId;
  final String? documentId;
  final String? mediaFileId;
  final String? mediaUrl;
  final String? mediaName;
  final String? mediaMimeType;
  final int? mediaSizeBytes;
  final bool isOfficial;
  final bool isPinned;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.postType,
    required this.poleId,
    required this.projectId,
    required this.eventId,
    required this.documentId,
    required this.mediaFileId,
    required this.mediaUrl,
    required this.mediaName,
    required this.mediaMimeType,
    required this.mediaSizeBytes,
    required this.isOfficial,
    required this.isPinned,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      title: json['title']?.toString(),
      content: json['content']?.toString() ?? '',
      postType: json['post_type']?.toString() ?? 'general',
      poleId: json['pole_id']?.toString(),
      projectId: json['project_id']?.toString(),
      eventId: json['event_id']?.toString(),
      documentId: json['document_id']?.toString(),
      mediaFileId: json['media_file_id']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      mediaName: json['media_name']?.toString(),
      mediaMimeType: json['media_mime_type']?.toString(),
      mediaSizeBytes: int.tryParse(json['media_size_bytes']?.toString() ?? ''),
      isOfficial: json['is_official'] == true,
      isPinned: json['is_pinned'] == true,
      visibility: json['visibility']?.toString() ?? 'internal',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    return postTypeLabel;
  }

  String get postTypeLabel {
    switch (postType) {
      case 'announcement':
        return 'Annonce';
      case 'pole':
        return 'Pôle';
      case 'project':
        return 'Projet';
      case 'event':
        return 'Événement';
      case 'document':
        return 'Document';
      case 'opportunity':
        return 'Opportunité';
      case 'formation':
        return 'Formation';
      case 'alumni':
        return 'Alumni';
      default:
        return 'Général';
    }
  }

  String get visibilityLabel {
    switch (visibility) {
      case 'public_club':
        return 'Club';
      case 'pole_only':
        return 'Pôle';
      case 'project_only':
        return 'Projet';
      case 'enacchef_only':
        return 'Bureau';
      case 'alumni_only':
        return 'Alumni';
      case 'private':
        return 'Privé';
      default:
        return 'Interne';
    }
  }

  bool get hasMedia => mediaUrl != null && mediaUrl!.trim().isNotEmpty;

  bool get mediaIsImage =>
      (mediaMimeType ?? '').toLowerCase().startsWith('image/');

  String? get absoluteMediaUrl {
    final url = mediaUrl;
    if (url == null || url.trim().isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${ApiClient.serverUrl}$url';
  }
}

class PostUploadedMediaModel {
  final String fileId;
  final String url;
  final String fileName;
  final String? contentType;
  final int sizeBytes;

  const PostUploadedMediaModel({
    required this.fileId,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  factory PostUploadedMediaModel.fromJson(Map<String, dynamic> json) {
    return PostUploadedMediaModel(
      fileId: json['file_id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      contentType: json['content_type']?.toString(),
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
    );
  }
}
