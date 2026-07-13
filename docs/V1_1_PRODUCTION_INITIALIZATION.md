# EnactSpace V1.1 - Initialisation production

## Commande

```bash
cd /opt/enactspace/app/backend
/opt/enactspace/venv/bin/python -m app.scripts.initialize_production
```

Dry-run:

```bash
/opt/enactspace/venv/bin/python -m app.scripts.initialize_production --dry-run
```

## Donnees creees

La commande est idempotente et cree uniquement les donnees absentes:

- roles de reference;
- saison courante;
- poles de reference;
- projets de reference;
- badges de gamification.

Elle ne supprime rien, ne reinitialise pas la base et n'ecrase pas les utilisateurs existants.

## Admin initial optionnel

Configurer temporairement ces variables dans l'environnement du shell d'administration, pas dans Git:

```bash
export ENACTSPACE_INITIAL_ADMIN_EMAIL="admin@example.com"
export ENACTSPACE_INITIAL_ADMIN_PASSWORD="CHANGE_ME_LONG_RANDOM_PASSWORD"
export ENACTSPACE_INITIAL_ADMIN_FIRST_NAME="Admin"
export ENACTSPACE_INITIAL_ADMIN_LAST_NAME="EnactSpace"
```

Puis lancer la commande. Le mot de passe n'est jamais affiche. Apres execution, nettoyer l'historique/shell selon la politique VPS.

## Ordre recommande

1. Restaurer/creer PostgreSQL.
2. Configurer `/etc/enactspace/enactspace.env`.
3. Valider l'environnement.
4. Executer `alembic upgrade head`.
5. Executer `initialize_production --dry-run`.
6. Executer `initialize_production`.
7. Demarrer `enactspace-api`.
