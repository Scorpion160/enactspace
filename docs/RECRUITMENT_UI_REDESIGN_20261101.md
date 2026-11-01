# Refonte du recrutement — 1er novembre 2026

La refonte remplace les cartes de campagne de hauteur fixe et les descriptions tronquées par des surfaces adaptées au contenu et une lecture dépliable. Elle reprend les couleurs, la typographie Poppins et les composants d’Academy dans les véritables écrans Flutter du recrutement.

## Périmètre livré

| Vue | Changement | Comportements conservés |
|---|---|---|
| Navigation | Entrées Candidatures, Campagnes, Jury, Entretiens ; accès selon les droits existants | Véritables gateways et routes, retour entre les vues |
| Campagnes | Cartes sans hauteur imposée, titre complet, Lire la suite/Réduire, indicateurs | Création, modification, activation, fermeture ; suppression protégée des campagnes vides |
| Informations | Page de création/modification ; informations, questionnaire, aperçu ; actions de sauvegarde accessibles | Validation des dates, activation à la création, conservation de la saisie en cas d’erreur |
| Questionnaire | Liste des questions et éditeur avec aperçu sur grand écran ; champs empilés sur mobile | Identifiants stables, ordre, ajout/retrait, caractère obligatoire, sections réellement supportées ; snapshots des dossiers reçus |
| Candidatures | En-tête compact, indicateurs, filtres repliables, anonymisation visible | Recherche, campagne, sept statuts, pôle/projet historique, département, promotion, genre, période de dépôt, remise à zéro, pagination |
| Confidentialité | Recherche par références en lecture anonymisée ; noms masqués non recherchables ; protection des identités déjà anonymisées par le serveur | Les restrictions du serveur restent applicables |
| Tri et dates | Nom puis prénom en lecture nominative ; références en lecture anonymisée ; refus d’une période inversée | Aucun classement automatique des personnes |
| Jury | Membres et équipes côte à côte sur ordinateur, empilés sur mobile | Sélection, ajout, retrait, Enacteurs/Alumni ; responsables autorisés inchangés |
| Équipes | Dialogue harmonisé, sélection des jurés nommés, jury unique ou équipes parallèles | Révisions, équipes en pause, signalement des entretiens à réattribuer ; pas d’équipe vide |
| Entretiens | Vue dédiée aux créneaux réellement enregistrés, accès au dossier, alertes de réattribution | Horaires à Dakar, choix de la durée, présentiel/en ligne/mixte, équipes et contrôle des conflits existants |
| Dossier | Raccourcis vers réponses, évaluation, entretien, décision, historique ; sections conservées | Documents privés, grille humaine, avis, décisions confirmées, invitation au questionnaire et conversion autorisée |
| Parcours public | Palette et formulaires harmonisés en clair/sombre | Six étapes, CV, validation, conservation du brouillon et des fichiers, reprise après erreur, suivi et questionnaire de préparation à l’entretien |

La navigation du dossier donne accès aux sections du même dossier par défilement. Le questionnaire supporte les sections `motivation` et `availability` de l’API existante. Les illustrations de référence n’ajoutent aucun statut, rôle, filtre côté serveur ou action non disponible dans l’application.

## Campagne réelle préservée

Identifiant : `65b3d1fd-f1e0-4012-90f7-ab3286058efc`.

- Titre : Recrutement Enactus ESP 2026-2027.
- Ouverture : 4 novembre 2026, 00 h, Dakar.
- Clôture : 9 novembre 2026, 00 h, Dakar, soit toute la journée du 8 incluse.

L’installation ne se connecte pas au VPS, ne crée ni ne ferme une campagne et ne modifie aucune candidature. Le backend 1.0.21, son schéma, les notifications et les paiements restent en dehors de cette livraison.

## Validation et installation

Base comparée : commit `220bfa4fe6e0f2f1c6a506a0e6885247d8516360`. Les 55 fichiers de référence ont été comparés à leurs blobs GitHub. Le manifeste distingue les remplacements des dépendances laissées intactes.

L’installateur `tools/sync_recruitment_redesign_windows.ps1` :

1. Télécharge les fichiers épinglés et vérifie leurs SHA-256.
2. Reconnaît les sources précédentes, nouvelles, ou équivalentes après formatage Dart. Une autre différence produit une archive limitée aux sources du recrutement, sans remplacement.
3. Sauvegarde les fichiers existants, revérifie les empreintes et applique uniquement les remplacements annoncés. Une erreur de copie restaure les fichiers copiés lorsque leur contenu n’a pas changé concurremment.
4. Lance l’analyse et l’ensemble des fichiers `recruitment*_test.dart` présents, comprenant les tests du cycle de vie, de confidentialité, de candidature, d’évaluation et de questionnaire.
5. Exécute `frontend/tool/recruitment_redesign_preview_test.dart` pour générer **52 captures réelles de widgets Flutter** : 13 vues × clair/sombre × 390/1440 pixels. Données fictives et gateways mémoire ; aucune API, aucun envoi de candidature, aucune notification.

Les captures montrent les composants du recrutement dans un hôte de test, avec les polices locales. Elles ne simulent pas la barre globale de l’application et ne prouvent pas un parcours HTTPS authentifié sur le site de production.

Tests supplémentaires : descriptions dépliables, navigation réelle entre écrans, recherche anonymisée, tri des noms, restrictions d’accès, préservation du brouillon entre les onglets, aperçu des questions configurées et sauvegarde. Vérification de mise en page à 320 pixels, à 390 pixels avec texte à 200 %, et sur ordinateur, en clair et en sombre.

**État à la livraison du code :** formatage et analyse Dart effectués ; syntaxe PowerShell, périmètre autorisé, empreintes et comparaison Dart non mutante vérifiés avec PowerShell 7.5.4 ; tests Flutter et captures à exécuter sur Windows. Le PC connecté est actuellement hors ligne. Aucun build web ni déploiement de cette refonte n’a été effectué. La version web publique observée dans le compte rendu utilisateur demeure 1.0.22, build 25.

Une validation locale réussie affiche `REFONTE_RECRUTEMENT_ANALYSE_ET_TESTS_OK` et le chemin de l’archive de captures. Le journal et le reçu de validation indiquent séparément les étapes réussies. Une erreur de test conserve les sources installées et leur sauvegarde pour correction ; elle ne déclenche aucune publication.

La publication web se fera après contrôle de ces résultats et des captures, avec vérification préalable de la version publique et du rollback. La nouvelle interface ne doit jamais être déclarée validée en production sur la seule base de l’analyse statique.

## Première exécution Windows et reprise ciblée

Le journal transmis le 1er novembre confirme : 24 sources installées et sauvegardées, formatage sans changement, analyse Flutter sans problème, **236 tests réussis et un échec sur 237**. Aucun build ni déploiement effectué. Les captures n’ont pas été lancées puisque la suite comportait un échec.

L’échec ne signale pas une donnée manquante : le test cherchait un seul texte « Réponses » dans toute la fiche, alors que ce libellé existe dans le raccourci de navigation et le titre de section. Le correctif vérifie séparément le raccourci, le titre du résumé, le titre et le contenu de la section Réponses, ainsi que les trois liens dans la section Documents. Les assertions restent précises ; elles ne deviennent pas une simple recherche acceptant plusieurs résultats. Le jeu de données fictif des captures utilise également la clé `question` attendue pour le libellé des réponses reçues.

La reprise cible uniquement les **deux fichiers de test** sur la base `49b446aa64428749f1bc1fe65922c1baeb501db0`. Le reste des 61 sources du manifeste est vérifié et laissé intact. Le script de reprise conserve les contrôles, la sauvegarde, l’analyse, la suite de tests et les 52 captures, sans accès au serveur. Les nouveaux résultats et captures restent à obtenir sous Windows ; les 237 tests ne sont pas encore déclarés tous réussis.

Le correctif ciblé a été formaté et analysé avec Dart 3.13.7 : aucun problème signalé. La logique PowerShell de reprise est inchangée ; seule son empreinte de manifeste est actualisée. Les empreintes des deux remplacements et des 59 dépendances ont été vérifiées.

## Validation Windows reçue et revue des 52 captures

Le second journal transmis le 1er novembre, opération `2aa4d02235214f8e93287704154b6cac`, confirme **237 tests réussis sur 237**, une analyse Flutter sans problème, puis les quatre exécutions de capture réussies. L’archive jointe contient bien **52 PNG**, soit les 13 vues à 390 et 1440 pixels, en clair et en sombre. Le build web et le déploiement restent non effectués. Ces résultats concernent les sources `7ce4ccb6e83f198bc9c1bfb1739c95a53d07167d`, avant les retouches décrites ci-dessous.

La lecture des 52 images a permis de relever des défauts que la réussite des tests fonctionnels ne suffit pas à écarter :

- Les libellés des onglets Informations, Questionnaire et Aperçu candidat sont rendus en rectangles ou disparaissent. Le thème local des chips remplaçait le style Poppins par un `TextStyle` sans police. Les styles des libellés sélectionnés et non sélectionnés conservent désormais la typographie du thème de l’application.
- Les rubriques du recrutement et les onglets de campagne dépassent horizontalement sur mobile. Ils passent désormais à la ligne selon l’espace disponible et la taille du texte, tout en conservant leurs actions et restrictions d’accès.
- L’icône du statut dans le suivi reste presque noire sur une carte sombre. Elle utilise désormais la couleur principale du thème du recrutement.
- Le symbole flèche entre les dates de l’aperçu candidat est absent de la police utilisée pour les captures. La période est écrite « du … au … » ; les dates manquantes ont un libellé dédié.

La bannière de debug est également retirée de l’hôte de capture, sans changement de l’application. La reprise cible **cinq fichiers** sur la base `7ce4ccb6…` et vérifie les **56 autres sources** du manifeste sans les remplacer. Elle conserve la sauvegarde, les vérifications de contenu local, l’analyse, la suite complète du recrutement et les 52 captures.

**Vérifications du correctif :** les cinq fichiers Dart ont été analysés syntaxiquement par le formateur Dart 3.13.7 avec le langage 3.12 du projet ; les contrôles PowerShell 7.5.4 de syntaxe, de périmètre, d’empreintes et de comparaison Dart non mutante ont réussi. Les 61 empreintes de référence ont été comparées aux blobs du commit de base ; les cinq remplacements et les 56 dépendances du nouveau manifeste concordent avec les fichiers préparés.

**Validation Flutter du correctif encore attendue :** une tentative de préparation de Flutter 3.47.5 dans l’environnement de travail a été interrompue par le contrôle automatique, qui a bloqué l’accès du détecteur d’environnement de Flutter au service de métadonnées cloud. Aucun résultat d’analyse Flutter, de test Flutter ou de nouvelle capture ne peut donc être revendiqué pour ces retouches. L’installateur permet de les valider sur le PC Windows déjà utilisé pour la première série. Aucun accès au VPS, changement de campagne, build web ou déploiement n’a été effectué pendant cette revue.

## Journal 71e2 reçu : contrôle des libellés non sélectionnés

Le journal Windows de l’opération `71e2e941fd054e0a8e4c6fc3dee35ae2`, avec les sources `15ddd559355a0462d417b7d93162864e8e20893c`, confirme le formatage des cinq fichiers sans changement, l’analyse Flutter sans problème, **237 tests réussis**, puis les quatre exécutions de capture réussies. L’archive contient 52 PNG. Aucun build web ni déploiement n’a été effectué par ce parcours.

Les nouvelles images confirment le retour à la ligne de la navigation mobile, la lisibilité de l’icône du suivi en sombre et la correction des dates. En revanche, le premier correctif de typographie est incomplet : le libellé sélectionné est lisible, tandis que les deux autres libellés restent absents ou rendus en rectangles. La comparaison avec l’archive précédente, en écartant l’angle de la bannière de debug, retrouve 34 images inchangées et 18 images modifiées, toutes dans les vues attendues.

La lecture de `RawChip.build` dans les sources officielles de Flutter 3.47.5 précise la cause : le composant fusionne le `TextStyle`, puis résout uniquement sa propriété `color`. Il ne résout pas un `WidgetStateTextStyle` complet. Le thème conserve donc un `TextStyle` concret avec la police Poppins ; seule sa couleur est un `WidgetStateColor`. Le style du libellé sélectionné reste concret lui aussi.

Les six cas responsive de `recruitment_redesign_test.dart` ouvrent désormais l’éditeur de campagne et contrôlent le `RenderParagraph` des trois libellés, à l’ouverture et après changement d’onglet. Le contrôle porte sur la famille de police et sa taille, en clair et en sombre, à 320 et 1440 pixels ainsi qu’à 390 pixels avec texte à 200 %. Ces vérifications complètent les tests fonctionnels qui ne détectaient pas la perte de police.

La reprise remplace seulement **deux fichiers**, le thème du recrutement et le test de refonte, sur la base `15ddd559…`. Les **59 autres sources** sont vérifiées et conservées. Le formateur Dart 3.13.7 avec langage 3.12, les contrôles PowerShell 7.5.4 et les empreintes du manifeste ont été vérifiés. **L’analyse Flutter, les tests renforcés et les nouvelles captures de ce dernier ajustement restent à exécuter sur Windows avant le build web.**
