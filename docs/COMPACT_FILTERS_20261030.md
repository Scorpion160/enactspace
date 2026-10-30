# Recherche et filtres compacts — 30 octobre 2026

## Présentation

Les références Academy fournies servent de modèle : champ de recherche, choix rapides et sélecteurs alignés lorsque la largeur le permet. La recherche conserve sa place sur mobile ; le bouton de réglage ouvre les critères détaillés. Les filtres actifs restent signalés lorsque le panneau se referme.

`AppFilterToolbar` et `AppQuickFilters` centralisent cette présentation. Ils utilisent le thème local, y compris le thème Academy. Les boutons ont une cible minimale de 48 px. Les choix rapides gardent leurs libellés entiers, avec défilement horizontal sur petit écran et retour à la ligne lorsque le texte est agrandi. Les sélecteurs utilisent une grille adaptée à la largeur disponible. Une sélection ne change pas le seuil de disposition en ajoutant un gros bouton de remise à zéro.

La fermeture conserve l'état des champs et exclut les contrôles cachés du focus. Les contrôleurs, options, clés de test, requêtes, autorisations et callbacks appartiennent toujours aux pages existantes.

## Couverture

| Module | Zones harmonisées |
|---|---|
| Academy | Catalogue : recherche, état, niveau, catégorie |
| Alumni | Annuaire et mentorats |
| Archives | Chronologie, collections historiques, projets, Hall of Fame, médias, Minutes de l'Enacteur |
| Présences | Sessions, participants, recherche d'inscription NFC |
| Chat | Recherche des conversations |
| Documents | Recherche et huit critères existants |
| Événements | Recherche, période et type |
| Finances | Recherche, états des paiements et comptes |
| Premières connexions | Recherche des membres et état des accès |
| Aide | Gestion des demandes et recherche dans le guide |
| EnactMeet | Choix rapides des réunions |
| Membres | Recherche, statut, rôle et département |
| Pôles | Recherche, type, responsable et alertes |
| Publications | Recherche, type, audience, pôle, projet et choix rapides du fil |
| Projets | Portefeuille et liste historique |
| Recrutements | Liste actuelle et ancienne administration ; critères détaillés et anonymisation conservés |
| Tâches | Recherche, statut, priorité, pôle, projet et assignation |
| Veille | Période, périmètre et choix rapides des tâches |
| Démonstration historique | Recherche et années des souvenirs ; la démo native réutilise déjà les pages ci-dessus |

Les formulaires de saisie, choix de destinataires et sélecteurs GIF restent des composants spécialisés. Les pages sans barre de recherche ou de filtrage, comme la fiche Impact, ne reçoivent pas de contrôles artificiels.

## Vérification

- Formatage Dart et analyse statique des 35 fichiers Dart concernés : sans erreur ni avertissement avec Dart 3.13.7 et les sources officielles Flutter 3.47.5.
- 19 nouveaux tests de widgets : quatre largeurs (320, 390, 768, 1440 px), deux thèmes et texte à 100 % / 200 %, repli, conservation de saisie, focus et filtrage réel du catalogue Academy.
- Cinq tests existants adaptés pour ouvrir le nouveau panneau avant d'utiliser les filtres ; leurs assertions métier sont conservées.
- Le script Windows lance d'abord les nouveaux tests, produit 18 captures, puis lance les tests de régression des modules concernés, dont les parcours Academy et la démo native.
- Les nouveaux tests Flutter et les nouvelles captures doivent encore être exécutés et examinés sur le poste Windows. La validation précédente des 91 tests Academy reste celle de la version antérieure à cette barre commune.

## Intégration

`tools/sync_compact_filters_windows.ps1` accepte un commit immuable et compare les sources locales avec la version Academy validée (`ad3229a1e20d2020b12fd7622dd77c2913872780`). Chaque téléchargement est vérifié par SHA-256. Le script prépare tous les fichiers, refuse une modification locale inconnue, sauvegarde les originaux, puis applique le lot. Une relance accepte également le candidat déjà installé.

Le journal indique le dossier de sauvegarde et l'archive des captures. Le script ne construit et ne déploie aucune version ; il n'applique aucune modification de backend, d'authentification ou de dépendance.
