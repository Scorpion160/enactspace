# EnactSpace V1 - Notes test Android

## Etat environnement

- Date: 2026-07-03
- Telephone detecte par ADB: `R83XA0BB4FK`
- Modele detecte: `SM_A065F`
- Etat ADB: `device`
- Adresse IPv4 PC relevee via `ipconfig`: `10.7.7.228`

## Commandes executees

```powershell
git pull origin main
flutter pub get
flutter analyze --no-pub
adb devices
adb devices -l
ipconfig
```

## Resultats

- `git pull origin main`: depot deja a jour.
- `flutter pub get`: OK.
- `flutter analyze --no-pub`: OK.
- `adb devices`: telephone visible et autorise.
- `python -m compileall backend/app`: `python` n'est pas disponible dans le PATH de cette session. La validation backend doit utiliser le Python embarque Codex ou le Python installe localement.
- `flutter doctor -v` et `flutter devices`: commandes restees bloquees sans sortie dans cette session, malgre ADB OK. Elles ont ete arretees pour poursuivre la stabilisation.

## Checklist telephone

1. Options developpeur activees.
2. Debogage USB active.
3. Cle RSA acceptee sur le telephone.
4. Mode USB en transfert de fichiers / MTP si la detection devient instable.
5. Telephone et PC sur le meme Wi-Fi pour les tests backend via IP locale.

## Decision V1

Comme ADB detecte correctement le telephone, la suite des tests Android peut utiliser l'ID:

```powershell
flutter run -d R83XA0BB4FK --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

Si `flutter devices` reste bloque, verifier Flutter/Android SDK sur la machine, mais ne pas remettre en cause la connexion USB tant que `adb devices -l` liste le telephone en etat `device`.
