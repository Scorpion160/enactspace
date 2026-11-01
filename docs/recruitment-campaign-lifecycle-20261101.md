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
immuables et vérifie leur SHA-256 local et distant. Il lance neuf tests du
lanceur, puis le programme distant rejoue les quinze tests HTTP et de
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

Le nouveau nettoyeur doit encore être exécuté sur le VPS ; aucune campagne
n'a été supprimée depuis l'environnement de développement. La commande ne
crée pas la campagne réelle du 4 au 8 novembre. Après son succès, créer et
contrôler cette campagne depuis un compte habilité, puis poursuivre les
vérifications de délivrabilité, de proxy et d'organisation du jury encore
énumérées dans l'audit de préparation.
