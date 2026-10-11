"""Photographs selected from the club's original photo collection and field folders."""
PHOTO_STORIES = [
 ('mobigel-prototypes','MobiGel : deux prototypes, un même élan','Deux vélos équipés racontent la riposte imaginée pendant la Covid-19 : distribuer du gel sans contact et aller vers le public pour sensibiliser. Avant les prix, il y a ces essais concrets, fabriqués et confrontés à l’usage.',2020,'mobigel'),
 ('deconaane-filtre','Deconaane : rendre une idée tangible','Autour de l’accès à l’eau, Deconaane transforme une idée en dispositif concret. Filtration, stockage et entretien deviennent des questions de terrain : comment rendre la solution accessible et la faire fonctionner dans le quotidien des communautés ?',None,'deconaane'),
 ('dimbali-gie-favec','Dimbali : des produits, des femmes, un collectif','Les produits du GIE FAVEC incarnent le cœur de Dimbali : transformer une ressource locale avec les personnes qui font vivre l’activité. Les savoir-faire, l’organisation et les liens comptent autant que le produit fini.',None,'dimbali'),
 ('world-cup-2018-delegation','2018 : le Sénégal jusqu’à San José','Le drapeau sénégalais et l’équipe réunie gardent la mémoire de la première participation effective à la World Cup, avec Dimbali et Deconaane. Le parcours mène à la demi-finale et au Top 12.',2018,None),
 ('world-cup-2022-delegation','2022 : une nouvelle génération à Porto Rico','Dimbali et Mën Nañ accompagnent le retour du club sur la scène mondiale. La World Cup 2022 rassemble une nouvelle génération autour d’un parcours qui mène à la demi-finale et nourrit les liens du collectif.',2022,None),
 ('world-cup-2022-emotion','Porto Rico : le collectif, aussi dans l’émotion','À Porto Rico, le parcours se vit aussi dans les moments partagés. Une étreinte, une présence, une équipe réunie : derrière la compétition, il y a des liens construits au fil des préparations et du voyage.',2022,None),
 ('haffe-2025-ecoute','Haffé : prendre le temps de se parler','À Haffé, en mars 2025, une membre échange avec un groupe réuni. Une immersion commence aussi ainsi : se rendre disponible, écouter et construire une compréhension commune.',2025,'terrasen'),
 ('haffe-2025-rencontre','Haffé : le terrain a plusieurs voix','Les rencontres réunissent les personnes qui vivent les contraintes du quotidien et celles qui viennent apprendre avec elles. Cette image de mars 2025 invite à regarder le projet du point de vue de ses interlocutrices.',2025,'terrasen'),
 ('haffe-2025-parcelles','Haffé : regarder les conditions réelles','À Haffé, le voyage de mars 2025 confronte l’équipe aux conditions concrètes de la production agricole. Eau, sol, année et travail quotidien : le terrain donne leur sens aux choix techniques.',2025,'terrasen'),
 ('niaguiss-2025-dialogue','Niaguiss : les carnets restent ouverts','En mars 2025, les échanges à Niaguiss prolongent le travail avec les communautés. Poser des questions, écouter les réponses et garder une trace font partie du travail qui permet d’adapter les projets.',2025,'meune-nagn'),
 ('niaguiss-2025-produits','Niaguiss : la transformation se voit en rayon','Bocaux et produits conditionnés donnent à voir une activité de transformation locale. En mars 2025, ces produits invitent à parler conservation, étiquetage, vente et suivi de l’activité.',2025,'meune-nagn'),
 ('niaguiss-2025-demonstration','Niaguiss : apprendre avec les mains','En mars 2025, la démonstration donne une place à l’essai et aux gestes. Montrer, faire essayer et expliquer l’entretien : un transfert doit laisser une capacité après le départ de l’équipe.',2025,'meune-nagn'),
 ('niaguiss-2025-equipe','Niaguiss : repartir avec des liens','À Niaguiss, le voyage de mars 2025 relie apprentissages, rencontres et travail collectif. Les projets avancent aussi grâce aux relations construites entre les générations d’étudiants et leurs interlocuteurs sur le terrain.',2025,'meune-nagn'),
]

PHOTO_AWARDS = [
 ('mobigel-initiative-2020','Best Team Initiative Award 2020','MobiGel reçoit le Best Team Initiative Award 2020 dans le programme « Célébrons l’entrepreneuriat social » powered by Citi. Une reconnaissance de la réponse construite dans le contexte de la pandémie.', 'award-mobigel-2020','mobigel'),
 ('team-leader-2020','Best Team Leader Award 2020','Le Best Team Leader Award 2020 met à l’honneur Ibrahima CISSE, alors Team Leader d’Enactus ESP, aux côtés d’Eugène NAMAR d’Enactus UGB de Saint-Louis. Cette reconnaissance collective figure dans les souvenirs de la génération mobilisée en 2020.', 'award-team-leader-2020',None),
 ('team-spirit-2020','Best Team Spirit Award 2020','L’École Supérieure Polytechnique reçoit le Best Team Spirit Award 2020. Ce prix garde la trace d’une énergie d’équipe, alors que la pandémie transforme les façons de se réunir et d’agir.', 'award-team-spirit-2020',None),
]


def enrich_photo_stories(projects, awards, competitions, hall):
    known = {row['id'] for row in awards}
    for key, title, body, image, project in PHOTO_AWARDS:
        if key not in known:
            awards.append(dict(id=key, archive_item_id=None, title=title, year=2020,
                competition='Célébrons l’entrepreneuriat social · Enactus Sénégal / Citi',
                rank='Distinction', result=title, description=body, archived_project_id=project,
                file_id=None, media_url=None, image_asset='assets/heritage/'+image+'.jpg',
                source_label='Photothèque Enactus ESP', is_featured=True,
                story_sections=[{'title':'Une reconnaissance dans une année singulière','body':body}]))
    for row in projects:
        if row['id'] == 'mobigel':
            row.update(image_asset='assets/heritage/mobigel-prototypes.jpg', source_label='Photothèque Enactus ESP')
        elif row['id'] == 'deconaane':
            row.update(image_asset='assets/heritage/deconaane-filtre.jpg', source_label='Photothèque Enactus ESP')
    for row in competitions + hall:
        if row['id'] in ('world-cup-2022','world-cup-2022-hall'):
            row.update(image_asset='assets/heritage/world-cup-2022-delegation.jpg',source_label='Photothèque Enactus ESP')
        elif row['id'] in ('world-cup-2018','demi-finaliste-world-cup-2018-hall'):
            row.update(image_asset='assets/heritage/world-cup-2018-delegation.jpg',source_label='Photothèque Enactus ESP')
