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
5. Construire le Web avec la **bonne URL API de production**, les fichiers Firebase requis et les véritables numéros de release. Le build CI de développement utilise `https://example.invalid` et **ne peut pas être publié tel quel**.
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
