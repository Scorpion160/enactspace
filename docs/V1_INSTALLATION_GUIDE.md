# EnactSpace V1 - Guide installation

Date: 2026-07-03

## 1. Preparer le backend

Depuis le dossier projet:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
```

Installer les dependances Python selon l'environnement local du projet, puis verifier que la configuration `.env` contient les variables necessaires.

Pour un test local Android, lancer FastAPI sur toutes les interfaces:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Verifier:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/health
Invoke-WebRequest -UseBasicParsing http://10.7.7.228:8000/health
```

## 2. Initialiser les donnees V1

Activer temporairement le seed uniquement en environnement local:

```text
ENABLE_SEED=true
```

Appeler ensuite `POST /api/seed/v1-demo` avec un compte Admin ou Team Leader.

Mot de passe par defaut des comptes V1:

```text
EnactSpaceV1!
```

Voir:

```text
docs/v1_test_accounts.md
```

## 3. Configurer l'adresse API Flutter

Sur navigateur ou emulateur Android, l'adresse peut rester locale selon le cas.

Sur telephone Android reel:

```text
http://10.7.7.228:8000
```

Lancer l'app sur le telephone:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter run -d R83XA0BB4FK --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

## 4. Construire l'APK

APK debug:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter clean
flutter pub get
flutter build apk --debug --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

APK release candidate:

```powershell
flutter build apk --release --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

Fichiers attendus:

```text
frontend\build\app\outputs\flutter-apk\app-debug.apk
frontend\build\app\outputs\flutter-apk\app-release.apk
```

## 5. Installer l'APK

Avec ADB:

```powershell
adb install -r frontend\build\app\outputs\flutter-apk\app-debug.apk
```

Ou transferer l'APK sur le telephone et autoriser l'installation depuis cette source.

## 6. Tester les modules principaux

1. Login Admin.
2. Login Team Leader.
3. Login SG.
4. Login Financier.
5. Login Chef de pole.
6. Login Chef de projet.
7. Login membre simple.
8. Login Alumni valide.
9. Dashboard.
10. Chat.
11. Posts.
12. Notifications.
13. Documents.
14. Membres.
15. Poles.
16. Projets.
17. Presences.
18. Finance.
19. Impact.
20. Academy.
21. Archives.
22. Hall of Fame.

## 7. Points de controle

1. Aucun overflow visible.
2. Le clavier ne cache pas les champs critiques.
3. Les roles ne voient que les modules prevus.
4. Les messages chat arrivent chez le destinataire.
5. Les notifications sont creees et lisibles.
6. Les fichiers uploades restent accessibles.
7. Les exports CSV se telechargent correctement.

## 8. Depannage rapide

- Si le telephone ne voit pas le backend, verifier le Wi-Fi, le firewall et `--host 0.0.0.0`.
- Si login impossible sur telephone, verifier `ENACTSPACE_API_URL`.
- Si `flutter` reste bloque, fermer VS Code/Android Studio, tuer les processus Dart/Flutter restants, ouvrir un nouveau terminal et relancer `flutter --version`.
- Si la release ne s'installe pas, produire d'abord un APK debug.
