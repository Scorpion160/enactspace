"""Historical courses based on club-approved archives; keep reported outcomes attributed."""

HISTORY = "Source : Histoire de Enactus ESP.pdf, archives Enactus ESP."
DIMBALI = "Source : Projet Dimbali/dimbali.pdf, archives Enactus ESP."
AQUATUS = "Source : FICHE DE PROJET AQUATUS (2).pdf, archives Enactus ESP."

COURSES = [
 ("Histoire d'Enactus ESP", "Mémoire du club", "debutant", [
  ("Fondation en 2015", "Le club naît en 2015 à l'École Supérieure Polytechnique de Dakar sous l'impulsion de M. Mare. Il commence avec trois membres. Javelisel explore la production d'eau de javel à partir d'eau de mer pour des structures sanitaires ; Soukhali Gokh accompagne la transformation de produits locaux par des femmes à Sébikotane.\n\n" + HISTORY),
  ("Projets et qualification 2017", "La période 2016–2017 voit naître Dimbali, SunCuiz et Ville Light. SunCuiz explore cuisson solaire et paniers thermiques ; Ville Light réoriente une idée d'éclairage en kits pédagogiques. Qualifié pour la World Cup 2017 à Londres, le club ne peut finalement pas y participer en raison de refus de visa.\n\n" + HISTORY),
  ("Première participation mondiale", "L'équipe concentre ses ressources sur Dimbali et Deconaane. Ce dernier travaille sur la filtration et le stockage local de l'eau. Enactus ESP participe effectivement à la World Cup 2018 aux États-Unis avec ces deux projets.\n\n" + HISTORY),
  ("Résilience et nouvelle génération", "La grève universitaire ralentit le club en 2019. Les projets à l'origine de Mën Nañ fusionnent ; Deconaane+ adapte des solutions d'accès à l'eau à Sinthiou Dimb. La pandémie conduit à des actions sanitaires en 2020. SHERY débute en 2021 pour répondre à la précarité menstruelle.\n\n" + HISTORY),
  ("Transmission de 2022 à 2023", "Dimbali et Mën Nañ représentent le club à la World Cup 2022. Dimbali arrive à la fin d'un cycle en 2022–2023 ; le club poursuit Mën Nañ et développe SHERY, Terrasen, Aquatus et CAJOR. Chaque nouvelle équipe doit pouvoir retrouver les choix, les résultats et les limites des précédentes.\n\n" + HISTORY),
 ]),
 ("Étude de cas : Dimbali", "Projets du club", "intermediaire", [
  ("Du besoin aux ressources locales", "Autour de Ngayène Sabakh, Dimbali relie désertification, activités économiques rurales et enjeux de nutrition. L'équipe étudie le fruit local dimb avec les groupements de femmes. Exercice : distinguer diagnostic local et solution proposée.\n\n" + HISTORY + " " + DIMBALI),
  ("Formation et transformation", "Les archives décrivent pépinières, farines à base de dimb et séchoirs solaires. Elles évoquent aussi des formations à la transformation, à la vente et à la comptabilité, ainsi qu'une formation d'artisans à la fabrication des séchoirs. Exercice : identifier ce que les bénéficiaires peuvent poursuivre seuls.\n\n" + DIMBALI),
  ("Résultats rapportés", "Un document sur Dimbali rapporte des résultats sur les revenus, l'emploi et la malnutrition. Ces chiffres sont des résultats attribués à ce document ; la fiche seule ne détaille pas l'ensemble des méthodes de mesure. Exercice : préciser les registres, la période et la situation de départ nécessaires à leur vérification.\n\n" + DIMBALI),
 ]),
 ("Étude de cas : Deconaane", "Projets du club", "intermediaire", [
  ("L'accès à l'eau", "Le récit historique décrit une recherche de solutions abordables pour améliorer l'accès à l'eau, puis un recentrage de Deconaane sur Sébikotane. Une intention d'améliorer l'accès à l'eau ne suffit pas à établir sa potabilité : celle-ci demande des contrôles adaptés.\n\n" + HISTORY),
  ("Filtration et stockage", "Le projet explore des systèmes de filtration, l'usage de poudre de graines de nebeeday et des dispositifs locaux de stockage. Exercice : établir une liste de contrôles de qualité, d'entretien et de coûts pour ces pistes.\n\n" + HISTORY),
  ("Adaptation à Sinthiou Dimb", "À Sinthiou Dimb, l'équipe constate que l'accès à l'eau est plus pressant que la culture du dimb. Deconaane+ adapte la réponse locale avec une pompe ; des séchoirs servent aussi à conserver les mangues. Exercice : expliquer le changement de priorité par le diagnostic terrain.\n\n" + HISTORY),
 ]),
 ("Étude de cas : SunCuiz et Ville Light", "Projets du club", "debutant", [
  ("SunCuiz et la cuisson", "SunCuiz explore un cuiseur solaire face à la cuisson au bois et évolue ensuite vers des paniers thermiques. Exercice : interroger les utilisatrices sur les horaires, les aliments cuisinés et la maintenance.\n\n" + HISTORY),
  ("Ville Light et l'éclairage", "Ville Light étudie un éclairage inspiré de bouteilles solaires sur toiture. Les contraintes de déploiement conduisent à des kits pédagogiques destinés aux jeunes. Exercice : distinguer le résultat recherché par chaque version.\n\n" + HISTORY),
  ("Documenter un changement de cap", "Une réorientation n'est pas un échec à cacher. Indique la solution initiale, les contraintes observées, la décision prise et les résultats effectivement constatés. Compare ce raisonnement entre SunCuiz et Ville Light.\n\n" + HISTORY),
 ]),
 ("Étude de cas : Mën Nañ", "Projets du club", "intermediaire", [
  ("Deux idées qui se rencontrent", "Le récit situe les origines de Mën Nañ en 2019 : valoriser les fruits en Casamance et réduire les pertes de lait à Saré Yoba, dans la région de Kolda. Ces deux initiatives fusionnent par la suite.\n\n" + HISTORY),
  ("Limiter les pertes", "Étudie séparément les contraintes de conservation des fruits et du lait : collecte, transformation, chaîne de distribution et débouchés. Le document historique décrit une origine commune du projet, pas un bilan technique exhaustif.\n\n" + HISTORY),
  ("Assurer la continuité", "Mën Nañ est poursuivi par plusieurs générations et fait partie, avec Dimbali, des projets présentés à la World Cup 2022. Exercice : préparer une fiche de passation comprenant les prototypes, les contacts autorisés et les difficultés encore ouvertes.\n\n" + HISTORY),
 ]),
 ("Étude de cas : Aquatus", "Projets du club", "intermediaire", [
  ("Comprendre l'aquaponie", "La fiche Aquatus propose d'associer élevage de poissons et culture de plantes ; les nutriments du circuit sont valorisés par les plantes. Exercice : dessiner les flux d'eau et les paramètres à surveiller avant de construire un prototype.\n\n" + AQUATUS),
  ("Offre et marché envisagés", "La fiche envisage poissons, alevins, légumes et herbes, et cite notamment restaurants, marchés et grandes surfaces comme clients possibles. Elle présente une offre projetée, pas des ventes déjà démontrées. Exercice : construire un test client pour chaque segment.\n\n" + AQUATUS),
  ("Budget prévisionnel", "La fiche estime le financement souhaité à 2 500 000 FCFA, réparti entre matériel et fonds de roulement. Il s'agit d'une prévision à rapprocher des devis, des essais et des dépenses réelles. Exercice : lister ces preuves avant de calculer la viabilité économique.\n\n" + AQUATUS),
 ]),
]
