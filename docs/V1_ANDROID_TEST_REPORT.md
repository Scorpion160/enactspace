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
- APK debug genere et installe sur `SM_A065F`.
- APK release genere pour release candidate interne.
- Backend LAN verifie sur `http://10.7.7.228:8000/health`.

## Smoke test APK V1

Le smoke test APK a revele que les comptes internes en `@enactspace.local` etaient rejetes par la validation `EmailStr` au login avant meme l'authentification.

Correction appliquee:

- Le schema de login accepte maintenant un identifiant email en `str`.
- Le backend normalise le login avec trim et lowercase.
- Le backend refuse encore les identifiants vides ou sans `@`.
- L'inscription publique garde sa validation email stricte avec `EmailStr`.

Resultat API apres correction:

- `POST /api/auth/login` avec `admin.v1@enactspace.local` ne retourne plus `422` a cause du domaine `.local`.
- Apres seed local V1, le login retourne un token en local et via LAN.
- Le backend LAN repond sur `127.0.0.1:8000` et `10.7.7.228:8000`.

Reprise smoke test sur `SM_A065F`:

- `adb devices -l` retourne `R83XA0BB4FK device`.
- Login Admin V1 OK sur l'APK installe.
- Dashboard Admin V1 OK.
- Drawer responsive OK apres correction: les routes internes principales sont visibles sur mobile.
- Bug bloquant detecte: apres login, le drawer restait parfois en mode limite et les routes comme `/chat` revenaient vers `/dashboard`.
- Cause 1: le profil utilisateur n'etait pas hydrate assez tot apres login.
- Cause 2: `GET /api/users/me` plantait en 500 pour `admin.v1@enactspace.local`, car `UserRead.email` utilisait encore `EmailStr`.

Corrections appliquees:

- `AuthService.login` recharge maintenant `/users/me` juste apres sauvegarde du token pour alimenter le cache utilisateur.
- `AppShell` lit le token et le profil cache avant de construire le menu.
- `AppRouter` tente de recuperer `/users/me` si le cache utilisateur est absent, puis autorise temporairement les routes internes authentifiees pendant l'hydratation du profil.
- `backend/app/schemas/user.py` expose les emails utilisateur en `str` pour accepter les comptes seed internes `.local`.

Etat telephone:

- L'app installee demarre correctement.
- L'ecran login s'affiche avec le logo EnactSpace lisible.
- Aucun crash Flutter/Dart visible au lancement.
- Le test de navigation complet doit etre repris apres redemarrage manuel du backend pour charger la correction `UserRead.email`.

## Points non executes automatiquement

`flutter doctor -v` et `flutter devices` sont restes bloques sans sortie dans cette session. Comme `adb devices -l` detecte correctement le telephone, la suite du test Android reel peut continuer via l'ID ADB `R83XA0BB4FK`.

Pendant la reprise, le backend etait joignable sur `http://10.7.7.228:8000`, mais l'environnement Codex a refuse le redemarrage du process serveur apres correction a cause d'une limite d'approbation. Les tests fonctionnels complets doivent etre repris apres relance manuelle de FastAPI avec:

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

La base Android est prete pour test reel. Les APK V1 sont generes et conserves hors repo dans `C:\Users\DIOP\Downloads\EnactSpace_V1_APK`. Les tests manuels complets doivent reprendre apres autorisation USB ADB sur le telephone.
