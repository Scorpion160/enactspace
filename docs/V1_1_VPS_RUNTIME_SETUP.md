# EnactSpace V1.1 - Configuration runtime VPS

## Structure recommandee

```text
/opt/enactspace/app
/opt/enactspace/venv
/var/lib/enactspace/uploads
/var/log/enactspace
/etc/enactspace/enactspace.env
```

## Utilisateur systeme

```bash
sudo adduser --system --group --home /opt/enactspace enactspace
sudo mkdir -p /opt/enactspace/app /var/lib/enactspace/uploads /var/log/enactspace /etc/enactspace
sudo chown -R enactspace:enactspace /opt/enactspace /var/lib/enactspace /var/log/enactspace
sudo chmod 750 /etc/enactspace
```

Le service ne doit pas tourner en root.

## Backend

```bash
cd /opt/enactspace/app
git clone https://github.com/Scorpion160/enactspace.git .
python3 -m venv /opt/enactspace/venv
/opt/enactspace/venv/bin/pip install -r backend/requirements.txt
```

Copier et editer le fichier d'environnement reel:

```bash
sudo cp backend/.env.production.example /etc/enactspace/enactspace.env
sudo chmod 600 /etc/enactspace/enactspace.env
sudo chown root:enactspace /etc/enactspace/enactspace.env
```

Valider:

```bash
cd /opt/enactspace/app/backend
/opt/enactspace/venv/bin/python -m app.scripts.validate_environment /etc/enactspace/enactspace.env
```

## Service systemd

```bash
sudo cp deploy/enactspace-api.service /etc/systemd/system/enactspace-api.service
sudo systemctl daemon-reload
sudo systemctl enable enactspace-api
sudo systemctl start enactspace-api
sudo systemctl status enactspace-api
```

## PostgreSQL

```bash
sudo -u postgres createuser enactspace_user
sudo -u postgres createdb -O enactspace_user enactspace
```

Definir un mot de passe fort et renseigner `DATABASE_URL` dans `/etc/enactspace/enactspace.env`.

## Migrations

```bash
cd /opt/enactspace/app/backend
/opt/enactspace/venv/bin/alembic upgrade head
```

Garder `AUTO_CREATE_TABLES=false` en production.
