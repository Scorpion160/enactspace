# Contribuer à EnactSpace

Préparer les évolutions sur une branche issue de `feature/recruitment-ui-20261101`, la branche de reprise documentée. Ouvrir une pull request (PR) vers cette branche pour les évolutions du lot en service. La convergence vers `main` fait l’objet d’une revue d’intégration distincte. Le dépôt est consultable publiquement. Les décisions de maintenance et de déploiement relèvent d’Enactus ESP.

1. Décrire le besoin, le périmètre et la manière de reproduire. Garder les changements concentrés sur le sujet.
2. Vérifier les contrats API, les permissions, les migrations éventuelles et la compatibilité client. Pour l’interface, joindre des captures fictives et vérifier clair/sombre si le changement est visuel.
3. Consigner les commandes et résultats des [tests](docs/TEST_MATRIX.md). Si le schéma change, documenter la recette PostgreSQL et le retour arrière.
4. Faire relire par un mainteneur autorisé. Examiner les checks du commit et les écarts. La cible de gouvernance est une revue, des checks obligatoires et l’interdiction des réécritures de branches de référence. Vérifier les réglages effectifs dans GitHub.
5. La publication suit la [checklist](docs/RELEASE_CHECKLIST.md) et produit un reçu propre au lot.

Conserver hors de Git et des PR les secrets, signatures, fichiers de fournisseurs, exports de membres, CV, résultats de jury et journaux non expurgés. Voir [SECURITY](SECURITY.md) pour le signalement privé.
