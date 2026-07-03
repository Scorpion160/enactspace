# EnactSpace V1 - Rapport test Android reel

## Appareil

- ID ADB: `R83XA0BB4FK`
- Modele: `SM_A065F`
- Etat: detecte par `adb devices -l`

## Validations automatiques realisees

```powershell
flutter pub get
flutter analyze --no-pub
python -m compileall backend/app
git diff --check
adb devices
adb devices -l
ipconfig
```

Resultat:

- Analyse Flutter: OK.
- Compilation backend: OK avec le Python embarque Codex.
- Verification whitespace Git: OK.
- Detection ADB: OK.

## Points non executes automatiquement

`flutter doctor -v` et `flutter devices` sont restes bloques sans sortie dans cette session. Comme `adb devices -l` detecte correctement le telephone, la suite du test Android reel peut continuer via l'ID ADB `R83XA0BB4FK`.

Le backend n'etait pas lance pendant l'audit. Les tests fonctionnels complets doivent etre faits apres lancement de FastAPI avec:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Puis:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter run -d R83XA0BB4FK --dart-define=ENACTSPACE_API_URL=http://10.7.7.228:8000
```

## Parcours manuel a valider

1. Login Admin.
2. Login Team Leader.
3. Login Secretaire generale.
4. Login Financier.
5. Login Chef de pole.
6. Login Chef de projet.
7. Login membre simple.
8. Login Alumni valide.
9. Alumni en attente bloque.
10. Candidat limite au suivi candidature.
11. Dashboard.
12. Chat.
13. Posts.
14. Notifications.
15. Documents.
16. Membres.
17. Poles.
18. Projets.
19. Presences.
20. Finance.
21. Impact.
22. Academy.
23. Archives.
24. Hall of Fame.
25. Profil.
26. Parametres.

## Points a surveiller pendant la manipulation

1. RenderFlex overflow.
2. Boutons ou onglets qui debordent.
3. Clavier qui cache les champs de formulaire.
4. Ecran blanc apres navigation.
5. Redirection login/dashboard.
6. Erreur 401/403 incoherente avec le role.
7. Erreur 404 sur fichiers ou medias.
8. WebSocket chat/notifications silencieux.

## Statut V1

La base Android est prete pour test reel. Les tests manuels doivent maintenant etre faits avec le backend actif et l'URL API locale transmise par `--dart-define`.
