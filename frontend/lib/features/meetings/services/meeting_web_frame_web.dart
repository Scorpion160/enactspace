import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../models/meeting_model.dart';

@JS('enactMeetCreate')
external JSPromise<JSAny?> _enactMeetCreate(
  JSString id,
  JSString serverUrl,
  JSString optionsJson,
);

@JS('enactMeetDispose')
external void _enactMeetDispose(JSString id);

@JS('enactMeetTakeEvents')
external JSString _enactMeetTakeEvents(JSString id);

class MeetingWebFrame extends StatefulWidget {
  final MeetingJoinModel join;
  final String? title;
  final VoidCallback? onConferenceJoined;
  final VoidCallback? onConferenceLeft;
  final ValueChanged<String>? onError;

  const MeetingWebFrame({
    super.key,
    required this.join,
    this.title,
    this.onConferenceJoined,
    this.onConferenceLeft,
    this.onError,
  });

  @override
  State<MeetingWebFrame> createState() => _MeetingWebFrameState();
}

class _MeetingWebFrameState extends State<MeetingWebFrame> {
  late final String _viewType;
  late final String _containerId;
  Timer? _eventTimer;
  bool _leftEmitted = false;

  @override
  void initState() {
    super.initState();
    final suffix = '${widget.join.meetingId}-${identityHashCode(this)}';
    _viewType = 'enactmeet-view-$suffix';
    _containerId = 'enactmeet-host-$suffix';
    _registerHost();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  void _registerHost() {
    final host = web.HTMLDivElement()
      ..id = _containerId
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => host,
    );
  }

  Future<void> _start() async {
    final payload = jsonEncode({
      'roomName': widget.join.roomKey,
      'jwt': widget.join.jwt,
      'displayName': widget.join.displayName,
      'email': widget.join.email,
      'avatarUrl': widget.join.avatarUrl,
      'subject': widget.title ?? 'EnactMeet',
      'startWithAudioMuted': widget.join.startWithAudioMuted,
      'startWithVideoMuted': widget.join.startWithVideoMuted,
      'lobbyEnabled': widget.join.lobbyEnabled,
    });
    try {
      await _enactMeetCreate(
        _containerId.toJS,
        widget.join.serverUrl.toJS,
        payload.toJS,
      ).toDart;
      _eventTimer = Timer.periodic(
        const Duration(milliseconds: 400),
        (_) => _pollEvents(),
      );
    } catch (error) {
      widget.onError?.call(_cleanError(error));
    }
  }

  void _pollEvents() {
    if (!mounted) return;
    try {
      final raw = _enactMeetTakeEvents(_containerId.toJS).toDart;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded.whereType<Map>()) {
        final event = Map<String, dynamic>.from(item);
        switch (event['type']?.toString()) {
          case 'joined':
            widget.onConferenceJoined?.call();
            break;
          case 'left':
          case 'readyToClose':
            if (!_leftEmitted) {
              _leftEmitted = true;
              widget.onConferenceLeft?.call();
            }
            break;
          case 'error':
            widget.onError?.call(
              event['message']?.toString() ?? 'Erreur EnactMeet web.',
            );
            break;
        }
      }
    } catch (error) {
      widget.onError?.call(_cleanError(error));
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  @override
  void dispose() {
    _eventTimer?.cancel();
    try {
      _enactMeetDispose(_containerId.toJS);
    } catch (_) {
      // The JS host may already be gone during browser navigation.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
