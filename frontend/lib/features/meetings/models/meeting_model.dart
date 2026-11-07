class MeetingModel {
  final String id;
  final String roomKey;
  final String title;
  final String? description;
  final String status;
  final String scopeType;
  final String? scopeId;
  final String provider;
  final String serverUrl;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String createdBy;
  final bool startWithAudioMuted;
  final bool startWithVideoMuted;
  final bool lobbyEnabled;
  final bool recordingEnabled;
  final bool canManage;
  final bool canDelete;
  final String currentUserRole;
  final int invitedCount;
  final int joinedCount;
  final DateTime? createdAt;

  const MeetingModel({
    required this.id,
    required this.roomKey,
    required this.title,
    required this.description,
    required this.status,
    required this.scopeType,
    required this.scopeId,
    required this.provider,
    required this.serverUrl,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.startedAt,
    required this.endedAt,
    required this.createdBy,
    required this.startWithAudioMuted,
    required this.startWithVideoMuted,
    required this.lobbyEnabled,
    required this.recordingEnabled,
    required this.canManage,
    required this.canDelete,
    required this.currentUserRole,
    required this.invitedCount,
    required this.joinedCount,
    required this.createdAt,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id']?.toString() ?? '',
      roomKey: json['room_key']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Réunion EnactMeet',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'scheduled',
      scopeType: json['scope_type']?.toString() ?? 'custom',
      scopeId: json['scope_id']?.toString(),
      provider: json['provider']?.toString() ?? 'jitsi',
      serverUrl: json['server_url']?.toString() ?? '',
      scheduledStart: _date(json['scheduled_start']),
      scheduledEnd: _date(json['scheduled_end']),
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      createdBy: json['created_by']?.toString() ?? '',
      startWithAudioMuted: json['start_with_audio_muted'] != false,
      startWithVideoMuted: json['start_with_video_muted'] != false,
      lobbyEnabled: json['lobby_enabled'] != false,
      recordingEnabled: json['recording_enabled'] == true,
      canManage: json['can_manage'] == true,
      canDelete: json['can_delete'] == true,
      currentUserRole: json['current_user_role']?.toString() ?? 'participant',
      invitedCount: int.tryParse(json['invited_count']?.toString() ?? '') ?? 0,
      joinedCount: int.tryParse(json['joined_count']?.toString() ?? '') ?? 0,
      createdAt: _date(json['created_at']),
    );
  }

  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isClosed => status == 'ended' || status == 'cancelled';

  String get statusLabel => switch (status) {
    'live' => 'En direct',
    'ended' => 'Terminée',
    'cancelled' => 'Annulée',
    _ => 'Planifiée',
  };

  String get scopeLabel => switch (scopeType) {
    'club' => 'Tout le club',
    'pole' => 'Pôle',
    'project' => 'Projet',
    _ => 'Sur invitation',
  };

  String get scheduleLabel {
    final start = scheduledStart?.toLocal();
    if (start == null) {
      return isLive ? 'En direct maintenant' : 'Démarrage libre';
    }
    final day = start.day.toString().padLeft(2, '0');
    final month = start.month.toString().padLeft(2, '0');
    final hour = start.hour.toString().padLeft(2, '0');
    final minute = start.minute.toString().padLeft(2, '0');
    return '$day/$month/${start.year} · $hour:$minute';
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class MeetingMemberModel {
  final String userId;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String role;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  const MeetingMemberModel({
    required this.userId,
    required this.displayName,
    this.firstName,
    this.lastName,
    required this.role,
    required this.joinedAt,
    required this.leftAt,
  });

  factory MeetingMemberModel.fromJson(Map<String, dynamic> json) {
    return MeetingMemberModel(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Membre',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      role: json['role']?.toString() ?? 'participant',
      joinedAt: _date(json['joined_at']),
      leftAt: _date(json['left_at']),
    );
  }

  static int compareAlphabetically(
    MeetingMemberModel left,
    MeetingMemberModel right,
  ) {
    final lastCompare =
        _meetingAlphabeticKey(
          left.lastName?.trim().isNotEmpty == true
              ? left.lastName!
              : _meetingFallbackLastName(left.displayName),
        ).compareTo(
          _meetingAlphabeticKey(
            right.lastName?.trim().isNotEmpty == true
                ? right.lastName!
                : _meetingFallbackLastName(right.displayName),
          ),
        );
    if (lastCompare != 0) return lastCompare;

    final firstCompare =
        _meetingAlphabeticKey(
          left.firstName?.trim().isNotEmpty == true
              ? left.firstName!
              : _meetingFallbackFirstName(left.displayName),
        ).compareTo(
          _meetingAlphabeticKey(
            right.firstName?.trim().isNotEmpty == true
                ? right.firstName!
                : _meetingFallbackFirstName(right.displayName),
          ),
        );
    if (firstCompare != 0) return firstCompare;
    return _meetingAlphabeticKey(
      left.displayName,
    ).compareTo(_meetingAlphabeticKey(right.displayName));
  }

  bool get isConnected => joinedAt != null && leftAt == null;
  String get roleLabel => switch (role) {
    'host' => 'Hôte',
    'cohost' => 'Co-hôte',
    _ => 'Participant',
  };
}

String _meetingFallbackLastName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  return parts.last;
}

String _meetingFallbackFirstName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.length <= 1) return displayName.trim();
  return parts.sublist(0, parts.length - 1).join(' ');
}

String _meetingAlphabeticKey(String value) {
  var result = value.trim().toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'õ': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  replacements.forEach((source, target) {
    result = result.replaceAll(source, target);
  });
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

class MeetingJoinModel {
  final String meetingId;
  final String roomKey;
  final String serverUrl;
  final String? jwt;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool moderator;
  final bool startWithAudioMuted;
  final bool startWithVideoMuted;
  final bool lobbyEnabled;
  final bool recordingEnabled;

  const MeetingJoinModel({
    required this.meetingId,
    required this.roomKey,
    required this.serverUrl,
    required this.jwt,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.moderator,
    required this.startWithAudioMuted,
    required this.startWithVideoMuted,
    required this.lobbyEnabled,
    required this.recordingEnabled,
  });

  factory MeetingJoinModel.fromJson(Map<String, dynamic> json) {
    return MeetingJoinModel(
      meetingId: json['meeting_id']?.toString() ?? '',
      roomKey: json['room_key']?.toString() ?? '',
      serverUrl: json['server_url']?.toString() ?? '',
      jwt: json['jwt']?.toString(),
      displayName: json['display_name']?.toString() ?? 'EnactSpace',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      moderator: json['moderator'] == true,
      startWithAudioMuted: json['start_with_audio_muted'] != false,
      startWithVideoMuted: json['start_with_video_muted'] != false,
      lobbyEnabled: json['lobby_enabled'] != false,
      recordingEnabled: json['recording_enabled'] == true,
    );
  }

  Uri get webUri {
    final base = Uri.parse(serverUrl);
    return base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/$roomKey',
      queryParameters: {if (jwt?.isNotEmpty == true) 'jwt': jwt!},
    );
  }
}
