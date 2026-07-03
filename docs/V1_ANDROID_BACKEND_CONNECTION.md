# EnactSpace V1 - Connexion backend Android

## Principe

Sur un telephone Android reel, `localhost` et `127.0.0.1` pointent vers le telephone, pas vers le PC. L'application doit donc appeler le backend FastAPI avec l'adresse IP locale du PC.

Dans cette session, l'adresse Wi-Fi du PC relevee par `ipconfig` est:

```text
10.7.7.228
```

L'URL API a utiliser pour un test Android reel est donc:

```text
http://10.7.7.228:8000
```

## Lancer le backend pour un telephone

Le backend doit ecouter sur toutes les interfaces, pas uniquement sur `127.0.0.1`.

Depuis `C:\Users\DIOP\Documents\Enactus\enactspace`:

```powershell
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Verification depuis le PC:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health
Invoke-WebRequest -UseBasicParsing http://10.7.7.228:8000/health
```

Si l'URL `127.0.0.1` repond mais pas l'URL `10.7.7.228`, verifier le firewall Windows et le profil reseau Wi-Fi.

## Lancer Flutter sur le telephone

Depuis `frontend`:

```powershell
flutter run -d R83XA0BB4FK --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

La meme variable doit etre fournie pendant un build APK destine au telephone:

```powershell
flutter build apk --debug --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
flutter build apk --release --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

## WebSocket chat et notifications

L'application derive automatiquement l'URL WebSocket depuis `ENACTSPACE_API_URL`.

Exemple:

```text
http://10.7.7.228:8000
```

devient:

```text
ws://10.7.7.228:8000/api/realtime/ws
```

Il n'y a donc pas de variable supplementaire a configurer pour le chat temps reel et les notifications temps reel.

## Fichiers et medias

Les uploads passent par:

```text
http://10.7.7.228:8000/api/files/upload
```

Les telechargements doivent etre verifies depuis le telephone avec:

1. Un document PDF ou image.
2. Une piece jointe chat.
3. Une preuve finance ou presence si disponible.

## Etat observe pendant cette tranche

- Telephone ADB detecte: `R83XA0BB4FK`.
- Backend non demarre au moment de l'audit: `http://127.0.0.1:8000/health` et `http://10.7.7.228:8000/health` ne repondaient pas.
- Configuration Android ajustee pour autoriser les appels HTTP locaux/LAN pendant la V1.

## Checklist reseau

1. PC et telephone connectes au meme Wi-Fi.
2. Backend lance avec `--host 0.0.0.0`.
3. Firewall Windows autorise Python/Uvicorn sur le reseau prive.
4. `ENACTSPACE_API_URL` pointe vers l'IP Wi-Fi du PC.
5. Tester login, chat, notifications et fichiers depuis le telephone.
