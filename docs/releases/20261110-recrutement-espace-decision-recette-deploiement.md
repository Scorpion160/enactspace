# EnactSpace — recette et préparation du déploiement du recrutement

Date : 10 novembre 2026  
Révision : PR #28, branche `feature/recruitment-decision-workspace-20261110`  
Objet : refonte de l'espace d'aide à la décision du recrutement, réutilisable pour toute campagne.

## 1. Ce qui est validé par GitHub Actions

- Analyse statique Flutter.
- Tests du backend (PostgreSQL temporaire, aucune donnée de production).
- Tests Flutter et du recrutement.
- Compilation Flutter Web.
- Captures d'écran **synthétiques** en clair/sombre sur téléphone et ordinateur : comparaison anonyme, statistiques de gestion, panneau complet (calendrier, paramètres, publication). Les captures sont déposées comme artifact `recruitment-visual-review-<run_id>`, conservé 7 jours.
- Les droits dans les statistiques sont testés : les indicateurs internes ne sont fournis qu'aux utilisateurs habilités à gérer le jury.

Les captures sont des maquettes *rendues par le code Flutter réel*, mais avec des données inventées. Leur réussite ne remplace pas la recette en conditions réelles de connexion.

## 2. Conditions de production à vérifier

**BLOQUANT : réconcilier la version de source avec le Web déjà servi.**

À la date de préparation, la branche de code de base porte `frontend/pubspec.yaml: version: 1.0.30+33`, tandis que la dernière vérification de production donnait `1.0.30+35`. Un simple build et déploiement de la PR #28 risquerait d'écraser des correctifs de production plus récents, même si les tests sont verts. Comparer le code source des builds effectivement déployés, inventorier les correctifs hors branche et mettre à jour la source et les numéros de version **avant toute bascule**. Ne jamais incrémenter un numéro sans confirmer le contenu et la filiation du build.

**BLOQUANT : compatibilité backend / frontend.**

Cette refonte comporte de nouveaux champs API :
- `GET /recruitment/statistics` -> `selection_progress` pour les gestionnaires autorisés seulement ;
- `GET /recruitment/campaigns/{id}/selection` -> `department` et `study_level` anonymes dans la liste de comparaison ;
- `ApplicationRead` -> `selection_ready` et `selection_required_reviews` pour distinguer les notes provisoires de celles complètes selon les seuils par campagne.

Déployer uniquement la nouvelle interface Web sur l'ancien backend rendrait ces fonctions incomplètes. Le backend doit être mis à niveau avec prudence ou l'interface doit être adaptée pour rester entièrement compatible avec la version en production.

**Également requis :**
- accès administrateur sécurisé au VPS ;
- confirmation de l'état réel des conteneurs, de la file de courriels et de l'API ;
- sauvegarde PostgreSQL récente et vérifiée ;
- sauvegarde des fichiers Web et de l'image backend en service ;
- validation visuelle du bureau/mobile, clair/sombre et des rôles manager, juré, membre simple ;
- ne pas effectuer la bascule au moment d'une délibération ou publication de résultats ;
- ne pas générer de mails ni modifier les notes pendant la recette.

## 3. Déroulement de la bascule — quand les prérequis seront satisfaits

1. Relever les versions et empreintes de `/opt/enactspace/web/main.dart.js`, `version.json` et de l'image backend. Stopper si les empreintes diffèrent des valeurs prévues.
2. Créer une sauvegarde `pg_dump -Fc` horodatée ; vérifier `pg_restore -l` et le SHA-256. Conserver une copie hors VPS. Sauvegarder aussi les fichiers Web servis, les documents et les images backend.
3. Construire le backend correspondant au commit validé dans une image distincte, tester son démarrage et `/health` hors production. Vérifier les contrats de données ci-dessus, les droits manager/juré et le fonctionnement de la file e-mail, **sans publier**.
4. Installer la nouvelle image backend uniquement si le plan de retour arrière est testé et les migrations/contrats compatibles avec la base existante. Effectuer les smoke tests en lecture seule.
5. Construire le Web avec la **bonne URL API de production**, les fichiers Firebase requis et les véritables numéros de release. La PR nº 28 de développement utilisait `https://example.invalid`. L'archive candidate de la PR nº 29 utilise désormais l'URL réelle de l'API, mais elle **n'est pas autorisée à être déployée** avant les contrôles de compatibilité et de sauvegarde.
6. Établir l'archive du Web, son SHA-256 et celui de `main.dart.js`. Vérifier `version.json`, `flutter_bootstrap.js`, le service worker et la cohérence des chemins.
7. Utiliser `tools/publish_web_release.py` sur le VPS, **d'abord sans `--execute`**, avec `--archive`, `--archive-sha256`, `--release VERSION BUILD MAIN_SHA` et `--expected-live VERSION BUILD MAIN_SHA`. La préparation vérifie l'archive, la version et le conteneur Web ; elle ne modifie pas le répertoire Web actif.
8. Lors de la bascule validée, relancer avec `--execute`. Le script sauvegarde l'ancien répertoire, contrôle les assets réellement servis et tente un retour arrière en cas d'erreur.
9. Vérifier le site HTTPS, les filtres, les chiffres, le classement, l'accès aux dossiers par rôle, les annonces non publiées, et les parcours candidats (suivi et e-mail) ; comparer le nombre de candidatures et les évaluations avant/après.
10. Documenter les empreintes, la nouvelle version, les contrôles, et l'emplacement de restauration. **Ne pas considérer la publication achevée tant que ces contrôles ne sont pas réussis.**

## 4. Décisions et confidentialité

- Classement par scores = outil d'analyse ; aucun candidat ne doit être automatiquement accepté ou rejeté.
- Le rapprochement des départements/niveaux est facultatif. L'estimation des années restant au cursus ne doit pas être utilisée comme critère d'inéligibilité.
- Les candidats disposant de notes provisoires sont clairement identifiés et ne sont pas classés devant les dossiers prêts.
- Le simulateur d'effectif n'enregistre aucun quota.
- Les opérations de publication de résultats, levée d'anonymat et envoi d'e-mails restent explicitement contrôlées par les responsables.

## 5. Situation au 10 novembre 2026

- PR #28 en brouillon ; aucune fusion effectuée.
- Aucun déploiement via GitHub n'est disponible dans le dépôt existant ; la branche n'introduit pas de workflow de déploiement automatisé non contrôlé.
- La recette CI utilise des données synthétiques seulement.
- La version de production actuelle et la filiation du code doivent être validées directement sur le VPS avant tout déploiement.


## 6. Réconciliation de la production et version candidate +36

Le 10 novembre 2026, la comparaison GitHub a établi que les sources `1.0.30+34` et `1.0.30+35` correspondent aux correctifs de téléchargement authentifié (PR nº 25) et de métadonnées des documents officiels (PR nº 27). Le correctif du générateur des PV Enac'Chefs (PR nº 26) a également été réintégré.

Ces sept fichiers ont été transférés sans modification de contenu sur la branche `integration/recruitment-production-parity-20261110`, empilée sur la refonte du recrutement (PR nº 28). La version candidate est numérotée **1.0.30+36** dans `frontend/pubspec.yaml` et `frontend/web/version.json`. Elle n'est pas déployée.

### Empreintes de référence : production publique observée

Un contrôle GitHub Actions **en lecture seule** a vérifié les ressources publiques, le 10 novembre :
- Web servi : `1.0.30+35` ;
- API de production : `1.0.30`, `/health` indique `ok: true` ;
- SHA-256 public de `main.dart.js` : `0edccbd6542c23c042a29164bcb64d22082ccc96b015269c9002beeb34fbec8e` ;
- SHA-256 du service worker Firebase actuellement servi : `5560e639af87e9c35428ac7ef0f6dccf0c1b8299ff359af82302ba491a50b2c3` ;
- script : `tools/fingerprint_public_production.py` ; workflow : `.github/workflows/public-production-fingerprint.yml`.

Ces empreintes sont des **observations horodatées**, pas des valeurs garanties à vie. Elles doivent être reconfirmées immédiatement avant la bascule.

### Archive candidate testée (sans déploiement)

GitHub Actions [Application CI / run 42848051022](https://github.com/Scorpion160/enactspace/actions/runs/42848051022) a construit puis testé :
- archive : `enactspace-web-1.0.30-build36-candidate.tar.gz` ;
- SHA-256 archive : `f4b1b35d8fa22bb64cbe9721d398464c8d52be3d1f3cd54b4b9e35cc75963e0d` ;
- SHA-256 du JavaScript candidat : `ce415c70ffd26b01f67fe7a78b7f21f96829467bbe58ad724e1752961cdbc1f4` ;
- worker Firebase : récupération du **fichier public déjà utilisé**, avec vérification stricte de son empreinte ;
- `tools/assemble_web_release.py` a testé l'archive avec l'extracteur `tools/publish_web_release.py::extract_bundle` ;
- résultat : `staging_archive_selfcheck = OK`, mais `deploy_ready = false`.

L'artefact GitHub est `enactspace-web-1.0.30-build36-PREFLIGHT-ONLY-42848051022`. Il contient l'archive, le manifeste JSON et le fichier de sommes SHA-256. Les artefacts CI ont une durée de conservation limitée.

### Préparation du pré-déploiement sur VPS

1. Effectuer une sauvegarde de PostgreSQL `pg_dump -Fc` et la vérifier avec `pg_restore -l` + SHA-256, hors VPS si possible.
2. Conserver l'image backend précédente, les fichiers Web actifs, les modèles PDF, les uploads et les secrets/configurations existants **sans les recopier dans GitHub**.
3. Relever le SHA-256 réel des fichiers actifs et le comparer aux empreintes publiques précédentes.
4. Construire la nouvelle image backend sous un **tag distinct** et tester `/health` sur une base temporaire ou isolée. Ne pas basculer l'API tant que le démarrage production, les migrations et les nouveaux champs du recrutement ne sont pas validés.
5. Vérifier les droits réels du jury et des responsables, le fonctionnement des PDF et la file d'e-mails sans envoyer de messages aux candidats.
6. Vérifier l'archive candidate avec `sha256sum` puis appeler l'outil de publication **sans `--execute`** :

```bash
python3 /opt/enactspace/app/tools/publish_web_release.py \
  --archive /CHEMIN/VERIFIE/enactspace-web-1.0.30-build36-candidate.tar.gz \
  --archive-sha256 f4b1b35d8fa22bb64cbe9721d398464c8d52be3d1f3cd54b4b9e35cc75963e0d \
  --release 1.0.30 36 ce415c70ffd26b01f67fe7a78b7f21f96829467bbe58ad724e1752961cdbc1f4 \
  --expected-live 1.0.30 35 0edccbd6542c23c042a29164bcb64d22082ccc96b015269c9002beeb34fbec8e
```

Si la version actuellement servie ne correspond plus, **arrêter** la procédure : ne pas forcer le déploiement. Après validation des prérequis, la bascule réelle reste une opération distincte avec sauvegarde et retour arrière.

**Restrictions maintenues :** aucune écriture sur les candidatures, les notes, les décisions, le contenu des archives ni les paramètres SMTP lors de cette préparation.
