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
    if (source == 'support_ticket_management' ||
        source == 'product_feedback_management') {
      return '/help/manage';
    }
    if (source == 'support_ticket' ||
        source == 'product_feedback' ||
        normalizedType == 'support') {
      return '/help';
    }
    if (normalizedType == 'chat_message' && id?.isNotEmpty == true) {
      return '/chat?thread=${Uri.encodeComponent(id!)}';
    }
    if (source.startsWith('veille_')) {
      final kind = source.substring('veille_'.length);
      if ({
            'task',
            'plan',
            'blocker',
            'report',
            'leave',
            'case',
          }.contains(kind) &&
          id?.isNotEmpty == true) {
        return '/veille/records/$kind/${Uri.encodeComponent(id!)}';
      }
      return '/veille';
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
    if (source.contains('meeting') || source.contains('meet')) {
      return id?.isNotEmpty == true ? '/meetings/$id' : '/meetings';
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
