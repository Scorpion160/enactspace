# Couverture de la démonstration Alumni Day

Audit du 24 octobre 2026 : les 40 chemins absolus déclarés dans le routeur principal ont été comparés au catalogue. Les entrées de connexion, démarrage et choix de démo sont exclues de la liste des modules. Les autres chemins sont rattachés explicitement à l’une des 23 rubriques ; un test vérifie ce rattachement pour détecter les oublis futurs.

| Module réel | Présentation dans la démo |
| --- | --- |
| Accueil | Choix Enacteur/Alumni, raccourcis et menu complet |
| Archives et mémoire | 40 photos publiques, recherche, années, favoris, lecture en grand, attributions |
| Alumni et mentorat | Annuaire fictif, profils, disponibilité et proposition d’échange simulée |
| Projets | Terrasen, Aquatus, Mën Nañ, Shery, Dimbali ; photos et dossiers publics disponibles |
| Pôles | Les 4 pôles cœur et 3 pôles support, leurs missions, fiches d’équipes et demandes simulées |
| Recrutement | Véritable formulaire en six étapes, code fictif, vrai écran de suivi avec données locales ; statuts modifiables côté équipe d’exemple |
| Academy | Leçons découvertes, progression, quiz, points et badge d’exemple |
| Discussions | Trois conversations, textes et médias locaux, documents publics, éléments partagés et GIF animés embarqués |
| Vie du club | Publications d’exemple, photos et essais de réaction/commentaire |
| Événements | Activités fictives et inscriptions/annulations simulées |
| EnactMeet | Présentation des usages ; aucune réunion réelle, caméra ou connexion audio |
| Membres | Profils et compétences fictifs ; aucune coordonnée réelle |
| Impact et performance | Explication des indicateurs, résultats et preuves à partir d’un exemple explicitement fictif |
| Tâches | Cases à cocher et progression locale |
| Documents | Quatre PDF publics, brouillon éditable, aperçu et conservation pendant la visite |
| Finances | Cotisation d’exemple et paiement simulé idempotent ; aucun opérateur appelé |
| Présences | Historique fictif et présentation du QR/NFC ; aucun pointage réel |
| Veille | Engagements et demande d’accompagnement simulée |
| Jeux et récompenses | Aperçu des jeux, brise-glace et points du quiz ; pas de session multijoueur réelle |
| Notifications | Exemples cliquables et lecture locale |
| Profil | Identité fictive et progression de visite |
| Paramètres | Apparence de la visite ; explication des préférences et notifications |
| Aide, accès, à propos et mentions légales | Présentation du fonctionnement, des droits et du retour à la connexion |

Les permissions, actions de responsable et fonctions matérielles sont présentées comme telles. La couverture de navigation ne signifie pas que la démo reproduit tous les traitements de production : les jeux multijoueurs, visioconférences, pointages, envois et paiements réels restent des aperçus ou simulations. Les informations internes du club ne sont jamais chargées pour alimenter la visite publique.

Le journal utilisateur initial indique une analyse Flutter sans problème, 98 tests réussis et 12 échecs. Le complément corrige leurs trois causes : présence d’un `Material` propre aux cartes interactives, acceptation des deux dossiers légitimes de photos publiques et chargement des ressources dans la zone asynchrone réelle des tests. La nouvelle exécution Flutter sur Windows doit confirmer le résultat avant publication.
