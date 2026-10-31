# Correction de la répétition isolée — 31 octobre 2026

Le premier lancement a construit l'image candidate `enactspace-backend:recruitment-hardening-e1f54c4f88a5` mais s'est arrêté avant le chargement des tests : le compte non privilégié du conteneur ne pouvait pas lire `/app/tools/audit_recruitment_campaign.py`. Le droit de lecture du fichier ne suffisait pas sans un droit de parcours sur son répertoire parent. Les 179 tests et les mesures 500/1 000 n'ont donc pas été exécutés.

Le compte rendu indique aussi `owned_runtime_resources_removed=false`. L'état des ressources doit être vérifié ; il ne faut ni ignorer ce signal ni utiliser un nettoyage Docker global.

Le correctif :

- fixe explicitement le droit de parcours du dossier `/app/tools` après les copies ;
- rétablit l'utilisateur non privilégié de l'image de base ;
- vérifie, sous cet utilisateur, la lecture des neuf fichiers avant de créer PostgreSQL ;
- produit un compte rendu structuré même si le chargement des tests échoue ;
- inscrit l'identifiant d'opération et les erreurs de nettoyage par ressource ;
- permet le nettoyage des anciens conteneurs temporaires uniquement après vérification du nom de l'image candidate, de son empreinte exacte et de son étiquette de propriété ;
- conserve les images de diagnostic et ne force jamais la suppression de l'image de base utilisée en production. Une éventuelle étiquette temporaire conservée est signalée séparément de l'état des conteneurs.

Empreinte attendue de l'ancienne image candidate : `sha256:095feb02436af1f3c661d8b57e802162c6081738e3c1bd0615f68f128aa100cc`.

Six tests locaux des gardes du lanceur réussissent, dont la restauration de l'utilisateur, les droits du répertoire et le refus de nettoyer une image ou un conteneur dont l'identité ne correspond pas. La syntaxe du programme de test est contrôlée. Le correctif n'atteste pas encore son exécution Docker sur le VPS.
