import json
from pathlib import Path

"""Voices of Enactus ESP. Quotes are distinguished from editorial PV summaries."""


def minute(key, speaker, title, theme, body, challenge, *, quote=None, year=None,
           date=None, asset=None, source='Archives Enactus ESP', original=None, note=None):
    return {'id':'minute-'+key, 'title':title, 'speaker':speaker, 'theme':theme,
        'description':body, 'challenge':challenge, 'quote':quote, 'original_text':original,
        'editorial_note':note, 'media_type':'minute_enacteur', 'year':year,
        'spoken_on':date, 'image_asset':asset, 'source_label':source,
        'project_id':None, 'file_id':None, 'external_url':None, 'source_url':None,
        'is_featured':True}


MINUTES = [
 minute('aita-dia-2020','Aïta Ndir DIA','Profiter, apprendre, essayer !','Curiosité',
  'En 2020, Aïta ouvre la première Minute de l’enacteur en ligne. Confinée à la maison, elle choisit de regarder aussi ce que cette pause rend possible : du temps en famille, de nouvelles expériences et même ses premiers stickers. Son invitation est simple et joyeuse : faire de cette période une occasion d’apprendre et de vivre pleinement.',
  'Choisis une petite chose que tu remets à plus tard. Consacre-lui dix minutes aujourd’hui et raconte ce que tu as découvert.',
  quote='Profitons de cette situation pour acquérir de nouvelles connaissances, faire de nouvelles choses, rencontrer de nouvelles personnes.',year=2020,
  source='Thread de la Minute de l’enacteur · 2020, partagé par Enactus ESP',
  original="Salut les lems ❤️\nJe m’appelle Aïta Ndir DIA, membre d’Enactus ESP. Je suis ravie de faire la première minute de l’enacteur en ligne. Le principe est simple : on va discuter ensemble 😊 (je vais surtout parler 😂).\n\nCes derniers mois, nous sommes presque tous à la maison. Ceci m’a permis de profiter des précieux moments en famille, de la nourriture et de mon lit 🤭. Je me suis rendue compte que j’avais maintenant la possibilité de faire tout ce que je ne pouvais pas avant. Par exemple, j’ai fait mes premiers stickers !\n\nLe maître mot : PROFITER ! Profitons de cette situation pour acquérir de nouvelles connaissances, faire de nouvelles choses, rencontrer de nouvelles personnes. Vivez pleinement votre vie 😊.\n\nAh, et proposez-moi des challenges contre l’ennui. Kiss ❤️",note='Extraits du thread, avec ponctuation harmonisée.'),
 minute('seydina-toure','Seydina TOURE','Et si on parlait de charisme ?','Confiance',
  'Seydina commence sa Minute en posant une question à l’équipe : qu’est-ce que le charisme ? Il propose une définition et ouvre une conversation sur la présence et la manière de s’adresser aux autres.',
  'Pense à quelqu’un dont la présence t’inspire. Est-ce son écoute, sa clarté, son assurance ou sa manière de faire une place aux autres ?',
  original='Slt guys, j’espère que vous allez bien. Aujourd’hui, je suis là pour vous parler du charisme. Euh, c’est quoi le charisme ? On peut le définir comme étant la qualité d’une personne qui a le don de plaire, de s’imposer dans la vie publique.',
  year=2020, source='Archives Enactus ESP'),
 minute('ibrahima-cisse','Ibrahima CISSE','La vie n’est pas une compétition','Confiance',
  'Alors Team Leader d’Enactus ESP, Ibrahima invite l’équipe à sortir de la comparaison permanente. Se mesurer aux autres peut décourager et détourner de son propre chemin. Il propose de regarder plutôt son évolution et ses aptitudes, sans confondre progrès personnel et valeur d’une personne.',
  'Note un progrès que tu as fait depuis le mois dernier. Compare-toi à ton point de départ, puis célèbre le chemin parcouru.',
  quote='La vie n’est pas une compétition.',year=2020,asset='assets/heritage/minute-ibrahima-cisse.jpg',
  source='Photothèque Enactus ESP',
  original="La vie n’est pas une compétition.\n\nLa comparaison : c’est la chose la plus ralentissante et même la plus déstabilisante de tous les méfaits de la compétition. Beaucoup de personnes souffrent de complexes et n’arrivent pas à se lancer dans quoi que ce soit car elles ont été comparées à d’autres personnes, puis elles en ont pris l’habitude.\n\nFixer sa valeur en fonction d’une personne est très dévalorisant. Pour autant, la comparaison peut être utile. Pour qu’elle puisse servir efficacement elle doit être portée sur ses performances et ses aptitudes, pas ceux des autres.\n\nVous avez une bonne raison de ne pas vous comparer aux autres : vous êtes UNIQUES, avec une histoire UNIQUE et un destin qui vous est propre.\n\nArrêtez de vous comparer et de comparer. Vous en serez plus heureux.",note=None),
 minute('betty-kane','Betty KANE','Cultiver la maîtrise de soi','Équilibre',
  'Betty adresse à l’équipe une invitation directe : cultiver la maîtrise de soi. Quelques mots suffisent pour lancer une réflexion sur la façon de réagir, d’écouter et de choisir sa réponse, même lorsqu’une situation nous bouscule.',
  'Lors du prochain désaccord, prends le temps de reformuler ce que tu as compris avant de répondre.',
  quote='Je me nomme Betty Kane et je vous exhorte à cultiver la maîtrise de soi !',
  year=2020, asset='assets/heritage/minute-betty-kane.jpg',source='Photothèque Enactus ESP',note=None),
 minute('moustapha-mbaye','Mouhamadou Moustapha MBAYE','Un essai raté ne ferme pas le chemin','Persévérance',
  'Mouhamadou Moustapha partage un rappel qui parle à toute équipe projet : ne pas réussir une fois ne signifie pas que tout s’arrête. Une tentative difficile peut devenir une occasion d’apprendre, de changer un détail et de poursuivre avec plus de recul.',
  'Reprends un essai qui n’a pas fonctionné. Écris ce qu’il t’a appris et une seule chose à changer pour la prochaine tentative.',
  quote='Ce n’est pas faute d’avoir réussi que tout s’arrête là.',year=2020, asset='assets/heritage/minute-moustapha-mbaye.jpg',source='Photothèque Enactus ESP',note=None),
 minute('papa-idrissa-wade','Papa Idrissa WADE','Retrouver sa source de motivation','Engagement',
  'La Minute de Papa Idrissa conserve un mot-clé : source de motivation. Une invitation à revenir à ce qui nous fait agir lorsque le quotidien, les difficultés ou la fatigue prennent toute la place.',
  'Complète cette phrase : « Je m’engage parce que… ». Garde-la près de ta prochaine tâche.',quote='Mot-clé : source de motivation !',
  year=2020, asset='assets/heritage/minute-papa-idrissa-wade.jpg',source='Photothèque Enactus ESP',note=None),
]

# Meeting summaries retain dates and do not invent quotations or portraits.
for date, speaker, title, theme, body, challenge in json.loads(
        Path(__file__).with_name('club_voices_2023.json').read_text(encoding='utf-8')):
    MINUTES.append(minute(date, speaker, title, theme, body, challenge,
                         year=2023, date=date, source='Archives Enactus ESP'))

# These are editorial summaries, never presented as verbatim speeches.
PV_MINUTES = [
 ('2024-11-14','Arame KEBE','Faire une place aux liens','Entraide',
  'Arame invite l’équipe à organiser aussi des jeux et des activités pour mieux se connaître. Le travail compte ; les liens qui donnent envie de revenir comptent également.',
  'Propose un petit moment collectif qui permet de rencontrer quelqu’un avec qui tu échanges peu.'),
 ('2024-11-19','Mohamed El Amine DIA et Mohamed LO','Être présents, se motiver','Engagement',
  'La Minute rappelle l’importance de prévenir en cas d’indisponibilité et de s’encourager mutuellement. Elle recentre la préparation des compétitions sur le travail concret, tout en ouvrant une nouvelle période d’engagement.',
  'Pour ta prochaine tâche, nomme une contribution précise et préviens l’équipe tôt si tu rencontres un blocage.'),
 ('2024-11-23','Sady et Mamady','Raconter ses apprentissages avec Enactus','Transmission',
  'Leurs expériences montrent que l’engagement dans Enactus peut compter dans un parcours professionnel. Encore faut-il savoir expliquer la structure et décrire ce que l’on a réellement fait et appris.',
  'Prépare trois phrases sur une contribution réelle : le contexte, ton action et ce que tu as appris.'),
 ('2024-11-30','Caroline','Revenir et trouver sa place','Confiance',
  'Caroline partage son envie d’être davantage présente et de mieux s’intégrer à l’équipe. Sa Minute rappelle qu’une place dans le collectif se construit aussi en revenant, petit à petit.',
  'Prends des nouvelles d’une personne qui revient dans l’équipe et propose-lui un premier point de contact.'),
 ('2024-12-10','Fedior','New Era : garder le cap sur la mission','Engagement',
  'Fedior salue une équipe plus engagée et plus dynamique. Il invite à rester concentrés sur la mission, sur ce que l’on apporte aux autres et sur des échanges qui font avancer le travail.',
  'Au début d’une réunion, formule en une phrase ce que le groupe doit réussir à décider.'),
 ('2024-12-19','Ousseynou BOYE','Connaître sa valeur','Confiance',
  'Ousseynou propose de réfléchir à la vision que chacun a de lui-même. Son message invite à reconnaître sa valeur et à réfléchir avant d’agir, plutôt qu’à laisser toutes les situations définir qui l’on est.',
  'Note une qualité que tu apportes à l’équipe et une manière de la mettre en action cette semaine.'),
 ('2024-12-24','Birahim SAMB','Transmettre l’élan aux nouvelles recrues','Transmission',
  'Birahim insiste sur la motivation à transmettre à celles et ceux qui arrivent. La New Era doit devenir un objectif compris et partagé, puis des actions utiles au but premier du club.',
  'Explique un objectif de ton équipe à une nouvelle recrue avec un exemple de contribution accessible.'),
 ('2025-01-07','Ndeye Awa SEYE','Choisir d’appartenir à une équipe','Confiance',
  'Ndeye Awa exprime sa reconnaissance d’avoir rejoint Enactus. Les rencontres et les intégrations l’ont aidée à s’ouvrir davantage ; elle est fière de ce choix et de la place qu’elle construit dans le collectif.',
  'Raconte à un binôme un moment où une équipe t’a aidé à faire un pas en avant.'),
 ('2025-01-09','Yaye Adama GUISSÉ','Demander simplement : comment vas-tu ?','Entraide',
  'Pour sa première Minute, Yaye Adama rappelle l’importance de demander aux autres comment ils vont. Un encouragement ou une question attentive peut ouvrir une place à ce que l’on ne voit pas dans une réunion.',
  'Demande à quelqu’un comment il va, puis laisse-lui réellement le temps de répondre.'),
 ('2025-01-14','Aminata FALL','Partager son enthousiasme','Entraide',
  'Aminata est heureuse d’être là et enthousiaste à l’idée de connaître l’équipe. Elle partage cette énergie positive et souhaite aux autres de vivre la même joie.',
  'Partage une bonne nouvelle avec l’équipe et invite quelqu’un d’autre à faire de même.'),
 ('2025-01-16','Mouhamadou Fadel NDIAYE','Apprendre en transmettant','Transmission',
  'Fadel apprécie de pouvoir partager ses connaissances en génie des procédés et échanger avec les autres. L’accueil et les présentations lui donnent le sentiment d’apprendre dans une famille.',
  'Propose une explication de cinq minutes sur une compétence que tu peux transmettre.'),
 ('2025-01-21','Aïcha NDIAYE et Mamadou Lamine BEYE','Faire une place à ses engagements','Équilibre',
  'Cette Minute croise l’envie de développer ses compétences et la réalité de responsabilités multiples. Elle ouvre une réflexion sur la façon de contribuer utilement tout en reconnaissant ses priorités et ses limites.',
  'Choisis un engagement réaliste pour cette semaine et annonce clairement ce que tu peux prendre en charge.'),
 ('2025-01-23','Hamidou SAMASSA','Les petits actes qui s’accumulent','Persévérance',
  'Inspiré par sa lecture de L’effet cumulé, Hamidou montre comment les petites décisions répétées peuvent façonner une habitude et une trajectoire sur le long terme.',
  'Choisis une habitude de cinq minutes et observe pendant une semaine ce qui te permet de la tenir.'),
 ('2025-01-28','Alimatou Sadiya THIAM','Faire connaître Enactus autour de soi','Transmission',
  'Après les exposés, Alimatou confie au groupe ayant proposé la meilleure définition la mission de faire connaître Enactus autour de lui. Comprendre doit aussi permettre de transmettre.',
  'Présente Enactus à une personne qui ne connaît pas le mouvement, avec un exemple concret du club.'),
 ('2025-02-04','Mohamed DIASSÉ','Résoudre des problèmes avec le cœur','Curiosité',
  'Mohamed est heureux d’intégrer une équipe dynamique qui agit avec le cœur. Il relie cette expérience à sa vision de l’ingénieur : résoudre des problèmes, tout en apprenant quelque chose à chaque réunion.',
  'Note ce que tu as appris à la dernière réunion et une manière de l’utiliser.'),
 ('2025-02-06','Adja Aïssatou LAYE','Oser se lancer','Confiance',
  'Adja Aïssatou encourage l’équipe à oser, à profiter de la vie et à ne pas laisser la peur dresser toutes les barrières. Son intervention porte une énergie de passage à l’action.',
  'Identifie une première action assez petite pour être faite aujourd’hui, même si tu ne maîtrises pas tout.'),
 ('2025-02-11','Mariama DIOP','Le premier pas de l’autre côté de la peur','Confiance',
  'Mariama raconte comment elle a choisi de dépasser sa réserve. Elle invite à chercher ce qui retient, à prendre une décision et à sauter le pas ; rejoindre Enactus fait partie de ce chemin dont elle est fière.',
  'Prépare une courte prise de parole, essaie-la avec un binôme, puis propose-la dans ton équipe.'),
 ('2025-02-18','Fatoumata SOW','Apprendre à compter sur les autres','Entraide',
  'L’organisation d’un atelier a appris à Fatoumata à demander de l’aide, à faire confiance et à persévérer lorsque tout ne se déroule pas comme prévu. Le collectif devient une ressource pour avancer.',
  'Sur une tâche difficile, formule une demande d’aide précise : le besoin, le point bloquant et l’appui souhaité.'),
 ('2025-03-04','Amdy Moustapha THIAM','Les voyages qui nous rapprochent','Entraide',
  'Amdy rappelle la place particulière des voyages dans l’expérience Enactus : le terrain donne du sens aux formations et aux projets, et les moments partagés tissent des liens qui durent.',
  'Avec quelqu’un qui a participé à une mission, parle d’un apprentissage de terrain et d’un souvenir collectif.'),
 ('2025-03-25','Anne Marie Kouta Da-Rosa et Fatou GAYE','Contribuer, même sans partir','Engagement',
  'Cette Minute parle du soutien qui aide à retrouver sa motivation et de l’investissement dans la préparation d’un voyage. Partir compte, mais contribuer avant le départ donne aussi sa place dans l’aventure.',
  'Trouve une contribution utile à une mission avant ou après le départ : préparation, documentation ou restitution.'),
 ('2025-03-29','Anna SARR','Avancer ensemble, avec exigence et confiance','Transmission',
  'Anna dit son attachement à une équipe qui s’engage et fait bien les choses. Elle encourage à ne pas avoir peur des critiques et à gagner ensemble, en gardant aussi la mémoire du professeur Ndiaga NDIAYE.',
  'Demande un retour précis sur ton travail et choisis une amélioration à mettre en œuvre.'),
 ('2025-04-15','Fatoumata Binetou Rassoul DIALLO','L’engagement se voit aujourd’hui','Engagement',
  'Fatoumata appelle à rendre l’engagement visible dans les projets. Chacun a du potentiel ; l’équipe a besoin de contributions concrètes, et les personnes qui cherchent leur place peuvent demander une tâche utile.',
  'Propose une action que tu peux terminer cette semaine et partage son résultat avec ton équipe.'),
 ('2025-04-29','Alimatou Sadiya THIAM','Prendre l’initiative sans attendre','Engagement',
  'Après le Salon du Polytechnicien, Alimatou revient sur les efforts de préparation et la mobilisation de l’équipe. Elle invite à s’activer sans attendre une relance et à maintenir l’exigence collective.',
  'Repère une tâche utile qui n’a pas de responsable et propose de la prendre en charge après échange avec l’équipe.'),
]
for date, speaker, title, theme, body, challenge in PV_MINUTES:
    parts = date.split('-')
    label = 'PV du '+parts[2]+'.'+parts[1]+'.'+parts[0]+' · Enactus ESP'
    MINUTES.append(minute(date,speaker,title,theme,body,challenge,year=int(parts[0]),date=date,
        source='Archives Enactus ESP',note=None))

HOMMAGE = {
 'id':'hommage-ndiaga-ndiaye', 'title':'Professeur Ndiaga NDIAYE',
 'subtitle':'Faculty Advisor · un mentor au cœur de notre histoire', 'entry_type':'hommage',
 'year':None, 'archive_item_id':None, 'file_id':None, 'external_url':None,
 'score_value':None, 'score_label':None, 'order_index':1, 'is_featured':True,
 'image_asset':'assets/heritage/professeur-ndiaga-ndiaye.jpg',
 'source_label':'Hommage partagé par Enactus ESP · Photothèque Enactus ESP',
 'description':
 "Il était de ceux qui accompagnent une équipe bien au-delà des réunions. Faculty Advisor d’Enactus ESP, le professeur Ndiaga NDIAYE a guidé des générations d’étudiants, encouragé leurs ambitions et mis sa générosité et son réseau au service de leurs projets. Son accompagnement fait partie de ce que le club transmet aujourd’hui.\n\n"
 "Enactus ESP garde en mémoire un mentor et un conseiller pédagogique dévoué, sa bienveillance, son sourire dans les moments de collaboration et sa présence auprès des jeunes entrepreneurs sociaux. Son départ laisse un vide ; son engagement continue d’inspirer celles et ceux qu’il a accompagnés.\n\n"
 "L’équipe présente ses sincères condoléances à sa famille, à ses proches et à la communauté Enactus Sénégal. Nous choisissons de garder vivant cet héritage en poursuivant le travail avec exigence, solidarité et attention aux autres.\n\n"
 "Repose en paix, Professeur. Que Jannatoul Firdaus soit ta demeure éternelle. Until we see each other again.",
}

MEETING_HIGHLIGHTS = [
 {'id':'pv-methodes-2025','title':'Des réunions qui préparent le terrain','year':2025,
  'description':'Les réunions de janvier et février 2025 accueillent des échanges sur les ODD, le business model, l’immersion et le transfert de technologies. Ces séances forment un chemin : comprendre un besoin, réfléchir au modèle et préparer une action avec les communautés.',
  'source_label':'PV Enactus ESP · janvier–février 2025'},
 {'id':'pv-restructuration-2026','title':'2026 : reprendre, questionner, construire','year':2026,
  'description':'Au printemps 2026, l’équipe relance son travail : réexaminer les projets, clarifier les priorités, répartir les responsabilités et solliciter les mentors. L’histoire conserve aussi ces moments où l’équipe prend le temps de choisir sa prochaine direction.',
  'source_label':'PV Enactus ESP · 14 avril et 12, 19, 21 mai 2026'},
]
MEETING_HIGHLIGHTS.extend([{'id': 'immersion-juin-2021', 'title': 'Juin 2021 : apprendre à regarder autrement', 'year': 2021, 'image_asset': 'assets/heritage/resources/immersion-equipe-2021.jpg', 'source_label': 'Photothèque Enactus ESP', 'description': 'En juin 2021, l’équipe part à la rencontre des communautés. Les échanges et l’observation des activités orientent la réflexion autour de la transformation alimentaire et de l’énergie. À Kolda, Bignarabé, Saré Amidou et Santankoy font partie des localités rencontrées.\n\nLe voyage demande de laisser une place aux personnes qui vivent la situation chaque jour. Les équipements, les matières disponibles, les habitudes et les contraintes deviennent des questions à travailler ensemble. Le retour à l’ESP ouvre ensuite le temps de la conception et des essais.'}, {'id': 'hafe-aout-2022', 'title': 'Hafé : apprendre en faisant', 'year': 2022, 'image_asset': 'assets/heritage/resources/hafe-atelier-2022.jpg', 'source_label': 'Photothèque Enactus ESP', 'description': 'En août 2022, les ateliers de transfert réunissent participantes et Enacteurs à Hafé. Autour des ingrédients et des gestes de transformation, l’apprentissage se fait ensemble : on prépare, on pratique et on échange.\n\nCes moments donnent tout son sens à la transmission. Le travail ne se limite pas à expliquer une méthode ; il consiste aussi à accompagner sa prise en main et à tenir compte des moyens disponibles. La rencontre collective du 21 août garde le souvenir des personnes réunies autour de cette démarche.'}, {'id': 'biogaz-apprentissage-2022', 'title': 'Biogaz : une idée, du terrain et des essais', 'year': 2022, 'image_asset': 'assets/heritage/resources/biogaz-travail-terrain-2022.jpg', 'source_label': 'Photothèque Enactus ESP', 'description': 'Le projet « Biogaz + Transformations » associe deux pistes : valoriser les déchets organiques et transformer davantage les ressources locales. En 2022, l’équipe travaille la modélisation d’un biodigesteur et la préparation d’un prototype, en parallèle des produits alimentaires.\n\nLa réflexion prévoit une formation, une pratique accompagnée et des supports d’installation et d’entretien pour les communautés. Une idée technique n’est utile que si son fonctionnement quotidien, sa maintenance et les responsabilités sont compris. Cette préparation ouvre un travail d’essais et d’apprentissage avec les communautés.'}, {'id': 'formation-collective-2023', 'title': '2023 : se former avant de partir', 'year': 2023, 'image_asset': None, 'source_label': 'Archives Enactus ESP', 'description': 'En février 2023, les réunions suivent une progression : comprendre les ODD, découvrir l’entrepreneuriat social, explorer le brainstorming et le design thinking, puis travailler le ciblage, l’immersion, le transfert et le recueil d’impact.\n\nLes nouveaux membres sont invités à apprendre avec les autres et à s’appuyer sur les conseillers pédagogiques. Les études gardent toute leur place. Enactus ESP devient un terrain d’application collectif où l’on prépare une action avant de rejoindre les communautés, puis où l’on revient discuter de ce qui a réellement fonctionné.'}])
_TRAVEL_GALLERIES = {'immersion-juin-2021': [{'asset': 'assets/heritage/resources/immersion-observation-2021.jpg', 'caption': 'Observer les équipements et échanger sur le terrain · juin 2021'}, {'asset': 'assets/heritage/resources/immersion-eau-2021.jpg', 'caption': 'Comprendre les gestes du quotidien · juin 2021'}, {'asset': 'assets/heritage/resources/immersion-depart-2021.jpg', 'caption': 'En route avec l’équipe · juin 2021'}], 'hafe-aout-2022': [{'asset': 'assets/heritage/resources/hafe-collectif-2022.jpg', 'caption': 'Enacteurs et participantes réunis à Hafé · août 2022'}]}
for row in MEETING_HIGHLIGHTS:
    row['gallery'] = _TRAVEL_GALLERIES.get(row['id'], [])
    row.update(media_type='recit',project_id=None,file_id=None,external_url=None,
               source_url=None,is_featured=True)
    row.setdefault('image_asset', None)
