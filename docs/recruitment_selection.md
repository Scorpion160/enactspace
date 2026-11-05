# Sélection des candidatures

Les nouvelles campagnes utilisent `blind-selection-v1`. La migration `20261105_0035` applique aussi ce processus aux campagnes actives et aux dossiers encore à étudier. Les résultats déjà communiqués et les entretiens déjà engagés sont conservés. Un ancien nombre de clubs inconnu reste « Non renseigné » ; les nouveaux dossiers doivent le déclarer.

## Parcours candidat

Les critères apparaissent avant le formulaire : DIC3, DESCAF3 (alias DESCFAF3), Master2 et DIT2 sont inéligibles, ainsi qu’un engagement dans au moins trois clubs ou structures étudiantes. Le serveur contrôle ces critères même si le formulaire est contourné.

Le suivi comprend réception, étude, résultat du dossier, entretien et décision finale. Un refus lors de la présélection termine le parcours au résultat du dossier. Les décisions préparées restent privées jusqu’à la publication de leur lot.

## Préparer et évaluer

1. Nommer les jurés actifs de la campagne.
2. Sélectionner la campagne dans l’espace recrutement et ouvrir le panneau de présélection.
3. Répartir les dossiers : deux avis indépendants par défaut, réglables de deux à cinq. La répartition aléatoire équilibre la charge et une relance complète seulement les attributions manquantes.
4. Chaque juré utilise la grille commune sur ses dossiers. Un écart d’au moins 20 points sur 100 déclenche un avis supplémentaire ; ce seuil est réglable. S’il manque un juré disponible, compléter le jury puis relancer la répartition.
5. Un juré qui reconnaît une personne peut demander un autre évaluateur. Son attribution et son éventuelle note sont écartées du calcul, avec conservation de la trace d’audit.
6. Préparer une décision par dossier, puis clôturer les dépôts avant de publier la présélection.

Avec 500 dossiers, 20 jurés et deux avis, la charge initiale est de 50 dossiers par juré, avant les avis supplémentaires.

## Anonymat et documents

Le serveur masque identité, coordonnées, parcours identifiant, code de suivi et liens de documents. Il masque aussi les noms, contacts et liens reconnaissables dans les réponses et les observations. Le formulaire demande de ne pas insérer d’identité dans les réponses libres ; une personne peut néanmoins être reconnaissable par un récit particulier, d’où la possibilité de déport.

Les métadonnées, téléchargements et aperçus des pièces jointes stockées par EnactSpace sont interdits pendant l’anonymat, y compris aux administrateurs. Les nouveaux dépôts anonymes exigent des fichiers envoyés dans EnactSpace, et refusent les simples liens de documents.

Après publication de la présélection, seuls administrateur, Team Leader, secrétaire générale et chef/adjoint du pôle Veille peuvent activer la levée d’anonymat. L’identité et les documents deviennent alors accessibles à ces responsables ; les autres jurés gardent une vue anonyme. L’action est journalisée.

Pour d’anciens documents déjà hébergés sur un service externe, masquer leur lien dans EnactSpace ne révoque pas un accès indépendant à ce service. Leur propriétaire doit les rendre privés ou les remplacer par des fichiers privés avant de garantir leur confidentialité hors d’EnactSpace.

## Publier les deux sélections

La publication exige les avis et une décision pour chaque dossier du lot. Elle refuse un bilan devenu obsolète et sérialise les publications concurrentes. Les résultats et leurs mails sont enregistrés dans une seule transaction ; un échec annule tout le lot. Une relance ne crée pas de doublons.

Les résultats sont consultables au même instant pour tout le lot. Tous les mails ont la même date de mise à disposition dans la file existante ; leur arrivée effective dépend de la file d’envoi et des fournisseurs des destinataires. Les messages de refus remercient le candidat sans présenter le résultat comme un jugement sur ses capacités.

L’envoi des e-mails doit être configuré (`EMAIL_ENABLED` et `SMTP_HOST`) et le traitement habituel de la file doit fonctionner. Le panneau affiche les envois terminés, les nouvelles tentatives et les échecs.

Après la présélection, programmer les entretiens des dossiers retenus et recueillir leurs évaluations. Les notes d’entretien sont distinctes des notes de dossier. Préparer ensuite acceptation, refus ou liste d’attente et publier ce deuxième lot. La conversion en compte membre exige une acceptation finale publiée.
