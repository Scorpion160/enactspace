# Politique de sécurité

## Signalement

Transmettre un signalement en privé au référent sécurité du pôle IT. Tant que le contact institutionnel GitHub n’est pas formalisé, utiliser le contact de repli `@Scorpion160` via un canal privé. Préciser la version, l’impact, l’environnement et les étapes reproductibles expurgées. Les détails d’exploitation, preuves privées, jetons et dossiers ne doivent pas apparaître dans une issue publique.

## Versions et contrôles

La [fiche de publication](docs/releases/20261103-web-1.0.25-backend-1.0.23.md) établit les versions à considérer pour le lot en service. Enactus ESP définit la politique de support et les délais de réponse. Les workflows contrôlent les dépendances et des catégories de fichiers sensibles. La protection de branche, le contrôle d’accès et les dispositifs GitHub administratifs doivent être vérifiés séparément.

La branche de reprise utilise PyJWT pour les jetons et limite l’algorithme applicatif à HS256. Examiner tout changement d’algorithme ou de rotation avec le référent sécurité. Séparer développement, recette et production. En cas de fuite, contenir, révoquer ou faire tourner à la source, évaluer les sessions et données affectées, puis documenter la reprise. Voir [les règles de configuration](docs/SECRETS_AND_ENVIRONMENTS.md).
