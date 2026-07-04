# EnactSpace V1 - Notes build Android

## Objectif

Produire un APK installable EnactSpace V1 pour test Android reel.

## Configuration Android V1

- Package Android: `sn.enactusesp.enactspace`
- Nom application: `EnactSpace`
- Internet autorise dans `AndroidManifest.xml`.
- Trafic HTTP local/LAN autorise pour la V1 via `network_security_config.xml`.
- Signature release actuelle: signature debug Flutter, suffisante pour une release candidate interne mais pas pour publication Play Store.

## URL API a injecter

Pour un telephone reel connecte au meme Wi-Fi que le PC:

```text
http://10.7.7.228:8000
```

Build debug:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter clean
flutter pub get
flutter build apk --debug --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

Build release candidate:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter build apk --release --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

APK attendu:

```text
frontend\build\app\outputs\flutter-apk\app-debug.apk
frontend\build\app\outputs\flutter-apk\app-release.apk
```

## Etat de la premiere session

Les commandes suivantes ont ete tentees:

```powershell
flutter clean
flutter --version
```

Resultat:

- `flutter clean` est reste bloque sans sortie.
- `flutter --version` est reste bloque sans sortie, meme apres arret des daemons Flutter/Dart visibles.
- Les processus bloques ont ete arretes pour eviter de laisser des sessions pendantes.
- Aucun nouvel APK n'a ete genere dans cette session.

Des artefacts APK existaient deja dans le dossier de build au moment du controle final:

```text
frontend\build\app\outputs\flutter-apk\app-debug.apk
frontend\build\app\outputs\flutter-apk\app-release.apk
```

Ils doivent etre consideres comme des builds precedents tant qu'un nouveau `flutter build apk` ne se termine pas avec succes.

## Etat APK V1 genere

La tranche courte APK V1 a ensuite ete relancee avec Flutter Tools directement via:

```powershell
C:\flutter\bin\cache\dart-sdk\bin\dart.exe C:\flutter\bin\cache\flutter_tools.snapshot
```

Resultat:

- `flutter clean`: OK avec acces hors sandbox.
- `flutter pub get`: OK.
- `flutter analyze --no-pub`: OK.
- `flutter build apk --debug --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000`: OK.
- `flutter build apk --release --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000`: OK.
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk`: OK sur `SM_A065F`.

Copies hors repo:

```text
C:\Users\DIOP\Downloads\EnactSpace_V1_APK\EnactSpace_V1_debug.apk
C:\Users\DIOP\Downloads\EnactSpace_V1_APK\EnactSpace_V1_release.apk
```

Le bug de login des comptes internes `@enactspace.local` detecte pendant le smoke test a ete corrige cote backend sans assouplir l'inscription publique.

## Validations projet deja OK

Avant le blocage de l'outil Flutter:

```powershell
flutter pub get
flutter analyze --no-pub
python -m compileall backend/app
git diff --check
```

Resultat:

- Dependencies Flutter: OK.
- Analyse Dart: OK.
- Compilation backend: OK.
- Verification Git whitespace: OK.

## Actions recommandees si Flutter reste bloque

1. Fermer VS Code/Android Studio si un language server Dart garde un verrou.
2. Fermer les processus `dart.exe`, `dartvm.exe`, `flutter.bat` restants.
3. Relancer un nouveau terminal PowerShell.
4. Tester `flutter --version`.
5. Relancer le build debug.
6. Si le blocage persiste, redemarrer Windows ou reparer le cache Flutter.

## Publication future

Avant distribution large:

1. Creer une cle de signature Android dediee.
2. Remplacer la signature debug dans `frontend/android/app/build.gradle.kts`.
3. Utiliser HTTPS en production.
4. Configurer une URL API stable et non liee a l'IP locale du PC.
