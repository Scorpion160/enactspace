class MemberImportIssue {
  final int? row;
  final String? field;
  final String message;

  const MemberImportIssue({
    required this.row,
    required this.field,
    required this.message,
  });

  factory MemberImportIssue.fromJson(Map<String, dynamic> json) {
    return MemberImportIssue(
      row: int.tryParse(json['row']?.toString() ?? ''),
      field: json['field']?.toString(),
      message: json['message']?.toString() ?? '',
    );
  }

  String get label {
    final rowLabel = row == null ? '' : 'Ligne $row - ';
    final fieldLabel = field == null || field!.isEmpty ? '' : '$field : ';
    return '$rowLabel$fieldLabel$message';
  }
}

class MemberImportPreviewItem {
  final int row;
  final String name;
  final String email;
  final String? phone;
  final String status;
  final List<String> roles;
  final String? corePole;
  final List<String> supportPoles;
  final String? project;
  final String responsibility;

  const MemberImportPreviewItem({
    required this.row,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.roles,
    required this.corePole,
    required this.supportPoles,
    required this.project,
    required this.responsibility,
  });

  factory MemberImportPreviewItem.fromJson(Map<String, dynamic> json) {
    return MemberImportPreviewItem(
      row: int.tryParse(json['row']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      status: json['status']?.toString() ?? '',
      roles: _stringList(json['roles']),
      corePole: json['core_pole']?.toString(),
      supportPoles: _stringList(json['support_poles']),
      project: json['project']?.toString(),
      responsibility: json['responsibility']?.toString() ?? '',
    );
  }
}

class MemberImportReport {
  final int totalRows;
  final int validRows;
  final int errorRows;
  final int warningRows;
  final int duplicates;
  final int createdUsers;
  final int updatedUsers;
  final int roleLinks;
  final int poleLinks;
  final int projectLinks;
  final List<MemberImportIssue> errors;
  final List<MemberImportIssue> warnings;
  final List<MemberImportPreviewItem> preview;

  const MemberImportReport({
    required this.totalRows,
    required this.validRows,
    required this.errorRows,
    required this.warningRows,
    required this.duplicates,
    required this.createdUsers,
    required this.updatedUsers,
    required this.roleLinks,
    required this.poleLinks,
    required this.projectLinks,
    required this.errors,
    required this.warnings,
    required this.preview,
  });

  factory MemberImportReport.fromJson(Map<String, dynamic> json) {
    return MemberImportReport(
      totalRows: _intValue(json['total_rows']),
      validRows: _intValue(json['valid_rows']),
      errorRows: _intValue(json['error_rows']),
      warningRows: _intValue(json['warning_rows']),
      duplicates: _intValue(json['duplicates']),
      createdUsers: _intValue(json['created_users']),
      updatedUsers: _intValue(json['updated_users']),
      roleLinks: _intValue(json['role_links']),
      poleLinks: _intValue(json['pole_links']),
      projectLinks: _intValue(json['project_links']),
      errors: _issueList(json['errors']),
      warnings: _issueList(json['warnings']),
      preview: _previewList(json['preview']),
    );
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

int _intValue(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

List<MemberImportIssue> _issueList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(MemberImportIssue.fromJson)
      .toList();
}

List<MemberImportPreviewItem> _previewList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(MemberImportPreviewItem.fromJson)
      .toList();
}
