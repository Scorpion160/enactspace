import 'help_models.dart';

class ManagedFeedback {
  final ProductFeedback feedback;
  final String? adminNote;
  const ManagedFeedback({required this.feedback, this.adminNote});
  factory ManagedFeedback.fromJson(Map<String, dynamic> json) =>
      ManagedFeedback(
        feedback: ProductFeedback.fromJson(json),
        adminNote: json['admin_note']?.toString(),
      );
}
