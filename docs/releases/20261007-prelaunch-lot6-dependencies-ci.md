# Préparation à la mise en service — lot 6
Date : 2026-10-07T11:48:25.041715+00:00

## Résultats vérifiés
- 115 tests backend PASS dans un conteneur isolé, réseau désactivé : authentification, sessions, permissions, fichiers, protection des requêtes, e-mails simulés et EnactMeet.
- Compatibilité des jetons HS256 entre python-jose et PyJWT dans les deux sens ; mêmes signatures pour les mêmes paramètres. exp/sub obligatoires, algorithme inattendu rejeté.
- Migration unique : 20261007_0027. Génération OpenAPI réussie.
- Deux contrôles CI exécutés localement : secrets suivis par git et références immuables des actions, PASS.
- 67 dépendances Python réellement installées et 122 dépendances Pub du lock examinées via OSV. Alertes sur python-jose, ecdsa et pip ; aucune alerte retournée pour Pub. Absence d'alerte ne constitue pas une preuve de sécurité.

## Corrections dans les sources
- python-jose remplacé par PyJWT[crypto]==2.15.1 : imports API, EnactMeet et tests adaptés. Cela supprime aussi la dépendance transitive ecdsa de cette chaîne.
- Installation de pip==26.2.1 prévue dans l'image backend et dans l'audit CI ; aucune installation en production.
- PyJWT téléchargé depuis PyPI et SHA256 vérifié ; deux nouvelles versions interrogées dans OSV, aucune alerte retournée.
- Exception PYSEC-2026-1325 retirée du workflow sécurité.
- CI : branche recovery/final-20260927 ajoutée, Flutter 3.47.5, dernière migration corrigée ; e-mails et push désactivés pendant les tests CI.
- Lecture intégrale de audit.py, account.py et payments.py. Le registre AST des autres routes n'est pas une relecture manuelle.

## Limites et travail restant
- Serveur public inchangé : les anciennes dépendances y restent présentes jusqu'au déploiement final des corrections.
- Résolution complète des nouvelles dépendances et pip-audit strict à refaire avant l'image finale ; les contrôles OSV ci-dessus portent sur les versions exactes examinées.
- CI GitHub non exécutée, aucun push. La syntaxe des scripts de contrôle a été compilée et ils ont été exécutés localement ; pas de prétention à un passage complet des jobs GitHub.
- Tests PostgreSQL du lot 5 déjà réussis ; pas de nouvel essai PostgreSQL dans ce lot (changements JWT/CI).
- Relecture manuelle globale encore en cours ; tests de parcours sur téléphone, nettoyage ciblé de la campagne et documentation finale restent à terminer.
- Aucun build, déploiement, nettoyage de données réelles ni e-mail envoyé.

## Sources techniques
- https://github.com/advisories/GHSA-3qf3-8w2g-rqmx
- https://pyjwt.readthedocs.io/en/stable/api.html
- https://google.github.io/osv.dev/api/
- https://github.com/pypa/pip-audit
