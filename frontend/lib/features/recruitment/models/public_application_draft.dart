class PublicApplicationDraft {
  final String campaignId;
  final String firstName;
  final String lastName;
  final String email;
  final String? gender;
  final String? phone;
  final String? department;
  final String? studyLevel;
  final String? className;
  final String? motivation;
  final String? knownEnactusFrom;
  final String? enactusKnowledge;
  final String? otherClubs;
  final String? contribution;
  final String? projectIdeas;
  final String? leadershipProfile;
  final String? preferredPole;
  final String? projectInterest;
  final String? associativeExperience;
  final String? availability;
  final String? publicComment;
  final String? cvUrl;
  final String? motivationLetterUrl;
  final String? attachmentUrl;

  const PublicApplicationDraft({
    required this.campaignId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.gender,
    this.phone,
    this.department,
    this.studyLevel,
    this.className,
    this.motivation,
    this.knownEnactusFrom,
    this.enactusKnowledge,
    this.otherClubs,
    this.contribution,
    this.projectIdeas,
    this.leadershipProfile,
    this.preferredPole,
    this.projectInterest,
    this.associativeExperience,
    this.availability,
    this.publicComment,
    this.cvUrl,
    this.motivationLetterUrl,
    this.attachmentUrl,
  });
}
