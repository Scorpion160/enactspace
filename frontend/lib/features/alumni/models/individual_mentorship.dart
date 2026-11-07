enum IndividualMentorshipStatus {
  pending('À valider'),
  active('Actif'),
  completed('Terminé'),
  cancelled('Annulé');

  const IndividualMentorshipStatus(this.label);
  final String label;
}

class IndividualMentorship {
  final String id;
  final String mentorName;
  final String menteeName;
  final String objective;
  final IndividualMentorshipStatus status;

  const IndividualMentorship({
    required this.id,
    required this.mentorName,
    required this.menteeName,
    required this.objective,
    required this.status,
  });

  factory IndividualMentorship.fromJson(Map<String, dynamic> json) {
    return IndividualMentorship(
      id: json['id'] as String,
      mentorName: json['mentor_name'] as String,
      menteeName: json['mentee_name'] as String,
      objective: json['objective'] as String,
      status: IndividualMentorshipStatus.values.byName(
        json['status'] as String,
      ),
    );
  }
}
