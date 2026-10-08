# Lot 27 — continuité GitHub et vérifications après sauvegarde

## Version de référence

Le checkpoint `ee5af1019a39194dacd399b920316b916201b44e`, branche `checkpoint/prelaunch-20261008-204719`, a été confirmé sur GitHub puis cloné dans une copie de travail distincte. La publication effectuée depuis Windows comprend 1 427 fichiers sélectionnés et 24 exclusions. Le contrôle Gitleaks 8.30.1 a réussi. La branche et l'index de travail Windows sont restés inchangés ; aucun build ni déploiement n'a été effectué.

La configuration générée du worker Firebase reste conservée sur le PC. Le dépôt contient le modèle, le générateur, ses tests et la procédure de build web. Les restrictions de la clé Firebase restent à vérifier avant la mise en service ; séparer la configuration du code ne remplace pas ces protections.

## Vérifications indépendantes du checkpoint

Une installation Python 3.12 isolée a été préparée avec les dépendances du backend et le client de test. Les tests d'application ont été lancés avec SQLite, un secret éphémère et les envois e-mail/push désactivés. Aucun service de production n'a été appelé.

- **75 tests backend réussis** : réunions, identité des comptes, cycle de vie des comptes et répétition des migrations. Cela vérifie notamment que les mots de passe de test générés restent compatibles avec les scénarios existants.
- **26 tests réussis** : sécurité de l'extraction/restauration, copies chiffrées hors site et garde de concurrence de la capture planifiée. Ces tests synthétiques ne sont pas une nouvelle restauration de la base réelle.
- **11 tests Firebase réussis** : validation, génération atomique, cohérence des paramètres et refus des configurations inattendues.
- **6 tests du diagnostic Windows réussis** : modes de chemins, masquage des erreurs, comparaison des données et suppression des fichiers temporaires. Ces tests utilisent un processus GnuPG simulé ; ils ne valident pas encore le runtime Windows.

Total : **118 exécutions de tests réussies**. Le contrôle complet du repository, la recette Flutter et les parcours sur appareils ne sont pas achevés.

La version installée de FastAPI émet un avertissement de dépréciation du client `httpx` via Starlette, et SQLite signale le cycle de suppression entre les tables de présences et de frais. Les tests réussissent ; ces messages doivent être examinés dans la revue de compatibilité et ne constituent pas une preuve de recette PostgreSQL.

## Secours de clé : diagnostic restant

Le prototype de secours de clé n'a produit aucun export réel. L'essai GnuPG dans cet environnement de travail ne peut pas démarrer son agent, car la création de sockets y est interdite. Il ne permet donc pas de conclure sur le comportement du GnuPG installé avec Git sur Windows.

`tools/diagnose_key_escrow_gpg.py` teste trois représentations de chemins avec un contenu et une phrase de test synthétiques. Il ne lit aucune clé réelle, n'appelle pas DPAPI et ne contacte pas le VPS. Les erreurs sont réduites à des catégories fixes, sans afficher le diagnostic brut. Le dossier de chaque tentative est nettoyé après arrêt de ses propres agents. Le compte rendu masqué reste dans `%LOCALAPPDATA%\EnactSpace\EscrowDiagnostics\masked-diagnostic-<identifiant>.json`.

L'exécution Windows doit établir quels modes fonctionnent avant de corriger et d'activer l'export réel. Aucun nouveau format cryptographique n'a été introduit dans ce lot.

## Suite du travail

1. Obtenir le diagnostic synthétique Windows et terminer le secours de clé indépendant.
2. Valider la reprise sur un hôte neuf, puis automatiser la copie hors site et fixer conservation, RPO et RTO.
3. Poursuivre la revue de toutes les sources, les audits de dépendances et les tests de permissions.
4. Terminer la recette Android/web, les notifications de test, le paiement en sandbox et le nettoyage ciblé des données de test.
5. Vérifier les contacts et valider séparément le rétablissement de l'envoi normal des e-mails avant mise en service.

Aucun e-mail réel, push réel, paiement, build, déploiement ou nettoyage de données de production n'a été exécuté dans ce lot.

Un second contrôle strict Gitleaks 8.30.1 a été exécuté sur cette copie de travail, diagnostic et documentation inclus : aucune alerte. Ce résultat ne remplace pas la revue manuelle complète.
