# Sélection des candidatures

Les nouvelles campagnes utilisent `blind-selection-v1`. La migration `20261105_0035` applique aussi ce processus aux campagnes actives et aux dossiers encore à étudier. Les résultats déjà communiqués et les entretiens déjà engagés sont conservés. Un ancien nombre de clubs inconnu reste « Non renseigné » ; les nouveaux dossiers doivent le déclarer.

## Calendrier de novembre 2026

Dans le panneau de sélection de la campagne concernée, ouvrir le calendrier, charger le planning de novembre 2026, contrôler les dates et enregistrer. Activer ensuite la campagne lorsqu’elle est prête à être diffusée : sa période contrôle son ouverture et sa clôture. La migration `20261105_0036` ajoute son stockage ; elle ne modifie aucune date historique. Le calendrier enregistré est visible avant la candidature et dans son suivi.

| Étape | Dates à Dakar |
| --- | --- |
| Diffusion et ouverture du formulaire | 6 novembre 2026 |
| Clôture des dépôts | 9 novembre 2026 à la fin de la journée |
| Étude des dossiers | dès les premières candidatures, puis finalisation jusqu’au 14 novembre 2026 |
| Première annonce groupée | 15 novembre 2026, proposition à confirmer avant l’enregistrement |
| Entretiens | du 16 au 21 novembre 2026 |
| Résultats finaux | 24 novembre 2026 |

Le 15 est proposé pour informer les dossiers retenus et non retenus ensemble après le tri et avant les entretiens. Les dépôts restent possibles pendant toute la journée du 9 ; leur fermeture est effective le 10 à 00 h, heure de Dakar. L’étude et les évaluations peuvent commencer dès le premier dépôt, sans attendre le 9 ni la clôture. Le modèle prévoit désormais le début de l’étude dès l’ouverture, le 6. Les dates d’étude restent indicatives pour l’organisation et ne bloquent pas une évaluation anticipée ; aucun calendrier déjà enregistré n’est remplacé automatiquement.

Les responsables habilités peuvent modifier toutes les dates à tout moment, y compris après la présélection et les résultats finaux. Le journal conserve l’auteur, la date, l’ancien calendrier et le nouveau. Le calendrier actualisé est visible dans le suivi ; aucun mail n’est déclenché par cette modification. Prévenir les candidats d’un report reste donc une communication à organiser.

Le serveur empêche la publication avant la nouvelle date annoncée et refuse une nouvelle programmation d’entretien hors de la période enregistrée. Les dates de publication ouvrent la possibilité de publier : elles ne déclenchent aucun envoi automatique. Les responsables doivent encore vérifier les évaluations et toutes les décisions, puis publier le lot.

Un changement de planning conserve les résultats et leurs dates réelles de publication, sans relancer leurs mails ni masquer une décision déjà communiquée. Une campagne ayant publié sa présélection ne reçoit plus de nouveaux dossiers, même si les dates de dépôt sont modifiées. Les rendez-vous existants restent fixés à leur horaire ; leur reprogrammation se fait séparément et déclenche la notification habituelle au candidat.

## Parcours candidat

Les critères apparaissent avant le formulaire : DIC3, DESCAF3 (alias DESCFAF3), Master2 et DIT2 sont inéligibles, ainsi qu’un engagement dans au moins trois clubs ou structures étudiantes. Le serveur contrôle ces critères même si le formulaire est contourné.

Le suivi comprend réception, étude, résultat du dossier, entretien et décision finale. Un refus lors de la présélection termine le parcours au résultat du dossier. Les décisions préparées restent privées jusqu’à la publication de leur lot.

## Préparer et évaluer

1. Nommer les jurés actifs de la campagne.
2. Sélectionner la campagne dans l’espace recrutement et ouvrir le panneau de présélection.
3. Dès chaque nouveau dépôt, les dossiers sont attribués automatiquement aux jurés disponibles : deux avis indépendants par défaut, réglables de deux à cinq. Les arrivées et les affectations sont sérialisées par campagne pour conserver l’équilibre et éviter les doublons. Les attributions automatiques sont journalisées. Si le jury est encore incomplet, le dépôt est conservé et les nominations suivantes complètent les attributions manquantes. Le bouton de répartition reste disponible pour compléter les besoins, sans effacer les notes et attributions existantes.
4. Chaque juré utilise la grille commune sur ses dossiers. Un écart d’au moins 20 points sur 100 déclenche un avis supplémentaire ; ce seuil est réglable. S’il manque un juré disponible, compléter le jury puis relancer la répartition.
5. Un juré qui reconnaît une personne peut demander un autre évaluateur. Son attribution et son éventuelle note sont écartées du calcul, avec conservation de la trace d’audit.
6. Préparer une décision par dossier, puis clôturer les dépôts avant de publier la présélection.

Avec 500 dossiers, 20 jurés et deux avis, la charge initiale est de 50 dossiers par juré, avant les avis supplémentaires.

## Anonymat et documents

Le serveur masque identité, coordonnées, parcours identifiant, code de suivi et liens de documents. Il masque aussi les noms, contacts et liens reconnaissables dans les réponses du candidat. Le formulaire demande de ne pas insérer d’identité dans les réponses libres ; une personne peut néanmoins être reconnaissable par un récit particulier, d’où la possibilité de déport.

Les informations du candidat restent en lecture seule pendant l’anonymat. Chaque juré retrouve ses propres observations telles qu’il les a saisies. Les commentaires et justifications d’autrui restent masqués jusqu’à la levée autorisée d’anonymat ; les notes par critère restent disponibles pour la sélection. Aucune observation saisie par le jury n’est comparée aux noms privés dans une réponse API, afin de ne pas permettre d’en deviner un nom. Les jurés ne peuvent pas réécrire les observations d’autrui pendant l’anonymat. Le déport utilise uniquement des motifs prédéfinis, sans champ permettant d’indiquer un nom.

Les métadonnées, téléchargements et aperçus des pièces jointes stockées par EnactSpace sont interdits pendant l’anonymat, y compris aux administrateurs. Les nouveaux dépôts anonymes exigent des fichiers envoyés dans EnactSpace, et refusent les simples liens de documents.

Après publication de la présélection, seuls administrateur, Team Leader, secrétaire générale et chef/adjoint du pôle Veille peuvent activer la levée d’anonymat. L’identité et les documents deviennent alors accessibles aux membres actifs du jury de cette campagne et aux responsables habilités. Les autres membres de l’équipe ne reçoivent pas cet accès. L’action est journalisée.

Pour d’anciens documents déjà hébergés sur un service externe, masquer leur lien dans EnactSpace ne révoque pas un accès indépendant à ce service. Leur propriétaire doit les rendre privés ou les remplacer par des fichiers privés avant de garantir leur confidentialité hors d’EnactSpace.

## Publier les deux sélections

La publication exige les avis et une décision pour chaque dossier du lot. Elle refuse un bilan devenu obsolète et sérialise les publications concurrentes. Les résultats et leurs mails sont enregistrés dans une seule transaction ; un échec annule tout le lot. Une relance ne crée pas de doublons.

Les anciennes actions de décision ou de clôture individuelle sont désactivées pour ces dossiers. La publication finale vérifie aussi les dates d’entretien courantes, afin qu’un entretien reporté après la préparation d’une décision bloque sa publication prématurée.

Les résultats sont consultables au même instant pour tout le lot. Tous les mails ont la même date de mise à disposition dans la file existante ; leur arrivée effective dépend de la file d’envoi et des fournisseurs des destinataires. Les messages de refus remercient le candidat sans présenter le résultat comme un jugement sur ses capacités.

L’envoi des e-mails doit être configuré (`EMAIL_ENABLED` et `SMTP_HOST`) et le traitement habituel de la file doit fonctionner. La redirection générale vers une adresse de test doit être désactivée avant la publication des résultats réels. Le panneau affiche les envois terminés, les nouvelles tentatives et les échecs. Les anciens dossiers sans code reçoivent un code de suivi dans leur mail de résultat.

Après la présélection, programmer les entretiens des dossiers retenus et recueillir leurs évaluations. Les notes d’entretien sont distinctes des notes de dossier. Préparer ensuite acceptation, refus ou liste d’attente et publier ce deuxième lot. La conversion en compte membre exige une acceptation finale publiée.
