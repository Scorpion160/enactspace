import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/tags/tag.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/ui/app_components.dart';
import '../../members/models/member_model.dart';
import '../../members/services/members_service.dart';
import '../models/attendance_nfc_model.dart';
import '../services/attendance_service.dart';

class AttendanceNfcEnrollmentScreen extends StatefulWidget {
  const AttendanceNfcEnrollmentScreen({super.key});

  @override
  State<AttendanceNfcEnrollmentScreen> createState() =>
      _AttendanceNfcEnrollmentScreenState();
}

String _nfcFailureMessage(Object error) {
  final message = error.toString().replaceAll('Exception: ', '');
  final normalized = message.toLowerCase();
  if (normalized.contains('not supported') ||
      normalized.contains('windows') ||
      normalized.contains('unavailable')) {
    return 'NFC indisponible sur cet appareil. Utilisez un téléphone Android compatible pour gérer les badges.';
  }
  return message;
}

enum NfcMemberLoadState { ready, empty, failed }

NfcMemberLoadState nfcMemberLoadState({
  required List<MemberModel> members,
  String? error,
}) {
  if (error != null && error.trim().isNotEmpty) {
    return NfcMemberLoadState.failed;
  }
  return members.isEmpty ? NfcMemberLoadState.empty : NfcMemberLoadState.ready;
}

class _AttendanceNfcEnrollmentScreenState
    extends State<AttendanceNfcEnrollmentScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MembersService _membersService = MembersService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _nfcAvailable = false;
  bool _listening = false;
  String? _nfcError;
  String? _membersError;
  String? _tagsError;
  String? _operationError;
  MemberModel? _selectedMember;
  AttendanceNfcTagModel? _selectedTag;
  List<MemberModel> _members = [];
  List<AttendanceNfcTagModel> _tags = [];
  String _tagStatusFilter = 'active';

  String? get _error => _operationError ?? _nfcError ?? _tagsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_listening) {
      NfcManager.instance.stopSession();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _nfcError = null;
      _membersError = null;
      _tagsError = null;
      _operationError = null;
    });

    var nfcAvailable = false;
    List<MemberModel> members = const [];
    List<AttendanceNfcTagModel> tags = const [];
    String? nfcError;
    String? membersError;
    String? tagsError;

    try {
      final availability = await NfcManager.instance.checkAvailability();
      nfcAvailable = availability == NfcAvailability.enabled;
    } catch (e) {
      nfcError = _nfcFailureMessage(e);
    }

    try {
      members = await _membersService.getMembers();
    } catch (e) {
      membersError =
          'Impossible de charger les membres actifs. '
          '${e.toString().replaceAll('Exception: ', '')}';
    }

    try {
      tags = await _attendanceService.listNfcTags(status: _tagStatusFilter);
    } catch (e) {
      tagsError =
          'Impossible de charger les badges NFC. '
          '${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      if (mounted) {
        setState(() {
          _nfcAvailable = nfcAvailable;
          _nfcError = nfcError;
          _membersError = membersError;
          _tagsError = tagsError;
          _members = members
              .where(
                (member) =>
                    member.isActive != false && member.status == 'active',
              )
              .toList();
          _tags = tags;
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectMember(MemberModel member) async {
    setState(() {
      _selectedMember = member;
      _selectedTag = null;
      _operationError = null;
    });

    try {
      final tag = await _attendanceService.getMemberNfcTag(member.id);
      if (!mounted) return;
      setState(() {
        _selectedTag = tag;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _operationError = _nfcFailureMessage(e);
      });
    }
  }

  Future<void> _startEnrollment() async {
    final member = _selectedMember;
    if (member == null || _listening) return;

    if (!_nfcAvailable) {
      setState(() {
        _operationError = 'NFC indisponible sur cet appareil.';
      });
      return;
    }

    setState(() {
      _listening = true;
      _operationError = null;
    });

    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (tag) async {
        final payload = _tagPayload(tag);
        await NfcManager.instance.stopSession();
        if (!mounted) return;
        setState(() => _listening = false);
        await _enrollTagPayload(member, payload);
      },
    );
  }

  Future<void> _enrollTagPayload(MemberModel member, String payload) async {
    try {
      final tag = await _attendanceService.enrollNfcTag(
        memberId: member.id,
        tagPayload: payload,
      );
      if (!mounted) return;
      setState(() {
        _selectedTag = tag;
        _operationError = null;
      });
      await _refreshTags();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Badge associé avec succès.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _operationError = _nfcFailureMessage(e);
      });
    }
  }

  Future<void> _revokeSelectedTag() async {
    final tag = _selectedTag;
    if (tag == null) return;

    try {
      final revoked = await _attendanceService.revokeNfcTag(tagId: tag.id);
      if (!mounted) return;
      setState(() {
        _selectedTag = revoked;
        _operationError = null;
      });
      await _refreshTags();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Badge revoque.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _operationError = _nfcFailureMessage(e);
      });
    }
  }

  List<MemberModel> get _filteredMembers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _members;
    return _members.where((member) {
      return member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.rolesLabel.toLowerCase().contains(query) ||
          member.departmentLabel.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _refreshTags() async {
    final tags = await _attendanceService.listNfcTags(status: _tagStatusFilter);
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 860;

    return Scaffold(
      appBar: AppBar(title: const Text('Badges NFC')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.all(width < 560 ? 14 : 24),
                  children: [
                    _NfcHeader(
                      nfcAvailable: _nfcAvailable,
                      listening: _listening,
                    ),
                    const SizedBox(height: 18),
                    if (_error != null)
                      _NfcErrorCard(message: _error!, onRetry: _load),
                    if (_error != null) const SizedBox(height: 18),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildMemberPicker()),
                          const SizedBox(width: 18),
                          Expanded(child: _buildEnrollmentPanel()),
                        ],
                      )
                    else ...[
                      _buildMemberPicker(),
                      const SizedBox(height: 18),
                      _buildEnrollmentPanel(),
                    ],
                    const SizedBox(height: 18),
                    _NfcTagsList(
                      tags: _tags,
                      membersById: {
                        for (final member in _members) member.id: member,
                      },
                      statusFilter: _tagStatusFilter,
                      onStatusChanged: (value) async {
                        setState(() => _tagStatusFilter = value);
                        await _refreshTags();
                      },
                      onRevoke: (tag) async {
                        await _attendanceService.revokeNfcTag(tagId: tag.id);
                        await _refreshTags();
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMemberPicker() {
    final members = _filteredMembers;
    final memberLoadState = nfcMemberLoadState(
      members: _members,
      error: _membersError,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sélectionner un membre',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Recherche',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (memberLoadState == NfcMemberLoadState.failed)
              _NfcMembersLoadFailure(message: _membersError!, onRetry: _load)
            else if (memberLoadState == NfcMemberLoadState.empty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucun membre actif trouvé.'),
              )
            else if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucun résultat pour cette recherche.'),
              )
            else
              ...members
                  .take(30)
                  .map(
                    (member) => ListTile(
                      selected: _selectedMember?.id == member.id,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.enactusYellow,
                        foregroundColor: AppTheme.softBlack,
                        child: Text(_memberInitials(member)),
                      ),
                      title: Text(member.displayName),
                      subtitle: Text(member.departmentLabel),
                      onTap: () => _selectMember(member),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentPanel() {
    final member = _selectedMember;
    final tag = _selectedTag;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Association badge',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (member == null)
              const Text('Choisissez un membre pour associer un badge NFC.')
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.enactusYellow,
                  foregroundColor: AppTheme.softBlack,
                  child: Text(_memberInitials(member)),
                ),
                title: Text(member.displayName),
                subtitle: Text(member.email),
              ),
              const SizedBox(height: 10),
              _NfcTagStatus(tag: tag),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _nfcAvailable && !_listening
                    ? _startEnrollment
                    : null,
                icon: const Icon(Icons.nfc_rounded),
                label: Text(
                  _listening
                      ? 'Approchez le badge...'
                      : 'Associer un badge NFC',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: tag?.isActive == true ? _revokeSelectedTag : null,
                icon: const Icon(Icons.block_rounded),
                label: const Text('Révoquer le badge'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _tagPayload(NfcTag tag) {
  final androidTag = NfcTagAndroid.from(tag);
  if (androidTag != null) {
    return androidTag.id
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
  return tag.hashCode.toString();
}

class _NfcHeader extends StatelessWidget {
  final bool nfcAvailable;
  final bool listening;

  const _NfcHeader({required this.nfcAvailable, required this.listening});

  @override
  Widget build(BuildContext context) {
    return AppDataCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.enactusYellow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.nfc_rounded, color: AppTheme.softBlack),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enrôlement NFC',
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listening
                      ? 'Approchez le badge NFC du telephone.'
                      : nfcAvailable
                      ? 'NFC disponible sur cet appareil.'
                      : 'NFC indisponible sur cet appareil.',
                  style: const TextStyle(color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcTagStatus extends StatelessWidget {
  final AttendanceNfcTagModel? tag;

  const _NfcTagStatus({required this.tag});

  @override
  Widget build(BuildContext context) {
    final current = tag;
    final active = current?.isActive == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.enactusYellow.withAlpha(45)
            : Colors.black.withAlpha(6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppTheme.enactusYellow : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Icon(active ? Icons.verified_rounded : Icons.credit_card_off_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.maskedTag ?? 'Aucun badge actif',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  current == null
                      ? 'Non attribué'
                      : 'Statut: ${current.status}'
                            '${current.lastUsedAt == null ? '' : ' - déjà utilisé'}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcTagsList extends StatelessWidget {
  final List<AttendanceNfcTagModel> tags;
  final Map<String, MemberModel> membersById;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function(AttendanceNfcTagModel tag) onRevoke;

  const _NfcTagsList({
    required this.tags,
    required this.membersById,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = const Text(
                  'Gestion des badges',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                );
                final filters = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusButton(
                      value: 'active',
                      label: 'Actifs',
                      selected: statusFilter == 'active',
                      onSelected: onStatusChanged,
                    ),
                    _StatusButton(
                      value: 'lost',
                      label: 'Perdus',
                      selected: statusFilter == 'lost',
                      onSelected: onStatusChanged,
                    ),
                    _StatusButton(
                      value: 'revoked',
                      label: 'Révoqués',
                      selected: statusFilter == 'revoked',
                      onSelected: onStatusChanged,
                    ),
                    _StatusButton(
                      value: 'replaced',
                      label: 'Remplacés',
                      selected: statusFilter == 'replaced',
                      onSelected: onStatusChanged,
                    ),
                    _StatusButton(
                      value: 'all',
                      label: 'Tous',
                      selected: statusFilter == 'all',
                      onSelected: onStatusChanged,
                    ),
                  ],
                );
                if (constraints.maxWidth >= 700) {
                  return Row(
                    children: [
                      Expanded(child: title),
                      filters,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), filters],
                );
              },
            ),
            const SizedBox(height: 12),
            if (tags.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucun badge pour ce filtre.'),
              )
            else
              ...tags.map((tag) {
                final member = membersById[tag.memberId];
                return ListTile(
                  leading: Icon(
                    tag.isActive ? Icons.nfc_rounded : Icons.block_rounded,
                    color: tag.isActive ? AppTheme.softBlack : Colors.black45,
                  ),
                  title: Text(member?.displayName ?? tag.maskedTag),
                  subtitle: Text('${tag.maskedTag} - ${tag.status}'),
                  trailing: tag.isActive
                      ? IconButton(
                          tooltip: 'Révoquer',
                          onPressed: () => onRevoke(tag),
                          icon: const Icon(Icons.block_rounded),
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String value;
  final String label;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _StatusButton({
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.enactusYellow.withAlpha(80),
    );
  }
}

class _NfcErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NfcErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.error_rounded, color: Colors.red.shade700),
        title: Text(message),
        trailing: IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }
}

class _NfcMembersLoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NfcMembersLoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

String _memberInitials(MemberModel member) {
  final source = member.displayName.trim().isEmpty
      ? member.email
      : member.displayName;
  final parts = source
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
