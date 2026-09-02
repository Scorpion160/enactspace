# Audit UI/UX exhaustif - EnactSpace

Date d'audit : 2026-07-22  
Portee : frontend Flutter de `Scorpion160/enactspace`, commit `7f0a9fd`.  
Nature : analyse uniquement. Aucun fichier applicatif, asset, backend ou configuration n'a ete modifie. Aucun commit n'est cree par cet audit.

## 1. Resume executif

EnactSpace a deja une base produit inhabituelle pour une application associative : elle couvre reellement le pilotage des membres, la communication, les operations, la finance, les presences, le recrutement, l'apprentissage, l'impact et la memoire collective. La marque est visible, le jaune Enactus et le noir sont employes avec constance, et les parcours publics de connexion et de candidature sont soignes.

Le produit ne manque donc pas de fonctionnalites ; il manque d'une direction d'interface suffisamment singuliere et d'un systeme de composants suffisamment structure pour faire sentir une meme experience, ecran apres ecran. La plupart des ecrans construisent localement leurs propres en-tetes, cartes, etats vides, filtres et modales. Ils reprennent les memes ingredients Material (carte blanche, grand rayon, icone Material, texte gras, bandeau sombre) avec des variations. Cela donne une impression de tableau de bord genere, propre mais interchangeable, et rend les futures evolutions couteuses.

Le risque le plus urgent est la recette responsive de la connexion : le rendu public observe a `375 x 812` et a `1440 x 900` montre un cadrage visuellement coupe du contenu de connexion, alors que `768 x 1024` est lisible et equilibre. Cette divergence entre rendu de production et logique du code source doit etre reproduite et expliquee avant toute refonte. Aucune erreur console n'a ete observee sur les ecrans publics testes.

Priorite recommandee : ne pas commencer par recolorer les ecrans. D'abord stabiliser les fondations (tokens, composants, navigation, etats), puis traiter les parcours quotidiens membre/responsable, enfin differencier les univers plus editoriaux (Academy, Impact, Archives, Hall of Fame).

## 2. Methode et limites de preuve

L'audit combine :

- lecture de l'architecture Flutter, des routes, du theme, du shell, des widgets et des assets ;
- inventaire de 25 fichiers d'ecrans et de leurs patrons de layout ;
- rendu de production de `https://enactspace.kerunjombor.net` aux viewports `375 x 812`, `768 x 1024` et `1440 x 900` ;
- test public de `/#/login` et `/#/application-tracking` ;
- analyse statique des ecrans authentifies, des permissions et des comportements responsive declares dans le code.

Les ecrans authentifies n'ont pas ete ouverts : aucun compte de test ni autorisation d'utiliser un compte reel n'a ete fourni. Les constats les concernant sont donc des constats de code et doivent etre confirmes par une recette avec des comptes de test Admin, Team Leader, SG, Finance, chef de pole/projet, membre et alumni. Le navigateur de production ne remontait aucune erreur/warning console sur les deux parcours publics. L'analyse Flutter complete a depasse 30 secondes dans l'environnement d'audit ; son resultat n'est donc pas utilise comme preuve de qualite visuelle.

## 3. Cartographie de l'interface et des parcours

### Routes et ecrans

| Domaine | Route / ecran | But principal | Public principal |
| --- | --- | --- | --- |
| Acces | `/splash`, `/login`, `/application-tracking` | Entree, connexion, candidature publique | Tous, candidat pour le suivi |
| Pilotage | `/dashboard` | Vue quotidienne et alertes | Tous selon le role |
| Communaute | `/posts`, `/chat`, `/notifications` | Fil, messages, alertes | Tous, scope selon permissions |
| Operations | `/tasks`, `/attendance`, `/poles`, `/projects`, `/events` | Travail, pointage, equipes et execution | Membres/responsables selon le module |
| Ressources | `/documents`, `/finance`, `/members`, `/recruitment` | Connaissances, argent, annuaire, recrutement | Responsables ou membres habilites |
| Parcours | `/gamification`, `/academy`, `/impact`, `/alumni`, `/archives` | Progression, apprentissage, impact et memoire | Selon role et statut |

Les ecrans QR et NFC sont exposes depuis Presence mais n'ont pas de routes shell distinctes pour chaque sous-parcours. Les profils personnels, parametres, organigramme, roles/permissions, medias et administration ne possedent pas de routes dediees dans [`app_router.dart`](../../frontend/lib/app/app_router.dart). Ils peuvent etre proposes par des dialogues ou des sous-vues, mais ils ne sont ni decouvrables, ni auditables, ni partageables par URL comme espaces autonomes.

### Roles visibles dans le shell

`UserExperience.visibleRoutesFor` etablit une separation utile : alumni limite, membre recentre sur la vie quotidienne, responsables avec acces progressif aux operations. C'est une bonne fondation produit. En revanche, la carte mentale du role n'est pas exposee dans la navigation : le menu presente des modules, pas un objectif courant ni la raison d'un acces/refus. Les responsabilites “Enacchef” agregent plusieurs situations metier tres differentes (pole, projet, SG, finance) dans une meme logique de visibilite.

| Role | Experience declaree | Risque UX a verifier |
| --- | --- | --- |
| Administrateur / Team Leader | Vue globale, membres, finance, presence, recrutement, impact | Menu tres long et priorites quotidiennes diluees |
| SG | Presence, membres, recrutement, coordination | Frontiere entre administration et pilotage insuffisamment nommee |
| Financier | Finance et tableau de bord | Risque de navigation et de dashboard encore trop generalistes |
| Chef/adjoint de pole ou projet | Operations, membres restreints, presence, poles/projets | Le perimetre reel (son pole/projet) doit etre visible partout |
| Enacteur/enactrice | Posts, chat, taches, documents, academy, archives, evenements | Navigation mobile limitee a cinq destinations, le reste devient moins decouvrable |
| Alumni | Actualites, chat, events, academy, archives, alumni | Experience specifique declaree mais univers visuel a confirmer |

## 4. Inventaire du design system actuel

### Fondations declarees

Le theme global est volontairement court dans [`app_theme.dart`](../../frontend/lib/app/app_theme.dart) : jaune `#FFC629`, noir profond `#101820`, texte `#151515`, fond `#F7F7F3`, carte blanche. Poppins est charge depuis Google Fonts. Le theme definit AppBar, Card, champs et ElevatedButton, avec rayons dominants `14`, `18` et `24` px.

Forces : le contraste noir/jaune est identitaire, le fond casse evite le blanc clinique, et Poppins donne un ton etudiant, net et accessible.

Limites :

- pas de tokens explicites pour les espacements, elevations, tailles de texte, rayons, couleurs semantiques, etats focus ou surfaces alternatives ;
- aucun theme sombre declare, alors que le noir est central et que l'usage mobile quotidien se prete a cette option ;
- le `ColorScheme.fromSeed` coexiste avec de nombreuses couleurs directes ;
- 224 occurrences de couleurs directes et 139 occurrences de rayons frequents ont ete reperees dans le frontend ;
- les statuts s'appuient localement sur vert, rouge, orange, bleu et violet Material sans langage semantique commun ;
- les cartes ont le meme rayon genereux quelle que soit leur fonction (contenu, outil, alerte, bloc editorial, action), d'ou une silhouette uniforme.

### Composants et patrons

| Element | Etat | Observation |
| --- | --- | --- |
| Navigation | `AppShell`, menu lateral et `NavigationBar` mobile | Solide structurellement, mais trop de destinations et aucun espace “Plus” explicite sur mobile |
| Header | Implementations locales `_HeaderActions`, `_Hero`, `_TopBar` | Meme besoin reimplemente dans de nombreux modules |
| Carte | `Card` theme + containers locaux | Cohesion de base, hierarchie faible entre carte de donnee, carte de commande et carte narrative |
| Formulaire | `InputDecorationTheme` + champs locaux | Bonne base, erreurs et aides varies selon l'ecran |
| Feedback | SnackBar, banners, textes vides, loaders circulaires | Fonctionnel mais heterogene, peu de skeletons ou feedback progressif |
| Icones | Material Icons quasi exclusivement | Lisible et economique, mais peu distinctif et parfois trop “dashboard Flutter” |
| Images | Logos, prix, icones et splash | Assets de marque existants et sous-exploites dans les ecrans operationnels |
| Graphiques | Visualisations codees dans les ecrans, pas de bibliotheque dediee | Risque de coherence faible et de maintenance lourde |

## 5. Diagnostic de l'aspect generique, template ou artificiel

L'impression ne vient pas d'un seul choix graphique. Elle vient de l'addition de comportements repetes :

1. **Carte blanche arrondie + icone Material + titre gras + sous-texte gris.** Ce motif apparait dans les operations, profils, finance, documents et ecrans publics. Sans grammaire fonctionnelle plus nuancee, tout a le meme poids.
2. **Bandeau noir hero reutilise.** Dashboard, projets, poles, presence, Academy et Impact s'appuient sur des blocs noirs tres voisins. Le noir Enactus devient un decor plutot qu'un signal reserve aux moments de pilotage ou d'identite.
3. **Boutons, chips et badges locaux.** Les memes intentions sont codees par module, avec rayons, tailles, contrastes et vocabulaire non strictement alignes.
4. **En-tetes de page trop similaires.** Plusieurs fichiers importants contiennent leur propre `_HeaderActions` : projets, poles, evenements, alumni. La repetition est visible a l'utilisateur et technique dans le code.
5. **Densite de surfaces.** Les ecrans riches semblent composer beaucoup d'informations via cartes imbriquees et `Wrap`, sans toujours distinguer contenu consultatif, decision urgente et action productive.
6. **Iconographie sans vocabulaire proprietaire.** Les Material Icons communiquent bien, mais ne racontent ni Enactus ESP, ni l'ambition locale, ni la progression collective.
7. **Microcopy et labels parfois generiques.** “Actualiser”, “Aucun ...”, “Erreur de chargement”, “Indisponible” sont corrects mais ne guident pas le prochain geste et ne construisent pas une voix communautaire constante.

Ce ne sont pas des defauts esthetiques superficiels : ils reduisent la memorisation de l'outil, ralentissent le balayage visuel et font perdre le sentiment d'appartenir a un espace commun vivant.

## 6. Audit ecran par ecran

Priorites : P0 = bloquant d'usage ou de recette, P1 = majeur, P2 = moyen, P3 = mineur.

| Ecran | Objectif / action | Forces a preserver | Problemes et preuves | Priorite |
| --- | --- | --- | --- | --- |
| Splash | Lancer la marque | Assets portrait et logos dedies existent | Ecran tres court, aucun controle de performance percue observe | P2 |
| Connexion | Entrer, recuperer l'acces, rejoindre, candidater | Parcours tres riche, champ de mot de passe, actions visibles, message de validation | Production a `375 x 812` et `1440 x 900` : texte et carte visuellement coupes; a `768 x 1024` le rendu est bon. Source : `LoginScreen` lignes 63-84 et `_LoginPanel` lignes 348-497 | P0 |
| Suivi candidature | Suivre un dossier | Ecran public clair, carte de formulaire, recapitulatif sombre, tres bon rendu mobile observe | Peut sembler deconnecte du reste par son logo Enactus ESP circulaire et ses rayons locaux; la suite des etapes n'a pas ete testee sans code reel | P2 |
| Dashboard | Prioriser ma journee | Adaptation de titre par role, grilles et alertes, `RefreshIndicator` | Hero tres “cockpit generique”; nombreuses cartes et panneaux risquent de niveler les urgences. Source : `dashboard_screen.dart` lignes 50-190, 215+ | P1 |
| Membres | Chercher, filtrer, consulter et importer | Fonction metier tres complete, import separable | Fichier de 2517 lignes : concentration de liste, detail, actions et import. Risque de densite et d'actions reservees peu differenciees | P1 |
| Presence / detail session | Creer, suivre et justifier les pointages | QR/NFC, statuts et journal repondent au metier | Deux tres gros ecrans (1798 et 1766 lignes), nombreux layouts locaux; la lisibilite des actions SG/chef/membre doit etre recetee sur mobile | P1 |
| Taches | Organiser et agir | Filtres, deadlines, assignes, etats vides prevus | Risque de tableau de bord secondaire avec filtres et cartes; etat “Aucune tache” peu orientant | P1 |
| Finance | Cotisations, comptes, paiements | Domaine sensible, etats vides et feuille mobile money | Ecran de 2073 lignes, nombreuses actions et donnees heterogenes; besoin d'une hierarchie de risque et de droits tres lisible | P1 |
| Documents | Trouver et rattacher des ressources | Recherche, rattachements, etats vide/erreur | Iconographie fichier/carte standard, poids des metadonnees a verifier sur petit ecran | P2 |
| Recrutement | Campagnes, besoins, candidatures, decisions | Parcours metier profond, layout adaptatif declare | 2993 lignes, filtrage et formulaires complexes. Le public et le pilotage interne devraient etre deux univers lisibles, pas seulement deux etats de la meme surface | P1 |
| Posts / communication | Publier, reagir, commenter | Medias, reactions, filtres pole/projet et publication officielle | Rafraichissement periodique, stats chargees post par post et riche form de composition; risque de fil charge et moins immediat qu'un reseau social | P1 |
| Chat | Echanger, media, groupe, epingles | Effort remarquable : cache local, typing, presence, reactions, statuts, pieces jointes, epingles | 4655 lignes dans un seul ecran. UX WhatsApp visee mais forte complexite locale; sous-ecrans, permissions et responsive doivent etre recetes avec vraies conversations | P1 |
| Notifications | Voir et agir | Badges shell et routage depuis notification | Polling shell 12 s et feedback SnackBar; risque de bruit, d'interruption et de duplication avec le fil/chat | P2 |
| Poles | Piloter les poles | Creation, membres, objectifs, stats, discussion envisagees | Hero/actions proches des projets et evenements, identite de pole insuffisamment specifique dans l'architecture de composants | P2 |
| Projets | Piloter projet, budget, equipe, livrables | Perimetre metier tres riche | 2565 lignes, panneaux, statut et dialogues locaux. Le projet doit devenir un espace de travail reconnaissable, pas une liste de cartes similaires | P1 |
| Evenements | Organiser, inscrire, rapporter | Participants, budget et documents presentes | Formulaire avec largeur fixe `480` reperee; possibilite de compression dans une modalite mobile | P2 |
| Alumni | Mentorat, opportunites, annuaire | Distinction de route et de contenu | Fichier 1689 lignes; le statut alumni est limite dans le menu, mais l'univers visuel specifique doit etre teste en session | P2 |
| Gamification | Voir et attribuer points/badges | Logique de filtres membre/pole et badges | Risque de fonction administrative plutot que reconnaissance motivante; aucune direction visuelle ludique propre declaree | P2 |
| Academy | Apprendre et mettre en pratique | Sous-domaines cours/cas, grilles responsives declarees | 1782 lignes et plusieurs composants locaux. Potentiel editorial eleve, actuellement susceptible de ressembler a un dashboard de ressources | P2 |
| Impact | Comprendre performance et impact | Dashboard dedie, classements et visualisations | Cartes/statistiques encore dependantes de patterns generiques; les chiffres doivent raconter une progression humaine et de projet | P2 |
| Archives / Hall of Fame | Conserver et valoriser la memoire | Contenu ideal pour photos de prix, projets et recits | L'ecran existe mais le Hall of Fame n'a pas de route dediee. Danger de le reduire a une liste documentaire sans force editoriale | P1 |
| NFC / QR | Pointer et enrôler | Besoin specifique et retours d'indisponibilite | Parcours materiel a receter sur terminal reel; les messages NFC doivent etre comprehensibles hors jargon | P2 |

## 7. Navigation et architecture de l'information

Le shell adopte un seuil desktop a `900 px`, un menu lateral de `284 px` et une barre mobile de cinq destinations. Cette separation est saine. La barre mobile choisit les cinq premieres routes autorisees et remplace la derniere si la route courante est absente. Le mecanisme evite une navigation sans etat, mais son cout est fort : des modules importants peuvent disparaitre sans point d'entree visible, et le terme “Plus” n'existe pas.

La navigation desktop comporte 18 entrees classees en trois sections. Elle est trop longue pour un outil quotidien et accorde une importance visuelle semblable a Communication, Gamification, Academy, Impact, Archives, Finance et Recrutement. Pour un membre, l'ordre devrait repondre a une journee reelle : ce que je dois faire, ce qui me concerne, ce qui se passe, puis le reste. Pour un responsable, la navigation devrait d'abord exprimer le perimetre qu'il pilote.

Points a preserver : filtrage des routes par role, badges de messages/alertes/taches, titre de page et deconnexion accessibles dans le shell.

## 8. Responsive et rendu observe

| Viewport | Ecran observe | Resultat | Preuve / interpretation |
| --- | --- | --- | --- |
| `375 x 812` | Connexion | A traiter avant release | Carte et texte paraissent rognés sur la droite dans le rendu de production, sans overflow DOM ni erreur console. Reproduction visuelle a conserver. |
| `768 x 1024` | Connexion | Bon | Marque mobile, carte, champs et actions sont centrees et lisibles. |
| `1440 x 900` | Connexion | A traiter avant release | Le panneau de connexion est visuellement decale/coupe vers la droite dans le rendu de production. |
| `375 x 812` | Suivi candidature | Bon | Top bar, carte, champs et panneau de parcours tiennent dans la largeur. |
| Source authentifie | Dashboard et modules | A confirmer | Nombreux `LayoutBuilder`, `Wrap`, grilles et breakpoints existent, mais plusieurs largeurs fixes sont presentes (`360`, `480`, `280`, `260`, `220`, `150` selon les modules). |

Le code prend largement en compte des seuils a `420`, `480`, `560`, `700`, `820`, `900`, `920`, `1040` et `1060 px`. Cette granularite traduit une intention responsive, mais elle est diffusee par module au lieu d'etre une strategie partagee. Les comportements redeviennent difficiles a predire et a receter lorsque l'ecran change de contexte.

## 9. Accessibilite

### Points positifs

- champs avec labels et icones dans les parcours publics ;
- tooltips dans une partie du chat et de la finance ;
- `overflow: TextOverflow.ellipsis` frequemment employe pour prevenir certains debordements ;
- contrastes forts noir/jaune/blanc pour les actions primaires ;
- presence de boutons texte pour plusieurs actions secondaires.

### Ecarts et risques

- aucune occurrence de `Semantics` n'a ete reperee dans le frontend : les icones, badges, images de prix et graphiques n'ont pas de semantique explicite ;
- les tooltips sont rares hors Chat/Finance ; les IconButton d'actions locales peuvent etre ambigus pour lecteur d'ecran et clavier ;
- le theme ne formalise pas les etats focus, hover, desactive, erreur et succes ;
- la couleur est souvent un signal principal pour danger/statut sans texte systematique ;
- le choix d'une police distante Google Fonts et le manque de mode sombre doivent etre evalues avec connexion lente, luminosite et sensibilite visuelle reelles ;
- les cibles et les espaces de tableaux/graphes doivent etre verifies avec clavier, zoom 200 % et lecteur d'ecran.

## 10. Ton, contenu et micro-interactions

Le ton public est globalement chaleureux et clair : “Espace interne des Enacteurs”, “Votre parcours, sans compte membre”, “Guide debutant”. Il devient plus administratif dans les modules : “Aucun ...”, “Erreur de chargement”, “Indisponible”. Le melange est logique mais pas encore gouverne par une voix editoriale unique.

Les actualisations periodiques (12 s pour certaines metriques shell, 20 s pour posts, 12 s pour chat, 45 s pour navigation) montrent la volonte de faire vivre l'app. Sans systeme de priorite, elles peuvent cependant provoquer des micro-changements, du reseau et un sentiment de bruit. Les loaders sont majoritairement circulaires ; l'absence de skeletons generalises rend les ecrans denses moins previsibles au chargement. Les SnackBars apportent du feedback mais leur apparence, leur couleur et leur hierarchie sont definies localement.

## 11. Performance percue et dette visuelle

Les assets declares representent environ 4,1 Mo, dont un logo Enactus ESP de 811 Ko et plusieurs logos/prix. C'est acceptable comme point de depart mais merite une recette sur reseau mobile. `PostsScreen` charge les statistiques avec un `Future.wait` sur chaque publication ; `AppShell` sollicite plusieurs metriques et dispose de deux timers. Le chat et les ecrans operationnels tres longs concentrent beaucoup de state et de widgets dans une seule unite.

La dette visuelle est donc aussi une dette de performance percue : plus le layout et les etats sont recodes localement, plus les chargements, erreurs et mises a jour deviennent differents d'un ecran a l'autre. La dette ne signifie pas que le produit est fragile ; elle signifie que chaque nouveau module risque d'ajouter une variation de plus au lieu d'enrichir un langage commun.

## 12. Registre priorise des problemes

| ID | Ecran / composant | Gravite | Preuve | Impact utilisateur | Cause probable | Piste de correction a valider | Effort |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UX-01 | Connexion production | Bloquant | Rendu coupe a 375 et 1440, rendu correct a 768 | Connexion peut sembler cassée, perte immediate de confiance | Ecart build/production/renderer ou contrainte de layout non recetee | Reproduire sur devices reels, verifier build deploye et canvas/layout avant toute refonte | S |
| UX-02 | Shell mobile | Majeur | Cinq destinations seulement, sans “Plus” | Modules autorises difficiles a retrouver | Priorisation implicite dans une liste trop grande | Concevoir une navigation secondaire mobile explicite et testee par role | M |
| UX-03 | Design system | Majeur | 224 couleurs directes, 139 rayons recurrents | Incoherence, maintenance lente, impression template | Tokens et composants partages insuffisants | Formaliser fondations et composants sans changer le style initialement | L |
| UX-04 | Ecrans operations | Majeur | Membres 2517, projets 2565, recrutement 2993, chat 4655 lignes | Densite, regressions responsive, comportements varies | Ecrans monolithiques et UI locale | Decouper par surfaces UX et reutiliser des patterns approuves apres audit | L |
| UX-05 | Navigation desktop | Moyen | 18 entrees sur trois sections | Charge cognitive et priorites floues | Menu organise par modules, pas par intentions quotidiennes | Reclasser apres validation des jobs-to-be-done par role | M |
| UX-06 | Accessibilite | Majeur | Pas de `Semantics` detecte, tooltips ponctuels | Difficultes lecteur d'ecran, clavier, ambiguite icones | Accessibilite non systematisee | Ajouter une recette a11y puis des exigences de composants | M |
| UX-07 | Etats de chargement | Moyen | Loaders circulaires et SnackBars locaux | Incertitude pendant chargements longs | Absence de bibliotheque d'etats | Definir etats vide/erreur/loading par categorie de surface | M |
| UX-08 | Identite editoriale | Moyen | Assets de prix/logos existants, faible vocabulaire visuel transversal | EnactSpace peu memorisable hors connexion | Assets reserves a quelques ecrans | Definir quand employer recits, preuves d'impact, images et iconographie | M |
| UX-09 | Hall of Fame / profil / admin | Moyen | Pas de routes dediees dans router | Fonctionnalites moins decouvrables et liens non partageables | Sous-vues ou absence de surface autonome | Clarifier la carte de l'information avant implementation | M |
| UX-10 | Performance percue | Moyen | Polling multiple, chargements paralleles de stats | Variations et lenteur ressentie sur mobile | Data fetching et UI couples par ecran | Mesurer avant optimisation, afficher une progression coherente | M |

## 13. Quick wins a envisager (sans implementation)

1. Bloquer la release visuelle tant que UX-01 n'est pas reproduit/corrige sur 375, 390, 768, 1024, 1440 et 1920 px.
2. Normaliser la copie des etats vide, erreur, chargement et succes autour d'une voix EnactSpace unique et d'une action suivante explicite.
3. Ajouter une entree mobile “Plus” ou une feuille de navigation qui garantit l'acces aux modules autorises.
4. Definir une echelle unique de rayons, espacements, elevations et textes avant de retoucher les ecrans.
5. Donner un vrai statut au Hall of Fame, aux prix et a la memoire dans la navigation et les surfaces editoriales.
6. Ajouter une checklist de recette clavier, contraste, zoom et lecteur d'ecran a chaque ecran modifie.

## 14. Chantiers structurants et matrice impact x effort

| Chantier | Impact | Effort | Dependances |
| --- | --- | --- | --- |
| Stabilisation responsive publique + recette multi-device | Tres eleve | M | Build de production, devices reels |
| Tokens et bibliotheque de composants | Tres eleve | L | Decision de direction artistique |
| Refonte de l'information par role / mobile | Eleve | M | Interviews utilisateurs, permissions metier |
| Refactorisation progressive des ecrans monolithiques | Eleve | L | Bibliotheque de composants approuvee |
| Systeme d'etats et feedback | Eleve | M | Tokens semantiques, contrats API |
| Accessibilite structurelle | Eleve | M | Checklist et tests de terrain |
| Univers editoriaux Academy/Impact/Archives/Hall of Fame | Eleve | M | Direction artistique, contenus qualifiees |
| Optimisation performance percue | Moyen | M | Mesures de production et priorites data |

## 15. Trois directions artistiques conceptuelles

### A. Institutionnelle et premium

**Personnalite.** Sereine, precise, credible, orientee resultats et gouvernance.  
**Principes.** Peu de surfaces, hierarchie typographique forte, jaune reserve aux actions et decisions, noir reserve aux reperes majeurs.  
**Formes.** Grille rigoureuse, angles legerement adoucis, tableaux et timelines lisibles.  
**Couleurs.** Noir Enactus, jaune Enactus, ivoire tres leger, gris neutres et couleurs semantiques contenues.  
**Typographie.** Sans serif humaniste pour les donnees, Poppins reserve a la marque et aux titres courts.  
**Illustrations/icones.** Pictogrammes sobres et proprietaires, photos documentaires authentiques des projets.  
**Animations.** Courtes, fonctionnelles, sobrement echelonnees.  
**Meilleurs ecrans.** Finance, presence, recrutement, membres, impact, projets.  
**Avantages.** Confiance, lisibilite, durabilite.  
**Risques.** Peut devenir trop institutionnelle et perdre l'energie etudiante.

### B. Communautaire, humaine et energique

**Personnalite.** Accueillante, collective, active au quotidien.  
**Principes.** Priorite aux personnes, aux equipes, aux conversations et aux petites victoires visibles.  
**Formes.** Modules souples, piliers de contenu, avatars, timeliness, accents jaunes ponctuels, images de terrain.  
**Couleurs.** Noir/jaune Enactus avec vert de progression et bleu de confiance, en accents limites.  
**Typographie.** Poppins conservee pour l'energie, echelle plus claire entre conversation, information et action.  
**Illustrations/icones.** Icones arrondies coherentement dessinees, badges de contribution, photos de membres/projets.  
**Animations.** Feedback de reaction, passage d'etape, lecture et presence, jamais decoratifs.  
**Meilleurs ecrans.** Dashboard membre, chat, posts, Academy, gamification, alumni.  
**Avantages.** Forte adoption quotidienne et sentiment d'appartenance.  
**Risques.** Surcharge ou gamification artificielle si les donnees reelles ne portent pas le recit.

### C. Senegalaise contemporaine et technologique, sans folklore superficiel

**Personnalite.** Locale, ambitieuse, urbaine, creative et tournee vers l'impact.  
**Principes.** S'inspirer des rythmes, de la composition editoriale et de la pluralite des savoir-faire, pas plaquer des motifs decoratifs.  
**Formes.** Trames geometriques discretes, blocs editoriaux, rythme vertical, photos de terrain et artefacts de projet.  
**Couleurs.** Jaune Enactus comme ancrage, noir bleute, blancs chauds et deux accents seulement issus d'un travail de contenu valide par l'equipe.  
**Typographie.** Une sans serif tres lisible, titres affirmes, possibilite d'une seconde fonte d'accent testee pour les campagnes uniquement.  
**Illustrations/icones.** Photographie Enactus ESP, cartes d'impact, representations des projets et des prix reels.  
**Animations.** Transitions inspirees du rythme editorial, sans effets “ethniques” decoratifs.  
**Meilleurs ecrans.** Connexion, recrutement public, Archives, Hall of Fame, Impact, projets.  
**Avantages.** Memorisation forte et sentiment d'appartenance authentique.  
**Risques.** Appropriation superficielle si les choix ne sont pas co-concus avec les membres et appuyes sur du contenu reel.

## 16. Questions a soumettre a l'equipe avant toute refonte

1. Quelle est la premiere raison d'ouvrir EnactSpace pour chaque role, chaque jour ?
2. Quels trois modules doivent etre accessibles sans chercher sur mobile pour chaque role ?
3. La marque doit-elle privilegier la rigueur institutionnelle, la communaute active ou une synthese des deux ?
4. Quelles photos, projets, prix et recits Enactus ESP peuvent etre utilises de maniere durable et avec les droits adequats ?
5. Quel niveau de personnalisation par pole/projet est souhaitable sans fragmenter la marque ?
6. Le Hall of Fame est-il une vitrine publique, une archive interne, ou les deux ?
7. Quels indicateurs sont reellement utiles a un membre, a un chef et au Team Leader ?
8. Quels appareils et qualites de reseau representent les conditions d'usage reelles a l'ESP ?
9. Qui valide le vocabulaire francais, les termes Enactus et la voix inclusive de l'application ?
10. Quelle politique d'accessibilite minimale l'equipe veut-elle tenir pour tous les prochains modules ?

## 17. Plan de refonte recommande, par phases

1. **Phase 0 - Recette et mesure.** Corriger/valider les ruptures publiques, recueillir des sessions par role, mesurer chargement et completion des taches principales.
2. **Phase 1 - Fondations.** Valider une direction artistique, tokens, composants, etats, typographie, iconographie et regles responsive/a11y.
3. **Phase 2 - Coeur quotidien.** Dashboard, navigation, chat, posts, notifications, taches et profil selon les roles.
4. **Phase 3 - Operations.** Membres, presence, poles, projets, evenements, finance et recrutement avec patrons de travail coherents.
5. **Phase 4 - Signature EnactSpace.** Academy, Impact, Archives, Hall of Fame, prix et recits de projets.
6. **Phase 5 - Validation.** Recette multi-device, a11y, performance percue, tests de comprehension et suivi post-lancement.

Chaque phase doit avoir un prototype valide, des criteres de recette explicites, un echantillon de roles et une mesure de succes ; aucune ne doit etre traitee comme une simple operation de “modernisation”.

## 18. Annexe technique

### Fichiers structurants

- [`frontend/lib/core/theme/app_theme.dart`](../../frontend/lib/core/theme/app_theme.dart) : theme unique, palette et composants Material globaux.
- [`frontend/lib/app/app_router.dart`](../../frontend/lib/app/app_router.dart) : routes, redirections, ecrans publics et shell.
- [`frontend/lib/shared/layout/app_shell.dart`](../../frontend/lib/shared/layout/app_shell.dart) : navigation desktop/mobile, badges, polling et notifications.
- [`frontend/lib/core/auth/user_experience.dart`](../../frontend/lib/core/auth/user_experience.dart) : roles, experience et routes visibles.
- [`frontend/lib/features/auth/screens/login_screen.dart`](../../frontend/lib/features/auth/screens/login_screen.dart) : acces, inscription, biometrie, guide et recrutement public.
- [`frontend/lib/features/chat/screens/chat_screen.dart`](../../frontend/lib/features/chat/screens/chat_screen.dart) : experience la plus volumineuse, 4655 lignes.
- [`frontend/lib/features/recruitment/screens/recruitment_screen.dart`](../../frontend/lib/features/recruitment/screens/recruitment_screen.dart) : recrutement, 2993 lignes.
- [`frontend/lib/features/projects/screens/projects_screen.dart`](../../frontend/lib/features/projects/screens/projects_screen.dart) : projets, 2565 lignes.
- [`frontend/lib/features/members/screens/members_screen.dart`](../../frontend/lib/features/members/screens/members_screen.dart) : membres, 2517 lignes.

### Assets observes

Les assets de marque se trouvent dans `frontend/assets/brand/` (logos, icones, splash) ; les logos de projets, ainsi que les prix 2016, dans `frontend/assets/img/`. Les assets representent environ 4,1 Mo. Ils sont un capital de marque a integrer a une narration, non un simple reservoir d'icones decoratives.

### Conditions de verification des futures ameliorations

- absence de texte coupe, overlap ou action inaccessible a `375`, `390`, `768`, `1024`, `1440` et `1920 px` ;
- navigation d'un module autorise a un autre en trois interactions ou moins, par role ;
- contraste, focus clavier, semantique et zoom verifies ;
- etats loading/empty/error/success coherents sur au moins Posts, Chat, Presence, Finance et Recrutement ;
- temps et comprehension mesures avec membres et responsables reels ;
- aucune regression des permissions visibles dans le shell.
