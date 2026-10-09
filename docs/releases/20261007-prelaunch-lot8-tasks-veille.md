# Préparation à la mise en service — lot 8
Date : 2026-10-07T12:42:32.767082+00:00

## Corrections
- Création d'une tâche : un seul périmètre, pôle ou projet. Le mélange d'un projet dirigé et d'un pôle extérieur ne peut plus contourner l'autorisation.
- Un Alumni portant d'anciens rôles de direction ou Veille ne bénéficie plus d'une vision globale des tâches ni des pouvoirs Veille. Ses tâches historiques assignées ou créées restent consultables, sans droit de modification opérationnelle.
- Un ancien rôle SG/TL/admin ne permet plus à un Alumni de lire tous les fichiers privés génériques ou d'utiliser le nettoyage des fichiers.
- Affectations figées dès la remise : ajout/retrait interdits sur les tâches terminées, validées ou annulées. Cela empêche de retirer sa propre affectation pour contourner l'interdiction de valider son livrable.
- Ajout et suppression des étapes figés après remise. Les modifications d'étapes et d'affectations se verrouillent sur la tâche PostgreSQL, comme la validation.
- Échéance et obligation de preuve ne peuvent plus être modifiées sur un livrable remis/clôturé via PATCH générique. Une reprise explicite rouvre les modifications.
- Identifiants UUID des routes tâches, étapes, membres assignés et filtres pôle/projet validés avant les requêtes SQL (422 standard pour les identifiants mal formés).
- Les rapports et commentaires restent consultables selon le périmètre autorisé ; aucun système de tâches parallèle n'a été introduit.
- Le runner Veille PostgreSQL vérifie désormais explicitement une URL PostgreSQL locale de base de test avant toute création de schéma.

## Vérification
- 201 tests backend regroupés PASS : régressions des lots précédents, Veille, intégrité opérationnelle et 14 nouveaux tests de périmètre/livrable.
- 54 tests ciblés PASS après la dernière correction fichiers : sécurité des fichiers, tâches et preuves de bout en bout.
- Suite PostgreSQL 16 élargie : délai de 180 secondes dépassé, résultat NON VALIDÉ. Le runner n’a pas conservé le journal partiel lors du timeout ; le test en cause reste à identifier. Les 6 tests PostgreSQL du lot 7 ne remplacent pas cette vérification. Environnement isolé contrôlé et nettoyé.
- Les comptes ci-dessus sont ceux de plusieurs suites qui se recoupent ; ne pas les additionner en un nombre de scénarios uniques.
- Vérifications réalisées avec données synthétiques. Tests backend sans réseau ; PostgreSQL dans un conteneur et réseau interne dédiés. E-mails/push désactivés ou simulés selon la suite ; aucun envoi réel.

## Relecture et suite
Lecture intégrale de routes/tasks.py, routes/veille.py, services/veille_service.py, schemas/task.py, models/task.py, routes/files.py et test_veille_postgresql.py. Registre de relecture mis à jour ; la relecture globale du dépôt reste inachevée.

Prochaine étape : isoler le timeout PostgreSQL et fiabiliser la conservation des journaux, puis permissions et cohérence des autres espaces, notamment finances/documents/pôles/projets, politique de suppression et conservation des historiques, puis parcours téléphone/web, nettoyage ciblé de la campagne de test, documentation et vérifications finales. Aucun build, push ou déploiement réalisé dans ce lot. Les sources corrigées n'ont pas encore remplacé le serveur public.
