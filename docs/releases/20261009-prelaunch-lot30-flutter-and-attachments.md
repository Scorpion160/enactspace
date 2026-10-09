# Lot 30 — Flutter et pièces jointes
Date : 9 octobre 2026.

## Dépendances Flutter
Le lock frontend/pubspec.lock a été interrogé directement via https://api.osv.dev/v1/querybatch pour 122 paquets hosted de l’écosystème Pub, à leurs versions exactes. La réponse contient 122 résultats et aucune alerte. Les quatre dépendances SDK (flutter, flutter_test, flutter_web_plugins, sky_engine) sont exclues de cette requête ; ce contrôle ne valide donc pas le SDK Flutter, les bibliothèques natives ou leurs dépendances Gradle. Empreinte du lock : f93f0655be168aaf8a33fb4141038a612531fb7e1d8cfde7ba257ab8ae7c7b90. Une réponse sans alerte ne constitue pas une preuve générale de sécurité.

## Revue ciblée
Lecture des contrôles de gestion, affectation, consultation et validation indépendante dans tasks.py ; lecture des transitions de statut, de la référence de preuve et des routes de dépôt du justificatif, validation et affectation ; lecture du service attachment_service.py et des branches de contrôle des fichiers de tâche dans files.py ainsi que de ses routes de téléchargement et aperçu. Cette lecture ciblée ne vaut pas relecture intégrale de ces modules.

Les routes de tâche exigent un membre actif validé. Le responsable affecté ne peut pas valider son propre livrable ; une preuve requise bloque la remise tant qu’elle manque. Le dépôt d’un fichier est lié à la tâche et produit une référence privée, les modifications du livrable remis sont refusées avant reprise. Le téléchargement vérifie les droits sur le dossier et utilise des en-têtes nosniff et CSP sandbox. La validation du format des pièces jointes vérifie extension, taille et certaines signatures ; elle n’est pas une analyse antivirus des documents.

Aucun correctif applicatif ajouté par ce lot. La revue exhaustive et les autres catégories de fichiers restent ouvertes.

## Tests exécutés
test_attachments_lifecycle : 27 tests réussis en 6,735 secondes, sur SQLite isolé avec e-mails et push désactivés. Le lot 28 a déjà exécuté les tests des limites de tâches ; ils n’ont pas été répétés ici. Avertissement de dépréciation httpx/Starlette présent, sans échec.

## Suite
Recette Android/web, dépendances natives et SDK, autres routes et services à relire, tests de livraison e-mail/push redirigés et paiement en test, nettoyage ciblé et livraison finale restent à terminer. Aucun build, déploiement, message réel ni mutation de production.
