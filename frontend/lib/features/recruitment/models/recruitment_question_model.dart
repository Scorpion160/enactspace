class RecruitmentApplicationQuestion {
  final String id, label, hint, section;
  final bool required;
  final String? legacyField;
  const RecruitmentApplicationQuestion({
    required this.id,
    required this.label,
    this.hint = '',
    this.section = 'motivation',
    this.required = false,
    this.legacyField,
  });
  factory RecruitmentApplicationQuestion.fromJson(Map<String, dynamic> json) =>
      RecruitmentApplicationQuestion(
        id: json['id'].toString(),
        label: json['label'].toString(),
        hint: json['hint']?.toString() ?? '',
        section: json['section']?.toString() ?? 'motivation',
        required: json['required'] == true,
        legacyField: json['legacy_field']?.toString(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'hint': hint,
    'section': section,
    'required': required,
    if (legacyField != null) 'legacy_field': legacyField,
  };
  RecruitmentApplicationQuestion copyWith({
    String? label,
    String? hint,
    String? section,
    bool? required,
  }) => RecruitmentApplicationQuestion(
    id: id,
    label: label ?? this.label,
    hint: hint ?? this.hint,
    section: section ?? this.section,
    required: required ?? this.required,
    legacyField: legacyField,
  );
}

const defaultRecruitmentQuestions = <RecruitmentApplicationQuestion>[
  RecruitmentApplicationQuestion(
    id: "personality",
    label: "Décris-toi : personnalité, caractère et manière d’être.",
    hint: "Quelques qualités, un point à améliorer et ce qui te ressemble.",
    section: "motivation",
    required: false,
    legacyField: "leadership_profile",
  ),
  RecruitmentApplicationQuestion(
    id: "motivation",
    label: "Qu’est-ce qui te motive à rejoindre Enactus ESP ?",
    hint:
        "Qu’aimerais-tu apprendre et apporter pour agir avec les communautés ? Tu n’as pas besoin d’une expérience associative.",
    section: "motivation",
    required: true,
    legacyField: "motivation",
  ),
  RecruitmentApplicationQuestion(
    id: "other-clubs",
    label:
        "Es-tu engagé dans une structure étudiante, bénévole ou entrepreneuriale ?",
    hint:
        "La structure, ton rôle et ce que tu y fais ; sinon, indique-le simplement.",
    section: "motivation",
    required: false,
    legacyField: "other_clubs",
  ),
  RecruitmentApplicationQuestion(
    id: "priority",
    label:
        "Comment organiserais-tu Enactus ESP avec tes études et tes autres engagements ?",
    hint:
        "Donne une organisation réaliste et explique comment tu préviendrais l’équipe en cas d’empêchement.",
    section: "availability",
    required: false,
  ),
  RecruitmentApplicationQuestion(
    id: "social-problem",
    label: "Quel problème social te tient particulièrement à cœur ?",
    hint: "Décris une situation concrète et pourquoi elle te touche.",
    section: "motivation",
    required: true,
  ),
  RecruitmentApplicationQuestion(
    id: "solution",
    label: "Quelle solution proposerais-tu face à ce problème ?",
    hint: "Une première piste suffit : elle pourra évoluer avec le terrain.",
    section: "motivation",
    required: true,
    legacyField: "project_ideas",
  ),
  RecruitmentApplicationQuestion(
    id: "community",
    label:
        "Avec qui construirais-tu cette solution et comment comprendrais-tu leurs besoins ?",
    hint:
        "Précise les personnes concernées et une première manière de les écouter avant de choisir une solution.",
    section: "motivation",
    required: true,
  ),
  RecruitmentApplicationQuestion(
    id: "teamwork-example",
    label:
        "Une tâche d’équipe prend du retard et un désaccord apparaît : comment réagirais-tu ?",
    hint:
        "Explique comment tu écouterais les autres, clarifierais les responsabilités et chercherais une prochaine étape ensemble.",
    section: "motivation",
    required: true,
  ),
  RecruitmentApplicationQuestion(
    id: "learning-example",
    label:
        "Raconte une situation où tu as essayé, appris ou amélioré quelque chose.",
    hint:
        "Un exemple des études, de la famille, d’un petit projet ou du quotidien suffit. Qu’as-tu fait et que changerais-tu aujourd’hui ?",
    section: "motivation",
    required: true,
  ),
  RecruitmentApplicationQuestion(
    id: "travel",
    label:
        "Pourrais-tu participer à des missions de plusieurs jours à l’intérieur du pays ?",
    hint:
        "Oui, non ou sous conditions. Tu peux aussi contribuer à la préparation ou au suivi des missions.",
    section: "availability",
    required: false,
  ),
  RecruitmentApplicationQuestion(
    id: "availability",
    label: "Quelles sont tes disponibilités pour l’équipe ?",
    hint:
        "Indique des créneaux réalistes et tes périodes d’examens ou d’indisponibilité. Promettre plus d’heures ne donne pas automatiquement plus de points.",
    section: "availability",
    required: true,
    legacyField: "availability",
  ),
  RecruitmentApplicationQuestion(
    id: "last-word",
    label: "Un dernier mot ?",
    hint:
        "Un message, une précision ou quelque chose que tu aimerais partager.",
    section: "availability",
    required: false,
    legacyField: "public_comment",
  ),
];
