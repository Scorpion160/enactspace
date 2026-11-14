# Statistiques automatiques des campagnes de recrutement

## Objet

La page **La campagne en chiffres** utilise un endpoint anonyme d'agrégats `GET /api/recruitment/statistics`. Le paramètre facultatif `campaign_id` sélectionne une campagne passée, en cours ou future. Sans paramètre, la campagne la plus récemment créée est sélectionnée. Toutes les valeurs sont recalculées depuis la base au chargement ou à l'actualisation de la page.

Le code ne comporte pas de chiffres, dates, départements, années ou identifiants spécifiques à la campagne 2026–2027.

## Sources de données

- `recruitment_campaigns` : titres, dates et objectif de recrutement.
- `applications` : dépôts, caractéristiques déclarées, état des dossiers et entretiens.
- `application_reviews` : notes, évaluateurs, recommandations et dates de saisie.

Aucune migration SQL ni table de statistiques n'est nécessaire.

## Contrôle d'accès et confidentialité

- Tous les comptes actifs et validés pouvant ouvrir la page voient le total et les répartitions générales.
- Seuls les membres habilités à consulter les dossiers de recrutement reçoivent `evaluation`, l'objet des statistiques détaillées.
- Aucune identité, aucun code de suivi, aucune adresse e-mail, aucune réponse libre ou note individuelle n'est renvoyé.
- Les réponses libres concernant le canal de découverte sont regroupées sous **Autre** si elles ne correspondent pas à une catégorie standard.
- L'API est en lecture seule. L'actualisation de la page ne modifie aucune candidature, évaluation ou recommandation.

## Définitions des indicateurs

- **Dossier suffisamment noté** : au moins trois évaluations distinctes comportant une note numérique. Ce minimum est défini dans `MINIMUM_SCORED_REVIEWS` (3 par défaut).
- **Nombre de notes manquantes** : somme, pour chaque dossier, du nombre de notes à ajouter pour atteindre ce minimum.
- **Moyenne des candidats** : moyenne des moyennes individuelles des dossiers ayant reçu au moins une note, sans pondérer davantage les dossiers ayant quatre ou cinq évaluations.
- **Moyenne de toutes les notes** : moyenne sur toutes les évaluations notées, chaque note ayant le même poids.
- **Note au milieu du classement** : valeur médiane des moyennes individuelles.
- **Quart inférieur/supérieur du classement** : valeurs repères correspondant respectivement à 25 % et 75 % des moyennes individuelles, présentées dans l'application en termes simples.
- **Dossier avec fort écart** : amplitude d'au moins 5/20 entre sa meilleure et sa plus faible note.
- **Avis directement opposés** : un même dossier comporte au moins un avis favorable et un avis défavorable.
- **Dossiers sensibles** : union des deux critères précédents, sans double comptage.
- **Avis le plus fréquent** : recommandation la plus fréquente par dossier, avec égalité si plusieurs avis arrivent en tête.

Aucun seuil de score n'entraîne de décision automatique.

## Fichiers

- `backend/app/services/recruitment_statistics.py` : calculs réutilisables, données anonymes, lectures filtrées par campagne.
- `backend/app/api/routes/recruitment.py` : route, sélection de campagne et contrôle des droits.
- `frontend/lib/features/recruitment/screens/recruitment_statistics_screen.dart` : page existante, sélection et rafraîchissement.
- `frontend/lib/features/recruitment/widgets/recruitment_evaluation_dashboard.dart` : indicateurs, graphiques de répartition et explications.
- `backend/test_recruitment_statistics.py` : tests unitaires.
- `frontend/test/recruitment_evaluation_dashboard_test.dart` : tests d'interface et des permissions d'affichage.

## Vérifications effectuées le 12 novembre 2026

Le moteur a été exécuté en lecture seule sur la campagne 2026–2027 en base de production : 95 candidatures, 301 évaluations, 95 dossiers ayant trois notes au minimum, 13,02/20 de moyenne des candidats, 29 forts écarts et 31 dossiers sensibles. Les tests unitaires du moteur (4) et les tests Flutter du nouveau tableau de bord (4) passent. Les trois tests précédents de la page statistique passent également.

## Livraison

Ne pas publier directement l'ensemble du répertoire de reprise local : il comporte des modifications non liées à ce tableau de bord. La fusion et le déploiement doivent se limiter à ce lot de fichiers, sur une base source cohérente avec la version déjà en production, puis être suivis des contrôles fonctionnels habituels.
