"""Course-specific assessments and explanatory feedback for the starter school."""
# Each item is (question, choices, correct index, explanation).
ASSESSMENTS = {
 "Découvrir Enactus": [
  ("Avant de choisir un équipement, que doit faire l’équipe ?", ["Commander le matériel", "Comprendre les pratiques et le besoin avec les personnes", "Préparer uniquement un logo"], 1, "La solution répond à un besoin vérifié. L’écoute permet de comparer les réponses avant d’engager des moyens."),
  ("Une communauté participe vraiment au projet lorsqu’elle…", ["Contribue aux choix et aux retours sur l’usage", "Assiste seulement à une photo de groupe", "Reçoit une solution sans échange"], 0, "La participation concerne le diagnostic, les décisions et l’évaluation. La présence à une activité ne suffit pas à montrer une implication dans les choix."),
  ("Quelle première contribution est la plus utile ?", ["Promettre de tout faire", "Attendre de maîtriser tous les sujets", "Proposer un livrable précis et une échéance réaliste"], 2, "Une contribution claire permet au collectif de s’organiser. Elle peut être modeste tout en produisant un résultat utilisable."),
 ],
 "Comprendre les ODD": [
  ("Comment relier un projet à un ODD ?", ["Choisir tous les logos", "Expliquer le lien entre besoin, activité, cible et résultat", "Retenir le plus populaire"], 1, "Le lien se justifie par ce que le projet fait et cherche à changer. Une cible précise aide à choisir une mesure adaptée."),
  ("Quel élément décrit une activité ?", ["Vingt personnes ont changé durablement de pratique", "Les revenus ont augmenté", "Un atelier a été organisé"], 2, "L’atelier est une action de l’équipe. Un changement de pratique ou de revenu relève d’un résultat à mesurer avec une période et une méthode."),
  ("Une affiche portant un logo ODD démontre-t-elle un impact ?", ["Non, il faut observer et expliquer un changement", "Oui, le logo suffit", "Oui, si elle est partagée"], 0, "Un logo exprime une intention ou un thème. La mesure doit préciser ce qui change, pour qui, à quel moment et avec quelles limites."),
 ],
 "Enquête terrain": [
  ("Quelle formulation décrit le mieux un problème ?", ["Nous voulons construire une machine", "Les producteurs de cette localité perdent une partie des fruits avant la vente", "Notre équipe manque de visibilité"], 1, "La formulation identifie un public, une difficulté et un contexte. Elle laisse ouvertes plusieurs réponses possibles."),
  ("Quelle question évite de pousser vers une approbation ?", ["Notre idée est utile, n’est-ce pas ?", "Acheteriez-vous notre produit parfait ?", "Racontez la dernière fois où cette difficulté s’est présentée"], 2, "Un récit récent apporte des faits sur les pratiques. Une question qui suggère la réponse risque de produire une approbation peu informative."),
  ("Après les entretiens, que faut-il faire ?", ["Séparer faits et interprétations, puis discuter la synthèse", "Transformer les suppositions en certitudes", "Publier tous les noms et réponses"], 0, "La restitution confronte les interprétations aux expériences recueillies. Les informations personnelles doivent être utilisées avec discernement et accord."),
 ],
 "Concevoir et tester une solution": [
  ("À quoi sert d’abord un prototype ?", ["À prouver un déploiement complet", "À tester une question ou une hypothèse précise", "À remplacer tout contact avec les utilisateurs"], 1, "Le prototype représente ce qui est nécessaire à l’observation. Une démonstration réussie ne valide pas tous les aspects du projet."),
  ("Quand choisir le critère de réussite d’un pilote ?", ["Après avoir vu les résultats", "Seulement pour une compétition", "Avant le test, avec une mesure et une durée"], 2, "Définir le critère à l’avance permet d’interpréter les observations sans déplacer l’objectif pour obtenir une réussite apparente."),
  ("Un résultat négatif doit conduire à…", ["Comprendre la difficulté et décider de modifier, poursuivre ou arrêter", "Supprimer le résultat du bilan", "Accuser automatiquement l’utilisateur"], 0, "Un test apporte un apprentissage, y compris lorsqu’il échoue. La décision dépend de la cause, des ressources et du besoin observé."),
 ],
 "Mesurer les résultats": [
  ("Quel élément décrit un changement plutôt qu’une portée ?", ["Cent personnes ont reçu une invitation", "Les pertes diminuent dans le groupe suivi pendant le pilote", "Trois réunions ont eu lieu"], 1, "La portée compte les personnes touchées ; le changement décrit une évolution de leur situation. Il faut préciser le groupe et la période."),
  ("Pour comparer deux mesures, il faut notamment…", ["Changer la définition de l’indicateur", "Compter plusieurs fois les mêmes personnes", "Garder des unités et des méthodes cohérentes"], 2, "Une comparaison exige une définition stable et des unités compatibles. Les différences de méthode doivent être expliquées."),
  ("Pourquoi présenter les limites d’un résultat ?", ["Pour préciser ce que les données permettent réellement de conclure", "Pour annuler toute utilité au projet", "Pour remplacer la mesure par une opinion"], 0, "L’échantillon, la période et les autres facteurs influencent l’interprétation. Les expliquer rend la conclusion plus précise."),
 ],
 "Modèle économique et pérennité": [
  ("Le client et le bénéficiaire sont-ils toujours la même personne ?", ["Oui, nécessairement", "Non, il faut identifier qui utilise, qui paie et qui bénéficie", "Non, donc le financement est inutile"], 1, "Les rôles peuvent se cumuler ou être répartis. Comprendre les flux aide à financer une offre accessible au public visé."),
  ("Un prix de 1 500 FCFA et un coût variable de 1 000 FCFA donnent…", ["Une marge sur coût variable de 500 FCFA par unité", "Un bénéfice net garanti de 500 FCFA", "Un investissement initial de 500 FCFA"], 0, "La différence couvre ensuite les coûts fixes et les autres charges. Elle n’est donc pas automatiquement un bénéfice net."),
  ("Que doit prévoir un passage de relais ?", ["Seulement la remise d’un objet", "Une publication de clôture", "Responsables, formation, entretien, financement et suivi"], 2, "La continuité dépend de capacités et de moyens disponibles localement. Une remise sans organisation laisse les usages fragiles."),
 ],
 "Travail d'équipe et transmission": [
  ("Une tâche est plus facile à suivre si elle comporte…", ["Un responsable, un résultat attendu et une échéance", "Une intention vague", "Plusieurs responsables sans coordination"], 0, "Ces repères rendent les attentes visibles. Ils permettent aussi de signaler un retard ou un besoin d’appui."),
  ("Quand signaler un blocage ?", ["Après la date limite", "Assez tôt, avec le point précis et l’aide souhaitée", "Uniquement lorsque tout est terminé"], 1, "Un signalement précis permet de réorganiser les moyens et de demander un appui avant que la difficulté s’étende."),
  ("Une bonne passation explique…", ["Uniquement les réussites", "Seulement les noms des fichiers", "Les décisions, les essais, les difficultés et les prochaines actions"], 2, "Le contexte des décisions permet à une nouvelle personne de reprendre le raisonnement et d’éviter de répéter des essais inutiles."),
 ],
 "Présenter un projet": [
  ("Comment introduire le besoin dans un pitch ?", ["Décrire une difficulté observée et son contexte", "Généraliser une anecdote à tout un pays", "Commencer par une liste de technologies"], 0, "Un besoin compréhensible relie une situation aux personnes concernées. Le récit doit respecter la réalité de l’observation."),
  ("Une démonstration de prototype permet d’affirmer…", ["Que tous les utilisateurs l’ont adopté", "Ce que le test a montré dans ses conditions", "Que la maintenance est définitivement résolue"], 1, "La présentation distingue prototype, pilote et déploiement. Chaque essai vérifie certaines questions et en laisse d’autres ouvertes."),
  ("Comment défendre un chiffre de résultat ?", ["Répéter le nombre plus fort", "Éviter les questions", "Expliquer période, unité, calcul et limites"], 2, "Un chiffre devient compréhensible lorsqu’on peut reconstruire sa mesure. Les limites font partie de la réponse aux questions."),
 ],
 "Apprendre des projets précédents": [
  ("Pour comprendre un ancien projet, commence par…", ["Comparer sa période, ses objectifs et ses décisions", "Copier une photo sans contexte", "Supposer que tous les projets se ressemblent"], 0, "Une archive devient un apprentissage quand les repères expliquent ce qui a été essayé et pourquoi."),
  ("Pourquoi retrouver les raisons d’un changement de solution ?", ["Pour éviter toute évolution future", "Pour comprendre les contraintes et les apprentissages", "Pour attribuer un échec à une personne"], 1, "Les raisons du choix peuvent éclairer un nouveau terrain. Elles n’imposent pas de reproduire une réponse dans un contexte différent."),
  ("Que faire lorsqu’un détail historique reste inconnu ?", ["Inventer une date plausible", "Le présenter comme une certitude", "Laisser la question ouverte et demander un éclairage"], 2, "Une histoire précise peut reconnaître un manque. Les échanges avec les personnes de la période peuvent aider à le compléter."),
 ],
 "Histoire d'Enactus ESP": [
  ("À quelle année remontent les débuts d’Enactus ESP ?", ["2015", "2020", "2023"], 0, "Le club commence en 2015. Les générations suivantes développent les projets et transmettent leurs expériences."),
  ("Pourquoi l’équipe ne participe-t-elle pas à Londres en 2017 ?", ["Tous les projets sont arrêtés", "Les difficultés de visas empêchent le déplacement", "La compétition a lieu au Sénégal"], 1, "L’épisode de 2017 rappelle que la préparation d’une compétition comprend aussi des contraintes de déplacement."),
  ("Quels projets accompagnent la World Cup 2018 ?", ["SHERY et Aquatus", "Terrasen et Ville Light", "Dimbali et Deconaane"], 2, "Dimbali et Deconaane portent cette étape mondiale. Situer les projets dans leur période permet de comprendre les générations."),
 ],
 "Étude de cas : Dimbali": [
  ("Quelle logique guide Dimbali ?", ["Valoriser une ressource locale avec transformation et formation", "Importer un produit sans diagnostic", "Remplacer toute activité par une compétition"], 0, "Le projet relie ressource, conservation, transformation et capacités économiques des communautés."),
  ("Pourquoi former à l’usage d’un séchoir ?", ["Pour éviter de prévoir l’entretien", "Pour soutenir l’usage autonome et la poursuite de l’activité", "Pour confondre présence et maîtrise"], 1, "La formation doit permettre de pratiquer et d’entretenir. L’équipement et la capacité d’usage se construisent ensemble."),
  ("Comment lire un résultat local de Dimbali ?", ["Comme un total valable pour toutes les localités", "Sans indiquer la période", "Avec sa localité, son groupe et sa période"], 2, "Un résultat décrit la population et les conditions suivies. L’étendre sans mesure à d’autres territoires change sa signification."),
 ],
 "Étude de cas : Deconaane": [
  ("Quelles fonctions faut-il distinguer dans une réponse d’accès à l’eau ?", ["Filtration, stockage et accès à la ressource", "Seulement la couleur du réservoir", "Uniquement la communication"], 0, "Chaque fonction répond à une contrainte différente. Le bon fonctionnement d’un élément ne valide pas l’ensemble."),
  ("Que montre l’adaptation à Sinthiou Dimb ?", ["Qu’une solution doit rester identique partout", "Qu’un besoin prioritaire peut conduire à adapter la réponse", "Que le diagnostic ne sert plus"], 1, "L’écoute fait apparaître un besoin d’eau prioritaire. Les technologies de Deconaane sont mobilisées en fonction de ce contexte."),
  ("Peut-on conclure que l’eau est potable à partir de son aspect ?", ["Oui, si elle paraît claire", "Oui, si le filtre est neuf", "Non, la qualité exige des contrôles adaptés"], 2, "L’aspect ne suffit pas à établir la qualité sanitaire. Un dispositif doit être évalué et entretenu avec les compétences appropriées."),
 ],
 "Étude de cas : SunCuiz et Ville Light": [
  ("Quelle évolution appartient au parcours de SunCuiz ?", ["De la cuisson solaire aux paniers thermiques", "De l’aquaponie au lait", "Du gel aux protections menstruelles"], 0, "Le parcours explore des réponses aux pratiques de cuisson. Les usages permettent de questionner et d’adapter une solution."),
  ("Quelle dimension se développe dans Ville Light ?", ["La production de poisson", "L’apprentissage par des kits pédagogiques", "La transformation du Dimb"], 1, "Ville Light évolue d’une recherche sur l’éclairage vers une approche de sensibilisation et de compréhension technique."),
  ("Pourquoi un projet peut-il changer de forme ?", ["Pour éviter toute observation", "Pour annoncer automatiquement un succès", "Pour mieux répondre aux contraintes et aux usages"], 2, "Une évolution utile se relie à ce que l’équipe apprend. Le changement de forme doit garder une raison compréhensible."),
 ],
 "Étude de cas : Mën Nañ": [
  ("Quelles activités se renforcent dans Mën Nañ ?", ["Transformation, conservation et organisation locale", "Seulement les affiches", "Uniquement les déplacements"], 0, "Le projet associe des capacités techniques à l’organisation des activités des groupements."),
  ("Pourquoi distinguer les contextes territoriaux ?", ["Pour ignorer les besoins", "Pour adapter l’eau, les filières et les débouchés au terrain", "Pour recopier le même bilan partout"], 1, "Les ressources et les contraintes varient. La réponse doit être construite avec les personnes de chaque contexte."),
  ("Quel signe montre un transfert utile ?", ["Une photo de remise seule", "Un nom de technologie connu", "Des personnes peuvent refaire les gestes et entretenir le matériel"], 2, "La capacité autonome et le suivi donnent du sens au transfert. La présence à une séance reste un indicateur d’activité."),
 ],
 "Étude de cas : Aquatus": [
  ("L’aquaponie relie notamment…", ["Poissons, bactéries, plantes et circulation de l’eau", "Plantes et poissons sans aucune maintenance", "Seulement un bac décoratif"], 0, "Les transformations biologiques et la circulation de l’eau relient l’élevage et les cultures. L’équilibre demande un suivi."),
  ("Un budget de pilote doit inclure…", ["Seulement les recettes souhaitées", "Équipement, fonctionnement, entretien et hypothèses de vente", "Uniquement le prix du premier bac"], 1, "Les coûts récurrents et la maintenance influencent la continuité. Les ventes sont des hypothèses à vérifier."),
  ("Une distinction en compétition remplace-t-elle le suivi du pilote ?", ["Oui, pour toujours", "Oui, si la présentation est réussie", "Non, l’usage et les résultats doivent encore être mesurés"], 2, "Une distinction reconnaît une initiative à une étape. Le fonctionnement, l’adoption et les résultats exigent des observations propres au terrain."),
 ],
}
