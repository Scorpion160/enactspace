# Campagne de novembre — contrôle VPS du 31 octobre 2026

Le compte rendu en lecture seule transmis par l'opérateur ne signale aucune modification de base, aucun redémarrage de service, aucun envoi d'e-mail ni activation de campagne pendant le contrôle.

## Ce qui est confirmé

- API et web en bonne santé ; les trois workers sont démarrés sans redémarrage enregistré. Les workers n'ont pas de sonde de santé configurée : cela n'atteste pas leur traitement de bout en bout.
- Stockage persistant des fichiers, accessible en écriture au backend, avec 143,1 Gio libres. La réserve conservatrice calculée pour 500 dossiers est de 29,3 Gio ; ce calcul ne prouve pas la capacité en débit ou en requêtes simultanées.
- Sauvegarde `20261031T030002Z_9dc1f7`, terminée le 31 octobre à 03:02 UTC, vérifiée et récente au contrôle. Timer actif. L'affichage de la prochaine exécution à 04:00 CET correspond à 03:00 UTC.
- Configuration production sans debug, création automatique de tables ni seed ; origine web attendue, e-mails activés, sans redirection, expéditeur institutionnel configuré.
- Schéma `20261007_0031`, une candidature existante, aucun code de suivi manquant ni conversion incohérente.
- Quatre comptes habilités au recrutement et quatre à la conversion. Ces nombres ne correspondent pas au nombre de jurys, lequel n'est pas encore décidé.
- La sélection de la file d'e-mails contient 21 messages envoyés, sans message en attente ou en échec dans ce périmètre. Cela n'atteste pas une nouvelle réception d'accusé candidat à une adresse contrôlée.
- Aucun fichier de recrutement n'entre dans l'échantillon : **zéro fichier contrôlé ne prouve pas un téléchargement de CV réussi**.

## Deux points bloquants

1. Les trois correctifs de recrutement ne sont pas déployés. Le backend et les workers utilisent encore la base `1ccbb0ac2b8220ee8eb19d24a9114790e7bf2b95`.
2. Aucune campagne correspondant à l'ouverture du 4 au 8 novembre n'a été trouvée par l'inventaire interne. L'inventaire portait sur les campagnes se terminant le 30 octobre ou après, ainsi que celles sans date de fin ; il ne constitue pas un inventaire historique exhaustif.

Les empreintes des trois fichiers présents sur le VPS correspondent aux sources de cette base Git avec les fins de ligne CRLF du checkout Windows. Aucune dérive de contenu supplémentaire n'a été constatée dans ces trois fichiers. Le candidat de correction sera construit sur l'image actuellement utilisée, avec un remplacement limité à ces trois modules et aux fichiers de recette. Les autres modules backend seront conservés.

## Volume retenu

L'équipe attend des centaines de candidatures, sans estimation plus précise. Préparer une vérification à **500 dossiers**, puis un essai de marge à **1 000 dossiers**. Les durées d'entretien et jurys parallèles restent à définir ; ils servent à organiser les créneaux et ne bloquent pas le travail technique.

La répétition proposée crée un PostgreSQL 16 temporaire sans réseau externe et un conteneur de tests partageant uniquement son réseau local isolé. Elle ne monte ni base, ni fichier, ni configuration secrète de production. Les ressources mémoire/CPU sont limitées et un contrôle de mémoire disponible est effectué avant de commencer.

Elle rejoue les tests SQLite existants, les scénarios PostgreSQL de doublons, clôture et conversion, puis crée 500 et 1 000 dossiers fictifs avec CV fictifs et une file d'e-mails sans envoi. Les latences du service, la taille et le temps de lecture des listes et exports sont relevés. **Ce test de volume du service et de la base ne remplace pas un test de charge HTTP à travers le proxy public**, ni une épreuve avec trois fichiers de taille maximale par candidat.

L'image candidate est conservée pour une publication ultérieure uniquement si les vérifications sont satisfaisantes. La répétition ne déploie rien et ne crée aucune campagne en production. Les conteneurs et données PostgreSQL temporaires sont supprimés après l'essai, en vérifiant leurs étiquettes de propriété.

Préparation contrôlée localement : 24 tests ciblés réussis, syntaxe Python et empreintes des neuf fichiers du paquet vérifiées. Le chargement de la suite de répétition assemble 179 tests (les 150 tests déjà validés et 29 tests PostgreSQL). Les 29 tests PostgreSQL et les mesures à 500/1 000 dossiers **ne sont pas encore exécutés** à ce stade. Le lancement Windows et Docker doit être attesté par son compte rendu.

## Test de personnalité : proposition à décider

Le maintien de cette étape est confirmé par l'équipe. Je recommande une **étape distincte intégrée à EnactSpace, après présélection, avant entretien**, accessible depuis le suivi avec les identifiants de candidature. Elle ne doit pas rallonger le dépôt initial.

| Solution | Atouts | Limites pour cette campagne |
|---|---|---|
| Module dans EnactSpace | Même parcours, lien au dossier, reprise après coupure, suivi terminé/en cours, résultat privé pour le candidat et le jury autorisé | Choisir l'instrument, relire la version française, tester le calcul et l'accès ; ces fonctions ne sont pas déjà implémentées |
| Site externe adapté et autorisé | Mise en place initiale plus courte | Conditions d'usage et confidentialité à vérifier ; retour du résultat souvent manuel sans API ; panne externe et association au bon dossier à prévoir |

La piste proposée est une échelle Big Five issue de l'**International Personality Item Pool (IPIP)**. Les items et échelles IPIP sont dans le domaine public, avec des instructions de calcul publiées. Le droit de les réutiliser ne valide pas automatiquement une traduction ou une interprétation pour des étudiants au Sénégal. L'IPIP précise que son équipe n'a pas vérifié l'exactitude des traductions répertoriées et ne fournit pas de normes universelles prêtes à l'emploi.

Avant réalisation, fixer une version précise plutôt que mélanger des items ou raccourcir une échelle au hasard. Prévoir des réponses graduées, un questionnaire versionné, une sauvegarde de progression, le traitement des questions inversées et un résultat descriptif. Ne pas inventer de percentile, de « personnalité idéale Enactus » ou de seuil éliminatoire.

Le résultat doit servir à préparer un échange sur la manière de travailler et à accompagner l'intégration. Il reste séparé de l'indice de présélection et ne déclenche aucune admission ou exclusion automatique. Les candidats sont informés de son objectif, des personnes qui accèdent aux résultats et de leur conservation.

**16Personalities n'est pas retenu pour imposer ce test dans cette campagne** : ses conditions décrivent un usage personnel et excluent les contextes éducatifs et de recrutement. Le fait de rediriger vers le site n'efface pas cette restriction. Ne pas copier son questionnaire, ses descriptions ou ses illustrations dans l'application.

Sources primaires consultées le 31 octobre 2026 :

- IPIP, présentation et droits de réutilisation : https://ipip.ori.org/
- IPIP, traductions et limites : https://ipip.ori.org/newItemTranslations.htm
- IPIP, calcul : https://ipip.ori.org/newScoringInstructions.htm
- IPIP, normes : https://ipip.ori.org/newNorms.htm
- 16Personalities, conditions d'utilisation : https://www.16personalities.com/terms

## Suite de la préparation

1. Exécuter la répétition isolée et examiner ses résultats, sans assimiler une mesure de volume à une validation du proxy.
2. Publier le candidat backend après résultat satisfaisant et sauvegarde vérifiée ; garder un retour arrière.
3. Créer ou planifier l'unique campagne avec les dates fournies, puis relire les questions et la communication. Actif avec une date de début future signifie planifié avant le 4, pas ouvert immédiatement.
4. Réaliser le dépôt et la réception d'e-mail contrôlés, le parcours du jury et le téléchargement du CV, puis la recette du proxy et du pic HTTP.
5. Choisir et spécifier le test de personnalité avant sa réalisation ; cette décision reste distincte du déploiement des correctifs déjà préparés.
