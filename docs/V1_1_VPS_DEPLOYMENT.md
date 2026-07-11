# EnactSpace V1.1 - Deploiement backend VPS

Objectif: deployer le backend FastAPI sur un VPS propre, securise et pret pour les tests V1.1.

## 1. Prerequis serveur

Recommandation:

- Ubuntu LTS recent.
- Python 3.12 ou version compatible avec les dependances du projet.
- PostgreSQL 15+ pour les donnees reelles.
- Nginx comme reverse proxy.
- Certbot pour HTTPS.
- UFW pour le firewall.

Paquets typiques:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip postgresql postgresql-contrib nginx ufw certbot python3-certbot-nginx git
```

## 2. Utilisateur et dossier applicatif

```bash
sudo adduser --system --group --home /opt/enactspace enactspace
sudo mkdir -p /opt/enactspace
sudo chown -R enactspace:enactspace /opt/enactspace
```

Cloner le projet:

```bash
sudo -u enactspace git clone https://github.com/Scorpion160/enactspace.git /opt/enactspace
cd /opt/enactspace
git checkout main
```

## 3. Base PostgreSQL

```bash
sudo -u postgres psql
```

```sql
CREATE DATABASE enactspace;
CREATE USER enactspace_user WITH PASSWORD 'CHANGE_ME_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE enactspace TO enactspace_user;
\q
```

Mettre ensuite `DATABASE_URL` dans `backend/.env`.

## 4. Environnement Python

```bash
cd /opt/enactspace/backend
python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Si PostgreSQL est utilise, ajouter le driver choisi dans l'environnement serveur si necessaire:

```bash
pip install "psycopg[binary]>=3.2,<4.0"
```

## 5. Configuration `.env`

```bash
cd /opt/enactspace/backend
cp .env.production.example .env
nano .env
chmod 600 .env
```

Points obligatoires:

- `APP_ENV=production`
- `APP_DEBUG=false`
- `ENABLE_SEED=false`
- `DATABASE_URL` vers PostgreSQL
- `SECRET_KEY` et `JWT_SECRET_KEY` longs et uniques
- `CORS_ORIGINS` avec les domaines reels
- `PUBLIC_API_BASE_URL=https://api.enactspace.example.com`
- `FILE_STORAGE_PATH=/var/lib/enactspace/uploads`

Creer le stockage persistant:

```bash
sudo mkdir -p /var/lib/enactspace/uploads
sudo chown -R enactspace:enactspace /var/lib/enactspace
```

## 6. Tables et compatibilite

Le backend actuel cree/ajuste certaines colonnes au demarrage via `ensure_compatibility_columns`.

Verification locale sur le VPS:

```bash
cd /opt/enactspace/backend
. .venv/bin/activate
python -m compileall app
python create_tables.py
```

Si Alembic est ajoute plus tard, remplacer cette etape par:

```bash
alembic upgrade head
```

## 7. Creation admin

Ne pas laisser `ENABLE_SEED=true` en production durablement.

Option recommandee:

1. Lancer temporairement le seed ou une commande admin locale.
2. Creer le compte administrateur.
3. Desactiver immediatement le seed.
4. Redemarrer le backend.

Compte admin attendu:

- email reel de l'administrateur Enactus ESP
- mot de passe temporaire fort
- changement obligatoire apres premiere connexion

## 8. Lancement manuel de test

```bash
cd /opt/enactspace/backend
. .venv/bin/activate
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Verifier:

```bash
curl http://127.0.0.1:8000/health
```

## 9. Service systemd

Creer `/etc/systemd/system/enactspace-backend.service`:

```ini
[Unit]
Description=EnactSpace backend
After=network.target postgresql.service

[Service]
User=enactspace
Group=enactspace
WorkingDirectory=/opt/enactspace/backend
EnvironmentFile=/opt/enactspace/backend/.env
ExecStart=/opt/enactspace/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Activer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable enactspace-backend
sudo systemctl start enactspace-backend
sudo systemctl status enactspace-backend
```

## 10. Nginx reverse proxy

Exemple `/etc/nginx/sites-available/enactspace-api`:

```nginx
server {
    server_name api.enactspace.example.com;

    client_max_body_size 520M;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /uploads/ {
        proxy_pass http://127.0.0.1:8000/uploads/;
    }
}
```

Activer:

```bash
sudo ln -s /etc/nginx/sites-available/enactspace-api /etc/nginx/sites-enabled/enactspace-api
sudo nginx -t
sudo systemctl reload nginx
```

## 11. HTTPS

```bash
sudo certbot --nginx -d api.enactspace.example.com
```

Verifier le renouvellement:

```bash
sudo certbot renew --dry-run
```

## 12. Firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
sudo ufw status
```

Ne pas exposer directement le port `8000` sur Internet.

## 13. Logs

Commandes utiles:

```bash
sudo journalctl -u enactspace-backend -f
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 14. Sauvegardes

Sauvegarder au minimum:

- base PostgreSQL
- dossier `FILE_STORAGE_PATH`
- fichier `.env` dans un coffre separe

Exemple PostgreSQL:

```bash
pg_dump -U enactspace_user -h 127.0.0.1 enactspace > enactspace_$(date +%F).sql
```

## 15. Smoke test production

Apres deploiement:

```bash
curl https://api.enactspace.example.com/health
curl https://api.enactspace.example.com/
```

Puis tester depuis l'APK construit avec:

```powershell
flutter build apk --release --dart-define=ENACTSPACE_API_URL=https://api.enactspace.example.com
```
