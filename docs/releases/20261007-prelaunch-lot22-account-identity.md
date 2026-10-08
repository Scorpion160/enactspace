# Préproduction — lot 22 : identifiants et année d'entrée

Date : 7 octobre 2026. Correctifs dans le dépôt Windows, sans build ni déploiement.

## Ce qui change

La base réelle exige un nom d'utilisateur non nul et limité à 50 caractères. La création administrative et la conversion des candidatures pouvaient construire un utilisateur sans identifiant. Le modèle attribue désormais un identifiant lisible fondé sur le prénom et le nom, avec un suffixe aléatoire, quand aucun identifiant n'est fourni. La contrainte d'unicité en base reste la protection finale. Un identifiant saisi est conservé après suppression des espaces de bord et passage en minuscules. Les valeurs vides, trop longues ou comportant des caractères de contrôle sont rejetées avant écriture. Un conflit de création administrative nomme désormais l'email ou le nom d'utilisateur.

L'année d'entrée déjà présente dans users est maintenant reliée au modèle et renvoyée dans le compte ainsi que dans l'annuaire des membres. La création administrative conserve également cursus et spécialité. La création d'un profil Enactrice est acceptée.

La création d'une demande d'adhésion conserve aussi son année d'entrée dans users. Le passage en Alumni copie cette année dans le profil créé et conserve les informations déjà renseignées. La modification de l'année depuis le compte ou par un responsable autorisé synchronise le profil Alumni existant dans la même transaction. L'édition du compte verrouille sa ligne afin de partager le verrou utilisé par sa conversion.

La migration 0029 ajoute la colonne user manquante sur les installations concernées et récupère une année connue dans le profil Alumni lorsque le compte n'en a pas. Elle préserve les années utilisateur déjà renseignées. Son retour arrière conserve cette colonne historique et ses données ; elle peut déjà exister avant cette réparation. Les années saisies sont bornées de 1900 à l'année courante.

## Vérifications

- SQLite : **74 tests réussis en 31.24 secondes**, aucun ignoré. Cette suite reprend les contrôles des comptes, responsabilités, années et règles opérationnelles, avec six cas supplémentaires sur les identifiants, les champs académiques et l'année d'entrée.
- PostgreSQL : structure réelle exportée sans lignes de production puis restaurée avec uniquement des données synthétiques. Création administrative réussie avec identifiant automatique, collision avec variante majuscule refusée, cursus et spécialité conservés, année accessible par le modèle de réponse et conservée en Alumni.
- Les migrations 0025 vers 0029, retour à 0025 et répétition vers 0029 réussissent. Les empreintes des 110 tables historiques restent conservées pour les scénarios du banc de migration, les trois écritures invalides de sécurité restent refusées et l'erreur injectée reste annulée transactionnellement.
- Une installation vide atteint également le head 0029 par Alembic.
- Syntaxe et git diff --check réussis. Conteneurs et réseau nommés PostgreSQL du lot absents après les tests.
- Un premier lancement SQLite n'a pas démarré : les deux préparations utilisaient le même nom de paquet temporaire. Les paquets et répertoires ont été séparés, puis la suite a été réexécutée.
- Aucun courriel, push ou paiement réel. Aucune donnée de production copiée, aucun build, déploiement ou push Git.

## Limites et suite

La conversion complète d'une candidature depuis l'interface et les parcours mobiles restent à recetter. Le banc PostgreSQL contrôle ici la création administrative et les règles de modèle partagées ; il ne prouve pas le parcours recrutement intégral.

Les anciennes années utilisateur et Alumni déjà renseignées mais contradictoires ne sont pas écrasées automatiquement. Une correction explicite du compte synchronise ensuite son profil Alumni. Le retour arrière de 0029 ne supprime pas les années historiques.

La revue manuelle intégrale du code, la restauration complète d'une sauvegarde réelle, la recette Android/web, le nettoyage ciblé des tests et la bascule finale des destinataires de courriels restent ouverts. La production demeure en révision 20261006_0025.
