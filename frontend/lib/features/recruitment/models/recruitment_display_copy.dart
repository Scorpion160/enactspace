// Refresh legacy help text when displaying saved campaign and questionnaire data.
// Custom wording, question identifiers and stored answers stay unchanged.
String recruitmentDisplayCopy(Object? value) {
  final text = value?.toString() ?? '';
  return _legacyRecruitmentCopy[text] ?? text;
}

const _legacyRecruitmentCopy = <String, String>{
  "Les réponses sont lues par des personnes. Chaque critère compte pour 20 points sur 100. La note doit s’appuyer sur un exemple ou une observation. Une information manquante appelle une précision, pas une note inventée. Le jury prend la décision finale.":
      "Choisis un niveau de 0 à 4 pour chaque critère et ajoute une observation tirée du dossier ou de l’entretien. Si un point reste flou, demande une précision avant de le noter.",
  "Relier son envie de rejoindre l’équipe à une action utile pour les communautés, au-delà du seul titre ou du certificat.":
      "Relier sa motivation à une action utile pour les communautés et à ce qu’il souhaite apprendre avec l’équipe.",
  "La réponse évaluée exprime une démarche contraire à la mission ou aucune envie d’y contribuer.":
      "Exprime une démarche contraire à la mission ou aucune envie d’y contribuer.",
  "L’envie est exprimée, mais le lien avec la mission reste général.":
      "Souhaite rejoindre l’équipe, mais explique peu le lien avec la mission.",
  "La personne relie sa motivation à une contribution sociale compréhensible.":
      "Relie sa motivation à une contribution sociale.",
  "La motivation s’appuie sur un exemple concret et une contribution envisageable.":
      "Illustre sa motivation par un exemple et une contribution possible.",
  "La personne explique sa motivation, la contribution envisagée et ce qu’elle souhaite apprendre avec l’équipe.":
      "Explique sa motivation, la contribution envisagée et ce qu’il souhaite apprendre avec l’équipe.",
  "Décrire un problème social, économique ou environnemental et chercher à comprendre les personnes concernées avant d’imposer une solution.":
      "Décrire le problème et les personnes concernées, puis expliquer comment vérifier leurs besoins.",
  "La réponse évaluée refuse de considérer les besoins ou la parole des personnes concernées.":
      "Écarte les besoins ou l’avis des personnes concernées.",
  "Le problème est nommé sans contexte ni personnes clairement identifiées.":
      "Nomme un problème, sans préciser le contexte ou les personnes concernées.",
  "Le contexte et les personnes concernées sont décrits de manière cohérente.":
      "Décrit le contexte et les personnes concernées.",
  "La personne distingue les besoins observés de ses hypothèses et propose d’écouter les personnes concernées.":
      "Distingue ce qui est observé de ce qui reste à vérifier et propose d’écouter les personnes concernées.",
  "La personne précise le besoin, les parties prenantes, les questions à vérifier et la manière de construire une solution avec elles.":
      "Précise le besoin, les personnes à associer et les questions à vérifier pour construire la solution avec elles.",
  "Proposer une première action réalisable, accepter les retours et apprendre d’un essai. Les exemples scolaires, personnels et familiaux ont autant leur place que le bénévolat.":
      "Proposer une première action réalisable et expliquer comment apprendre d’un essai. Les exemples scolaires, personnels, familiaux ou associatifs sont recevables.",
  "La réponse évaluée montre un refus d’essayer ou de tenir compte d’un retour.":
      "Refuse d’essayer ou de tenir compte des retours.",
  "Une idée est avancée, sans premier pas ni apprentissage identifié.":
      "Propose une idée, sans première étape ni apprentissage identifié.",
  "Une première action simple et réaliste est proposée.":
      "Propose une première action simple et réalisable.",
  "La personne décrit un essai, un retour ou un ajustement concret.":
      "Décrit un essai, un retour ou un ajustement concret.",
  "La personne relie l’action, les retours, les apprentissages et une amélioration réalisable.":
      "Relie l’action, les retours, les apprentissages et une amélioration réalisable.",
  "Écouter, partager le travail, prévenir en cas de difficulté et reconnaître les contributions. L’aisance à l’oral ne remplace pas la coopération.":
      "Décrire sa contribution, son écoute et sa manière de gérer un désaccord.",
  "La réponse évaluée justifie l’exclusion, l’irrespect ou le refus de rendre compte à l’équipe.":
      "Justifie l’irrespect, l’exclusion ou le refus de rendre compte à l’équipe.",
  "La personne affirme aimer travailler en équipe sans préciser sa manière de contribuer.":
      "Dit apprécier le travail en équipe, sans préciser sa contribution.",
  "Un exemple ou une situation explique sa contribution et son écoute des autres.":
      "Donne un exemple de sa contribution et de son écoute.",
  "La personne explique comment elle répartit le travail, communique et traite un désaccord.":
      "Explique la répartition du travail, les échanges et la gestion d’un désaccord.",
  "La personne décrit une coopération concrète, assume sa part et propose un traitement constructif d’un blocage.":
      "Décrit sa contribution, assume ses responsabilités et propose une issue à un blocage.",
  "Annoncer une contribution compatible avec ses études et ses contraintes, organiser ses disponibilités et prévenir tôt. L’impossibilité de voyager ne constitue pas une exclusion automatique.":
      "Présenter des disponibilités, une organisation et des solutions en cas d’empêchement.",
  "La réponse évaluée refuse de respecter un engagement ou de signaler une indisponibilité.":
      "Refuse de tenir un engagement ou de signaler une indisponibilité.",
  "La personne promet une disponibilité générale sans organisation précise.":
      "Annonce une disponibilité générale, sans organisation précise.",
  "La personne annonce des créneaux ou une contribution réaliste et ses contraintes.":
      "Présente des créneaux ou une contribution réaliste et ses contraintes.",
  "La personne explique comment elle organise ses engagements et prévient en cas de difficulté.":
      "Explique son organisation et sa façon de prévenir l’équipe en cas de difficulté.",
  "La personne propose un engagement réaliste, une organisation concrète et une solution de relais ou d’adaptation en cas de blocage.":
      "Propose un engagement réaliste, une organisation concrète et un relais ou une adaptation en cas d’empêchement.",
  "Ce questionnaire aide à préparer notre échange sur ta façon de travailler. Il n’y a pas de profil idéal ni de note d’admission. Les réponses sont déclaratives ; cette traduction de travail n’a pas été validée auprès des étudiants de l’ESP. Tu peux préférer en parler pendant l’entretien. Les réponses terminées sont accessibles aux responsables du recrutement et au jury habilité de ta campagne.":
      "Ce questionnaire porte sur ta façon de travailler et de participer à une équipe. Tes réponses aideront à préparer l’entretien. Tu peux les enregistrer pour les reprendre plus tard ou choisir d’en parler directement avec le jury. Une fois confirmées, elles seront accessibles au jury et aux responsables du recrutement de ta campagne. Ce questionnaire n’est pas un bilan psychologique.",
  "Honnêteté, distinction entre personnes touchées et impact démontré ; aucun score automatique.":
      "Honnêteté et précision des faits présentés.",
  "Moyennes déclaratives à discuter, sans seuil ni classement. Les deux extrémités décrivent des préférences, pas une valeur personnelle.":
      "Cette synthèse reprend tes réponses et les thèmes à aborder pendant l’entretien.",
  "Indique des créneaux réalistes et tes périodes d’examens ou d’indisponibilité. Promettre plus d’heures ne donne pas automatiquement plus de points.":
      "Indique tes créneaux disponibles et tes périodes d’examens ou d’indisponibilité.",
};
