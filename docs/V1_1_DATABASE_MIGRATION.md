# EnactSpace V1.1 - Migrations base de donnees

## Objectif

La production ne doit pas dependre uniquement de `Base.metadata.create_all()` au demarrage de l'application. En V1.1, Alembic est prepare pour rendre les migrations reproductibles sur le VPS.

## Configuration

Fichiers ajoutes:

- `backend/alembic.ini`
- `backend/alembic/env.py`
- `backend/alembic/script.py.mako`
- `backend/alembic/versions/20260713_0001_v1_1_baseline.py`

Variable production:

```env
AUTO_CREATE_TABLES=false
```

En developpement, l'auto-creation reste active par defaut pour garder un lancement rapide. En production, appliquer les migrations avant de demarrer le service.

## Commandes

Depuis le dossier backend:

```bash
cd /opt/enactspace/app/backend
python -m alembic current
python -m alembic heads
python -m alembic upgrade head
```

Sur Windows local:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m alembic heads
.\.venv\Scripts\python.exe -m alembic upgrade head
```

## Baseline V1.1

La revision `20260713_0001` cree le schema V1.1 sur une base vide a partir des modeles SQLAlchemy actuels. Elle sert de baseline RC1.

Important:

- ne pas l'executer aveuglement sur une base contenant deja des tables sans backup;
- pour une base V1 existante, faire un dump, tester sur copie, puis stamp/upgrade selon l'etat reel;
- les prochaines modifications de schema doivent etre des revisions Alembic explicites.

## Procedure base vide

1. Creer la base PostgreSQL et l'utilisateur dedie.
2. Configurer `DATABASE_URL` dans `/etc/enactspace/enactspace.env`.
3. Valider l'environnement:

```bash
python -m app.scripts.validate_environment
```

4. Lancer:

```bash
python -m alembic upgrade head
```

5. Lancer le backend avec `AUTO_CREATE_TABLES=false`.

## Procedure base existante

1. Stopper le backend.
2. Sauvegarder la base:

```bash
pg_dump -Fc -f /var/backups/enactspace/enactspace-before-v1-1.dump enactspace
```

3. Restaurer la sauvegarde sur une base de test.
4. Comparer le schema avec les modeles V1.1.
5. Si la base correspond deja au baseline, utiliser `alembic stamp 20260713_0001`.
6. Sinon, creer une migration de transition testee sur la copie.
7. Executer `alembic upgrade head`.
8. Redemarrer le backend.

## Tests requis

- base vide -> `upgrade head` reussit;
- base V1 existante restauree en test -> migration ou stamp controle;
- `upgrade head` execute deux fois -> aucune erreur;
- backend demarre avec `AUTO_CREATE_TABLES=false`;
- creation utilisateur, recrutement, presence, finance et Mobile Money fonctionnent.

## Interdictions

- pas de suppression de tables en production sans sauvegarde et validation;
- pas de migration destructive sans plan de rollback;
- pas de `create_all` comme strategie unique de production;
- pas de base SQLite pour donnees reelles.
