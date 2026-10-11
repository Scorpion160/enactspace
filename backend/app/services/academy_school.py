"""Complete, versioned Academy lessons. Duration includes reading and practice."""
from pathlib import Path
import math
import re
from app.services.academy_expansions import EXPLANATIONS

DESCRIPTIONS = {
 "Découvrir Enactus": "Comprends la démarche Enactus, la place des communautés et ta première contribution au collectif.",
 "Comprendre les ODD": "Relie un besoin local aux objectifs de développement durable et distingue intention, activité et résultat.",
 "Enquête terrain": "Prépare un diagnostic, conduis des entretiens ouverts et transforme tes observations en décisions.",
 "Concevoir et tester une solution": "Construis un prototype utile, organise un pilote et décide d’améliorer ou de changer de piste.",
 "Mesurer les résultats": "Choisis des indicateurs, reconstruis les calculs et présente les changements avec leur contexte.",
 "Modèle économique et pérennité": "Comprends les rôles économiques, les coûts et les moyens de poursuivre une activité.",
 "Travail d'équipe et transmission": "Clarifie les responsabilités, conserve les décisions et prépare une passation utile.",
 "Présenter un projet": "Raconte le besoin, montre la solution et réponds aux questions avec des résultats expliqués.",
 "Apprendre des projets précédents": "Lis les archives pour comprendre les choix et transmettre les apprentissages aux nouvelles générations.",
 "Histoire d'Enactus ESP": "Découvre les débuts de 2015, les projets, les étapes mondiales et les générations qui font vivre le club.",
 "Étude de cas : Dimbali": "Explore le lien entre ressource locale, transformation, formation et activité économique.",
 "Étude de cas : Deconaane": "Analyse l’accès à l’eau, les fonctions d’un dispositif et son adaptation à un nouveau territoire.",
 "Étude de cas : SunCuiz et Ville Light": "Comprends comment les usages conduisent une équipe à faire évoluer une réponse technique.",
 "Étude de cas : Mën Nañ": "Relie les filières, la conservation, les débouchés et la transmission entre générations.",
 "Étude de cas : Aquatus": "Découvre l’aquaponie, les questions de marché et la construction d’un budget de pilote.",
 "Entrepreneuriat social : de l’idée à l’impact": "Pars d’un changement recherché et organise une première réponse avec les personnes concernées.",
 "Social business avec Muhammad Yunus": "Comprends les modèles de social business et relie mission sociale, gestion et viabilité.",
 "Immersion : écouter avant d’agir": "Prépare une mission, écoute les pratiques et décide de la suite avec les communautés.",
 "Ciblage : choisir avec qui agir": "Définis un public, comprends les obstacles à l’usage et rends le pilote plus accessible.",
 "Brainstorming et idéation : ouvrir le champ": "Formule un défi ouvert, anime une séance et choisis une hypothèse à tester.",
 "Design thinking : du terrain au prototype": "Utilise l’écoute, la définition, l’idéation, le prototype et le test pour apprendre par l’usage.",
 "Vivre et transmettre Enactus ESP": "Relie l’histoire, la Minute de l’enacteur et le rôle des mentors à ta vie dans le collectif.",
 "Études de terrain : Terrasen et SHERY": "Analyse les choix de terrain, les usages et le transfert des capacités autour de deux projets du club.",
 "Premiers pas dans EnactSpace": "Trouve tes repères, organise ta première contribution et construis une routine d’apprentissage.",
}
REFERENCES = {
 "Découvrir Enactus": "https://enactus.org/who-we-are/",
 "Comprendre les ODD": "https://sdgs.un.org/goals",
 "Présenter un projet": "https://enactus.org/competition-handbook/",
 "Social business avec Muhammad Yunus": "https://www.muhammadyunus.org/post/363/seven-principles-of-social-business",
 "Design thinking : du terrain au prototype": "https://dschool.stanford.edu/tools/design-thinking-bootleg",
 "Étude de cas : Aquatus": "https://www.fao.org/family-farming/detail/fr/c/1743025/",
}

REPHRASINGS = {
 "La mémoire distingue immersion, formation et transfert :": "Immersion, formation et transfert :",
 "La mémoire de Mën Nañ distingue les contextes de": "Mën Nañ relie",
 "En 2025–2026, la mémoire évoque": "En 2025–2026, le club connaît",
 "Le PV du 12 décembre 2024 rappelle son intention : faire passer un message de vie.": "Son intention est de faire passer un message de vie.",
 "Les PV de 2025 parlent aussi": "Les interventions de 2025 parlent aussi",
 "La mémoire situe la naissance de Terrasen en 2022, après": "Terrasen naît en 2022, après",
 "La mémoire décrit une protection": "La solution comprend une protection",
 "Les missions de mars 2025 et les PV abordent": "Les missions de mars 2025 associent",
 "La mémoire rappelle aussi les transferts réalisés à Mbour pendant la restructuration 2025–2026.": "Des transferts sont aussi réalisés à Mbour pendant la réorganisation de 2025–2026.",
 "Le dossier décrit des tables réalisées avec des matériaux simples, puis le goutte-à-goutte et un prototype": "L’équipe fabrique des tables avec des matériaux simples et développe le goutte-à-goutte ainsi qu’un prototype",
 "Le premier prix du Salon du Polytechnicien 2023 marque le parcours du projet.": "Le premier prix du Salon du Polytechnicien 2023 marque une étape du parcours de SHERY.",
 "La démarche du club relie": "La démarche du club relie",
}


def read_manuscript():
    courses = {}
    course = None
    lesson = None
    chunks = []
    def save():
        if course and lesson:
            courses.setdefault(course, {})[lesson] = "\n".join(chunks).strip()
    for line in Path(__file__).with_name('academy_lessons.md').read_text(encoding='utf-8').splitlines():
        if line.startswith('# '):
            save(); course = line[2:]; lesson = None; chunks = []
        elif line.startswith('## '):
            save(); lesson = line[3:]; chunks = []
        else:
            chunks.append(line)
    save()
    return courses


def expand_curriculum(original):
    manuscript = read_manuscript()
    result = []
    for title, category, level, lessons in original:
        updated = []
        for lesson_title, original_content in lessons:
            if title in manuscript:
                content = manuscript[title][lesson_title]
            else:
                content = original_content.split('\n\nPour aller plus loin\n')[0]
                for old, new in REPHRASINGS.items():
                    content = content.replace(old, new)
                extra = EXPLANATIONS[lesson_title]
                # Put explanation before the example and practical activity.
                content = content.replace('\n\nSur le terrain\n', '\n\n### Approfondir\n' + extra + '\n\nSur le terrain\n', 1)
            updated.append((lesson_title, content))
        result.append((title, category, level, updated))
    onboarding = manuscript['Premiers pas dans EnactSpace']
    result.append(('Premiers pas dans EnactSpace', 'Vie du club', 'debutant', list(onboarding.items())))
    return result


def learning_minutes(content):
    words = len(re.findall(r"\b[\w’'-]+\b", content))
    reading = max(1, math.ceil(words / 180))
    practice = 20 if 'vingt minutes' in content or 'En vingt minutes' in content else 10 if 'dix minutes' in content else 6
    return reading + practice


def lesson_summary(content):
    blocks = content.split('\n\n')
    return re.sub(r'^### [^\n]+\n', '', blocks[0]).replace('Objectif\n', '').split('\n')[-1]
