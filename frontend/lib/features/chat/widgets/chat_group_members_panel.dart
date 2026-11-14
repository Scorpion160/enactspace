import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/chat_gateway.dart';

/// Participant management for a group: always fetches the full membership,
/// not the six-person preview used in the conversation list.
class ChatGroupMembersPanel extends StatefulWidget {
  final ChatThreadModel thread;
  final ChatGateway gateway;
  final String? currentUserId;
  final Future<void> Function()? onAddMembers;
  final Future<void> Function() onChanged;

  const ChatGroupMembersPanel({
    super.key,
    required this.thread,
    required this.gateway,
    required this.currentUserId,
    required this.onChanged,
    this.onAddMembers,
  });

  @override
  State<ChatGroupMembersPanel> createState() => _ChatGroupMembersPanelState();
}

class _ChatGroupMembersPanelState extends State<ChatGroupMembersPanel> {
  late Future<List<ChatThreadMemberModel>> _participants;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _participants = widget.gateway.getParticipants(widget.thread.id);
  }

  @override
  void didUpdateWidget(ChatGroupMembersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread.id != widget.thread.id) {
      _refresh();
    }
  }

  void _refresh() {
    setState(() {
      _participants = widget.gateway.getParticipants(widget.thread.id);
    });
  }

  Future<void> _add() async {
    if (_working || widget.onAddMembers == null) return;
    setState(() => _working = true);
    try {
      await widget.onAddMembers!();
      if (mounted) _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _changeRole(ChatThreadMemberModel member, String role) async {
    if (_working) return;
    final promote = role == 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          promote ? 'Nommer administrateur ?' : 'Retirer les droits admin ?',
        ),
        content: Text(
          promote
              ? '${member.displayName} pourra ajouter ou retirer des participants et gérer les rôles.'
              : '${member.displayName} restera membre du groupe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(promote ? 'Nommer administrateur' : 'Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.gateway.updateParticipantRole(
        threadId: widget.thread.id,
        userId: member.userId,
        participantRole: role,
      );
      await widget.onChanged();
      if (mounted) _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove(ChatThreadMemberModel member) async {
    if (_working) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text(
          '${member.displayName} ne pourra plus accéder à ce groupe. '
          'Ses anciens messages resteront dans la discussion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer du groupe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.gateway.removeParticipant(
        threadId: widget.thread.id,
        userId: member.userId,
      );
      await widget.onChanged();
      if (mounted) _refresh();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<ChatThreadMemberModel>>(
      future: _participants,
      builder: (context, snapshot) {
        final members = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    members == null
                        ? 'Participants'
                        : 'Participants (${members.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.onAddMembers != null)
                  TextButton.icon(
                    key: const Key('chat-group-add-members'),
                    onPressed: _working ? null : _add,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Ajouter'),
                  ),
              ],
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Réessayer de charger les membres'),
              )
            else if (members == null || members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Aucun membre à afficher.'),
              )
            else
              for (final member in members)
                ListTile(
                  key: ValueKey('chat-group-member-${member.userId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Text(
                      member.displayName.isEmpty
                          ? '?'
                          : member.displayName.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    member.participantRole == 'member'
                        ? member.email
                        : '${member.participantRoleLabel} · ${member.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _memberActions(member),
                ),
          ],
        );
      },
    );
  }

  Widget? _memberActions(ChatThreadMemberModel member) {
    if (widget.thread.threadType == 'direct' ||
        !widget.thread.canManageMembers ||
        member.userId == widget.currentUserId ||
        member.participantRole == 'owner') {
      return null;
    }
    return PopupMenuButton<String>(
      key: ValueKey('chat-group-manage-${member.userId}'),
      tooltip: 'Gérer ${member.displayName}',
      enabled: !_working,
      onSelected: (value) {
        if (value == 'remove') {
          _remove(member);
        } else {
          _changeRole(member, value);
        }
      },
      itemBuilder: (context) => [
        if (member.participantRole == 'member')
          const PopupMenuItem(
            value: 'admin',
            child: Text('Nommer administrateur'),
          )
        else if (member.participantRole == 'admin')
          const PopupMenuItem(
            value: 'member',
            child: Text('Retirer le rôle admin'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'remove', child: Text('Retirer du groupe')),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }
}
