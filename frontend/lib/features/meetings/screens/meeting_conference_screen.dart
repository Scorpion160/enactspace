import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../models/meeting_model.dart';
import '../services/meeting_web_frame.dart';
import '../services/meetings_service.dart';

class MeetingConferenceScreen extends StatefulWidget {
  final String meetingId;
  final String? title;
  final MeetingsService? service;

  const MeetingConferenceScreen({
    super.key,
    required this.meetingId,
    this.title,
    this.service,
  });

  @override
  State<MeetingConferenceScreen> createState() =>
      _MeetingConferenceScreenState();
}

class _MeetingConferenceScreenState extends State<MeetingConferenceScreen> {
  late final MeetingsService _service;
  final JitsiMeet _jitsi = JitsiMeet();
  MeetingJoinModel? _join;
  String? _error;
  bool _loading = true;
  bool _nativeClosed = false;
  bool _enteredReported = false;
  bool _leaveReported = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MeetingsService();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final join = await _service.joinMeeting(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _join = join;
        _loading = false;
      });
      if (!kIsWeb) {
        await _openNative(join);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  Future<void> _openNative(MeetingJoinModel join) async {
    final options = JitsiMeetConferenceOptions(
      serverURL: join.serverUrl,
      room: join.roomKey,
      token: join.jwt,
      configOverrides: {
        'subject': widget.title ?? 'EnactMeet',
        'startWithAudioMuted': join.startWithAudioMuted,
        'startWithVideoMuted': join.startWithVideoMuted,
        'disableDeepLinking': true,
        'disableInviteFunctions': true,
        'requireDisplayName': true,
        'prejoinConfig': {'enabled': true, 'hideDisplayName': true},
        'lobby': {'autoKnock': true, 'enableChat': true},
      },
      featureFlags: {
        FeatureFlags.welcomePageEnabled: false,
        FeatureFlags.preJoinPageEnabled: true,
        FeatureFlags.preJoinPageHideDisplayName: true,
        FeatureFlags.unsafeRoomWarningEnabled: false,
        FeatureFlags.resolution: FeatureFlagVideoResolutions.resolution720p,
        FeatureFlags.audioMuteButtonEnabled: true,
        FeatureFlags.audioOnlyButtonEnabled: true,
        FeatureFlags.videoMuteEnabled: true,
        FeatureFlags.videoShareEnabled: true,
        FeatureFlags.chatEnabled: true,
        FeatureFlags.raiseHandEnabled: true,
        FeatureFlags.reactionsEnabled: true,
        FeatureFlags.breakoutRoomsEnabled: true,
        FeatureFlags.tileViewEnabled: true,
        FeatureFlags.filmstripEnabled: true,
        FeatureFlags.fullScreenEnabled: true,
        FeatureFlags.settingsEnabled: true,
        FeatureFlags.androidScreenSharingEnabled: true,
        FeatureFlags.speakerStatsEnabled: true,
        FeatureFlags.kickOutEnabled: join.moderator,
        FeatureFlags.lobbyModeEnabled: join.lobbyEnabled,
        FeatureFlags.securityOptionEnabled: join.moderator,
        FeatureFlags.meetingPasswordEnabled: join.moderator,
        FeatureFlags.meetingNameEnabled: true,
        FeatureFlags.notificationEnabled: true,
        FeatureFlags.overflowMenuEnabled: true,
        FeatureFlags.pipEnabled: true,
        FeatureFlags.pipWhileScreenSharingEnabled: true,
        FeatureFlags.closeCaptionsEnabled: false,
        FeatureFlags.conferenceTimerEnabled: true,
        FeatureFlags.inviteEnabled: false,
        FeatureFlags.addPeopleEnabled: false,
        FeatureFlags.recordingEnabled: join.recordingEnabled,
        FeatureFlags.liveStreamingEnabled: false,
        FeatureFlags.serverUrlChangeEnabled: false,
        FeatureFlags.toolboxEnabled: true,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: join.displayName,
        email: join.email,
        avatar: join.avatarUrl,
      ),
    );

    final listener = JitsiMeetEventListener(
      conferenceJoined: (_) {
        unawaited(_reportEntered());
        unawaited(_jitsi.retrieveParticipantsInfo());
      },
      conferenceTerminated: (_, error) {
        unawaited(_handleNativeClosed(error));
      },
      readyToClose: () {
        unawaited(_handleNativeClosed(null));
      },
      participantJoined: (_, _, _, _) {
        unawaited(_jitsi.retrieveParticipantsInfo());
      },
      participantLeft: (_) {
        unawaited(_jitsi.retrieveParticipantsInfo());
      },
    );

    final result = await _jitsi.join(options, listener);
    if (!result.isSuccess && mounted) {
      setState(() {
        _error =
            result.message ??
            result.error?.toString() ??
            'Impossible d’ouvrir EnactMeet.';
      });
      await _reportLeave();
    }
  }

  Future<void> _handleNativeClosed(Object? error) async {
    await _reportLeave();
    if (!mounted) return;
    setState(() {
      _nativeClosed = true;
      if (error != null) _error = error.toString();
    });
  }

  Future<void> _reportEntered() async {
    if (_enteredReported) return;
    _enteredReported = true;
    try {
      await _service.enterMeeting(widget.meetingId);
    } catch (_) {
      _enteredReported = false;
    }
  }

  Future<void> _reportLeave() async {
    if (_leaveReported || !_enteredReported) return;
    _leaveReported = true;
    try {
      await _service.leaveMeeting(widget.meetingId);
    } catch (_) {
      _leaveReported = false;
    }
  }

  Future<void> _leaveWeb() async {
    await _reportLeave();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/meetings/${widget.meetingId}');
    }
  }

  void _handleWebError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    unawaited(_reportLeave());
  }

  @override
  void dispose() {
    if (!kIsWeb && _join != null && !_nativeClosed) {
      unawaited(_jitsi.hangUp());
    }
    if (_join != null && !_leaveReported) unawaited(_reportLeave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _join == null) {
      return _FailureState(
        message: _error!,
        onBack: () => context.go('/meetings/${widget.meetingId}'),
      );
    }

    final join = _join!;
    if (kIsWeb) {
      return ColoredBox(
        color: const Color(0xFF101418),
        child: SafeArea(
          child: Column(
            children: [
              _ConferenceHeader(
                title: widget.title ?? 'EnactMeet',
                moderator: join.moderator,
                onLeave: _leaveWeb,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: MeetingWebFrame(
                    join: join,
                    title: widget.title,
                    onConferenceJoined: () => unawaited(_reportEntered()),
                    onConferenceLeft: () => unawaited(_leaveWeb()),
                    onError: _handleWebError,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _nativeClosed
                    ? Icons.check_circle_rounded
                    : Icons.video_call_rounded,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _nativeClosed ? 'Réunion quittée' : 'EnactMeet est ouvert',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error ??
                    (_nativeClosed
                        ? 'Votre sortie a été synchronisée avec EnactSpace.'
                        : 'La visioconférence utilise la fenêtre sécurisée Jitsi intégrée à EnactSpace.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/meetings/${widget.meetingId}'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Retour à la réunion'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}

class _ConferenceHeader extends StatelessWidget {
  final String title;
  final bool moderator;
  final Future<void> Function() onLeave;

  const _ConferenceHeader({
    required this.title,
    required this.moderator,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.video_call_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (moderator)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Hôte',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => onLeave(),
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('Quitter'),
          ),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _FailureState({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_call_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Impossible d’ouvrir EnactMeet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
