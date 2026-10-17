# Academy — accueil et catalogue illustrés, 17 octobre 2026

Référence de départ : checkpoint 1ccbb0ac2b8220ee8eb19d24a9114790e7bf2b95.

## Première étape
Bannière bleu nuit / jaune, illustrations locales issues du pack fourni, progression réelle (leçons, quiz, points), cartes de parcours et formations illustrées. Présentation adaptée à la largeur disponible et à la taille du texte, en clair et sombre. Les images sont décoratives : titres et données restent des composants Flutter. Aucun chiffre de maquette n'est copié dans les données. Dix WebP inclus dans assets/img/ (déclaration existante).

## Fonctionnement conservé
Gateway, API, reprise des leçons, navigation, prérequis, validation des quiz, cache et file hors connexion. Les photos des cours restent les photos originales ; les images de personnes générées dans les maquettes ne les remplacent pas. Recherche et filtres conservés.

## Validation
Nouveaux tests : présence des dix assets ; accueil à 320, 390 et 1280 pixels, texte 100/200 %, clair/sombre, compteurs issus du gateway et bouton désactivé sans formation disponible. Tests opérationnels existants exécutés par le script. Flutter/Dart non disponibles dans le conteneur de préparation : analyse, tests et contrôle visuel Windows requis. Le script vérifie les sources, sauvegarde et parse les candidats avant remplacement. Aucun build ni déploiement.

## Suite du chantier
Après validation de cet accueil : harmoniser la fiche de formation, le parcours détaillé et le lecteur de leçon à partir des maquettes du pack, sans altérer les actions pédagogiques. Contrôle visuel réel mobile et web avant publication.
