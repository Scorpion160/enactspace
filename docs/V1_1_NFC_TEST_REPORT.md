# EnactSpace V1.1 - Rapport Test NFC

## Validations automatiques

- `flutter analyze --no-pub` : OK.
- `backend\.venv\Scripts\python.exe -m compileall backend\app` : OK.
- `git diff --check` : OK.

## Couverture implementee

- Enrolement badge NFC.
- Liste et filtres des badges.
- Revocation badge.
- Pointage NFC responsable.
- Detection present / retard.
- Refus badge inconnu.
- Refus badge revoque.
- Refus double pointage.
- Audit des scans NFC.
- Application installable sur appareil sans NFC avec `android:required="false"`.

## Test physique

Le telephone `SM_A065F` ne doit pas etre suppose compatible NFC. Si NFC est indisponible, tester l'ecran d'indisponibilite et utiliser un autre telephone NFC pour le test physique final.
