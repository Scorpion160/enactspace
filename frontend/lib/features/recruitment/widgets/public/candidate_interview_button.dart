import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../meetings/models/meeting_model.dart';
import '../../../meetings/screens/meeting_conference_screen.dart';
import '../../services/recruitment_message.dart';

class CandidateInterviewButton extends StatefulWidget {
  final String code;
  final String email;
  const CandidateInterviewButton({super.key, required this.code, required this.email});
  @override
  State<CandidateInterviewButton> createState() => _CandidateInterviewButtonState();
}

class _CandidateInterviewButtonState extends State<CandidateInterviewButton> {
  bool _busy = false;
  String? _error;
  Future<void> _join() async {
    setState(() { _busy = true; _error = null; });
    try {
      final data = await ApiClient().postJson('/recruitment/applications/interview/join',
        data: {'application_id': widget.code, 'email': widget.email});
      final join = MeetingJoinModel.fromJson(Map<String, dynamic>.from(data as Map));
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        MeetingConferenceScreen(meetingId: join.meetingId, title: 'Ton entretien avec Enactus ESP', guestJoin: join)));
    } catch (error) {
      if (mounted) setState(() => _error = recruitmentMessage(error, fallback: 'L’entretien n’a pas pu être ouvert. Réessaie dans quelques instants.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ton entretien sur EnactMeet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Tu peux rejoindre la salle quinze minutes avant ton rendez-vous, une fois le jury connecté. Prépare ton micro et ta caméra.'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _join, icon: const Icon(Icons.video_call_outlined),
          label: Text(_busy ? 'Ouverture…' : 'Rejoindre mon entretien')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ],
    ))),
  );
}
