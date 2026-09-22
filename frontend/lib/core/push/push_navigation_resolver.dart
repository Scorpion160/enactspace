class PushNavigationResolver {
  const PushNavigationResolver._();

  static String resolve({
    required String type,
    String? relatedType,
    String? relatedId,
  }) {
    final normalizedType = type.toLowerCase();
    final source = (relatedType?.isNotEmpty == true ? relatedType! : type)
        .toLowerCase();
    final id = relatedId?.trim();
    if (normalizedType == 'chat_message' && id?.isNotEmpty == true) {
      return '/chat?thread=${Uri.encodeComponent(id!)}';
    }
    if (source.contains('task')) {
      return id?.isNotEmpty == true ? '/tasks/$id' : '/tasks';
    }
    if (source.contains('attendance') ||
        source.contains('presence') ||
        source.contains('absence')) {
      return '/attendance';
    }
    if (source.contains('payment') ||
        source.contains('finance') ||
        source.contains('fee')) {
      return '/finance';
    }
    if (source.contains('document')) {
      return id?.isNotEmpty == true ? '/documents/$id' : '/documents';
    }
    if (source.contains('recruitment') || source.contains('application')) {
      return '/recruitment';
    }
    if (source.contains('post') ||
        source.contains('communication') ||
        source.contains('announcement')) {
      return '/posts';
    }
    if (source.contains('chat') || source.contains('message')) {
      return '/chat';
    }
    if (source.contains('event')) {
      return id?.isNotEmpty == true ? '/events/$id' : '/events';
    }
    if (source.contains('project')) {
      return id?.isNotEmpty == true ? '/projects/$id' : '/projects';
    }
    if (source.contains('pole')) {
      return id?.isNotEmpty == true ? '/poles/$id' : '/poles';
    }
    return '/notifications';
  }

  static String fromData(Map<String, String> data) => resolve(
    type: data['type'] ?? 'general',
    relatedType: data['related_type'],
    relatedId: data['related_id'],
  );
}
