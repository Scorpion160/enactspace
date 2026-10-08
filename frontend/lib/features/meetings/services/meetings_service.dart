import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../models/meeting_model.dart';

class MeetingsService {
  final ApiClient _api;
  final AuthService _auth;

  MeetingsService({ApiClient? apiClient, AuthService? authService})
    : _api = apiClient ?? ApiClient(),
      _auth = authService ?? AuthService();

  Future<String> _token() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Utilisateur non connecté.');
    }
    return token;
  }

  Future<List<MeetingModel>> listMeetings() async {
    final response = await _api.get('/meetings', token: await _token());
    return _list(response).map(MeetingModel.fromJson).toList();
  }

  Future<MeetingModel> getMeeting(String meetingId) async {
    final response = await _api.get(
      '/meetings/$meetingId',
      token: await _token(),
    );
    return MeetingModel.fromJson(_map(response));
  }

  Future<MeetingModel> createMeeting({
    required String title,
    String? description,
    String scopeType = 'custom',
    String? scopeId,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    List<String> inviteUserIds = const [],
    bool startWithAudioMuted = true,
    bool startWithVideoMuted = true,
    bool lobbyEnabled = true,
  }) async {
    final response = await _api.postJson(
      '/meetings',
      token: await _token(),
      data: {
        'title': title.trim(),
        'description': _nullable(description),
        'scope_type': scopeType,
        'scope_id': scopeId,
        'scheduled_start': scheduledStart?.toUtc().toIso8601String(),
        'scheduled_end': scheduledEnd?.toUtc().toIso8601String(),
        'invite_user_ids': inviteUserIds,
        'start_with_audio_muted': startWithAudioMuted,
        'start_with_video_muted': startWithVideoMuted,
        'lobby_enabled': lobbyEnabled,
      },
    );
    return MeetingModel.fromJson(_map(response));
  }

  Future<MeetingModel> updateMeeting(
    String meetingId, {
    String? title,
    String? description,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    bool clearScheduledStart = false,
    bool clearScheduledEnd = false,
    bool? startWithAudioMuted,
    bool? startWithVideoMuted,
    bool? lobbyEnabled,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title.trim();
    if (description != null) data['description'] = _nullable(description);
    if (clearScheduledStart) {
      data['scheduled_start'] = null;
    } else if (scheduledStart != null) {
      data['scheduled_start'] = scheduledStart.toUtc().toIso8601String();
    }
    if (clearScheduledEnd) {
      data['scheduled_end'] = null;
    } else if (scheduledEnd != null) {
      data['scheduled_end'] = scheduledEnd.toUtc().toIso8601String();
    }
    if (startWithAudioMuted != null) {
      data['start_with_audio_muted'] = startWithAudioMuted;
    }
    if (startWithVideoMuted != null) {
      data['start_with_video_muted'] = startWithVideoMuted;
    }
    if (lobbyEnabled != null) data['lobby_enabled'] = lobbyEnabled;
    final response = await _api.patchJson(
      '/meetings/$meetingId',
      token: await _token(),
      data: data,
    );
    return MeetingModel.fromJson(_map(response));
  }

  Future<List<MeetingMemberModel>> listMembers(String meetingId) async {
    final response = await _api.get(
      '/meetings/$meetingId/members',
      token: await _token(),
    );
    final members = _list(response).map(MeetingMemberModel.fromJson).toList();
    members.sort(MeetingMemberModel.compareAlphabetically);
    return members;
  }

  Future<List<MeetingMemberModel>> inviteMembers(
    String meetingId,
    List<String> userIds, {
    String role = 'participant',
  }) async {
    final response = await _api.postJson(
      '/meetings/$meetingId/invite',
      token: await _token(),
      data: {'user_ids': userIds, 'role': role},
    );
    final members = _list(response).map(MeetingMemberModel.fromJson).toList();
    members.sort(MeetingMemberModel.compareAlphabetically);
    return members;
  }

  Future<MeetingJoinModel> joinMeeting(String meetingId) async {
    final response = await _api.postJson(
      '/meetings/$meetingId/join',
      token: await _token(),
      data: const {},
    );
    return MeetingJoinModel.fromJson(_map(response));
  }

  Future<void> enterMeeting(String meetingId) async {
    await _api.postJson(
      '/meetings/$meetingId/entered',
      token: await _token(),
      data: const {},
    );
  }

  Future<void> leaveMeeting(String meetingId) async {
    await _api.postJson(
      '/meetings/$meetingId/leave',
      token: await _token(),
      data: const {},
    );
  }

  Future<MeetingModel> endMeeting(String meetingId) async {
    final response = await _api.postJson(
      '/meetings/$meetingId/end',
      token: await _token(),
      data: const {},
    );
    return MeetingModel.fromJson(_map(response));
  }

  Future<MeetingModel> cancelMeeting(String meetingId) async {
    final response = await _api.postJson(
      '/meetings/$meetingId/cancel',
      token: await _token(),
      data: const {},
    );
    return MeetingModel.fromJson(_map(response));
  }

  Future<void> deleteMeeting(String meetingId) async {
    await _api.delete('/meetings/$meetingId', token: await _token());
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    if (value is Map && value['items'] is List) {
      return (value['items'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (value is Map && value['data'] is List) {
      return (value['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('Réponse EnactMeet invalide.');
  }

  String? _nullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
