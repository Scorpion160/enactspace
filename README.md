# EnactSpace

EnactSpace est l’espace numérique d’Enactus ESP. L’application réunit les membres, les projets, les pôles, les tâches, la présence, les finances, la communication, le recrutement, l’Academy et la mémoire du club.

## Reprendre le projet

La branche de travail documentée est `feature/recruitment-ui-20261101`. Le point de reprise vérifié pour le lot web et API est le commit `d65d22402af4debb620260346a6174f717ab47bb`. Ouvrir un clone de cette branche, puis suivre le [dossier de passation du pôle IT](docs/POLE_IT_HANDOFF.md).

| Composant | État attesté le 3 novembre 2026 |
| --- | --- |
| Web | 1.0.25, build 28, servi en HTTPS avec empreinte contrôlée |
| API et workers | Image 1.0.23 vérifiée pour l’API et les workers e-mail, push et Veille |
| Données | PostgreSQL 16, révision Alembic `20261031_0033` |
| Mobile | La publication du 3 novembre couvre le web et le backend. Voir les [preuves et contrôles mobiles](docs/MOBILE_RELEASE_AND_PUSH.md). |

La [fiche de publication](docs/releases/20261103-web-1.0.25-backend-1.0.23.md) distingue les artefacts déployés, les versions par défaut du dépôt et les validations qui exigent encore une recette externe.

## Carte du dépôt

| Répertoire | Rôle |
| --- | --- |
| `frontend/` | Client Flutter, ressources, tests, intégrations Android, iOS et web |
| `backend/` | API FastAPI, modèles SQLAlchemy, workers, migrations Alembic et tests |
| `deploy/` et `tools/` | Modèles d’infrastructure, contrôles et outils de publication |
| `.github/` | Contrôles GitHub Actions et règles de contribution |
| `docs/` | Références techniques, exploitation et comptes rendus datés |

## Documentation

- [Index des procédures](docs/README.md)
- [Architecture et carte des domaines](docs/ARCHITECTURE.md)
- [Installation et développement local](docs/DEVELOPMENT.md)
- [Matrice de tests](docs/TEST_MATRIX.md) et [checklist de publication](docs/RELEASE_CHECKLIST.md)
- [Exploitation et reprise sur incident](docs/OPERATIONS_RUNBOOK.md)
- [Environnements et secrets](docs/SECRETS_AND_ENVIRONMENTS.md)
- [Contribution](CONTRIBUTING.md), [maintenance](MAINTAINERS.md) et [signalement privé](SECURITY.md)

V1 conçue et développée par Chicodev en 2026. La maintenance relève du pôle IT d’Enactus ESP. Le dépôt est publiquement consultable, sans licence open source déclarée. Voir [NOTICE](NOTICE.md).
