# Campagne test et cycle de vie du recrutement — 1 novembre 2026

## Constat

Le backend 1.0.21, schéma `20261031_0033`, refuse volontairement la
suppression d'une campagne contenant des candidatures (HTTP 409). L'interface
annonçait pourtant une suppression en cascade. Une ancienne campagne test et
un dossier sont recensés par l'audit du 1 novembre ; la liste `campaigns: []`
de cet audit filtre les campagnes antérieures au 30 octobre et ne prouve pas
l'absence de cette ancienne campagne.

## Comportement de l'interface corrigée

- Campagne vide : confirmation explicite avant suppression définitive.
- Campagne avec candidatures : explication de la conservation des dossiers et
  action de fermeture ; aucune promesse de suppression en cascade.
- Candidature déposée entre chargement et suppression : le HTTP 409 fait
  apparaître la fermeture, sans répéter une suppression impossible.
- Campagne active déjà expirée : sa fermeture reste accessible.
- Campagne déjà fermée avec dossiers : informations conservées et consultables.

Les trois fichiers Dart concernés sont analysés avec le SDK officiel Dart
3.13.7 et les sources Flutter 3.47.5. Les nouveaux tests de widgets doivent
être exécutés sur Windows avant le prochain build ; le correctif n'est pas
encore dans le web public 1.0.21 build 24.

## Vérifications HTTP isolées

`backend/test_recruitment_campaign_lifecycle.py` couvre sept parcours :

1. Création, annonce avant ouverture, dates UTC incluant le 8 novembre,
   refus avant ouverture, candidature et doublon, fermeture, suivi et
   évaluation après fermeture, refus de suppression d'un dossier existant.
2. Suppression d'une campagne vide, préservation de l'autre, seconde
   suppression et identifiant inconnu en 404.
3. Titre vide et dates inversées refusés sans création.
4. Modification partielle des dates invalide refusée sans altération.
5. Fermeture d'une campagne expirée conservant les dates.
6. Un juré sélectionné peut consulter, sans droit de créer, fermer ou supprimer.
7. CV encore accessible au personnel autorisé après fermeture et refusé à
   un membre sans autorisation.

Le module existant `test_recruitment_campaign_readiness` complète ces
parcours. La concurrence PostgreSQL entre dépôt et fermeture a déjà été
validée par la répétition privée de la version déployée ; ces nouveaux tests
HTTP exécutés localement utilisent une base SQLite isolée.

## Nettoyage exceptionnel demandé par le propriétaire

`tools/cleanup_recruitment_test_campaign_windows.ps1` télécharge des fichiers
immuables et vérifie leur SHA-256 local et distant. Il lance les tests du
lanceur et du contrôle de sauvegarde, puis le programme distant rejoue les quinze tests HTTP et de
nettoyage dans un conteneur sans réseau avec base SQLite et messagerie
désactivée. Aucun test ne se connecte à la base de production.

Par défaut, seul un inventaire PostgreSQL en lecture seule est effectué. Avec
`-Execute`, le nettoyage autorisé est limité à l'unique campagne existante,
terminée avant novembre, et exactement au dossier recensé par l'audit. Une
autre campagne, un autre volume, une conversion en compte ou des pièces
jointes bloquent cette sélection automatique et produisent un inventaire
pour préparer une opération adaptée.

Après cet inventaire, le lanceur prend le verrou de publication du backend,
arrête temporairement les quatre services applicatifs et exige une nouvelle
sauvegarde avec restauration vérifiée. Il ne modifie ni Compose, ni image,
ni schéma, ni réglages de messagerie. Les lignes de la campagne sont relues
et leur empreinte complète doit encore correspondre au plan.

Une seule transaction PostgreSQL supprime les dossiers, évaluations,
questionnaires, compositions et affectations de jurys, notifications, files
de courriels et de push et événements d'audit liés à cette campagne. Les
liaisons inconnues ou entre campagnes bloquent l'opération. Les comptes
globaux, les notifications et courriels indépendants, y compris ceux adressés
au même destinataire, sont conservés. Les pièces jointes nécessitent une
opération distincte qui prend en compte fichiers physiques et références.

Avant commit, le nombre de lignes supprimées et les identifiants des lignes
non ciblées sont vérifiés. Toute erreur avant commit annule la transaction.
Les services sont redémarrés avec la configuration initiale et leur image,
leur version et les réglages de messagerie sont contrôlés. Un conteneur
temporaire dont l'arrêt n'est pas prouvé bloque ce redémarrage pour éviter
une écriture concurrente non maîtrisée.

Le compte rendu privé `cleanup.json` conserve uniquement le périmètre,
les quantités, l'identifiant de sauvegarde et les vérifications. Les
sauvegardes suivent leur rétention habituelle ; les courriels déjà livrés
aux boîtes des destinataires ne peuvent pas être rappelés par ce nettoyage.
Le lancement distant via systemd continue si la session SSH se ferme.

## Limites et suite

### Première exécution sur le VPS

L'opération `cleanup-recruitment-test-75d0ed9b932948118efebfdafc093491`
a réussi ses quinze tests isolés et identifié l'unique campagne
`c430e401-34ca-4f4b-8713-aaab44faba6f`, intitulée
« Campagne de recrutement Enactus ESP 2027-TEST », du 16 au 29 octobre.
Elle contient un dossier, quatre notifications, six courriels, un push et
un événement d'audit ; aucun fichier ni compte converti n'est lié.
L'arrêt s'est produit à `fresh_verified_backup` avant toute suppression,
et les quatre services ont été remis en marche. L'installation de
l'interface sur Windows n'a donc pas encore été exécutée.

Le code du planificateur de sauvegarde n'autorisait que les révisions
0025 et 0031. La révision 0033, déjà déployée, est désormais ajoutée à cette
liste explicite, et ses tests refusent toujours les révisions inconnues.
La reprise ci-dessous a confirmé cette ancienne liste sur le VPS. Les
sources reconnues utilisaient des fins de ligne Windows ; leurs empreintes
normalisées correspondaient aux programmes vérifiés.

La reprise ajoute `-ApproveBackupSchema` : avant de mettre les services en
pause, elle vérifie le programme systemd, le répertoire de travail et les
empreintes connues du planificateur et du moteur de restauration. Si la
copie correspond exactement à la version connue, seul le littéral
`APPROVED_REVISIONS` reçoit `20261031_0033`. Le fichier précédent est conservé
en privé, et propriétaire et permissions sont préservés. Une version
inconnue ou une sauvegarde en cours bloque avant l'arrêt des services.

La sauvegarde complète et la restauration isolée restent obligatoires.
Le nouveau reçu doit prouver explicitement la restauration du schéma
0033 ; un ancien reçu 0031 est refusé. Les erreurs du lanceur affichent
maintenant leur code fixe et un diagnostic limité à l'état systemd et aux
indicateurs de la dernière sauvegarde, sans journaux bruts ni secrets.
La reprise vérifie aussi l'identifiant exact de la campagne déjà identifiée.

### Nettoyage terminé sur le VPS

Le compte rendu du 1 novembre, fourni à 12:56 UTC, confirme le succès de
`cleanup-recruitment-test-86cfb8feebf042c9b1359b6f446b755d` :

- 27 tests du lanceur et du contrôle de sauvegarde, puis 15 tests isolés,
  sans échec ni test ignoré.
- Nouvelle sauvegarde `20261101T125122Z_bd40f1`, avec restauration du schéma
  0033 explicitement vérifiée.
- Une campagne et un dossier supprimés, ainsi que quatre notifications,
  six lignes de livraison d'e-mails, une livraison push et un événement
  d'audit appartenant à ce test.
- Aucune pièce jointe à retirer ; comptes et lignes non ciblées conservés.
- Inventaire final : zéro campagne, zéro candidature.
- Quatre services remis en marche et contrôle HTTPS public de l'API réussi.

Le champ `backup_guard.unit` contient l'état initial de l'unité, avant
correction ; son ancien état `failed` ne contredit pas la restauration
0033 réussie ensuite. L'actualisation du planificateur a été appliquée, sans
changer le schéma, l'image applicative ou le routage des messages.

### Installation de l'interface à terminer

La suppression est acquise. L'étape suivante, `SyncFrontend`, a refusé le
premier fichier local avant tout remplacement. Le premier installateur
n'acceptait que l'empreinte d'un code déjà reformatté, pas celle du fichier
d'origine pourtant présent dans le dépôt. Les contenus locaux exacts n'ont
pas été lus depuis le poste, actuellement hors ligne dans Desktop Commander.

La version 2 du synchroniseur reconnaît à la fois les sources d'origine
épinglées et leur version reformattée. En cas de différence d'empreinte,
elle compare la sortie du même formateur Dart, avec des options explicites
et `--output=show`, sur le fichier local et les deux références. Elle
n'écrit pas dans le fichier local pour effectuer cette comparaison.

Une différence réelle de contenu prépare une archive limitée aux trois
sources concernées et aux empreintes de comparaison, dans Téléchargements,
avant tout remplacement. Cette archive peut être jointe pour réaliser une
fusion adaptée. Aucune différence de code inconnue n'est acceptée de force.
Les trois références téléchargées et les trois fichiers cibles sont
vérifiés avant comparaison. Des contrôles supplémentaires détectent une
modification pendant la préparation, et les sources précédentes sont
sauvegardées avant copie.

Treize vérifications avec le SDK officiel Dart 3.13.7 confirment les
empreintes épinglées, la reconnaissance du formatage et des fins de ligne
Windows, et le refus d'un changement de texte dans le code.

### Interface installée et validée sur Windows

Le synchroniseur du commit `917405168450da023d0a86e5fd4c832f01350a8e`
a ensuite terminé son exécution sur le poste de développement :

- Sauvegarde des trois fichiers dans
  `C:\Users\DIOP\AppData\Local\EnactSpace\CodeRollback\recruitment-lifecycle-60feba67731e44cb909891bcccaf3c2a`.
- Formatage des trois fichiers : aucun changement restant.
- Analyse ciblée : aucune anomalie.
- 29 tests de gestion des campagnes réussis, dont fermeture d'une campagne
  avec dossier, arrivée d'une candidature avant suppression, fermeture
  d'une campagne expirée, confirmation avant suppression d'une campagne vide,
  conservation des données après erreur et affichage mobile à 390 pixels.

L'installation locale est donc terminée. Le marqueur
`CORRECTIF_INTERFACE_NON_ENCORE_DEPLOYE_SUR_LE_WEB` confirme que ce test
n'a pas effectué de build ou de publication web.

### Publication web terminée

La publication est le web **1.0.22, build 25**, à partir des sources
locales analysées et testées. Le lanceur inchangé est
`tools/build_publish_web_windows.ps1` du commit
`5dc33c30398db9a040debb68a32778cc255f5e66`, SHA-256
`2535e443cc5de435cd4d9953c6ac563a1583d05aa53879d4a96aae33eb9c7656`.
Il a déjà servi aux publications précédentes et vérifie la version et
l'empreinte du JavaScript servi publiquement après la publication.

La commande préalable a contrôlé le web 1.0.21 build 24 et l'API 1.0.21.
Le compte rendu confirme ensuite le build 1.0.22 build 25, les cinq tests du
programme de publication et les contrôles des ressources et routes web.
La dernière vérification du lanceur, après les contrôles locaux du VPS,
confirme la version publique et le SHA-256 du JavaScript par HTTPS :

- JavaScript public :
  `047f7328b4dc0c038b2d6e5540e73b4b9d7367647cfe385a0388cc2685d311e5`.
- Retour arrière web :
  `/opt/enactspace/releases/web-previous-885466447cb94d4a9640443dfabbfcd2`.
- Backend et Android inchangés par cette publication ; aucun nouveau
  nettoyage ni création de campagne n'a été effectué.

Le champ `public_https_checked: false` appartient au compte rendu du
programme exécuté localement sur le VPS. Le marqueur ultérieur
`WEB_PUBLIC_1.0.22_25_HTTPS_ET_EMPREINTE_OK` est la preuve du contrôle public
supplémentaire effectué depuis Windows.

### Paramétrage de la campagne réelle

La campagne réelle reste à créer depuis le compte habilité de son
responsable, afin que `created_by` soit celui de l'utilisateur connecté.
L'accès est `/recruitment`, puis « Gérer les campagnes » et « Créer une
campagne ». Paramètres préparés à partir du calendrier fourni :

| Champ | Valeur |
| --- | --- |
| Titre proposé | Recrutement Enactus ESP 2026-2027 |
| Date de début | 04/11/2026 |
| Date de fin | 08/11/2026 |
| Activer après création | Oui |
| Questions | Questionnaire préparé, à relire dans l'éditeur avant création |

L'activation avec cette date future produit l'état « Planifiée » et rend
la campagne disponible dans le calendrier public pour le compte à rebours.
Les candidatures restent refusées avant le 4 novembre 2026 à 00:00 UTC
(Africa/Dakar). La date de fin est inclusive : fermeture le 9 novembre à
00:00 UTC, après toute la journée du 8.

Le tri reste prévu du 9 au 14 novembre et les entretiens du 16 au 21,
prioritairement entre 12:00 et 14:30, avec des possibilités en soirée.
La durée par candidat, les équipes de jury et les créneaux précis restent
à paramétrer. Aucun quota de candidatures ou de recrutements n'a été inventé.

Après création, contrôler le calendrier public et reprendre l'audit de
préparation. Il reste à vérifier notamment la délivrabilité réelle,
le proxy et ses limites, la copie de sauvegarde hors site, les habilitations
des jurys, le contact candidat et le calendrier de décision finale. Les
essais privés PostgreSQL et 500/1000 dossiers de l'image déployée ont déjà
réussi ; un inventaire en lecture seule ne constitue pas à lui seul une
certification de tout le parcours en production.
