# Campagne Enactus ESP — jury, entretiens et questionnaire

État au 31 octobre 2026 : sources préparées ; cette extension ne constitue pas encore un déploiement ni un feu vert de campagne. Le rapport de recette PostgreSQL sur le VPS reste nécessaire. Aucun paiement n’est réactivé par ce chantier.

## Planning confirmé et paramètres encore ouverts

| Période, heure de Dakar | Organisation |
|---|---|
| Mercredi 4 au dimanche 8 novembre inclus | Candidatures ; dates de campagne enregistrées au serveur, fermeture après le 8 novembre |
| 9 au 14 novembre | Étude des dossiers, confrontation des avis, invitations au questionnaire selon la présélection humaine |
| 16 au 21 novembre | Entretiens ; priorité aux pauses de 12 h à 14 h 30, possibilités en soirée et en ligne |
| Après les entretiens | Délibération, réponses, éventuelle liste d’attente, intégration des personnes retenues |

La date des décisions, les créneaux du soir, la durée des entretiens et les disponibilités des jurés restent à confirmer. Ils ne sont pas inventés dans le programme. Chaque rendez-vous possède sa propre heure de début, sa fin, son format, son lieu ou lien, et ses jurés. Les heures saisies dans la nouvelle interface sont explicitement celles de Dakar, y compris si l’alumni organise l’entretien depuis un autre fuseau.

Les durées et le nombre de jurys servent au calcul de capacité, pas à autoriser le développement. Pour six pauses proposées de 150 minutes, un jury peut réaliser au maximum `6 × floor(150 / (durée + battement))` entretiens : 42 pour 20 minutes sans battement, 30 pour 25 minutes avec 5 minutes de battement. Ce sont des hypothèses, non des créneaux promis. Le nombre de personnes à recevoir correspondra à la présélection, pas nécessairement à toutes les candidatures. Les soirées complètent cette capacité selon les disponibilités réelles.

## Ce qui est intégré

- Le formulaire demande facultativement la résidence au campus, les formats d’entretien possibles et les contraintes de disponibilité. Les réponses passent dans le dossier interne et l’export protégé. Une ancienne candidature conserve « non renseigné ». Un « non » n’est jamais transformé en donnée manquante.
- La résidence ne modifie aucune note ni aucune décision. Aucune adresse de chambre n’est demandée.
- Un jury est constitué séparément pour chaque campagne. Un compte enacteur ou alumni actif et vérifié peut être sélectionné. Une nomination n’ajoute aucun rôle global.
- L’administration, le Team Leader, la SG et les chef/adjoint du pôle Veille peuvent ajouter, retirer et réintégrer un juré. Un simple juré ne peut pas nommer d’autres membres.
- Les jurés sélectionnés consultent les campagnes et dossiers autorisés, les pièces jointes, les évaluations et les réponses terminées au questionnaire. Ils enregistrent leur propre avis. La nomination ne permet pas de gérer les campagnes, exporter les dossiers, décider des admissions ou créer les comptes membres.
- Les accès de recrutement déjà attachés à une responsabilité restent distincts de la nomination au jury. Retirer un administrateur du jury ne lui retire pas ses droits d’administration.
- Un retrait coupe l’accès donné par la nomination dès la requête suivante, conserve les avis et signale les entretiens à réattribuer dans une liste permettant d’ouvrir directement chaque dossier. Réintégrer une personne réactive la même nomination sans effacer l’historique.
- Le serveur vérifie les conflits de créneaux d’un juré, même entre deux campagnes. Les écritures prennent des verrous de campagne et de juré pour empêcher une double réservation concurrente. Le jury choisi doit encore être actif lors de l’enregistrement.
- Les anciens champs d’entretien restent lisibles. Le nouveau planning utilise des jurés identifiés ; les rendez-vous historiques reposant seulement sur du texte doivent être revus avant la campagne.

## Benchmark et choix du questionnaire

| Option | Intérêt et limite | Choix pour EnactSpace |
|---|---|---|
| Site externe de typologie | Parcours rapide, mais données hors de l’application, conditions de réutilisation variables et catégories faciles à surinterpréter | Pas de dépendance nécessaire pour cette campagne |
| IPIP à 50 affirmations | Fonds public et cotation documentée ; questionnaire plus long, traduction et usage local à vérifier | Référence pour une évolution ultérieure |
| Mini-IPIP à 20 affirmations | Cinq dimensions, quatre affirmations par dimension ; format court, avec une mesure moins détaillée | Base de préparation à l’échange, avec limites affichées |
| Mises en situation Enactus | Raisonnement, exemples vécus, engagement et manière de coopérer | Cinq questions séparées, lues par un jury humain |

Les affirmations anglaises et les clés IPIP sont dans le domaine public. Une adaptation française publiée du Mini-IPIP existe (Laverdière et al., 2020), mais sa validation ne s’applique pas automatiquement à une autre traduction ou aux étudiants de l’ESP. La présente version utilise une **traduction de travail EnactSpace**, annoncée comme non validée localement. Elle ne reproduit pas la traduction française de l’article et ne se présente pas comme un diagnostic ni comme une mesure certaine de la personnalité.

Le candidat répond de 1 à 5. Le serveur applique `6 − réponse` aux affirmations inversées et calcule la moyenne des quatre réponses de chaque dimension. Il ne produit ni percentile, ni type de personnalité, ni classement ou note globale d’adéquation. Aucune moyenne n’entre dans la grille humaine de recrutement. Les résultats sont des déclarations contextualisées, susceptibles notamment de désirabilité sociale ; demander des exemples et permettre au candidat de nuancer sa réponse.

Les cinq situations Enactus abordent :

1. Une solution qui ne répond pas aux priorités de la communauté : écouter et vérifier les besoins.
2. Un examen avancé qui met une mission en difficulté : prévenir et proposer un engagement réaliste.
3. Un prototype qui échoue avec un budget limité : tester une petite hypothèse avant d’investir davantage.
4. Un nombre de bénéficiaires non vérifié : présenter les faits honnêtement.
5. Une réunion où certaines personnes n’osent pas contribuer : faire une place à plusieurs manières de participer.

Ces situations s’inspirent des principes de projet Enactus ; le critère de compétition n’est pas transformé en test d’admission. Les réponses ne donnent pas de score automatique. Le jury croise des comportements décrits, les exemples et l’entretien. Il ne pénalise ni l’introversion, ni les contraintes de transport, ni les cours, ni la résidence hors campus.

### Parcours du candidat et confidentialité

L’équipe propose explicitement le questionnaire après le début de l’étude du dossier. Le candidat le retrouve dans le suivi de sa candidature avec son e-mail et son code, sans compte supplémentaire. Les identifiants restent dans le corps des requêtes, jamais dans l’URL.

Le candidat prend connaissance de l’utilisation des réponses, avance en six étapes et peut enregistrer pour plus tard. Chaque sauvegarde confirmée est conservée au serveur. Un message d’échec ne prétend pas que la sauvegarde a réussi. Une version de réponse empêche deux onglets de s’écraser silencieusement. Les réponses partielles ne sont pas accessibles au jury.

La confirmation finale fige les réponses et produit la synthèse côté serveur. Réessayer un envoi réussi n’ajoute pas une deuxième réponse. La synthèse est également visible par le candidat. Une échéance peut être prolongée sans perdre son brouillon. Le candidat peut choisir d’en parler pendant l’entretien : ses éventuelles réponses à ce questionnaire sont effacées, la préférence est enregistrée et son statut de candidature n’est pas modifié.

Les questions, la version et les règles de cotation sont conservées avec la réponse. Une modification future du questionnaire ne réinterprète pas les réponses anciennes. Les réponses ne figurent ni dans l’export CSV général ni dans les e-mails d’invitation. Les accès aux réponses terminées sont revérifiés par campagne.

Sources primaires consultées le 31 octobre 2026 :

- IPIP, [clés du Mini-IPIP](https://ipip.ori.org/MiniIPIPKey.htm), [permission](https://ipip.ori.org/newPermission.htm), [cotation](https://ipip.ori.org/newScoringInstructions.htm), [limites des normes](https://ipip.ori.org/newNorms.htm).
- Donnellan et al. (2006), [étude originale](https://pubmed.ncbi.nlm.nih.gov/16768595/).
- Laverdière et al. (2020), [adaptation française publiée](https://doi.org/10.1016/j.erap.2019.100512).
- Enactus, [Student Teams / Competition Handbook](https://enactus.org/competition-handbook/).

## Conditions avant le lancement

| Contrôle | Preuve à obtenir / solution en cas de difficulté |
|---|---|
| Recette de l’extension | Tests SQLite, migration, frontières d’accès, PostgreSQL, doubles réservations, sauvegardes concurrentes et volumes 500/1 000 sur données fictives ; aucun test sauté accepté |
| Interface Windows | Analyse Flutter et suites recrutement, démonstration et autorisations sur une copie du frontend avant remplacement des sources |
| Migration 0032 | Sauvegarde vérifiée, maintenance API/workers, migration contrôlée puis redémarrage de la version candidate ; ne pas publier le frontend avant que les nouveaux endpoints soient disponibles |
| Retour arrière | Garder l’image et la configuration précédentes ; les ajouts de schéma sont compatibles avec l’ancienne application. Ne pas supprimer les réponses ou nominations pour revenir au code précédent |
| Campagne | Une seule campagne active avec dates du 4 au 8 novembre ; confirmer questionnaire, contacts, message public et absence de campagne d’essai accessible |
| Candidat de contrôle | Déposer un dossier fictif identifié, recevoir réellement l’e-mail à une adresse maîtrisée, retrouver le suivi, être invité, sauvegarder/reprendre le questionnaire, planifier/replanifier un entretien et vérifier le message reçu |
| Accès du jury | Tester un compte enacteur et un compte alumni sélectionnés, puis retirer/réintégrer ; tester aussi un compte non sélectionné et les CV d’une autre campagne |
| École et connexion partagée | Tester plusieurs candidats derrière la même adresse réseau ; vérifier les quotas, le message de reprise et le comportement à 429 sans désactiver les protections |
| Fichiers et proxy public | Vérifier tailles autorisées, type réel, erreur explicite, limite du proxy et bonne attribution de l’IP. La recette de volume avec de petits PDF ne prouve pas le débit maximal des gros fichiers |
| Charge publique | Compléter la recette PostgreSQL par un essai HTTP sur un environnement isolé reproduisant le proxy ; ne pas bombarder le site public ou la messagerie |
| E-mails en panne | Surveiller la file d’envoi et les échecs ; le suivi de candidature reste la référence. Ne pas renvoyer en masse sans contrôler les messages déjà délivrés |
| Juré absent ou retiré | Filtrer les rendez-vous à réattribuer ; remplacer le juré et confirmer au candidat seulement si l’heure, le format ou le lieu change |
| Report d’entretien | Modifier le rendez-vous depuis la fiche, vérifier les chevauchements et contrôler l’e-mail ; prévoir des créneaux de réserve et un canal de contact annoncé |
| Sauvegardes | Contrôler fraîcheur et restauration, puis vérifier une copie hors site. Une sauvegarde locale récente ne prouve pas à elle seule la récupération hors VPS |
| Décisions et intégration | Croiser les avis humains ; tester acceptation, refus, liste d’attente et création d’un seul compte ; vérifier l’accès initial et l’accueil du nouveau membre |

Conserver un responsable opérationnel et un remplaçant identifiés pendant chaque phase, avec un point quotidien sur candidatures, erreurs de fichiers, messages non remis et entretiens à attribuer. Le contact candidat et la date finale de décision restent à renseigner avant l’ouverture.

## Lecture du résultat de recette

Le lanceur utilise une image candidate et des conteneurs PostgreSQL temporaires sans accès à la base ni aux volumes de production. Il ne migre pas la production, n’active pas la campagne, ne transmet pas de courriels et ne déploie pas le web. Les ressources temporaires sont supprimées uniquement après vérification de leur identité. Un échec de nettoyage bloque le compte rendu final ; aucun nettoyage Docker global n’est nécessaire.

Le statut attendu de la recette complète est `RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED`, avec zéro échec/erreur/test sauté, les deux volumes réussis et `owned_runtime_resources_removed=true`. Ce statut ouvre la préparation du déploiement ; il n’atteste pas encore les contrôles publics, la réception réelle des courriels ou l’activation de campagne.


Validation locale : 178 tests backend réussis, dont les frontières de jury, la reprise du questionnaire, la migration SQLite et les gardes du lanceur ; analyse Dart sans erreur ni avertissement sur le recrutement, les démonstrations et les tests. Les neuf nouveaux tests Flutter sont livrés pour exécution dans la copie Windows. Les essais Docker/PostgreSQL et les deux volumes doivent encore produire leur compte rendu sur le VPS.
