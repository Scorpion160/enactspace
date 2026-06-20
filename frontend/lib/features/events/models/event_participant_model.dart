class EventParticipantModel {
  final String id;
  final String userId;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime registeredAt;

  const EventParticipantModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.registeredAt,
  });

  factory EventParticipantModel.fromJson(Map<String, dynamic> json) {
    return EventParticipantModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Participant',
      email: json['email']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      registeredAt:
          DateTime.tryParse(json['registered_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
