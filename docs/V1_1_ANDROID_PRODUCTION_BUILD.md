# EnactSpace V1.1 - Build Android production

Objectif: construire une APK connectee au backend VPS sans coder l'URL API dans plusieurs fichiers.

## Principe

Le frontend lit une seule variable de build:

```text
ENACTSPACE_API_URL
```

Le code central est `frontend/lib/core/api/api_client.dart`.

Regle:

- ne pas dupliquer l'URL API dans les ecrans Flutter;
- ne pas committer une URL VPS secrete ou temporaire dans le code;
- utiliser `--dart-define=ENACTSPACE_API_URL=...` pour chaque build.

## Modes supportes

### 1. Developpement local web/desktop

Sans `--dart-define`, Flutter utilise:

```text
http://127.0.0.1:8000
```

Commande:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter run -d edge
```

ou Firefox si configure dans Flutter:

```powershell
flutter run -d web-server
```

### 2. Developpement Android emulateur

Sans `--dart-define`, Android utilise:

```text
http://10.0.2.2:8000
```

C'est l'adresse speciale de l'hote depuis l'emulateur Android.

### 3. Test telephone sur reseau local

Utiliser l'IP Wi-Fi du PC qui lance le backend:

```powershell
flutter run -d R83XA0BB4FK --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

Build debug LAN:

```powershell
flutter build apk --debug --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

### 4. Production VPS

Utiliser uniquement HTTPS:

```powershell
flutter build apk --release --dart-define=ENACTSPACE_API_URL=https://api.enactspace.example.com
```

Si l'URL est donnee avec `/api` a la fin, l'app la normalise automatiquement:

```text
https://api.enactspace.example.com/api -> https://api.enactspace.example.com
```

L'app ajoute ensuite elle-meme `/api` pour les endpoints REST.

## Verification avant build production

Verifier le backend:

```powershell
curl.exe https://api.enactspace.example.com/health
```

Le diagnostic detaille `/api/system/status` sera ajoute dans la tranche suivante.

Verifier la configuration CORS dans `backend/.env`:

```text
CORS_ORIGINS=https://app.enactspace.example.com
PUBLIC_API_BASE_URL=https://api.enactspace.example.com
```

## Build APK release

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter clean
flutter pub get
flutter analyze --no-pub
flutter build apk --release --dart-define=ENACTSPACE_API_URL=https://api.enactspace.example.com
```

APK generee:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

Copie recommandee hors repo:

```powershell
Copy-Item .\build\app\outputs\flutter-apk\app-release.apk C:\Users\DIOP\Downloads\EnactSpace_V1_1_APK\EnactSpace_V1_1_release.apk
```

## Installation telephone

```powershell
adb install -r .\build\app\outputs\flutter-apk\app-release.apk
adb shell monkey -p sn.enactusesp.enactspace 1
```

## Smoke test minimum

1. Ouvrir l'app.
2. Login Admin.
3. Dashboard.
4. Chat.
5. Posts.
6. Notifications.
7. Documents.
8. Presence.
9. Finance.
10. Deconnexion.

## Erreurs frequentes

- `SocketException`: URL VPS incorrecte, firewall, HTTPS ou DNS.
- `404`: URL fournie avec mauvais chemin ou reverse proxy Nginx incorrect.
- `401`: token expire ou secret JWT change.
- `403`: role insuffisant.
- `CORS`: `CORS_ORIGINS` ne contient pas le domaine web qui appelle l'API.
- `HandshakeException`: certificat HTTPS invalide ou auto-signe.

## Regle de release

Ne pas committer:

- `frontend/build/`
- APK
- captures telephone
- secrets VPS
- fichier `.env`
