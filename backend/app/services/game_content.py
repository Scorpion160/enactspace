"""Club game content: shuffled without repetition within a room."""
import secrets

UNDERCOVER = {
    "vie du club": [
        ("réunion", "atelier"), ("projet", "programme"), ("pôle", "équipe"),
        ("mentor", "conseiller"), ("membre", "alumni"), ("campus", "école"),
        ("présentation", "pitch"), ("événement", "conférence"), ("rapport", "bilan"),
        ("soutenance", "concours"), ("budget", "trésorerie"), ("cotisation", "don"),
        ("impact", "résultat"), ("partenaire", "sponsor"), ("innovation", "invention"),
        ("prototype", "maquette"), ("planning", "calendrier"), ("archive", "mémoire"),
        ("formation", "cours"), ("élection", "nomination"),
    ],
    "quotidien": [
        ("café", "thé"), ("stylo", "crayon"), ("pluie", "orage"),
        ("bus", "taxi"), ("soleil", "lune"), ("riz", "mil"),
        ("livre", "cahier"), ("téléphone", "ordinateur"), ("chaise", "fauteuil"),
        ("vélo", "moto"), ("fenêtre", "porte"), ("marché", "boutique"),
        ("pêche", "agriculture"), ("mangue", "papaye"), ("sac", "valise"),
        ("photo", "vidéo"), ("musique", "danse"), ("rivière", "lac"),
        ("sable", "terre"), ("bateau", "pirogue"),
    ],
    "sciences": [
        ("atome", "molécule"), ("tension", "courant"), ("capteur", "détecteur"),
        ("robot", "automate"), ("satellite", "fusée"), ("algorithme", "programme"),
        ("batterie", "pile"), ("réseau", "internet"), ("énergie", "puissance"),
        ("microbe", "virus"), ("climat", "météo"), ("étoile", "planète"),
        ("filtre", "membrane"), ("circuit", "carte"), ("moteur", "générateur"),
        ("lentille", "miroir"), ("laser", "radar"), ("donnée", "mesure"),
        ("polygone", "triangle"), ("gravité", "masse"),
    ],
}

ICEBREAKERS = {
    "rencontre": [
        "Quelle compétence aimerais-tu apprendre cette année ?",
        "Quel projet t'a donné envie de rejoindre le club ?",
        "Quel conseil donnerais-tu à une nouvelle recrue ?",
        "Quelle rencontre a changé ta façon de travailler ?",
        "Quel est ton talent caché ?",
        "Quel lieu du campus te rappelle un bon souvenir ?",
        "Quel membre du club aimerais-tu remercier et pourquoi ?",
        "Quel défi aimerais-tu relever avec ton équipe ?",
        "Quel objet te représente le mieux aujourd'hui ?",
        "Quelle activité te redonne de l'énergie ?",
        "Quel est le meilleur compliment professionnel reçu ?",
        "Quel projet voudrais-tu découvrir de l'intérieur ?",
        "Quelle valeur d'équipe t'aide quand tu es sous pression ?",
        "Quel ancien projet du club aimerais-tu comprendre ?",
        "Qu'aimerais-tu transmettre à la promotion suivante ?",
        "Quelle personne t'a encouragé à essayer quelque chose de nouveau ?",
        "Quel rôle te met le plus à l'aise dans une équipe ?",
        "Quelle activité communautaire aimerais-tu organiser ?",
        "Quel endroit aimerais-tu faire découvrir au club ?",
        "Qu'est-ce qui te donne le sentiment d'appartenir à une équipe ?",
    ],
    "projets": [
        "Imagine un projet utile avec un budget de 1 000 FCFA.",
        "Quel besoin de ta communauté reste trop peu entendu ?",
        "Quelle erreur d'équipe t'a le plus appris ?",
        "Présente ton projet en une phrase sans jargon.",
        "Si tu pouvais ajouter une compétence à ton équipe, laquelle ?",
        "Quel petit test permettrait de valider ton idée demain ?",
        "Décris un problème local sous la forme d'une question.",
        "Quel risque faudrait-il expliquer au prochain chef de projet ?",
        "Quelle méthode de mesure d'impact te semble la plus honnête ?",
        "Quel objet ordinaire réinventerais-tu pour le campus ?",
        "Quel partenariat improbable pourrait aider ton équipe ?",
        "Quelle décision collective a été la plus difficile ?",
        "Quel projet aurais-tu aimé voir démarrer plus tôt ?",
        "Comment célébrer une petite victoire d'équipe ?",
        "Quel obstacle as-tu surmonté grâce à une autre personne ?",
        "Quelle donnée te manque pour prendre ta prochaine décision ?",
        "Quel est le meilleur apprentissage d'un projet interrompu ?",
        "Quelle solution locale te rend fier ou fière ?",
        "Quelle habitude rend vos réunions plus efficaces ?",
        "Que changerais-tu dans la façon de transmettre un projet aux nouveaux ?",
    ],
    "fun": [
        "Quel superpouvoir choisirais-tu pour finir un projet en retard ?",
        "Si ton pôle était un plat, lequel serait-il ?",
        "Quelle chanson accompagnerait ton prochain pitch ?",
        "Quel animal représenterait ta façon de travailler ?",
        "Raconte une journée parfaite en trois mots.",
        "Quelle invention farfelue créerais-tu pour le campus ?",
        "Quel slogan donnerais-tu à votre équipe ?",
        "Si tu échangeais ton rôle une journée, qui choisirais-tu ?",
        "Quelle chose minuscule t'a rendu heureux cette semaine ?",
        "Quelle règle amusante ajouterais-tu à la prochaine réunion ?",
        "Quel serait le titre d'un film sur votre projet ?",
        "Quelle tradition du club aimerais-tu inventer ?",
        "Si tu créais une mascotte du club, à quoi ressemblerait-elle ?",
        "Quelle compétence improbable te serait utile pendant un concours ?",
        "Quel objet emmènerais-tu sur une île pour monter un projet ?",
        "Raconte une réussite récente comme si c'était une bande-annonce.",
        "Quel mot inventerais-tu pour décrire votre équipe ?",
        "Si la prochaine réunion avait un thème musical, lequel choisirais-tu ?",
        "Quel personnage fictif recruterais-tu dans ton pôle ?",
        "À quoi ressemblerait une journée sans téléphone dans le club ?",
    ],
}

# (theme, question, four choices, correct choice index)
QUIZ = [
    ("sciences", "Combien de côtés a un hexagone ?", ["5", "6", "7", "8"], 1),
    ("sciences", "Quelle unité mesure une tension électrique ?", ["Watt", "Volt", "Ampère", "Ohm"], 1),
    ("sciences", "Quelle unité mesure un courant électrique ?", ["Volt", "Joule", "Ampère", "Newton"], 2),
    ("sciences", "Quel gaz est le plus abondant dans l'air ?", ["Oxygène", "Azote", "Argon", "Hélium"], 1),
    ("sciences", "Combien de degrés fait un angle droit ?", ["45", "60", "90", "180"], 2),
    ("sciences", "Combien d'octets contient un kilo-octet binaire (KiB) ?", ["100", "512", "1000", "1024"], 3),
    ("sciences", "Que vaut 2 à la puissance 5 ?", ["16", "25", "32", "64"], 2),
    ("sciences", "Quel organe assure principalement la circulation du sang ?", ["Foie", "Cœur", "Poumon", "Rein"], 1),
    ("sciences", "Quelle est la formule chimique de l'eau ?", ["CO2", "H2O", "O2", "NaCl"], 1),
    ("sciences", "Quel phénomène transforme la lumière en énergie chimique chez les plantes ?", ["Osmose", "Photosynthèse", "Condensation", "Érosion"], 1),
    ("géographie", "Sur quel continent se trouve le Sénégal ?", ["Asie", "Afrique", "Europe", "Amérique"], 1),
    ("géographie", "Quel océan borde la côte ouest du Sénégal ?", ["Indien", "Pacifique", "Atlantique", "Arctique"], 2),
    ("géographie", "Quelle est la capitale du Sénégal ?", ["Dakar", "Thiès", "Kaolack", "Saint-Louis"], 0),
    ("géographie", "Quel fleuve porte aussi le nom du Sénégal ?", ["Nil", "Fleuve Sénégal", "Niger", "Gambie"], 1),
    ("géographie", "Quel continent contient le désert du Sahara ?", ["Afrique", "Océanie", "Europe", "Amérique"], 0),
    ("géographie", "Quelle ligne imaginaire partage la Terre en deux hémisphères ?", ["Méridien", "Équateur", "Tropique", "Axe"], 1),
    ("géographie", "Combien de continents compte le modèle à sept continents ?", ["5", "6", "7", "8"], 2),
    ("géographie", "Quelle direction indique habituellement le haut d'une carte orientée au nord ?", ["Est", "Sud", "Nord", "Ouest"], 2),
    ("histoire", "Dans quel siècle se situe l'année 1900 ?", ["18e", "19e", "20e", "21e"], 1),
    ("histoire", "Combien d'années compte un siècle ?", ["10", "50", "100", "1000"], 2),
    ("histoire", "Quel continent a vu naître l'écriture cunéiforme en Mésopotamie ?", ["Afrique", "Asie", "Europe", "Océanie"], 1),
    ("histoire", "Que désigne le mot « archive » ?", ["Un document conservé", "Un repas", "Un métal", "Une unité"], 0),
    ("histoire", "À quelle époque appartient l'an 1 ?", ["Avant notre ère", "Notre ère", "Préhistoire", "Âge du bronze"], 1),
    ("histoire", "Combien d'années compte une décennie ?", ["5", "10", "20", "100"], 1),
    ("entrepreneuriat", "Qu'est-ce qu'un prototype ?", ["Un produit fini en série", "Une première version à tester", "Un budget", "Une facture"], 1),
    ("entrepreneuriat", "Que décrit un budget prévisionnel ?", ["Dépenses et recettes prévues", "Un résultat garanti", "Le nombre de membres", "Un organigramme"], 0),
    ("entrepreneuriat", "Avant d'affirmer un impact mesuré, que faut-il préciser ?", ["Une preuve et une méthode", "Un slogan", "Une couleur", "Un logo"], 0),
    ("entrepreneuriat", "Qui exprime un besoin dans une enquête terrain ?", ["La population concernée", "Seulement le sponsor", "Seulement le jury", "Le hasard"], 0),
    ("entrepreneuriat", "Une dépense déjà réalisée est-elle une projection ?", ["Oui", "Non", "Toujours", "Jamais connue"], 1),
    ("entrepreneuriat", "Pourquoi tester une idée avec des utilisateurs ?", ["Comprendre leurs besoins", "Éviter toute discussion", "Garantir un prix", "Remplacer la comptabilité"], 0),
    ("entrepreneuriat", "Que permet un indicateur suivi dans le temps ?", ["Comparer une évolution", "Deviner sans données", "Supprimer les sources", "Éviter les retours"], 0),
    ("entrepreneuriat", "Quel document conserve une décision prise en réunion ?", ["Procès-verbal", "Affiche", "Carte", "Catalogue"], 0),
    ("sciences", "Quel nombre représente le symbole romain X ?", ["5", "10", "50", "100"], 1),
    ("sciences", "Combien de millimètres y a-t-il dans un mètre ?", ["10", "100", "1000", "10000"], 2),
    ("sciences", "Quelle unité correspond à une fréquence ?", ["Hertz", "Pascal", "Watt", "Tesla"], 0),
    ("sciences", "Quel organe permet principalement d'échanger l'oxygène de l'air ?", ["Estomac", "Poumons", "Reins", "Peau"], 1),
    ("sciences", "Quelle valeur décimale vaut 1/4 ?", ["0,2", "0,25", "0,4", "0,5"], 1),
    ("sciences", "Quel élément chimique a pour symbole Fe ?", ["Fluor", "Fer", "Francium", "Phosphore"], 1),
    ("sciences", "Que mesure un thermomètre ?", ["Température", "Pression", "Vitesse", "Masse"], 0),
    ("sciences", "Quelle est la somme des angles d'un triangle plan ?", ["90°", "120°", "180°", "360°"], 2),
    ("géographie", "Quel océan est à l'est de l'Afrique ?", ["Atlantique", "Indien", "Arctique", "Pacifique"], 1),
    ("géographie", "Dans quel hémisphère se situe Dakar ?", ["Nord", "Sud", "Les deux", "Aucun"], 0),
    ("géographie", "Quelle direction se trouve à l'opposé de l'est ?", ["Nord", "Sud", "Ouest", "Nord-est"], 2),
    ("géographie", "Quel instrument aide à repérer les points cardinaux ?", ["Baromètre", "Boussole", "Thermomètre", "Balance"], 1),
    ("géographie", "Quel continent est traversé par l'équateur ?", ["Afrique", "Europe", "Antarctique", "Aucun"], 0),
    ("géographie", "Quel est le principal astre au centre du système solaire ?", ["Lune", "Mars", "Soleil", "Terre"], 2),
    ("histoire", "Quel support utilise-t-on pour établir une chronologie ?", ["Dates", "Couleurs", "Masses", "Distances"], 0),
    ("histoire", "Quel siècle correspond à l'année 2001 ?", ["19e", "20e", "21e", "22e"], 2),
    ("histoire", "Quelle période précède l'Antiquité dans la classification usuelle ?", ["Moyen Âge", "Préhistoire", "Époque moderne", "Renaissance"], 1),
    ("histoire", "Une source primaire est-elle créée à l'époque étudiée ?", ["Oui", "Non", "Jamais", "Seulement en ligne"], 0),
    ("histoire", "Combien d'années compte un millénaire ?", ["100", "500", "1000", "10000"], 2),
    ("histoire", "Pourquoi conserver les sources d'une affirmation historique ?", ["Pour pouvoir la vérifier", "Pour rallonger le texte", "Pour masquer l'auteur", "Pour effacer la date"], 0),
    ("entrepreneuriat", "Qu'est-ce qu'une hypothèse de projet ?", ["Une idée à vérifier", "Un résultat certain", "Un reçu", "Une loi physique"], 0),
    ("entrepreneuriat", "Quel montant est une dépense réalisée ?", ["Un coût payé", "Un prix imaginé", "Un don prévu", "Une cible"], 0),
    ("entrepreneuriat", "Que facilite un calendrier de projet ?", ["Le suivi des étapes", "La suppression des rôles", "L'absence de réunion", "Le hasard"], 0),
    ("entrepreneuriat", "Quel rôle joue une preuve dans un rapport d'impact ?", ["Étayer une affirmation", "Remplacer un bénéficiaire", "Décorer le document", "Garantir un financement"], 0),
    ("entrepreneuriat", "Que signifie améliorer un prototype après un test ?", ["Itérer", "Abandonner toute mesure", "Copier", "Facturer"], 0),
    ("entrepreneuriat", "Qui valide qu'une solution répond à un besoin ?", ["Les personnes concernées", "Seulement le logo", "Le hasard", "Une affiche"], 0),
    ("entrepreneuriat", "À quoi sert un retour d'utilisateur ?", ["Comprendre et corriger", "Déclarer un profit", "Changer une date", "Remplacer une source"], 0),
    ("entrepreneuriat", "Quelle différence entre recette et bénéfice ?", ["Le bénéfice déduit les charges", "Aucune", "La recette est une dépense", "Le bénéfice est un stock"], 0),
]


def choose(content, theme, used):
    pool = [(key, index, item) for key, items in content.items()
            for index, item in enumerate(items) if theme in ("mix", key)]
    available = [entry for entry in pool if f"{entry[0]}:{entry[1]}" not in used]
    if not available:
        raise ValueError("Aucun contenu inédit pour ce thème")
    key, index, item = secrets.choice(available)
    used.append(f"{key}:{index}")
    return item


def choose_quiz(theme, used):
    pool = [index for index, item in enumerate(QUIZ) if theme in ("mix", item[0])]
    available = [index for index in pool if index not in used]
    if not available:
        raise ValueError("Aucune question inédite pour ce thème")
    index = secrets.choice(available)
    used.append(index)
    theme_name, question, choices, correct = QUIZ[index]
    order = secrets.SystemRandom().sample(range(4), 4)
    return theme_name, question, [choices[i] for i in order], order.index(correct)
