# Comptes de test V1 — procédure historique sécurisée

> **DÉPRÉCIÉ / NON AUTORITATIF.** Utiliser [Development](DEVELOPMENT.md) et [Secrets and environments](SECRETS_AND_ENVIRONMENTS.md). Les identités ci-dessous sont locales et ne sont jamais des comptes ou credentials de production.

Date historique: 2026-07-03.

Le seed de démonstration est volontairement protégé:

- `ENABLE_SEED` doit être activé uniquement en environnement `development` ou `test`.
- Un Admin ou Team Leader local autorisé appelle `POST /api/seed/v1-demo`.
- Le mot de passe est fourni dans le corps de cette requête; il doit être généré pour l'exécution ou lu depuis une variable d'environnement locale ignorée.
- Aucun mot de passe partagé, réutilisable ou par défaut n'est documenté.
- Les credentials de production ne sont jamais utilisés.
- Après la vérification, désactiver le seed et supprimer l'environnement/base de test conformément au plan local.

Le seed peut créer des identités synthétiques `.local` pour exercer les rôles Admin, Team Leader, SG, finance, chefs de pôle/projet, membre, alumni et candidat. Leur existence, leur adresse et leur état dépendent du code de seed de la révision testée; ne pas copier ces identités dans un autre environnement.

Conserver comme preuve uniquement la date, le commit, les rôles exercés et le résultat attendu/observé. Ne jamais consigner le mot de passe, un token, une base réelle ou des données membres.
