# Campagne Enactus ESP — jury, entretiens et questionnaire

État au 31 octobre 2026 : la recette de l’extension 0033 réussit sur le VPS : 265 tests et les volumes 500 et 1 000 dossiers, sans échec/erreur/test sauté. La base temporaire ne présente aucun événement de manque de mémoire et tous les conteneurs et volumes temporaires sont supprimés. La synchronisation Windows s’arrête ensuite sur une différence de source avant tout remplacement ; les tests Flutter restent nécessaires. Un défaut de comparaison des fins de ligne Windows/Linux est reproduit et corrigé sur les copies de vérification. Les sources préparées ne constituent pas encore un déploiement ni un feu vert de campagne. Aucun paiement n’est réactivé par ce chantier.

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
- Les responsables autorisés peuvent constituer une ou plusieurs équipes nommées par campagne, en changer les membres, les renommer ou les mettre en pause. Les membres proviennent du jury de la campagne. « Réunir tout le jury » propose tous les membres disponibles ; pour fonctionner en jury unique, conserver cette équipe active et mettre les autres en pause.
- Chaque candidat reçoit son propre rendez-vous, avec une équipe enregistrée ou une composition personnalisée. Deux équipes sans membre commun peuvent travailler au même moment. Une équipe ou un juré commun ne peut pas recevoir deux candidats sur des créneaux qui se chevauchent ; deux créneaux adjacents sont possibles. Prévoir des salles distinctes pour les équipes en présentiel : le nom libre du lieu n’est pas un système de réservation de salles.
- Les modifications d’équipe utilisent une version pour éviter que deux responsables écrasent leur travail. Les rendez-vous existants conservent le nom, la version d’équipe et les jurés choisis. Les entretiens à venir sont signalés si l’équipe change ou est mise en pause ; le responsable ouvre le dossier et confirme sa composition actuelle ou choisit une autre équipe. Aucune nouvelle convocation n’est envoyée pour un simple changement interne de jury ; les changements d’horaire, format ou lieu continuent à prévenir le candidat.
- Les anciens champs d’entretien restent lisibles. Le nouveau planning utilise des jurés identifiés ; les rendez-vous historiques reposant seulement sur du texte doivent être revus avant la campagne.

## Compte à rebours public

La page Postuler affiche les campagnes actives à venir et ouvertes, avec quatre cases : jours, heures, minutes et secondes. Les campagnes inactives ou déjà terminées ne sont pas annoncées par ce calendrier public. Les informations internes de préparation et les données du jury restent privées.

Le compteur part de l’heure du serveur puis avance localement, sans requête à chaque seconde. La page recharge les dates chaque minute pour reprendre une modification de campagne. Avant l’ouverture, l’action de candidature est désactivée ; à l’ouverture le compteur vise la clôture, puis le bouton devient indisponible. Le serveur reste l’autorité pour accepter ou refuser un dépôt, même en cas de page ancienne ou d’horloge locale incorrecte.

Les dates existantes sont interprétées à l’heure de Dakar : ouverture le 4 novembre 2026 à 00 h et clôture le 9 novembre à 00 h, donc tout le dimanche 8 reste disponible. Une autre date de campagne produit automatiquement un autre compte à rebours. Aucune candidature anticipée ni activation de campagne n’est créée par le widget. Le compteur n’affiche pas de durée négative ; ses quatre cases passent sur deux colonnes lorsque la largeur ou le grossissement du texte le demande. Il n’annonce pas chaque seconde comme une alerte de lecteur d’écran.

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
| Migrations 0032 puis 0033 | Sauvegarde vérifiée, maintenance API/workers, migration contrôlée puis redémarrage de la version candidate ; ne pas publier le frontend avant que les nouveaux endpoints soient disponibles |
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


Validation locale après correction du lanceur de recette : 205 tests backend réussis, dont les frontières de jury, la reprise du questionnaire, les migrations SQLite et les gardes du lanceur ; analyse Dart sans problème sur le recrutement, les démonstrations et les tests. Un contrôle exécuté avec Dart vérifie aussi les instants d’ouverture, de clôture et l’ancrage sur l’heure du serveur. Les 17 nouveaux tests Flutter du compteur et des équipes s’ajoutent aux neuf précédents et restent à exécuter dans la copie Windows. La nouvelle recette Docker/PostgreSQL comporte 265 tests puis les deux volumes.


## Compte rendu du 31 octobre — compatibilité de la migration 0032

Le journal transmis confirme la recette du premier durcissement : 179 tests, aucun échec, aucune erreur, aucun test sauté ; les volumes 500 et 1 000 dossiers passent et les ressources temporaires sont supprimées. Il ne s’agit pas d’un essai de charge du proxy public. Avec la limitation de recette à 0,5 CPU pour le conteneur de tests, la soumission au 95e percentile prend respectivement 2,480 s et 2,204 s. Le chargement complet de 1 000 dossiers représente encore environ 10,8 Mo et 5,266 s dans cet essai ; ce résultat ne prouve pas à lui seul le confort sur un réseau mobile.

La recette étendue a ensuite exécuté 213 tests mais s’est arrêtée sur trois initialisations PostgreSQL. La cause commune est `DuplicateColumn: campus_resident` pendant la migration 0032. La révision initiale 0001 construit une base neuve avec `Base.metadata.create_all` et les modèles actuels : les nouveaux objets peuvent donc exister avant que 0032 soit atteinte. La production en 0031 précède ces modèles et doit au contraire recevoir les ajouts.

Le correctif conserve les deux chemins. Il contrôle les types, la nullabilité, les clés et les liens des objets déjà présents, crée uniquement ceux qui manquent et bloque sur une structure incompatible. Il ne supprime ni ne remplace les données existantes. Le retour arrière refuse également d’effacer des informations de campus ou d’entretien, même sans nomination au jury ni réponse au questionnaire.

Cinq tests ciblés vérifient notamment une base issue des modèles actuels avec un jury et un brouillon déjà enregistrés, la mise à jour d’un ancien schéma, une deuxième exécution, le refus d’un type incompatible et la protection des données au retour arrière. La suite locale complète de 181 tests passe. Un essai PostgreSQL supplémentaire reconstruit une base 0031 dans un schéma temporaire, y place une candidature fictive avec référence de CV, puis vérifie la migration vers 0032 et la conservation de ces informations. Son exécution, celle des tests PostgreSQL précédemment bloqués et les deux volumes doivent encore être confirmées par le nouveau compte rendu du VPS.

Les deux essais reçus confirment `production_services_changed=false`, `production_migration_performed=false` et `owned_runtime_resources_removed=true`. Aucun nettoyage supplémentaire des conteneurs de ces essais n’est nécessaire avant la nouvelle recette.

## Compte rendu du 31 octobre — recherche du code de suivi

Le compte rendu suivant, opération `c60ad100500343fabe01d1dc1ef9f63d`, exécute 227 tests : aucune erreur ni aucun test sauté, mais un échec. Les chemins de migration précédemment bloqués passent. Le test de deux sauvegardes concurrentes reçoit deux réponses 404 avant d’atteindre le contrôle de version ; il attend une sauvegarde acceptée et une réponse 409 invitant à recharger la version récente. Les volumes ne sont pas lancés après cet échec. Les ressources temporaires sont supprimées et aucun service ni schéma de production n’est modifié.

La référence du candidat de ce test est un code de suivi de 32 caractères hexadécimaux. La recherche précédente le traitait exclusivement comme l’identifiant historique d’une candidature parce qu’il peut être converti en UUID. Le correctif recherche le code de suivi et, lorsque le format le permet, l’identifiant historique, toujours avec l’e-mail du candidat. Une référence qui correspondrait à deux dossiers distincts est refusée plutôt que de sélectionner arbitrairement une campagne. Les codes habituels `ESP-…` conservent leur comportement.

Trois nouveaux tests reproduisent le chargement et l’enregistrement avec un code de cette forme, le maintien des références historiques et de la vérification de l’e-mail, ainsi que le refus d’une référence ambiguë entre campagnes. Le test PostgreSQL vérifie désormais aussi que le code retrouve le bon candidat avant de lancer les deux écritures. Son attente reste une réponse 200 et une réponse 409 ; le contrôle de concurrence n’est pas assoupli. La recette complète à relancer contient 233 tests, puis les deux volumes. Ce résultat PostgreSQL reste à obtenir sur le VPS avant de préparer le déploiement.

## Compte rendu suivant — recette 0032 réussie et extension équipes

Le journal transmis pour l’opération `3b9e686206e4475397b3a02ac21e7a56`, commit `324ecb21982be5c682db4ad08c8ea80857e532c2`, confirme 233 tests, zéro échec/erreur/test sauté et les deux volumes. Le statut final est `RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED`, avec `owned_runtime_resources_removed=true`. L’image conservée est `enactspace-backend:recruitment-hardening-3b9e686206e4`, identifiant `sha256:41784ddcfcada82216f97515f2ba2bd533cd17e628833e6dca39b6e403e9cd18`. Aucun nettoyage supplémentaire n’est requis pour ces conteneurs.

Les 500 et 1 000 dossiers correspondent bien aux codes de suivi et aux pièces fictives. Le 95e percentile de soumission est respectivement de 2,502 s et 2,194 s ; les lectures internes des listes prennent 1,085 s et 1,854 s. La liste complète de 1 000 dossiers reste volumineuse (environ 11,2 Mo). Ces mesures isolées avec de petits PDF ne démontrent pas le débit du proxy public, les fichiers maximaux ni le confort sur tous les réseaux mobiles.

L’extension 0033 ajoute trois tables pour les équipes, leurs membres et l’équipe retenue pour chaque rendez-vous. Sa migration conserve les chemins base neuve et ancienne 0032 et refuse un retour arrière qui effacerait un historique d’équipe. Treize tests locaux supplémentaires couvrent les équipes, les dates et cette migration. La nouvelle recette ajoute leurs contrôles PostgreSQL ainsi que les courses de deux rendez-vous du même jury, de deux équipes distinctes et de deux modifications de composition.

Le script de synchronisation Windows vérifie une copie complète du frontend avant de remplacer les fichiers, et accepte les sources de base ou la version précédente explicitement épinglée. Une modification locale différente bloque le remplacement. Les sources du compte à rebours ne seront publiées sur le web qu’après disponibilité des nouveaux endpoints et validation du parcours réel.

## Compte rendu suivant — les 257 tests passent, arrêt de la base d’essai pendant le volume

L’opération `dc98795e7c6c49aab8ccc7efa77633f5`, lancée depuis le commit `3eb061181f07ed7d78e7b3c884411a59f8653463`, exécute les 257 tests avec succès en 378,604 s. Pendant l’essai de volume, PostgreSQL ferme ensuite ses connexions. Le statut final est `RECRUITMENT_REHEARSAL_BLOCKED`, étape `volume_tests`. Le nettoyage des deux conteneurs est confirmé ; la production, son schéma et ses services ne sont pas modifiés. Le script frontend n’a pas été exécuté après cet arrêt.

Le journal ne contient pas l’état mémoire du conteneur disparu ; une saturation mémoire n’est donc pas prouvée pour cet incident. La configuration du banc avait cependant un plafond mémoire de 512 Mio et un répertoire de données PostgreSQL en `tmpfs` de 768 Mio. Docker documente que les données `tmpfs` comptent dans le plafond mémoire du conteneur : cette configuration pouvait donc saturer pendant l’accumulation des écritures. [Référence Docker](https://docs.docker.com/engine/storage/tmpfs/).

Le correctif ne change ni les fonctions de recrutement, ni la concurrence de huit écritures, ni les volumes de 500 et 1 000 dossiers. Il utilise un volume disque neuf portant l’identifiant de l’opération, sans montage de données de production. Les limites CPU et mémoire des deux conteneurs restent celles de la recette précédente. Une réserve disque d’au moins 8 Gio est requise ; le lanceur surveille cette réserve et arrête son propre conteneur de tests si les données temporaires dépassent 2 Gio ou si le délai de 20 minutes est atteint.

Avant le nettoyage, le rapport conserve l’état et le code de sortie des conteneurs, les indicateurs de manque de mémoire et quelques signaux d’erreur PostgreSQL. Les variables d’environnement et les journaux bruts ne sont pas inclus dans ce diagnostic. Les compteurs des tests déjà terminés restent dans le rapport même si le volume échoue ensuite. Le volume est supprimé après les conteneurs uniquement si son nom, son propriétaire et son pilote sont vérifiés ; une erreur d’inventaire ou un volume encore utilisé bloque un compte rendu de nettoyage réussi. Aucune suppression globale de volumes n’est exécutée.

La suite locale complète de 205 tests passe ; les 20 tests ciblés du lanceur et de son enveloppe passent également. Huit nouveaux tests du lanceur vérifient les frontières de propriété, le stockage sur disque, la réserve, l’arrêt du seul processus de recette, les diagnostics sans secrets et la conservation du résultat des tests. La nouvelle collection contient 265 tests avant les mêmes deux essais de volume. Les sources d’interface et les fichiers métier du backend sont identiques à la version ayant passé les 257 tests ; les suites Flutter attendent toujours leur exécution sous Windows.

## Compte rendu suivant — recette 0033 complète réussie, vérification Windows à reprendre

L’opération `abaf52081f3b46eca9f763d8c4ae681a`, commit de lancement `ed97bdd3a69f0093a45ffe5f401ea19c908a45e2`, termine les 265 tests en 459,592 s puis les deux volumes. Le statut est `RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED`, avec zéro échec/erreur/test sauté et `owned_runtime_resources_removed=true`. L’image conservée est `enactspace-backend:recruitment-hardening-abaf52081f3b`, identifiant `sha256:415403e80c33ab717337d3e742bfea544dcc3651fc147da107450d76582bcc04`. Les sources vérifiées correspondent à la révision de paquet `be81a48f50c6eb06e9c34b60d84c6e2cdf654209` et au schéma `20261031_0033`.

Les deux mesures conservent huit écritures concurrentes et un CV fictif de 8 415 octets. Pour 500 dossiers, le 95e percentile de soumission est de 2,269 s, la lecture interne de liste de 0,976 s et l’export de 0,203 s. Pour 1 000 dossiers, ces valeurs sont de 2,204 s, 1,685 s et 0,308 s. Les dossiers, codes de suivi et fichiers concordent. Le répertoire de données temporaire occupe environ 325 Mo au dernier relevé ; PostgreSQL reste dans sa limite de 512 Mio sans événement `oom` ni `oom_kill`. Les tests ne couvrent toujours pas le proxy public ni les fichiers maximaux.

Le script client s’arrête ensuite sur `lib/core/auth/user_experience.dart` et n’installe aucun fichier. Les fins de ligne constituent une cause possible de ce rejet, sans preuve du contenu exact du fichier Windows. Un essai avec Dart 3.13.7 reproduit le défaut : le même fichier au format LF et CRLF conserve des empreintes différentes après `dart format`, alors que son texte normalisé est identique.

Le correctif normalise les fins de ligne et l’encodage UTF-8 des seules copies de candidat, de référence et de comparaison avant et après leur formatage. Les originaux restent inchangés pendant ces vérifications ; une véritable différence de code, un fichier manquant ou une modification concurrente continue de bloquer le remplacement. Les empreintes de téléchargement sont vérifiées sur les octets d’origine avant cette normalisation. La reprise porte uniquement sur le script frontend : le manifeste, les sources applicatives et la recette serveur réussie restent inchangés. Si une différence de code demeure après normalisation, examiner le fichier local avant de préparer une fusion ; ne pas contourner le contrôle.

Le correctif de comparaison est vérifié sur les 28 fichiers du paquet : variantes LF, CRLF et UTF-8 avec marqueur initial, soit 84 copies. Leur texte formaté normalisé concorde, tandis qu’une modification réelle de texte demeure distincte. Aucun fichier applicatif original ne change pendant ce contrôle. Si le script Windows constate encore des différences, il les regroupe avant de s’arrêter et prépare `recruitment-source-review.zip` avec les seules copies Dart concernées par le paquet et son manifeste public, pour permettre une revue groupée. Le frontend complet, les configurations de déploiement et les éléments de signature ne sont pas inclus.
