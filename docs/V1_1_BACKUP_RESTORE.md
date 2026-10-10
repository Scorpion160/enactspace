# Sauvegarde et restauration des données EnactSpace

Cette procédure couvre PostgreSQL et les fichiers persistants de l’application. Elle ne constitue pas une sauvegarde de tout le VPS, des configurations Jitsi, des secrets ni des artefacts Android/web. La source et les artefacts compatibles, les configurations et la récupération des secrets restent des éléments distincts du plan de reprise.

## Périmètre constaté

La base de production utilise PostgreSQL 16 dans `enactspace_postgres`. Les fichiers de l’application sont montés depuis `/var/lib/enactspace/uploads` vers `/app/uploads`. Le service de stockage utilise `/app/uploads/files`. La révision de production est 0025 ; le head source attendu pour la prochaine livraison est 0031.

## Répétition isolée

Le script `backend/app/scripts/prelaunch_backup_restore.py` nécessite l’option explicite `--execute-rehearsal` et s’exécute sur l’hôte Linux autorisé. Il ne restaure jamais la base de production : il crée un conteneur PostgreSQL, un réseau interne et un volume nommés pour l’essai, sans port publié. Aucun backend ni worker applicatif n’est démarré avec les données restaurées.

La capture utilise un dump PostgreSQL et une archive des fichiers, chiffrés avec GPG/AES-256. Le script compare les données et les fichiers avant et après la capture ; une modification entraîne le refus de la répétition. Il restaure ensuite les archives dans l’espace privé de l’essai et compare le contenu des tables, les séquences, les contraintes, les index et les fichiers. Les références des fichiers en base sont contrôlées : emplacement, existence, taille et empreinte lorsqu’elle est disponible.

Le schéma complet est comparé à une capture indépendante du schéma seul, restaurée dans une base de référence du même conteneur isolé. Cela traite les reformulations de représentation de PostgreSQL sans supprimer de contraintes ou de prédicats de la comparaison. Les colonnes, énumérations, vues, fonctions et déclencheurs sont également vérifiés. Trois modifications volontaires de structure synthétique doivent être détectées.

Le manifeste du point de récupération contient les empreintes attendues et l’inventaire des fichiers ; il est conservé chiffré dans verification.json.gpg. Conserver l’ensemble des archives, l’identité de l’image utilisée et la clé selon le protocole habilité. Ne jamais publier le manifeste déchiffré. Le paramètre --expected-revision doit correspondre à la révision approuvée pour la capture ; sa valeur par défaut actuelle reste 20261006_0025 et doit être adaptée après livraison.

Les noms et contenus des fiches personnelles ne sont pas publiés dans les preuves. Les empreintes de comparaison de la base utilisent un HMAC et une clé privée. Les fichiers déchiffrés temporaires et les ressources de test sont supprimés après l’essai. Les archives chiffrées et leur clé de récupération sont conservées dans des emplacements privés distincts, avec fichiers en mode 600 et répertoires privés en mode 700.

## Conservation et récupération

Une copie hors du VPS a été vérifiée sur le PC Windows autorisé, avec clé protégée par DPAPI et restauration depuis cette copie. Voir [la procédure Windows](BACKUP_RECOVERY_WINDOWS.md). La reprise sur un hôte entièrement neuf et le second secours de clé restent à vérifier.

Les archives de l’essai sont conservées dans un répertoire privé sous `/var/backups/enactspace/prelaunch-lot26-…`. La clé reste dans un répertoire privé distinct sous `/opt/enactspace/backup-keys`. Ne pas publier la clé, la placer dans Git ou l’inclure dans un rapport. Une sauvegarde et sa clé présentes uniquement sur le même VPS ne protègent pas contre la perte de ce VPS.

Avant ouverture, définir la conservation et les personnes habilitées, pérenniser la copie chiffrée hors du VPS et ajouter un secours de clé indépendant du profil Windows, puis vérifier une reprise sur un hôte neuf. Les objectifs RPO/RTO restent à approuver par Enactus ESP ; la durée mesurée d’un essai n’est pas un engagement de délai de reprise.

Pour une reprise réelle, faire approuver le point de récupération et la fenêtre d’intervention, mettre l’application en maintenance, restaurer dans une cible contrôlée, vérifier les données et fichiers, remettre les versions compatibles et effectuer la recette d’authentification, des droits, des documents et des tâches avant réouverture. Aucun exemple de cette procédure ne donne l’instruction de restaurer directement sur la base active.

## Limites

La répétition décrite vérifie les données et les fichiers persistants dans leur périmètre actuel. Elle ne prouve pas la reprise complète de l’infrastructure ni le fonctionnement des écrans, des paiements ou de la réception des notifications. Ces contrôles restent dans la recette de mise en service.

Preuves : [lot 26](releases/20261008-prelaunch-lot26-backup-restore.md).

## Sauvegardes planifiées — 8 octobre, point suivant

Le service d’exploitation enactspace-verified-backup.service et son timer sont installés. Capture quotidienne à **03 h 00 UTC**, première échéance le **9 octobre 2026 à 03 h 00 UTC**. Un lancement réel par systemd a réussi : 111 tables, 721 lignes et 14 fichiers comparés, références intactes et ressources de l’essai supprimées. Les quatre tests de révision et de verrouillage passent. Le calendrier et les unités sont vérifiés, leurs permissions corrigées et le timer actif.

Le service dispose d’un verrou contre deux captures simultanées, refuse les révisions de production non approuvées et utilise un répertoire GPG privé. Les versions autorisées sont 0025 et 0031 ; mettre à jour ce garde lors d’une livraison future. Les journaux ne contiennent que les résultats agrégés. L’application de production n’a pas été livrée ni migrée ; seule la configuration d’exploitation des sauvegardes a été installée. Aucun envoi réel.

**La capture planifiée reste locale au VPS. La copie automatique hors du VPS, la conservation et les objectifs RPO/RTO restent ouverts.** Aucune purge automatique n’est activée.

Le contrôle sur un environnement neuf est bloqué par l’indisponibilité du moteur Docker Windows et le disque Ubuntu WSL introuvable. La référence immuable de l’image PostgreSQL a été identifiée pour la reprise ; aucune distribution n’a été supprimée ou réinstallée.

Un outil de secours de clé portable est préparé dans tools/prelaunch_key_escrow.py. Il prévoit une phrase secrète saisie de façon masquée par son détenteur, export chiffré et import dans un autre profil Windows. Test synthétique validé : **False**. Aucune clé réelle n’a été exportée et aucune remise à une seconde personne ou à un autre support n’est validée. Ne pas considérer ce secours comme opérationnel avant cet essai et cette remise.
