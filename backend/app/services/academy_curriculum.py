"""Curated starter curriculum. Project histories require source review before publishing."""

from app.models.academy import AcademyCourse, AcademyLesson, AcademyQuiz, AcademyQuestion
from app.services.academy_practice import COURSES as PRACTICE_COURSES, QUIZ_ITEMS
from app.services.academy_history import COURSES as HISTORY_COURSES

COURSES = [
    ("Découvrir Enactus", "Culture Enactus", "debutant", [
        ("La démarche Enactus", "Enactus réunit des étudiants qui apprennent par l'action entrepreneuriale au service des autres. Un projet commence par l'écoute des personnes concernées, puis la construction et la vérification d'une solution.\n\nExercice : écris un problème concret, les personnes touchées, une hypothèse de solution et une façon de vérifier son utilité.\n\nSource : https://enactus.org/who-we-are/"),
        ("Agir avec les communautés", "Identifier les personnes concernées ne suffit pas : elles doivent participer à la définition du problème et à l'évaluation de la solution. Distingue ce que l'équipe suppose de ce que les personnes disent ou font réellement.\n\nExercice : prépare cinq questions ouvertes pour un entretien et note les réponses sans les reformuler à ton avantage."),
        ("Le rôle de l'enacteur", "Un enacteur contribue à la recherche, à l'exécution, à la mesure et à la transmission. Documente les décisions, les difficultés et les preuves ; demande de l'aide tôt et partage ce que tu apprends.\n\nExercice : décris une contribution précise que tu peux réaliser cette semaine."),
    ]),
    ("Comprendre les ODD", "Impact", "debutant", [
        ("Les 17 objectifs", "Les objectifs de développement durable sont un cadre mondial pour décrire des enjeux sociaux, économiques et environnementaux. Ils ne remplacent pas le diagnostic local.\n\nExercice : choisis un objectif lié à un besoin observé et explique ce lien.\n\nSource : https://sdgs.un.org/goals"),
        ("Choisir une cible pertinente", "Relie le problème, le public, l'action et le résultat attendu à une cible précise. Un projet peut contribuer à plusieurs objectifs, mais chaque lien doit être justifié par des activités et des résultats mesurables."),
        ("Éviter l'affichage d'impact", "Un logo ODD sur une affiche ne prouve aucun résultat. Sépare l'intention, l'activité effectivement menée et le changement observé. Indique les limites des données disponibles."),
    ]),
    ("Enquête terrain", "Méthode projet", "debutant", [
        ("Formuler le problème", "Décris qui rencontre quelle difficulté, dans quel contexte et avec quelles conséquences. Cherche des exemples observables et identifie les personnes que la solution risque d'exclure."),
        ("Interroger sans orienter", "Commence par les pratiques réelles et les difficultés vécues. Évite les questions qui invitent à approuver ton idée. Demande des exemples récents et confronte plusieurs points de vue."),
        ("Restituer le terrain", "Résume les entretiens sans exposer inutilement les données personnelles. Distingue citations anonymisées, observations, hypothèses et décisions. Fais valider ta synthèse auprès des personnes concernées."),
    ]),
    ("Concevoir et tester une solution", "Méthode projet", "intermediaire", [
        ("Hypothèses et prototype", "Liste les hypothèses à risque : besoin, usage, coût, sécurité et capacité de maintenance. Un prototype sert à tester ces hypothèses avec le minimum de moyens nécessaires."),
        ("Pilote et indicateurs", "Définis avant le pilote le public, la durée, le résultat attendu, l'indicateur, la méthode de collecte et les critères d'arrêt. Documente les échecs autant que les réussites."),
        ("Améliorer ou arrêter", "Compare les observations aux hypothèses initiales. Décide de poursuivre, modifier ou arrêter sur la base des preuves, des coûts et des retours du public concerné."),
    ]),
    ("Mesurer les résultats", "Impact", "intermediaire", [
        ("Activité, portée et changement", "Une activité est ce que l'équipe fait ; la portée est le nombre de personnes touchées ; le changement est ce qui s'améliore pour elles. Ne présente jamais la portée seule comme une preuve de changement."),
        ("Définir une mesure fiable", "Précise une situation de départ, une période, une source et un mode de calcul. Évite le double comptage et note les données manquantes. Avec consentement, recueille les retours des bénéficiaires."),
        ("Présenter les limites", "Indique la taille de l'échantillon et les autres causes possibles du changement. Un résultat non vérifié doit être présenté comme une hypothèse, pas comme un impact établi."),
    ]),
    ("Modèle économique et pérennité", "Entrepreneuriat", "intermediaire", [
        ("Valeur et bénéficiaires", "Décris les bénéficiaires, les clients ou financeurs éventuels et la valeur apportée à chacun. Le bénéficiaire et le payeur peuvent être différents."),
        ("Coûts et revenus", "Distingue investissements, coûts variables et coûts récurrents. Calcule le coût par unité et teste plusieurs volumes. Présente clairement les hypothèses de prix, de ventes et de financement."),
        ("Passage de relais", "Identifie qui exploitera la solution après le départ de l'équipe : responsabilités, maintenance, financement, documentation et formation. Une solution utile doit rester opérable."),
    ]),
    ("Travail d'équipe et transmission", "Vie du club", "debutant", [
        ("Responsabilités visibles", "Pour chaque tâche, nomme un responsable, un résultat attendu et une échéance. Partage les blocages dans l'équipe sans attendre la fin du projet."),
        ("Décisions et documents", "Consigne les décisions, leurs motifs et les versions des documents. Classe les preuves avec la date, le contexte et les restrictions d'accès appropriées."),
        ("Passation aux nouveaux", "Prépare une synthèse des objectifs, contacts autorisés, dépenses, prototypes, résultats, échecs et prochaines actions. Les nouveaux membres doivent pouvoir reprendre le travail."),
    ]),
    ("Présenter un projet", "Communication", "intermediaire", [
        ("Raconter le problème", "Présente une difficulté réelle et les personnes concernées sans dramatiser ni généraliser. Explique comment le besoin a été vérifié sur le terrain."),
        ("Montrer la solution", "Démontre ce qui a effectivement été construit et utilisé. Sépare prototype, pilote et déploiement ; indique les limites techniques et économiques."),
        ("Défendre les résultats", "Relie chaque résultat à une période et à une preuve. Prépare les questions sur les coûts, l'éthique, les bénéficiaires et la continuité du projet.\n\nRéférence : https://enactus.org/competition-handbook/"),
    ]),
    ("Apprendre des projets précédents", "Mémoire du club", "debutant", [
        ("Lire une archive", "Pour comprendre un ancien projet, consulte sa fiche, ses documents datés, ses prototypes et ses témoignages autorisés. Vérifie que le statut et la période correspondent aux sources."),
        ("Reconstituer les choix", "Note le besoin initial, les alternatives envisagées, les décisions, les tests et les raisons d'un changement de direction. N'attribue pas un succès ou un échec sans preuve."),
        ("Transmettre sans inventer", "Rédige une synthèse distinguant faits documentés, témoignages et éléments inconnus. Invite les alumni à vérifier les détails avant la publication d'une étude de cas."),
    ]),
]
COURSES.extend(HISTORY_COURSES)
COURSES.extend(PRACTICE_COURSES)

# Keep baseline text solely to identify untouched seeded records during an upgrade.
LEGACY_CONTENT = {(title, name): text for title, _, _, rows in COURSES for name, text in rows}
from app.services.academy_school import expand_curriculum, learning_minutes, lesson_summary, DESCRIPTIONS, REFERENCES
COURSES = expand_curriculum(COURSES)



def seed_curriculum(db):
    """Add missing lessons without overwriting administrator edits."""
    created = 0
    for title, category, level, lessons in COURSES:
        course = db.query(AcademyCourse).filter(AcademyCourse.title == title).first()
        if course is None:
            course = AcademyCourse(title=title, category=category, level=level,
                                   description=DESCRIPTIONS[title],
                                   estimated_duration_minutes=sum(learning_minutes(content) for _, content in lessons),
                                   points=0, is_published=True)
            db.add(course)
            db.flush()
            created += 1
        for index, (lesson_title, content) in enumerate(lessons, 1):
            exists = db.query(AcademyLesson).filter(
                AcademyLesson.course_id == course.id,
                AcademyLesson.title == lesson_title,
            ).first()
            if exists is None:
                db.add(AcademyLesson(course_id=course.id, title=lesson_title,
                    summary=lesson_summary(content), content=content,
                    order_index=index, duration_minutes=learning_minutes(content), is_published=True,
                    external_url=REFERENCES.get(title)))
                created += 1
            elif exists.content == LEGACY_CONTENT.get((title, lesson_title)):
                exists.content = content
                exists.summary = lesson_summary(content)
                exists.duration_minutes = learning_minutes(content)
                exists.external_url = REFERENCES.get(title)
        if course.created_by_id is None and (course.description == " · ".join(item[0] for item in lessons) or course.description == DESCRIPTIONS[title]):
            course.description = DESCRIPTIONS[title]
            course.estimated_duration_minutes = sum(learning_minutes(text) for _, text in lessons)
    db.flush()
    seed_quizzes(db)
    from app.services.academy_progression import seed_prerequisites
    seed_prerequisites(db)
    db.flush()
    return created



CORE_FACTS = {
 "Découvrir Enactus": ("Comprendre les besoins avant de proposer une réponse", "Associer les personnes concernées aux décisions", "Documenter ce que l’équipe apprend"),
 "Comprendre les ODD": ("Relier l’activité à une cible précise", "Distinguer une intention d’un résultat", "Justifier un lien avec un ODD"),
 "Enquête terrain": ("Demander un exemple récent", "Séparer observation et interprétation", "Restituer le diagnostic aux interlocuteurs"),
 "Concevoir et tester une solution": ("Tester une hypothèse à risque", "Définir un critère avant le pilote", "Modifier une solution après un résultat négatif"),
 "Mesurer les résultats": ("Décrire la situation de départ", "Éviter de compter deux fois une personne", "Présenter les limites de la mesure"),
 "Modèle économique et pérennité": ("Distinguer client et bénéficiaire", "Séparer coûts variables et investissements", "Prévoir le financement de la maintenance"),
 "Travail d'équipe et transmission": ("Nommer un responsable par tâche", "Signaler les blocages tôt", "Transmettre les décisions et leurs motifs"),
 "Présenter un projet": ("Montrer un besoin observé", "Distinguer prototype et déploiement", "Relier chaque résultat à une période"),
 "Apprendre des projets précédents": ("Lire des documents datés", "Reconstituer les raisons des choix", "Distinguer faits et éléments inconnus"),
 "Histoire d'Enactus ESP": ("Le club démarre en 2015", "Les visas empêchent la participation à Londres en 2017", "Dimbali et Deconaane accompagnent la World Cup 2018"),
 "Étude de cas : Dimbali": ("Le projet valorise des ressources locales", "Les formations facilitent la poursuite des activités", "Les chiffres doivent garder leur période et leur localité"),
 "Étude de cas : Deconaane": ("Le projet explore filtration et stockage", "L’accès à l’eau devient une priorité à Sinthiou Dimb", "La qualité de l’eau exige des contrôles adaptés"),
 "Étude de cas : SunCuiz et Ville Light": ("SunCuiz explore la cuisson solaire", "Ville Light évolue vers des kits pédagogiques", "Changer une solution peut répondre aux contraintes"),
 "Étude de cas : Mën Nañ": ("Le projet relie plusieurs contextes territoriaux", "Les activités portent sur la transformation locale", "Une transmission utile rend les procédés reprenables"),
 "Étude de cas : Aquatus": ("L’aquaponie associe poissons et cultures", "Un pilote doit préciser ses mesures", "La maintenance fait partie de la pérennité"),
}


def _assessment_items(title):
    from app.services.academy_assessments import ASSESSMENTS
    if title in ASSESSMENTS:
        # Keep the starter answer positions stable for cached/offline submissions.
        items = []
        for index, (prompt, choices, answer, explanation) in enumerate(ASSESSMENTS[title]):
            choices = list(choices)
            target = index % 3
            choices[answer], choices[target] = choices[target], choices[answer]
            items.append((prompt, choices, target, explanation))
        return items
    if title == 'Premiers pas dans EnactSpace':
        return [
            ('Une première contribution utile comporte…', ['Une intention sans échéance', 'Un livrable clair et une disponibilité annoncée', 'Un document privé publié partout'], 1, 'Un livrable et une disponibilité réalistes permettent de préparer une première contribution utile avec l’équipe.'),
            ('Après une leçon, le quiz sert à…', ['Éviter les exercices', 'Prendre une décision sur les membres', 'Vérifier la compréhension et revoir les idées difficiles'], 2, 'Le quiz vérifie des repères et propose une correction. Les exercices permettent ensuite de mettre ces idées en pratique.'),
            ('Lorsqu’une tâche bloque, il vaut mieux…', ['Partager le point précis et demander une aide', 'Ne rien dire', 'Changer les chiffres du bilan'], 0, 'Une demande précise permet à une autre personne de t’aider. Signaler tôt un blocage donne aussi le temps de réorganiser le travail.'),
        ]
    return [(prompt, choices, answer, choices[answer]) for prompt, choices, answer in QUIZ_ITEMS[title]]


def _legacy_items(title):
    if title in QUIZ_ITEMS:
        return QUIZ_ITEMS[title]
    items = []
    for index, fact in enumerate(CORE_FACTS.get(title, ())):
        choices = ["Il faut présenter toutes les hypothèses comme des résultats", "Le terrain n’est pas nécessaire", "Il suffit de compter les réunions"]
        choices[index % 3] = fact
        items.append(("Quel repère correspond à ce cours ?", choices, index % 3))
    return items


def seed_quizzes(db):
    """Upgrade untouched starter questions; preserve administrator assessments and IDs."""
    created = 0
    for title, _, _, _ in COURSES:
        course = db.query(AcademyCourse).filter(AcademyCourse.title == title).first()
        if not course:
            continue
        items = _assessment_items(title)
        quiz = db.query(AcademyQuiz).filter(AcademyQuiz.course_id == course.id).first()
        if quiz is None:
            quiz = AcademyQuiz(course_id=course.id, title='Mise en pratique — '+title,
                               description='Trois questions pour vérifier ta compréhension.',
                               passing_score=60, time_limit_minutes=5, allow_retake=True, is_published=True)
            db.add(quiz)
            db.flush()
            for index, (prompt, choices, answer, explanation) in enumerate(items):
                db.add(AcademyQuestion(quiz_id=quiz.id, prompt=prompt, choices=choices,
                         correct_answers=[answer], explanation=explanation, points=1,
                         order_index=index))
            created += 1
        elif quiz.created_by_id is None:
            questions = db.query(AcademyQuestion).filter(AcademyQuestion.quiz_id == quiz.id).order_by(AcademyQuestion.order_index).all()
            baseline = _legacy_items(title)
            untouched = len(questions) == len(baseline) == len(items) and all(
                q.prompt == prompt and q.choices == choices and q.correct_answers == [answer]
                and q.explanation == choices[answer]
                for q, (prompt, choices, answer) in zip(questions, baseline))
            if untouched:
                for question, (prompt, choices, answer, explanation) in zip(questions, items):
                    question.prompt, question.choices = prompt, choices
                    question.correct_answers, question.explanation = [answer], explanation
                quiz.time_limit_minutes = 5
    db.flush()
    return created


def main():
    import app.models.base  # Register the full foreign key metadata for standalone seeding.
    from app.db.database import SessionLocal
    with SessionLocal() as db:
        with db.begin():
            created = seed_curriculum(db)
    print(f"Academy: {created} cours et leçons créés")


if __name__ == "__main__":
    main()
