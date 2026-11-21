import 'package:flutter/material.dart';

import '../models/meeting_model.dart';

class MeetingWebFrame extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text('EnactMeet web est réservé au navigateur.'),
    );
  }
}
