# EnactSpace V1.1 - Deploiement VPS isole

Ce guide deploie uniquement EnactSpace. Il ne modifie jamais Kerr Un Jombor,
HydroPilot, leurs conteneurs, leurs volumes, leurs fichiers d'environnement ou
leur tunnel Cloudflare existant.

## Architecture retenue

| Element | Emplacement / port |
| --- | --- |
| Code | `/opt/enactspace/app` |
| Frontend Flutter Web | `/opt/enactspace/web` puis `127.0.0.1:18080` |
| API FastAPI | `127.0.0.1:18002` |
| PostgreSQL | reseau Docker prive `enactspace_network` |
| Uploads | `/var/lib/enactspace/uploads` |
| Imports prives | `/var/lib/enactspace/import` |
| Sauvegardes | `/var/backups/enactspace` |
| Secrets | `/etc/enactspace/enactspace.env` |

Le fichier Compose est `deploy/docker-compose.vps.yml`, avec le projet Docker
`enactspace`. Toute commande Docker de ce guide contient explicitement ces deux
elements.

## 1. Audit et reference

Avant toute ecriture, relever les applications, ports, conteneurs, sites Nginx
et tunnel Cloudflare existants. Tester leurs URLs publiques et conserver le code
HTTP, la date et le statut. Ne pas reparer une application existante qui etait
deja indisponible.

Verifier que les ports proposes sont libres :

```bash
ss -lntup | grep -E '18080|18002' || true
```

Si l'un est occupe, choisir deux ports libres superieurs a `18000`, modifier
seulement le Compose EnactSpace et le fichier Cloudflare EnactSpace, puis noter
la decision dans le rapport de deploiement.

Sauvegarder les configurations existantes sous `/root/enactspace_predeploy_DATE`
avant de les consulter davantage. Ces sauvegardes restent hors Git.

## 2. Repertoires et compte de service

```bash
install -d -m 750 -o enactspace -g enactspace /opt/enactspace/app
install -d -m 750 -o enactspace -g enactspace /opt/enactspace/web
install -d -m 750 -o 10001 -g 10001 /var/lib/enactspace/uploads
install -d -m 750 -o 10001 -g 10001 /var/lib/enactspace/import
install -d -m 700 -o enactspace -g enactspace /var/backups/enactspace
install -d -m 750 -o root -g enactspace /etc/enactspace
```

Creer d'abord le compte hote uniquement s'il n'existe pas :

```bash
id enactspace >/dev/null 2>&1 || useradd --system --create-home \
  --home-dir /opt/enactspace --shell /usr/sbin/nologin enactspace
```

Le backend tourne non-root sous l'UID `10001` dans son conteneur; les deux
repertoires montes sont donc volontairement attribues a cet UID. Ne pas changer
les permissions d'autres dossiers applicatifs.

## 3. Code et secrets

```bash
git clone https://github.com/Scorpion160/enactspace /opt/enactspace/app
git -C /opt/enactspace/app checkout main
git -C /opt/enactspace/app pull --ff-only origin main
git -C /opt/enactspace/app status --short
```

Copier `backend/.env.production.example` vers `/etc/enactspace/enactspace.env`.
Renseigner des secrets distincts, longs et aleatoires pour PostgreSQL, JWT, QR
et NFC. Definir notamment :

```dotenv
APP_ENV=production
APP_DEBUG=false
POSTGRES_DB=enactspace
POSTGRES_USER=enactspace
POSTGRES_PASSWORD=SECRET_UNIQUE
DATABASE_URL="postgresql+psycopg://enactspace:SECRET_UNIQUE@postgres:5432/enactspace"
SECRET_KEY=SECRET_UNIQUE
JWT_SECRET_KEY=SECRET_UNIQUE
PUBLIC_API_BASE_URL="https://api.enactspace.kerunjombor.net"
CORS_ORIGINS="https://enactspace.kerunjombor.net"
FILE_STORAGE_PATH=/app/uploads
AUTO_CREATE_TABLES=false
EMAIL_ENABLED=false
NOTIFICATION_EMAIL_ENABLED=false
MOBILE_MONEY_ENABLED=false
PAYMENT_PROVIDER_ENABLED=false
ATTENDANCE_QR_ENABLED=true
ATTENDANCE_QR_SECRET=SECRET_UNIQUE
ATTENDANCE_NFC_ENABLED=true
ATTENDANCE_NFC_HASH_SECRET=SECRET_UNIQUE
ENACTSPACE_INITIAL_ADMIN_EMAIL=dioppylsci@gmail.com
ENACTSPACE_INITIAL_ADMIN_PASSWORD=SECRET_TEMPORAIRE_12_CARACTERES_MINIMUM
```

Puis restreindre le fichier :

```bash
chown root:enactspace /etc/enactspace/enactspace.env
chmod 640 /etc/enactspace/enactspace.env
```

Ne jamais afficher ce fichier, ni le placer dans Git. Desactiver SMTP et
PayDunya durant cette release candidate.

## 4. Frontend Flutter Web

Construire sur le poste Windows avec l'API HTTPS reelle :

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter clean
flutter pub get
flutter build web --release --dart-define=ENACTSPACE_API_URL=https://api.enactspace.kerunjombor.net
flutter analyze --no-pub
```

Copier le contenu vers un dossier temporaire VPS, verifier les fichiers, puis
basculer vers `/opt/enactspace/web` sans toucher aux repertoires web existants.

## 5. Demarrage controle

```bash
cd /opt/enactspace/app
docker compose -p enactspace -f deploy/docker-compose.vps.yml config --quiet
docker compose -p enactspace -f deploy/docker-compose.vps.yml run --rm backend python -m app.scripts.validate_environment /etc/enactspace/enactspace.env
docker compose -p enactspace -f deploy/docker-compose.vps.yml build
docker compose -p enactspace -f deploy/docker-compose.vps.yml up -d postgres
docker compose -p enactspace -f deploy/docker-compose.vps.yml run --rm backend alembic upgrade head
docker compose -p enactspace -f deploy/docker-compose.vps.yml run --rm backend alembic current
docker compose -p enactspace -f deploy/docker-compose.vps.yml run --rm backend python -m app.scripts.initialize_production
docker compose -p enactspace -f deploy/docker-compose.vps.yml run --rm backend python -m app.scripts.initialize_production
docker compose -p enactspace -f deploy/docker-compose.vps.yml up -d backend web
docker compose -p enactspace -f deploy/docker-compose.vps.yml ps
```

Apres la creation de l'administrateur, supprimer uniquement les variables
`ENACTSPACE_INITIAL_ADMIN_*` de l'environnement puis recreer le backend :

```bash
docker compose -p enactspace -f deploy/docker-compose.vps.yml up -d --force-recreate backend
```

Verifier avant Cloudflare :

```bash
curl -fsS http://127.0.0.1:18002/health
curl -fsS http://127.0.0.1:18002/api/system/status
curl -I http://127.0.0.1:18080
```

## 6. Cloudflare dedie

Utiliser un tunnel distinct `enactspace` et le service systemd
`cloudflared-enactspace.service`. Ne jamais utiliser `cloudflared service
install`, ni ecraser la configuration ou les credentials du tunnel existant.

Le tunnel dedie doit pointer uniquement vers :

```yaml
ingress:
  - hostname: enactspace.kerunjombor.net
    service: http://127.0.0.1:18080
  - hostname: api.enactspace.kerunjombor.net
    service: http://127.0.0.1:18002
  - service: http_status:404
```

Valider avec `cloudflared tunnel ingress validate` avant d'activer le service.
Sans acces Cloudflare permettant de creer un tunnel dedie, s'arreter apres les
tests locaux et documenter les deux hostnames a ajouter. Ne pas modifier le
tunnel existant a l'aveugle.

## 7. Verification et rollback limite a EnactSpace

Apres l'activation publique, tester EnactSpace, puis les URLs existantes relevees
au depart. Si une application protegee ne repond plus, arreter seulement le
tunnel et les conteneurs EnactSpace :

```bash
systemctl stop cloudflared-enactspace
docker compose -p enactspace -f /opt/enactspace/app/deploy/docker-compose.vps.yml stop
```

Ne supprimer aucun volume et ne redemarrer aucun conteneur d'une autre
application. L'import des membres reste obligatoirement en `--dry-run` pendant
cette tranche.
