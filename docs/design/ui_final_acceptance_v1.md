# Recette finale UI/UX — EnactSpace v1

## 1. Baseline

- Branche : `chore/ui-final-acceptance-v1`
- Commit de base : `04c205dd4369b384524c3c5c3051190a619289d3`
- État initial : worktree propre.
- Date de recette : 1 septembre 2026.
- Méthode : inspection statique ciblée, tests widgets avec utilisateurs et gateways mémoire déterministes, puis validation Flutter locale sans réseau réel.

## 2. Périmètre

La recette couvre les 38 routes déclarées par `app_router.dart`, les profils dérivés de `UserExperience`, les navigations desktop et mobile, le responsive, le zoom texte, les deep-links, les permissions UX, l’accessibilité, les états asynchrones, l’humanisation et l’absence de fallback de démonstration silencieux.

Aucun backend, contrat API, package, fichier Docker, fichier d’environnement ou asset n’a été modifié. Aucun `pub get`, seed, appel réseau réel, capture, commit, push, merge ou déploiement n’a été effectué. Les gateways mémoire n’ont réalisé aucune mutation réelle.

## 3. Matrice rôles

Le backend demeure l’autorité finale. Cette matrice décrit seulement les gardes et points d’entrée UX actuels.

| Profil audité | Expérience et routes principales | Actions sensibles vérifiées |
|---|---|---|
| Non connecté | Splash, connexion, suivi de candidature et recrutement public | Toute route interne redirige vers la connexion |
| Membre / Enacteur | Espace personnel, présence personnelle, tâches, communication, documents, événements, Academy, gamification, archives | Pas de commandes globales membres, finance, présence ou Academy admin |
| Chef de pôle | Expérience Enacchef, membres, pôle, projets, événements, recrutement, impact | Commandes locales pertinentes ; pas de pouvoir global implicite |
| Adjoint chef de pôle | Même périmètre de consultation Enacchef | Commandes locales seulement selon les droits de l’objet |
| Chef de projet | Expérience Enacchef, membres, pôles, projets, événements, recrutement, impact | Gestion locale pertinente ; pas de pouvoir global implicite |
| Adjoint chef de projet | Même périmètre de consultation Enacchef | Commandes locales seulement selon les droits de l’objet |
| Financier | Dashboard finance, finance personnelle et gestion financière, recrutement via statut Enacchef | Pas de gestion globale membres/présence/Academy |
| Secrétaire Générale | Membres, présence, recrutement, opérations, alumni, impact | Outils globaux prévus, sans Academy admin |
| Team Leader | Ensemble des outils globaux prévus, finance et impact | Gestion globale prévue, sans Academy admin |
| Administrateur | Ensemble des modules et Academy admin | Gestion globale et administration Academy |
| Alumni | Communication, événements, Academy, archives, annuaire alumni | Aucune opération interne réservée aux actifs |
| Recruteur / veille | Recrutement et expérience membre active | Décisions recrutement selon le rôle, sans pouvoirs globaux annexes |
| Faculty advisor | Expérience Enacchef, opérations, recrutement et impact | Pas d’élévation automatique vers l’administration globale |

## 4. Matrice routes

`Directe` signifie qu’un chargement direct/refresh est supporté par le routeur. Pour les fiches, un identifiant absent est rendu par l’état erreur/introuvable du module ; une route non déclarée rend la page 404. Une route authentifiée refusée redirige proprement vers `/dashboard`, sauf NFC qui revient vers `/attendance` lorsqu’il est consultable.

| # | Route | Accès | Rôle/garde UX | Shell | Directe | Paramètres | ID invalide / fallback |
|---:|---|---|---|:---:|:---:|---|---|
| 1 | `/splash` | Public | Aucun | Non | Oui | — | 404 globale si chemin inconnu |
| 2 | `/login` | Public | Déconnecté ; connecté → dashboard | Non | Oui | — | 404 globale si chemin inconnu |
| 3 | `/application-tracking` | Public | Aucun | Non | Oui | — | État métier du suivi |
| 4 | `/recruitment/apply` | Public | Aucun | Non | Oui | — | État vide/erreur des campagnes |
| 5 | `/recruitment/apply/:campaignId` | Public | Aucun | Non | Oui | `campaignId` | Erreur de campagne, jamais écran blanc |
| 6 | `/dashboard` | Auth | Tout profil connecté | Oui | Oui | — | Refus → login/dashboard |
| 7 | `/members` | Auth | Gestion globale ou responsable pôle/projet | Oui | Oui | — | Refus → dashboard |
| 8 | `/attendance` | Auth | Membre actif | Oui | Oui | — | Refus → dashboard |
| 9 | `/attendance/scan` | Auth | Membre actif | Oui | Oui | — | Refus → dashboard |
| 10 | `/attendance/nfc` | Auth | Admin, TL ou SG actif | Oui | Oui | — | Refus → attendance/dashboard |
| 11 | `/tasks` | Auth | Actif non alumni | Oui | Oui | `view` optionnel | Vue par défaut si filtre inconnu |
| 12 | `/tasks/:taskId` | Auth | Hérite de Tasks | Oui | Oui | `taskId` | Erreur/introuvable du gateway |
| 13 | `/finance` | Auth | Membre actif ; gestion selon rôle finance | Oui | Oui | — | Refus → dashboard |
| 14 | `/recruitment` | Auth | Admin, TL, SG, recrutement ou Enacchef | Oui | Oui | — | Refus → dashboard |
| 15 | `/documents` | Auth | Actif non alumni | Oui | Oui | — | États loading/empty/error distincts |
| 16 | `/documents/:documentId` | Auth | Hérite de Documents | Oui | Oui | `documentId` | Erreur/introuvable du gateway |
| 17 | `/notifications` | Auth | Tout profil connecté | Oui | Oui | — | Refus → login |
| 18 | `/posts` | Auth | Tout profil connecté | Oui | Oui | — | États loading/empty/error distincts |
| 19 | `/chat` | Auth | Tout profil connecté | Oui | Oui | `thread` optionnel | Fil absent : liste/état vide, sans crash |
| 20 | `/poles` | Auth | Enacchef | Oui | Oui | — | Refus → dashboard |
| 21 | `/poles/:poleId` | Auth | Hérite de Pôles | Oui | Oui | `poleId` | Erreur/introuvable du gateway |
| 22 | `/projects` | Auth | Enacchef | Oui | Oui | — | Refus → dashboard |
| 23 | `/projects/:projectId` | Auth | Hérite de Projets | Oui | Oui | `projectId` | Erreur/introuvable du gateway |
| 24 | `/events` | Auth | Tout profil connecté | Oui | Oui | — | États loading/empty/error distincts |
| 25 | `/events/:eventId` | Auth | Hérite d’Événements | Oui | Oui | `eventId` | Erreur/introuvable du gateway |
| 26 | `/alumni` | Auth | Alumni ou leadership/responsable | Oui | Oui | — | Refus → dashboard |
| 27 | `/alumni/:profileId` | Auth | Hérite d’Alumni | Oui | Oui | `profileId` | Erreur/introuvable du gateway |
| 28 | `/gamification` | Auth | Actif non alumni | Oui | Oui | — | États loading/empty/error distincts |
| 29 | `/academy` | Auth | Tout profil connecté | Oui | Oui | — | États loading/empty/error distincts |
| 30 | `/academy/courses/:courseId` | Auth | Hérite d’Academy | Oui | Oui | `courseId` | Erreur/introuvable du gateway |
| 31 | `/academy/admin` | Auth | Administrateur uniquement | Oui | Oui | — | Refus → dashboard |
| 32 | `/archives` | Auth | Tout profil connecté | Oui | Oui | — | États loading/empty/error distincts |
| 33 | `/archives/items/:archiveId` | Auth | Hérite d’Archives | Oui | Oui | `archiveId` | Erreur/introuvable du gateway |
| 34 | `/archives/projects/:projectId` | Auth | Hérite d’Archives | Oui | Oui | `projectId` | Erreur/introuvable du gateway |
| 35 | `/archives/hall-of-fame/:entryId` | Auth | Hérite d’Archives | Oui | Oui | `entryId` | Erreur/introuvable du gateway |
| 36 | `/impact` | Auth | Enacchef | Oui | Oui | — | Refus → dashboard |
| 37 | `/impact/records` | Auth | Hérite d’Impact | Oui | Oui | — | États loading/empty/error distincts |
| 38 | `/impact/records/:impactRecordId` | Auth | Hérite d’Impact | Oui | Oui | `impactRecordId` | Erreur/introuvable du gateway |

## 5. Responsive

Viewports audités : `375×812`, `390×844`, `768×1024`, `1366×768`, `1440×900`.

La matrice combine le nouveau point d’entrée de recette et les suites spécialisées existantes pour couvrir écran public, dashboard, listes denses, fiches, formulaires, feed, chat à deux panneaux, centres opérationnels et écrans éditoriaux. Login est testé sur les cinq viewports. Le zoom texte proche de 200 % couvre Login et son formulaire de demande de compte, Dashboard, Chat, Finance, Hall of Fame et Academy admin. Les blocages reproduits sur Dashboard et la fiche Academy ont été corrigés par adaptation locale de layout, sans redesign.

## 6. Deep-links

Le routeur accepte le chargement direct des routes dynamiques de tâches, documents, pôles, projets, événements, alumni, cours Academy, enregistrements Impact et trois familles Archives. Les tests spécialisés existants couvrent les données valides et absentes avec gateways mémoire ; la recette ajoute la vérification de déclaration, d’héritage de garde et de fallback. Les accès refusés redirigent sans écran blanc ; les chemins inconnus affichent « Page introuvable » et un retour vers l’accueil.

## 7. Navigation desktop/mobile

Sur desktop, le drawer reste scrollable, la route active est identifiable, les badges et la déconnexion restent accessibles, et le shell ne réduit pas le contenu à une largeur bloquante.

Sur mobile, le drawer demeure le catalogue complet des routes autorisées. La barre basse affiche les destinations principales et remplace son cinquième emplacement par la route secondaire courante lorsqu’elle est autorisée. Les cas `/events` à 390 px et `/finance` à 375 px prouvent que la route courante reste sélectionnée au lieu de sélectionner « Accueil » à tort.

## 8. Accessibilité

- Les champs importants conservent leurs labels et les erreurs restent associées au formulaire.
- Les bascules de mot de passe exposent désormais un tooltip dynamique « Afficher/Masquer le mot de passe » dans connexion, récupération et demande de compte.
- Les actions Chat ambiguës de fermeture de réponse et de recherche de membres ont un tooltip explicite.
- Les boutons importants utilisent les tailles tactiles Material ; aucun rétrécissement bloquant n’a été constaté sur les scénarios mobiles.
- Les actions sensibles restent textuelles et confirmées dans les suites de module ; aucune sémantique décorative superflue n’a été ajoutée.

## 9. Loading / empty / error

Les suites Dashboard, Tasks, Finance, Posts, Chat, Events, Documents, Academy, Impact et Archives distinguent les états chargement, vide et erreur et utilisent des gateways mémoire. Les erreurs ne deviennent ni un succès ni un dataset de démonstration. Les fiches dynamiques rendent un état d’échec/introuvable lorsque leur identifiant n’est pas résolu. Les retry existants restent disponibles lorsque le module le prévoit.

## 10. Permissions

Les tests transversaux exercent 13 profils déterministes et vérifient les helpers `visibleRoutesFor` et `canAccessPath`. Les flags objet (`can_manage`, `can_validate`, `can_edit`, etc.) restent l’autorité UX lorsqu’ils existent. La recette ne reproduit pas la politique backend.

Le défaut Academy admin a été corrigé : le point d’entrée et la route directe `/academy/admin` sont maintenant réservés à l’administrateur. Les responsabilités locales ne confèrent pas automatiquement de droits globaux, Finance ne donne pas de droits membres/présence, et Alumni reste hors des opérations internes.

## 11. Actions sensibles

Les suites fonctionnelles existantes couvrent confirmation, état submitting, blocage du double-submit, conservation du formulaire en erreur et mutation unique pour les actions de suppression, rejet, validation, archivage, retrait de membre, changement de leadership, clôture/annulation et décision recrutement. La recette n’a révélé aucune nouvelle mutation double ou commande sensible exposée hors rôle après la correction Academy.

## 12. Humanisation

Les valeurs utilisateur Archives/Hall of Fame, Academy et Recrutement ont été revues. Les types de document et de distinction, les statuts d’archive inconnus, les catégories/roles Academy et les libellés de stabilité Recrutement sont humanisés. Les chaînes utilisateur mal encodées dans Auth, Documents, Members, Posts et Recrutement ont été corrigées. Les normaliseurs conservent volontairement certaines variantes mal encodées comme entrées de compatibilité, sans les afficher.

## 13. Données demo/fallback

Le scan de `frontend/lib/` n’a trouvé aucun dataset silencieux nommé `_demo`, `demoData`, `mockData`, `fakeData`, `fixture`, `hardcoded` ou `sampleData`. Les occurrences légitimes de fallback restent des comportements techniques, placeholders ou valeurs contractuelles et ne simulent pas des données serveur. Academy, Impact et Archives restent alimentés par leurs gateways, sans progression ni historique local fictif.

## 14. Performance perçue

Aucun fetch manifeste déclenché depuis un `build`/`itemBuilder`, N+1 évident, timer dupliqué ou `Timer.periodic` non annulé n’a été reproduit. Les surfaces qui pollent annulent leur timer dans `dispose`. Les listes importantes utilisent les primitives scrollables/lazy existantes. Le chargement du cache utilisateur Academy est désormais non bloquant par rapport au chargement du cours.

Mesure du build web release :

- taille totale : 49 306 775 octets, soit 47,02 Mio, 67 fichiers ;
- plus gros artefact JS/WASM : `canvaskit/canvaskit.wasm`, 7 229 467 octets, soit 6,89 Mio ;
- artefact applicatif : `main.dart.js`, 4 781 182 octets, soit 4,56 Mio.

Principaux fichiers supérieurs à 500 Kio :

| Fichier | Octets |
|---|---:|
| `canvaskit/canvaskit.wasm` | 7 229 467 |
| `canvaskit/chromium/canvaskit.wasm` | 5 760 502 |
| `canvaskit/skwasm_heavy.wasm` | 5 172 643 |
| `main.dart.js` | 4 781 182 |
| `canvaskit/experimental_webparagraph/canvaskit.wasm` | 4 138 344 |
| `canvaskit/skwasm.wasm` | 3 580 947 |
| `canvaskit/wimp.wasm` | 3 514 226 |
| symboles CanvasKit/Skwasm/Wimp | 1 004 464 à 1 801 519 |
| `assets/NOTICES` | 1 367 891 |
| `assets/assets/img/logo_enactus_esp.png` | 831 057 |

Ces éléments sont documentés sans compression ni changement d’asset dans cette passe.

## 15. Anomalies trouvées

| ID | Sévérité | Surface | Reproduction | Cause | Correction | Test associé | Statut |
|---|:---:|---|---|---|---|---|---|
| UIFA-NAV-001 | P1 | Shell mobile | Ouvrir `/events` à 390 px ou `/finance` à 375 px : Accueil apparaissait sélectionné | La barre basse ignorait les routes secondaires autorisées | Destination secondaire courante injectée dans le cinquième emplacement | `navigation mobile et responsive` | Corrigé |
| UIFA-A11Y-001 | P2 | Login et Chat | Inspecter les boutons icône de mot de passe, réponse et recherche | Actions iconographiques sans libellé accessible explicite | Tooltips dynamiques et contextuels | `login responsive et accessibilité`, `polling et actions accessibles` | Corrigé |
| UIFA-HUM-001 | P2 | Archives, Hall of Fame, Academy | Injecter un type/statut/role en snake_case | Présentation directe ou humanisation incomplète | Getters et helpers de libellés humains | `humanisation et absence de données démo` | Corrigé |
| UIFA-COPY-001 | P1 | Recrutement et messages de service | Afficher les libellés concernés | Chaînes utilisateur contenant un encodage cassé | Microcopy française corrigée localement | `les libellés recrutement ne contiennent aucun encodage cassé` | Corrigé |
| UIFA-PERM-001 | P1 | Academy admin | Utiliser un membre connecté puis accéder au bouton ou à `/academy/admin` | Garde UX absente et bouton visible à tout utilisateur chargé | `canManageAcademy`, garde de route et visibilité admin | `Gestion Academy est réservée à l’administrateur` | Corrigé |
| UIFA-RESP-001 | P1 | Fiche Academy | 390×844, text scale 2 | En-tête horizontal à hauteur/largeur insuffisante | En-tête responsive empilé sur largeur/zoom contraints | `Academy admin reste exploitable sur mobile à zoom 200 %` et test fiche ciblé | Corrigé |
| UIFA-RESP-002 | P1 | Dashboard | 390×844, text scale 2 | Grilles KPI/actions et hauteur de métrique fixes | Une colonne et hauteur adaptative au grand texte | `Dashboard reste exploitable sur mobile à zoom 200 %` | Corrigé |
| UIFA-NOTE-001 | P3 | Formulaire Academy admin | Ouvrir la création/édition de cours avec un scope pôle/projet | Le contrat n’expose que les IDs et aucun référentiel convivial n’est injecté dans ce formulaire | Documenté ; pas de chantier transverse dans cette passe | Revue statique | Résiduel non bloquant |

Décompte : P0 = 0, P1 = 5, P2 = 2, P3 = 1.

## 16. Corrections appliquées

- `UIFA-NAV-001` : sélection et accessibilité des routes secondaires dans la navigation mobile.
- `UIFA-A11Y-001` : tooltips des actions importantes ambiguës.
- `UIFA-HUM-001` : humanisation Archives/Hall of Fame/Academy et valeurs inconnues sûres.
- `UIFA-COPY-001` : correction de microcopy et d’encodage utilisateur.
- `UIFA-PERM-001` : restriction UX de l’administration Academy aux administrateurs.
- `UIFA-RESP-001` : en-tête de cours Academy utilisable en mobile à zoom 200 %.
- `UIFA-RESP-002` : Dashboard utilisable en mobile à zoom 200 %.

Les changements visibles sont limités à la sélection correcte de navigation, au wrapping responsive et aux libellés corrigés. Ils ne constituent pas une refonte et aucune capture validée n’a été régénérée.

## 17. Anomalies résiduelles

`UIFA-NOTE-001` est conservée en P3 : les champs de scope du formulaire Academy admin manipulent encore des identifiants techniques. Une correction complète demande un sélecteur alimenté par les référentiels pôles/projets et une décision d’intégration transverse. Masquer ou transformer localement les valeurs empêcherait l’administration correcte ; ce chantier n’a donc pas été ouvert pendant la recette finale.

## 18. Blockers production

Aucun `BLOCKER_EXTERNAL` et aucun défaut frontend P0/P1 résiduel. La note P3 Academy admin n’empêche pas les parcours actuels et reste limitée à une surface d’administration.

## 19. Résultats tests / analyze / build

- Nouveau point d’entrée : `frontend/test/ui_final_acceptance_test.dart`, 39 tests.
- Suite complète : **416/416 tests réussis** (`flutter test --no-pub --reporter expanded -j 1 --timeout 45s`).
- Analyse : **aucune erreur** (`flutter analyze --no-pub`).
- Build : **réussi** (`flutter build web --release --no-pub --pwa-strategy=none`).
- Format : 18 fichiers Dart vérifiés, 0 changement après formatage.
- Réseau réel : aucun.
- Mutations réelles : aucune.

## 20. Verdict

**PASS_WITH_NON_BLOCKING_NOTES**

La recette ne laisse aucun défaut P0/P1 ni blocker externe. Les 377 tests existants sont préservés et les 39 nouveaux tests portent le total à 416. La seule note résiduelle est le P3 d’ergonomie du scope Academy admin, explicitement hors chantier local sûr.

## 21. Validation visuelle finale

La matrice finale a été produite avec un harness Flutter widget temporaire, les écrans applicatifs existants, le vrai `ThemeData` EnactSpace et le vrai `AppShell`. Les scénarios utilisent des utilisateurs synthétiques par rôle et des gateways/transports mémoire déterministes. Poppins et MaterialIcons ont été chargées dans le harness, sans navigateur intégré, API réelle, seed ni mutation.

Les huit captures validées sont :

| Capture | Profil | Route | Viewport |
|---|---|---|---:|
| `01_login_mobile_375x812.png` | Public | `/login` | 375×812 |
| `02_member_mobile_navigation_390x844.png` | Membre | `/dashboard` | 390×844 |
| `03_admin_dashboard_desktop_1440x900.png` | Administrateur | `/dashboard` | 1440×900 |
| `04_local_manager_projects_desktop_1366x768.png` | Chef de projet | `/projects/project-horizon` | 1366×768 |
| `05_finance_role_desktop_1366x768.png` | Financier | `/finance` | 1366×768 |
| `06_chat_tablet_768x1024.png` | Membre | `/chat` | 768×1024 |
| `07_editorial_desktop_1440x900.png` | Chef de projet autorisé | `/archives` | 1440×900 |
| `08_deep_link_mobile_390x844.png` | Chef de projet autorisé | `/archives/hall-of-fame/moment-final` | 390×844 |

Le deep-link Hall of Fame a été rendu directement avec son shell authentifié, son contenu stable et sa destination parent accessible, sans UUID visible. Un spot check à `TextScaler.linear(2.0)` a couvert Login et cette fiche dense : aucun overflow bloquant n’a été détecté. Le contrôle sémantique ciblé a confirmé les labels des champs Login, les tooltips des actions icon-only critiques, la compréhension de la navigation mobile et l’absence d’action destructive silencieuse visible.

La revue 8/8 confirme le thème EnactSpace, les icônes Material rendues sans glyphe manquant, l’absence de palette Material violette dominante, de snake_case, d’enum métier brut, d’UUID, de texte backend brut, de fallback démo, de harness visible, de scroll horizontal obligatoire et de RenderFlex overflow. Les données montrées proviennent uniquement des scénarios mémoire explicitement déterministes ; aucune donnée distante n’est revendiquée.

Tous les compteurs de mutations réelles restent à zéro et `application_mutation_performed=false`. La trace détaillée, les marqueurs atteints et les SHA-256 sont consignés dans `docs/design/screenshots/ui_final_acceptance_v1/capture_state_results.json`.

Résultat visuel final : **PASS_WITH_NON_BLOCKING_NOTES**, avec `VISUAL_BLOCKER_FOUND=false`.
