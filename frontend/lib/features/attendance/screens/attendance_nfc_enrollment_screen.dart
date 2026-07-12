import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_android/tags/tag.dart';

import '../../../core/theme/app_theme.dart';
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

class _AttendanceNfcEnrollmentScreenState
    extends State<AttendanceNfcEnrollmentScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MembersService _membersService = MembersService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _nfcAvailable = false;
  bool _listening = false;
  String? _error;
  MemberModel? _selectedMember;
  AttendanceNfcTagModel? _selectedTag;
  List<MemberModel> _members = [];

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
      _error = null;
    });

    try {
      final availability = await NfcManager.instance.checkAvailability();
      final members = await _membersService.getMembers();
      if (!mounted) return;
      setState(() {
        _nfcAvailable = availability == NfcAvailability.enabled;
        _members = members
            .where(
              (member) => member.isActive != false && member.status == 'active',
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectMember(MemberModel member) async {
    setState(() {
      _selectedMember = member;
      _selectedTag = null;
      _error = null;
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
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startEnrollment() async {
    final member = _selectedMember;
    if (member == null || _listening) return;

    if (!_nfcAvailable) {
      setState(() {
        _error = 'NFC indisponible sur cet appareil.';
      });
      return;
    }

    setState(() {
      _listening = true;
      _error = null;
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
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Badge associe avec succes.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
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
        _error = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Badge revoque.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
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
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMemberPicker() {
    final members = _filteredMembers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selectionner un membre',
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
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Aucun membre actif trouve.'),
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
                onPressed: _listening ? null : _startEnrollment,
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
                label: const Text('Revoquer le badge'),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.softBlack,
        borderRadius: BorderRadius.circular(24),
      ),
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
                  'Enrolement NFC',
                  style: TextStyle(
                    color: Colors.white,
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
                  style: const TextStyle(color: Colors.white70),
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
                      ? 'Non attribue'
                      : 'Statut: ${current.status}'
                            '${current.lastUsedAt == null ? '' : ' - deja utilise'}',
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
