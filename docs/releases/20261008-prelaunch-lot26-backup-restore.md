# Préproduction — lot 26 : restauration locale vérifiée

Date : 8 octobre 2026. **Restauration isolée et restauration depuis la copie Windows réussies ; plan de reprise complet encore à finaliser.**

## Résultat

La sauvegarde chiffrée de PostgreSQL et des fichiers persistants a été restaurée dans un conteneur PostgreSQL isolé, sur réseau interne et sans port publié. Aucun serveur applicatif ni worker n’a été démarré sur cette copie.

| Contrôle | Résultat |
|---|---|
| Tests de protection et chiffrement | **19 tests réussis** |
| Tables et lignes restaurées | **111 tables, 721 lignes**, contenu identique |
| Séquences et révision | Identiques à la capture |
| Schéma | Contraintes, index, colonnes, énumérations, vues, fonctions et déclencheurs comparés |
| Fichiers | **14 fichiers, 6 435 699 octets**, contenus identiques |
| Références en base | 14 références ; aucun fichier absent, taille incorrecte, empreinte incorrecte ou chemin dangereux |
| Essais négatifs PostgreSQL | Modification de contrainte, prédicat d’index et caractère obligatoire d’une colonne détectée |
| Nettoyage | Conteneur, réseau, volume et stockage déchiffré temporaires supprimés |
| Durée de l’essai final | 94.723 secondes, sans valeur d’engagement RTO |

## Traitement de l’écart initial

Le premier contrôle strict échouait sur la représentation de 54 déclarations de contraintes et 3 définitions d’index. Les exemples diagnostiqués correspondaient à une conversion de tableau varchar vers text reformulée en conversions de chaque élément après restauration.

La solution conserve les comparaisons complètes. Une capture indépendante du schéma seul, effectuée pendant la capture stable, est restaurée dans une seconde base du même conteneur isolé. Les catalogues de cette référence sont comparés à ceux de la restauration complète. Aucune expression SQL n’est raccourcie ou normalisée par remplacement de texte. Les valeurs littérales, types, opérateurs, validations et prédicats restent dans les empreintes de comparaison.

La référence de schéma ne remplace jamais les empreintes des lignes, les séquences ou la révision capturées sur la source. Des changements volontaires sur une table synthétique dans la base de référence vérifient que des différences réelles sont détectées. Cette table est supprimée avant la comparaison finale.

## Protection et reproductibilité

Les captures sont chiffrées avec GPG/AES-256. Les chemins et contenus personnels ne sont pas publiés dans les preuves. Le manifeste de vérification du point de récupération, avec empreintes de la base et inventaire des fichiers, est lui-même chiffré et son déchiffrement a été vérifié. L’identité de l’image de restauration est conservée dans les preuves.

Le nettoyage est limité aux ressources attribuées à l’essai, y compris après un démarrage partiellement réussi. Une ressource préexistante n’est jamais réutilisée ni supprimée par ce mécanisme. Les tests vérifient aussi les chemins d’archive, les liens, les fichiers spéciaux, les permissions, les clés incorrectes et les archives altérées.

Le test d’intégrité GPG est séparé des tests découverts dans l’image applicative. La CI l’exécute explicitement sur son hôte Linux avec GPG installé ; son head Alembic attendu est corrigé vers 0031. **La CI GitHub n’a pas été exécutée dans ce lot.**

## Production et limites

Aucun build, push, déploiement, migration de production, paiement ou envoi réel. La production reste sur la révision 0025 et la source sur le head attendu 0031. La redirection des courriels de test reste conservée. Le fichier de secours local du worker email est préservé.

Les archives et la clé de récupération restent dans des emplacements privés distincts du même VPS. La copie Windows et la répétition depuis cette copie sont désormais vérifiées, avec une clé récupérée depuis DPAPI Windows. Définir aussi les personnes habilitées, la conservation et les objectifs RPO/RTO.

Ce périmètre vérifie PostgreSQL et les fichiers persistants, pas toute l’infrastructure VPS, Jitsi, les secrets, les rôles système ou les artefacts de livraison. La relecture manuelle intégrale du dépôt et la recette finale des appareils restent inachevées ; ce résultat ne déclare pas toute l’application prête à ouvrir.

Procédure : [sauvegarde et restauration](../V1_1_BACKUP_RESTORE.md).

## Complément : copie hors du VPS et récupération depuis Windows

Une copie des quatre archives chiffrées et de leur reçu a été conservée sur le PC Windows autorisé. Les tailles et empreintes ont été vérifiées. Les dossiers et fichiers ont des ACL limitées au compte Windows courant et à SYSTEM. La clé est protégée par DPAPI CurrentUser dans un dossier distinct ; aucun fichier de clé en clair n’est conservé sur le PC.

La récupération a été répétée depuis la copie existante, sans téléchargement de la clé d’origine ni consultation des lignes de production. Les archives du PC ont été transférées dans un espace privé de retour pour restaurer un conteneur PostgreSQL isolé utilisant l’image exacte de l’essai initial. Le manifeste chiffré du point de récupération a permis de comparer **111 tables, 721 lignes et 14 fichiers**, leur schéma, leurs séquences et leurs références. Aucun écart. Durée de la dernière restauration : 37.973 secondes, sans valeur d’engagement RTO.

Les **23 tests Linux** passent, ainsi que les contrôles Windows de protection et récupération DPAPI, de rejet d’une clé protégée altérée et d’identifiants dangereux. Les espaces de retour, clés déchiffrées, conteneurs, réseaux et volumes de l’essai ont été supprimés.

Cette preuve valide la copie conservée sur le PC et la récupération indépendante de la clé du VPS. Elle repose encore sur le profil Windows existant et sur l’environnement Docker du VPS actuel. **Le secours de clé par une seconde personne ou un second support, la disponibilité de l’image sur un hôte neuf, l’automatisation des captures, la conservation et les objectifs RPO/RTO restent ouverts.** Aucune purge ni planification automatique n’est activée.

Guide : [récupération Windows](../BACKUP_RECOVERY_WINDOWS.md).

## Sauvegardes planifiées — 8 octobre, point suivant

Le service d’exploitation enactspace-verified-backup.service et son timer sont installés. Capture quotidienne à **03 h 00 UTC**, première échéance le **9 octobre 2026 à 03 h 00 UTC**. Un lancement réel par systemd a réussi : 111 tables, 721 lignes et 14 fichiers comparés, références intactes et ressources de l’essai supprimées. Les quatre tests de révision et de verrouillage passent. Le calendrier et les unités sont vérifiés, leurs permissions corrigées et le timer actif.

Le service dispose d’un verrou contre deux captures simultanées, refuse les révisions de production non approuvées et utilise un répertoire GPG privé. Les versions autorisées sont 0025 et 0031 ; mettre à jour ce garde lors d’une livraison future. Les journaux ne contiennent que les résultats agrégés. L’application de production n’a pas été livrée ni migrée ; seule la configuration d’exploitation des sauvegardes a été installée. Aucun envoi réel.

**La capture planifiée reste locale au VPS. La copie automatique hors du VPS, la conservation et les objectifs RPO/RTO restent ouverts.** Aucune purge automatique n’est activée.

Le contrôle sur un environnement neuf est bloqué par l’indisponibilité du moteur Docker Windows et le disque Ubuntu WSL introuvable. La référence immuable de l’image PostgreSQL a été identifiée pour la reprise ; aucune distribution n’a été supprimée ou réinstallée.

Un outil de secours de clé portable est préparé dans tools/prelaunch_key_escrow.py. Il prévoit une phrase secrète saisie de façon masquée par son détenteur, export chiffré et import dans un autre profil Windows. Test synthétique validé : **False**. Aucune clé réelle n’a été exportée et aucune remise à une seconde personne ou à un autre support n’est validée. Ne pas considérer ce secours comme opérationnel avant cet essai et cette remise.
