# EnactSpace V1.1 - Smoke test production VPS

Objectif: verifier rapidement qu'un backend VPS est exploitable par l'APK et par les outils d'administration.

## Prealable

Le backend doit etre demarre derriere HTTPS avec:

```text
APP_ENV=production
APP_DEBUG=false
PUBLIC_API_BASE_URL=https://api.enactspace.example.com
CORS_ORIGINS=https://app.enactspace.example.com
FILE_STORAGE_PATH=/var/lib/enactspace/uploads
```

## 1. Sante publique

```powershell
curl.exe https://api.enactspace.example.com/health
```

Resultat attendu:

```json
{
  "ok": true,
  "service": "EnactSpace",
  "version": "1.1.0",
  "environment": "production"
}
```

## 2. Diagnostic systeme

```powershell
curl.exe https://api.enactspace.example.com/api/system/status
```

Resultat attendu:

```json
{
  "ok": true,
  "backend": {"online": true},
  "database": {"reachable": true},
  "storage": {"reachable": true, "writable": true}
}
```

Cet endpoint ne doit jamais exposer:

- `DATABASE_URL`
- `SECRET_KEY`
- `JWT_SECRET_KEY`
- secrets SMTP
- secrets Mobile Money
- tokens FCM

Si `ok=false`, le code HTTP attendu est `503`.

## 3. API authentification

Tester avec un compte admin reel ou un compte temporaire cree pour la recette.

```powershell
curl.exe -X POST https://api.enactspace.example.com/api/auth/token `
  -H "Content-Type: application/x-www-form-urlencoded" `
  -d "username=admin@example.com&password=CHANGE_ME"
```

Le resultat doit contenir un `access_token`.

## 4. Profil utilisateur

```powershell
curl.exe https://api.enactspace.example.com/api/users/me `
  -H "Authorization: Bearer TOKEN_ICI"
```

Verifier:

- email correct
- roles corrects
- statut actif
- `can_review_join_requests` coherent

## 5. Fichiers et stockage

Depuis l'app:

1. Upload document simple.
2. Upload image dans un post.
3. Upload media dans le chat.
4. Ouvrir le fichier depuis un autre compte autorise.

Sur VPS:

```bash
sudo ls -lah /var/lib/enactspace/uploads
sudo journalctl -u enactspace-backend -n 100
```

## 6. CORS web

Depuis le domaine web autorise, ouvrir la console navigateur et tester login/dashboard.

Si erreur CORS:

1. Verifier `CORS_ORIGINS`.
2. Redemarrer `enactspace-backend`.
3. Verifier Nginx.

## 7. APK production

Construire l'APK avec:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter build apk --release --dart-define=ENACTSPACE_API_URL=https://api.enactspace.example.com
```

Smoke test telephone:

1. Login Admin.
2. Dashboard.
3. Chat.
4. Posts.
5. Notifications.
6. Documents.
7. Membres.
8. Presences.
9. Finance.
10. Deconnexion.

## 8. Logs a surveiller

Backend:

```bash
sudo journalctl -u enactspace-backend -f
```

Nginx:

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

Android:

```powershell
adb logcat | Select-String "flutter|EnactSpace|Exception|Error|SocketException|401|403|404|422|500"
```

## 9. Criteres de validation

La tranche VPS est valide si:

- `/health` retourne `ok=true`.
- `/api/system/status` retourne `ok=true`.
- login admin OK.
- `/api/users/me` OK.
- stockage fichiers OK.
- APK production connectee au VPS.
- aucune erreur `500` inattendue.
- aucune fuite de secret dans les reponses API.
