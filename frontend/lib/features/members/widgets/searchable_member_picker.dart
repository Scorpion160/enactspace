import 'package:flutter/material.dart';

import '../models/member_model.dart';

class SearchableMemberPickerField extends StatelessWidget {
  final List<MemberModel> members;
  final String? value;
  final String label;
  final IconData icon;
  final bool enabled;
  final String hintText;
  final String emptyText;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const SearchableMemberPickerField({
    super.key,
    required this.members,
    required this.value,
    required this.label,
    required this.onChanged,
    this.icon = Icons.person_rounded,
    this.enabled = true,
    this.hintText = 'Rechercher un membre',
    this.emptyText = 'Aucun membre trouvé.',
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...members]..sort(MemberModel.compareAlphabetically);
    final selected = sorted.where((member) => member.id == value).firstOrNull;

    return FormField<String>(
      initialValue: value,
      validator: validator,
      builder: (field) {
        final colors = Theme.of(context).colorScheme;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: !enabled
              ? null
              : () async {
                  final selectedId = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => _MemberPickerSheet(
                      members: sorted,
                      selectedId: field.value,
                      title: label,
                      emptyText: emptyText,
                    ),
                  );
                  if (selectedId == null) return;
                  field.didChange(selectedId);
                  onChanged(selectedId);
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixIcon: Icon(icon),
              errorText: field.errorText,
              enabled: enabled,
              suffixIcon: const Icon(Icons.search_rounded),
            ),
            isEmpty: false,
            child: Text(
              selected?.displayName ?? hintText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected == null
                    ? colors.onSurfaceVariant
                    : colors.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MemberPickerSheet extends StatefulWidget {
  final List<MemberModel> members;
  final String? selectedId;
  final String title;
  final String emptyText;

  const _MemberPickerSheet({
    required this.members,
    required this.selectedId,
    required this.title,
    required this.emptyText,
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MemberModel> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.members;
    return widget.members.where((member) {
      return member.displayName.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query) ||
          member.departmentLabel.toLowerCase().contains(query) ||
          member.rolesLabel.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Rechercher par nom ou e-mail…',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _visible.isEmpty
                  ? Center(child: Text(widget.emptyText))
                  : ListView.builder(
                      itemCount: _visible.length,
                      itemBuilder: (context, index) {
                        final member = _visible[index];
                        final selected = member.id == widget.selectedId;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.displayName.isEmpty
                                  ? '?'
                                  : member.displayName.characters.first
                                        .toUpperCase(),
                            ),
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                            [member.email, member.department]
                                .whereType<String>()
                                .where((value) => value.trim().isNotEmpty)
                                .join(' · '),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle_rounded)
                              : null,
                          onTap: () => Navigator.of(context).pop(member.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
