# Copie chiffrée hors du VPS et récupération Windows

## Périmètre vérifié

Les archives chiffrées de PostgreSQL, du schéma de référence, des fichiers persistants et du manifeste du point de récupération sont conservées sous %LOCALAPPDATA%\EnactSpace\PrivateBackups\<identifiant>. Le reçu de capture et les résultats agrégés des essais sont également présents. Aucun contenu de fiche ni fichier métier déchiffré n’est conservé dans ce dossier.

La clé protégée est conservée séparément sous %LOCALAPPDATA%\EnactSpace\RecoveryKeys\<identifiant>.dpapi. Les dossiers et fichiers sont limités au compte Windows courant et à SYSTEM. DPAPI CurrentUser lie la récupération au profil Windows qui a protégé la clé ; copier seulement le fichier .dpapi vers un autre compte ne constitue pas un secours de clé indépendant.

Le point vérifié est 20261008T094513Z_fcf746 : révision de production à la capture 20261006_0025, 111 tables, 721 lignes et 14 fichiers. Conserver la source compatible et le plan de récupération de l’environnement séparément.

## Outil et mode de récupération

tools/prelaunch_offsite_recovery.py s’exécute avec Python 3.12 sur le PC Windows autorisé. L’option --execute-offsite-rehearsal est obligatoire. Fournir --backup-id et --repo avec le dossier du dépôt.

Lors d’une nouvelle copie, l’outil télécharge uniquement les archives chiffrées et le reçu par SSH/SCP, compare les empreintes, transfère la clé par canal SSH sans l’afficher, puis la protège avec DPAPI.

Pour répéter la récupération d’une copie existante, ajouter --restore-existing. Ce mode utilise la clé protégée du PC et les archives conservées ; il ne relit pas la clé d’origine sur le VPS. L’outil crée ensuite un espace privé de retour, transfère les archives du PC et restaure un conteneur PostgreSQL isolé. Aucun backend ni worker n’est démarré, aucune ligne de production n’est consultée et aucun message n’est envoyé.

La base, le schéma, les séquences et les fichiers sont comparés au manifeste chiffré du point de récupération. Les références des fichiers sont contrôlées. Les espaces privés de retour et les ressources Docker attribuées à l’essai sont supprimés, y compris la clé déchiffrée temporaire. Les archives chiffrées du PC et la clé DPAPI restent conservées.

Les résultats agrégés sont enregistrés dans offsite-rehearsal.json. Ne pas ouvrir ou afficher une clé déchiffrée dans un terminal, un rapport ou une conversation. En cas d’échec, conserver les preuves chiffrées et diagnostiquer les contrôles avant toute nouvelle tentative.

## Limites et décisions restantes

La restauration a été exécutée dans l’environnement Docker actuel du VPS, avec son image PostgreSQL déjà disponible. La reprise sur un serveur entièrement neuf, la disponibilité externe de cette image, les configurations, les secrets et les artefacts de livraison n’ont pas encore été vérifiés.

Prévoir un secours de clé réellement indépendant du profil Windows et désigner les personnes habilitées. Définir la conservation, les objectifs RPO/RTO et le calendrier de capture. Aucune purge automatique ni tâche planifiée n’est activée par cet outil. Le PC est un premier emplacement hors du VPS ; il ne suffit pas à lui seul à clôturer le plan de reprise.

Preuves : [lot 26](releases/20261008-prelaunch-lot26-backup-restore.md).

## État du secours portable

Outil préparé : tools/prelaunch_key_escrow.py, option --execute-key-escrow et --backup-id. La phrase est saisie de façon masquée et confirmée pour l’export. Un import avec --import-file doit créer une nouvelle clé DPAPI sans écraser celle d’un profil existant. Ne jamais partager la phrase dans la conversation. Aucun export de clé réelle ni remise à un second détenteur n’a été effectué. Le premier prototype avait échoué au test synthétique. Le diagnostic Windows et le correctif ci-dessous précisent la suite de cette vérification.

## Diagnostic Windows du 8 octobre 2026 et correctif des chemins

Le diagnostic synthétique a réussi avec les chemins MSYS absolus et avec les chemins relatifs au dossier privé de travail. Le mode utilisant les chemins Windows absolus a échoué au démarrage ou à la connexion de l'agent GnuPG. Les trois dossiers temporaires ont été supprimés ; aucune clé réelle n'a été lue et aucun export n'a été produit.

Le correctif de `tools/prelaunch_key_escrow.py` utilise désormais les chemins relatifs `gpg` et `passphrase`, avec le dossier privé comme répertoire du processus. Il masque les erreurs GnuPG, borne la durée du processus et nettoie le dossier même si l'arrêt de l'agent échoue. Les phrases contenant un saut de ligne ou un caractère nul sont refusées avant toute création de fichier.

Cinq tests de protection du correctif ont réussi dans l'environnement isolé. Le sixième teste GnuPG et les permissions Windows avec des données fictives ; il doit être exécuté sur le PC avant l'export réel. La remise sur un support indépendant et à un second détenteur reste à faire. Aucun export réel n'est autorisé automatiquement par les tests.

Le test Windows du correctif a ensuite réussi les cinq tests unitaires, mais échoué avant GnuPG au contrôle ACL du sous-dossier. La création du sous-dossier sous Windows utilise désormais les permissions héritées du parent privé, suivies du contrôle strict utilisateur/SYSTEM. Cette correction reste à vérifier sur Windows ; aucun export réel ne découle de ces tests.

Au second essai Windows, le contrôle ACL passe, mais GnuPG échoue au chiffrement. Le correctif rapproche les chemins temporaires et la locale du diagnostic réussi, et ne rapporte que des catégories d’erreur fixes. Le nouveau test Windows reste à exécuter.

## Validation Windows du correctif — 8 octobre 2026, 22:04 UTC

Le résultat PowerShell transmis par l’utilisateur confirme six tests réussis, sans test ignoré, en 9,964 secondes, pour le code du commit `39142a6a4f1b87757a8a0b57cbc4c939886e360d`. Les empreintes SHA-256 des trois fichiers téléchargés ont été contrôlées avant exécution.

Le test Windows exerce réellement GnuPG avec des données fictives : chiffrement AES256, déchiffrement fidèle, refus d’une autre phrase et refus d’un fichier chiffré altéré. Il contrôle aussi les permissions privées utilisateur/SYSTEM et le nettoyage des espaces temporaires. Les autres tests couvrent les arguments relatifs, les erreurs masquées, les délais dépassés, la validation de la phrase et l’identification de la sauvegarde.

Cette validation remplace le statut d’attente du test synthétique des paragraphes précédents, qui relatent les essais successifs. Aucune clé de sauvegarde réelle n’a été lue ou exportée, aucune opération DPAPI réelle n’a été exécutée et aucun build ni déploiement n’a eu lieu. Le bloc téléchargé travaille hors du dépôt Windows et ne met donc pas à jour ses fichiers source.

Restent à réaliser : intégrer la version vérifiée au dépôt Windows sans écraser les modifications locales ; créer le secours chiffré de la clé réelle avec une phrase saisie localement ; vérifier sa récupération sur un autre profil ou poste ; organiser sa conservation et celle de la phrase par des canaux séparés ; terminer la restauration sur hôte vierge. Le succès du test synthétique ne vaut pas validation de ces étapes ni recette générale de l’application.
