import 'post_model.dart';

class PostUpdateModel {
  final Map<String, dynamic> _fields;

  PostUpdateModel._(this._fields);

  factory PostUpdateModel.fromChanges({
    required PostModel original,
    required String? title,
    required String content,
    required String postType,
    required String visibility,
    bool? isOfficial,
    String? replacementMediaFileId,
  }) {
    final normalizedTitle = _nullable(title);
    final normalizedOriginalTitle = _nullable(original.title);
    final normalizedContent = content.trim();
    final fields = <String, dynamic>{};

    if (normalizedTitle != normalizedOriginalTitle) {
      fields['title'] = normalizedTitle;
    }
    if (normalizedContent != original.content) {
      fields['content'] = normalizedContent;
    }
    if (postType != original.postType) {
      fields['post_type'] = postType;
    }
    if (visibility != original.visibility) {
      fields['visibility'] = visibility;
    }
    if (isOfficial != null && isOfficial != original.isOfficial) {
      fields['is_official'] = isOfficial;
    }
    if (replacementMediaFileId != null &&
        replacementMediaFileId.trim().isNotEmpty) {
      fields['media_file_id'] = replacementMediaFileId.trim();
    }

    return PostUpdateModel._(Map.unmodifiable(fields));
  }

  bool get isEmpty => _fields.isEmpty;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_fields);

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
