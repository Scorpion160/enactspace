# Mémoire institutionnelle Enactus ESP 2015-2026 — analyse exhaustive et modèle vivant

## 1. Executive verdict

**Verdict : exploitable comme mémoire institutionnelle rapportée et comme cahier de besoins produit, non exploitable comme preuve autonome.** Le document élargit la narration antérieure jusqu’en 2026, avec sept mandats de Team Leaders, quinze identités ou évolutions de projets, dix missions datées, huit pôles support, six valeurs, une méthode en six étapes, onze lignes de palmarès et un ensemble très riche de chiffres historiques. Il doit devenir une couche éditoriale reliée aux objets probants d’EnactSpace, pas une page statique ni un import de valeurs présumées vraies.

Le contrôle a couvert **les 287 paragraphes, dont 266 non vides, les 76 titres structurés, les 25 tableaux et les quatre images incorporées**. Le fichier porte 11 titres de niveau 1, 33 de niveau 2 et 32 de niveau 3 ; son pied de page annonce 28 pages. Les 14 rapports `00` à `13` ont été relus et 19 domaines de code EnactSpace ont été contrôlés en lecture seule : 13 domaines backend, cinq familles d’interfaces frontend et la navigation/architecture de l’information.

Le registre consolidé de ce rapport contient :

| Objet | Nombre | Portée |
|---|---:|---|
| Événements de chronologie | 32 | 22 événements institutionnels et 10 missions |
| Projets/évolutions nommés | 15 | sans fusion automatique de Deconaane+ |
| Mandats de Team Leader rapportés | 7 | identités à publier sous politique institutionnelle |
| Missions terrain | 10 | aucune liste de participants reconstituée |
| Claims numériques ou d’impact | 101 | aucun `VERIFIED_IN_ENACTSPACE` |
| Distinctions rapportées | 11 | participation et prix séparés |
| Conflits ou incertitudes ouverts | 20 | dont plusieurs bloquent seulement le peuplement |
| Décisions institutionnelles | 24 | 6 de schéma, 16 de peuplement, 2 non bloquantes |
| Exigences produit nouvelles | 8 | en plus des 18 opportunités existantes |

Il n’existe **aucun nouveau blocage architectural avant PR-2B**. PR-2B peut continuer. PR-2C doit en revanche établir la vérité, la provenance et les états d’incertitude avant tout peuplement historique ; PR-2D doit créer le cœur temporel de la mémoire ; PR-6.6 doit livrer l’expérience Héritage.

## 2. Source and methodology

### Source contrôlée

| Champ | Valeur |
|---|---|
| Fichier | `Enactus_ESP_Memoire_Institutionnelle_2026.docx` |
| Emplacement | source externe au dépôt, dossier documentaire Enactus ESP |
| Taille | 4 936 623 octets |
| Date de modification du fichier | 2026-09-02 22:47:50 UTC |
| SHA-256 | `617632ABF662181BAA274819855BEF991AEF6D657D8E8DBB5A6ADD760E77D66D` |
| Présence dans `catalog/sources.csv` | aucune correspondance de chemin, nom ou SHA |
| Présence dans `source_to_normalized.csv` | aucune |
| Copie dans Git / normalisation | aucune ; source et catalogues laissés intacts |

Le fichier source était ouvert par un autre processus. Une lecture partagée a servi à produire une copie temporaire byte-for-byte hors Git ; taille et horodatage ont été revérifiés avant et après la copie, puis le SHA a été calculé sur cette copie stable. Aucun contenu généré n’a été écrit dans le dépôt.

### Méthode de lecture

La lecture a suivi l’ordre réel du corps Word, et non le seul sommaire : paragraphes, niveaux de titres, listes, tableaux et relations d’images ont été parcourus. Les en-têtes, pieds de page, propriétés du package, liens, révisions et commentaires ont aussi été inspectés. Résultats structurels : quatre relations image, 75 hyperliens internes de navigation, aucun lien externe, aucun commentaire, aucune insertion/suppression suivie et aucun texte alternatif sur les images.

La tentative de rendu page par page prévue par la procédure documentaire n’a pas abouti, car LibreOffice/`soffice` n’est pas disponible dans l’environnement. L’analyse utilise donc le **fallback structurel**. Les quatre images ont néanmoins été extraites hors Git et inspectées visuellement. Limite résiduelle : les défauts purement typographiques, coupures, débordements ou superpositions de page n’ont pas pu être certifiés. C’est la seule omission de contrôle ; aucun contenu textuel ou tabulaire substantiel n’a été omis.

### Références internes à ce rapport

- `MI26-Pnnn` désigne le paragraphe d’index `nnn` dans l’ordre du corps Word.
- `MI26-Tnn:Rnn` désigne le tableau `nn`, ligne `nn`, en comptant l’en-tête comme ligne 0.
- `R00` à `R13` désignent les rapports existants correspondants.
- `TT26` désigne le rapport technique TERRASEN à Mbour des 14–16 août 2026, déjà référencé par `R04` et `R07`, consulté via sa normalisation existante ; chemin, SHA et sections probantes sont précisés en section 27.
- `APP:` désigne un chemin relatif dans le dépôt EnactSpace au SHA contrôlé.

### Règles de vérité

| Classe | Usage dans ce rapport |
|---|---|
| `VERIFIED_IN_ENACTSPACE` | valeur reliée à une preuve et une validation réelles dans EnactSpace ; **aucune claim MI26 ne satisfait ce critère** |
| `HISTORICAL_REPORTED` | fait ou chiffre affirmé par la mémoire, sans chaîne probante suffisante |
| `EXTERNAL_SOURCE_REPORTED` | chiffre attribué à un tiers, sans source primaire jointe ni vérifiée ici |
| `PROJECTION` | résultat futur, anticipé ou perspective |
| `ESTIMATE` | coût ou grandeur explicitement estimatif |
| `TARGET` | résultat visé, non réalisé |
| `UNKNOWN_VALIDATION` | nature ou période insuffisante pour classer plus précisément |

La présence d’un chiffre dans une table, d’un récit dans une mémoire ou d’une valeur statique dans le code ne vaut jamais validation.

`CORROBORATED_BY_SOURCE` est un qualificatif documentaire complémentaire à `HISTORICAL_REPORTED`, pas un nouvel état de validation : pour FM-10, `TT26` corrobore la réalisation, le projet, les dates, le lieu, les GIE et les quatre tables. Il ne vaut pas `VERIFIED_IN_ENACTSPACE`.

## 3. Exhaustive content map

| Bloc substantiel | Localisateur | Contenu exploité | Classes principales |
|---|---|---|---|
| Couverture et devise | `MI26-P002:P014` | titre, 2015-2026, ESP/UCAD, devise, citation Gandhi, document vivant | `INSTITUTIONAL_IDENTITY`, `ARCHIVE` |
| Mot d’ouverture | `MI26-P016:P018` | citation attribuée au Team Leader courant | `PERSON_ROLE_HISTORY`, `INSTITUTIONAL_VALUE` |
| Remerciements | `MI26-P019:P020` | conseillers, alumni, membres, partenaires, communautés | `OTHER`, `GIE_OR_PARTNER` |
| Mode d’emploi | `MI26-P021:P024` | lectures chronologique/thématique, extrait RSE, zones photo à enrichir | `FUTURE_UPDATE`, `ARCHIVE`, `PHOTO` |
| Enactus mondial | `MI26-P025:P036` | SIFE 1975, nom Enactus 2012, philosophie, chiffres réseau, compétition | `INSTITUTIONAL_IDENTITY`, `EXTERNAL_SOURCE_REPORTED`, `COMPETITION` |
| Enactus Sénégal | `MI26-P037:P038` | coordination, ateliers, formations, accompagnement | `ORGANIZATION` |
| Histoire 2015-2026 | `MI26-P039:P087` | fondation, générations, projets, compétitions, crises et restructuration | `GENERATION`, `PROJECT`, `PARTICIPATION`, `AWARD` |
| Présence territoriale | `MI26-P088:P104` | 14 entrées territoriales, dont une catégorie Nord non précisée | `TERRITORY`, `COMMUNITY` |
| Réalisations techniques | `MI26-P105:P115` | neuf familles de technologies et savoir-faire | `TECHNOLOGY` |
| Mission et valeurs | `MI26-P116:P125` | identité de l’équipe et six valeurs | `INSTITUTIONAL_IDENTITY`, `INSTITUTIONAL_VALUE` |
| Organisation | `MI26-P126:P131` | TL, SG, huit pôles, quatre équipes projet, deux conseillers | `ORGANIZATION`, `ROLE` |
| Huit pôles | `MI26-T00` | Veille, Technique, IT, Communication, Finances et Trésorerie, Gestion, Chimie, Organisation | `ORGANIZATION` |
| Organigramme | image à `MI26-P132` | hiérarchie conseillers/alumni/TL/SG/pôles/projets ; texte projet inférieur endommagé | `ORGANIZATION`, `PHOTO`, `UNKNOWN_VALIDATION` |
| Méthode | `MI26-P133:P134`, `MI26-T01` | ciblage, immersion, brainstorming, design thinking, transfert, impact | `METHODOLOGY` |
| Projets fondateurs | `MI26-P135:P162`, `MI26-T02` | Javelisel, Soukhali Gokh, Kong’Serve, Deconaane/+, SunCuiz, Ville Light, MobiGel | `PROJECT`, `PROJECT_RELATIONSHIP`, `IMPACT_CLAIM` |
| Dimbali | `MI26-P163:P167`, `MI26-T03` | zones, quatre volets, résultats et vision | `PROJECT`, `PROJECT_COMPONENT`, `IMPACT_CLAIM` |
| Mën Nañ | `MI26-P168:P189`, `MI26-T04:T06` | trois zones, GIE, technologies, chiffres, ODD, perspectives | `PROJECT`, `PROJECT_ALIAS`, `GIE_OR_PARTNER`, `IMPACT_CLAIM` |
| SHERY | `MI26-P190:P196`, `MI26-T07` | problème, produit, étude tierce, budget, ODD, prix, perspectives santé | `PROJECT`, `BUDGET`, `EXTERNAL_SOURCE_REPORTED`, `AWARD` |
| Terrasen | `MI26-P197:P216`, `MI26-T08:T09` | micro-jardinage, transformation, ESP32, coûts, impacts, prix | `PROJECT`, `TECHNOLOGY`, `ESTIMATE`, `IMPACT_CLAIM` |
| Aquatus | `MI26-P217:P221` | aquaponie, site, audit, recherche, prix | `PROJECT`, `TECHNOLOGY`, `AWARD` |
| Voyages terrain | `MI26-P222:P223`, `MI26-T10:T11` | dix missions et espace photo | `FIELD_MISSION`, `IMMERSION`, `TECHNOLOGY_TRANSFER`, `IMPACT_COLLECTION` |
| Impact global | `MI26-P226:P228`, `MI26-T12` | treize indicateurs consolidés | `IMPACT_CLAIM`, `FINANCIAL_CLAIM` |
| ODD | `MI26-P229:P230`, `MI26-T13` | onze ODD et projets associés | `SDG` |
| RSE | `MI26-P231:P239` | volets social, économique, environnemental, gouvernance | `IMPACT_CLAIM`, `ORGANIZATION` |
| Palmarès | `MI26-P240:P243`, `MI26-T14:T15` | onze distinctions, revendication de quatre World Cups, presse/TV/radio | `AWARD`, `PARTICIPATION`, `MEDIA_REFERENCE` |
| Galerie | `MI26-P245:P257`, `MI26-T16:T21` | six périodes générationnelles avec emplacements à compléter | `GENERATION`, `PHOTO`, `FUTURE_UPDATE` |
| Team Leaders | `MI26-P259:P260`, `MI26-T22` | sept mandats 2015-2026 | `PERSON_ROLE_HISTORY`, `GENERATION` |
| Conseillers | `MI26-P261:P265` | deux premiers advisors, un conseiller 2026, liste incomplète | `PERSON_ROLE_HISTORY`, `ROLE` |
| Glossaire | `MI26-P266`, `MI26-T23` | AGR, GIE, ODD, QHSE, FAVEC, World Cup, RSE | `GLOSSARY` |
| Sources déclarées | `MI26-P267:P276` | neuf références internes, sans URL/SHA/version complète | `SOURCE` |
| Espace de mise à jour | `MI26-P277:P281`, `MI26-T24` | futur enrichissement, date éditoriale du 22 juillet 2026 | `FUTURE_UPDATE`, `PHOTO` |
| Message aux générations | `MI26-P282:P286` | héritage, responsabilité, transmission et devise | `INSTITUTIONAL_VALUE`, `FUTURE_UPDATE` |

## 4. Institutional identity

MI26 présente Enactus ESP comme l’équipe Enactus de l’École Supérieure Polytechnique de Dakar, rattachée à l’Université Cheikh Anta Diop, fondée en 2015 et tournée vers l’entrepreneuriat social. Sa devise rapportée est « Empowering our society is our priority ». La formule EN-ACT-US est expliquée comme esprit entrepreneurial, passage à l’action et communauté. Ces éléments relèvent de l’identité institutionnelle ; leur rédaction et leur traduction peuvent être publiées après validation de marque, sans les convertir en règles applicatives.

La mission locale ressort du document sous trois formulations compatibles : identifier des problèmes communautaires concrets, co-concevoir des solutions entrepreneuriales durables et créer une valeur sociale, économique et environnementale transmissible. L’énoncé selon lequel « les meilleurs étudiants » composent l’équipe est historique/descriptif ; il ne doit pas devenir un critère automatisé de recrutement, car aucun mécanisme de définition ou d’évaluation de « meilleur » n’est donné.

Le document distingue implicitement trois couches que le produit doit garder séparées :

1. une identité intemporelle et éditorialement approuvée ;
2. une organisation versionnée par saison ;
3. des récits et claims historiques reliés à leurs sources et à leur niveau de validation.

Le contexte mondial (SIFE en 1975, changement de nom en 2012, chiffres du réseau) est une référence externe à dater et rafraîchir depuis une source officielle. Le contexte Enactus Sénégal est descriptif, sans document d’autorité ou date d’effet cité dans MI26.

## 5. Chronology 2015-2026

Les dates annuelles sont marquées `YEAR_ONLY`; les périodes sont `DATE_RANGE`; les dates journalières des missions sont `EXACT_RANGE`. Les événements `EV-023` à `EV-032` sont les dix missions détaillées en section 11.

`EV-032 / FM-10` correspond au transfert de technologie TERRASEN réalisé à Mbour du 14 au 16 août 2026 : quatre tables de micro-jardinage pour le GIE Adji Ba et le GIE Sope Babacar Sy (`MI26-T10:R10`, `TT26` §§1, 3, 5.1). Classification : `HISTORICAL_REPORTED / CORROBORATED_BY_SOURCE`. La date de mise à jour du 22/07/2026 dans MI26 reste une incohérence éditoriale (C-12), sans remettre en doute la réalisation documentée de cette mission.

| ID | Date | Type | Événement | Projets / génération / territoire | Source | Statut |
|---|---|---|---|---|---|---|
| EV-001 | 2015 | `FOUNDATION` | Création sous l’impulsion d’un enseignant de Gestion ; démarrage à trois membres | génération fondatrice, ESP Dakar | `MI26-P041:P044` | `YEAR_ONLY`, rapporté |
| EV-002 | 2015-2016 | `PROJECT_CREATED` | Lancement de Javelisel et Soukhali Gokh | Dakar/Pikine/Tilène ; Sébikotane ou Darou Thioub selon section | `MI26-P045:P048`, `P138:P149` | `DATE_RANGE`, conflit de lieu à qualifier |
| EV-003 | 2016-2017 | `PROJECT_CREATED` | Expansion à près de trente membres ; Dimbali, SunCuiz et Ville Light | génération fondatrice ; plusieurs territoires | `MI26-P049:P054` | `DATE_RANGE`, rapporté |
| EV-004 | 2016 | `AWARD` | Prix Sonatel, vice-champion national et quatre prix Uhodari | projets non tous reliés | `MI26-T14:R01:R03` | `YEAR_ONLY`, preuves à relier |
| EV-005 | 2017 | `COMPETITION` | Titre national après audit, qualification Londres, visas refusés | Dimbali/SunCuiz/Ville Light possibles, non attribués par l’événement | `MI26-P055` | qualification certaine dans le récit, absence effective rapportée |
| EV-006 | 2017 | `LEADERSHIP_CHANGE` | Début du mandat de Mayacine Ndiaye | génération 2017-2019 | `MI26-P057`, `T22:R02` | `YEAR_ONLY` |
| EV-007 | 2017-2018 | `PROJECT_EVOLVED` | Dimbali se diversifie ; Deconaane est recentré sur Sébikotane | Dimbali, Deconaane | `MI26-P058:P059` | `DATE_RANGE` |
| EV-008 | 2018 | `COMPETITION` / `AWARD` | Champion national, présence effective aux États-Unis, demi-finale World Cup | Dimbali, Deconaane | `MI26-P060`, `T14:R05:R06` | `YEAR_ONLY`, présence effective explicitement dite |
| EV-009 | 2019 | `LEADERSHIP_CHANGE` / `OTHER` | Départ du TL, arrivée d’Ibrahima Cissé, grève et baisse d’effectif | génération 2019-2021 | `MI26-P061:P063`, `T22:R03` | `YEAR_ONLY` |
| EV-010 | 2019 | `PROJECT_MERGED` | Deux initiatives fruits/lait fusionnent pour former Mën Nañ | Niaguiss/Casamance ; Saré Yoba/Kolda | `MI26-P064:P065` | `YEAR_ONLY`, porteurs nommés dans la source |
| EV-011 | 2019 | `PROJECT_EVOLVED` | Technologies Deconaane adaptées à Dimbali sous le nom Deconaane+ | Sinthiou Dimb | `MI26-P066:P067` | `YEAR_ONLY`, relation exacte à décider |
| EV-012 | 2019 | `PROJECT_CREATED` | Kong’Serve sur la Petite Côte ; pas de compétition nationale | Kong’Serve, Mbour/Petite Côte | `MI26-P068:P069` | `YEAR_ONLY` |
| EV-013 | 2020 | `PROJECT_CREATED` / `OTHER` | Riposte Covid : masques, MobiGel, Diappeu Thi ; programmes Water Race/Impact at Work | Dakar/Maristes mentionné dans le détail MobiGel | `MI26-P070:P075`, `P161:P162` | `YEAR_ONLY` |
| EV-014 | 2021 | `LEADERSHIP_CHANGE` / `PROJECT_CREATED` | Famara Badji devient TL ; création de SHERY ; maintien de Mën Nañ | génération 2021 | `MI26-P076:P077`, `T22:R04` | `YEAR_ONLY` |
| EV-015 | 2021-2022 | `LEADERSHIP_CHANGE` | Mandat de Sady Wade, « génération des Yahya » | Mën Nañ, SHERY | `MI26-P078:P079`, `T22:R05` | `DATE_RANGE`; nom de génération informel |
| EV-016 | 2022 | `COMPETITION` / `MEDIA` | Qualification sur dossier, visas accordés, représentation World Cup et film de 77 secondes | Dimbali, Mën Nañ | `MI26-P080:P081` | `YEAR_ONLY`, lieu/résultat World Cup non donnés |
| EV-017 | 2022-2023 | `PROJECT_ENDED` / `PROJECT_CREATED` | Fin de cycle Dimbali ; lancement/relance SHERY, Terrasen, Aquatus et CAJOR | génération Alimatou Sadiya Thiam | `MI26-P082:P083`, `T22:R06` | `DATE_RANGE`; statut courant non prouvé |
| EV-018 | date inconnue ; projet depuis 2022 | `PARTNERSHIP` | Partenariat Terrasen rapporté avec la mairie de Ndiedieng et le ministère de l’Agriculture | Terrasen, Ndiedieng ; génération non attribuée | `MI26-P197:P202` | `UNKNOWN_DATE`, preuve d’accord absente |
| EV-019 | 2023 | `AWARD` / `COMPETITION` | Champion national et premier prix SHERY au Salon du Polytechnicien | SHERY | `MI26-P083`, `P196`, `T14:R07:R08` | `YEAR_ONLY` |
| EV-020 | 2024-2025 | `OTHER` | Consolidation terrain Terrasen/Aquatus à Kaolack et Ziguinchor | Terrasen, Aquatus | `MI26-P084:P085` | `DATE_RANGE` |
| EV-021 | 2025 | `AWARD` | Terrasen 1er Polytech’Innovation et 2e SENAYSKILLS ; Aquatus 2e Polytech’Innovation | Terrasen, Aquatus | `MI26-P085`, `P215`, `P221`, `T14:R09:R11` | `YEAR_ONLY` |
| EV-022 | 2025-2026 | `RESTRUCTURING` | Reprise après inactivité, formation avec alumni, dépôts RSE, transferts à Mbour, recrutement envisagé | génération Amdy Thiam | `MI26-P086:P087`, `T22:R07` | `DATE_RANGE`; réalisations et intentions à séparer |

Le média évoqué dans `MI26-P243` (L’Observateur, 2STV, RFI) ne forme pas trois événements datables : dates, titres, liens et droits manquent. Il entre au registre média avec date inconnue, pas dans le compte des 32 événements.

## 6. Generations and leadership

### Mandats rapportés

| Période | Personne / rôle | Génération ou contexte | Source | Limite |
|---|---|---|---|---|
| 2015-2017 | Alioune Badara Kamara — Team Leader | fondation et première croissance | `MI26-T22:R01` | dates de prise/fin exactes absentes |
| 2017-2019 | Mayacine Ndiaye — Team Leader | concentration du portefeuille, World Cup 2018 | `MI26-P057`, `T22:R02` | dates exactes absentes |
| 2019-2021 | Ibrahima Cissé — Team Leader | réorganisation, Covid | `MI26-P062`, `T22:R03` | dates exactes absentes |
| 2021 | Famara Badji — Team Leader | recrutement, création SHERY | `MI26-P077`, `T22:R04` | mandat intra-annuel non daté |
| 2021-2022 | Sady Wade — Team Leader | « génération des Yahya » | `MI26-P079`, `T22:R05` | le sens/membres de la génération ne sont pas définis |
| 2022-2025 | Alimatou Sadiya Thiam — Team Leader | fin Dimbali, projets récents, titres 2023/2025 | `MI26-T22:R06` | lien aux événements à confirmer |
| 2025-2026 | Amdy Thiam — Team Leader | restructuration | `MI26-P018`, `T22:R07` | « actuel » n’est valable qu’à l’édition MI26 |

### Autres rôles historiques

- Fondateur rapporté : M. Mare, enseignant en Gestion (`MI26-P042`, `P262`).
- Premiers Faculty Advisors rapportés : M. Mare et Dr Cheikhou Kane (`MI26-P044`, `P262:P263`).
- Conseiller cité pour 2026 : M. Racine Ly, département GCBA (`MI26-P264`), sans date de début/fin ni intitulé précis.
- Pionniers cités : Alioune Badara Kamara, Pa Omar Diop, Angel, Lissoune Ndiaye et Adama Diop (`MI26-P043`). Ces noms sont utiles à l’histoire institutionnelle, mais leur affichage public relève d’une politique éditoriale et, pour photos/profils, d’une revue de consentement.
- Deux porteurs d’initiatives à l’origine de Mën Nañ et deux personnes associées à Diappeu Thi sont nommés dans le texte. Ils ne doivent pas devenir automatiquement des comptes, membres ou propriétaires de projet.
- Aucun Secrétaire Général historique, responsable de pôle, adjoint de pôle ou liste complète de conseillers n’est attribué. `MI26-P265` demande explicitement de compléter cette liste.

Une `Generation` ne doit pas être déduite d’un mandat : elle représente une saison ou cohorte éditoriale ; un `RoleTerm` relie une personne, un rôle, une unité, des dates et une source. Les chevauchements et mandats partiels doivent être permis. Le produit doit pouvoir publier le rôle tout en restreignant le profil personnel.

## 7. Organization and roles

L’organisation rapportée comporte un Team Leader, un Secrétaire Général, huit pôles support, quatre équipes projet, deux conseillers pédagogiques, des chefs et adjoints de pôles/projets, et un rôle des alumni dans l’accompagnement. Les responsables de pôles seraient désignés par le TL après appel à candidatures ; les décisions stratégiques ou financières importantes seraient consultées avec les conseillers ; des réunions auraient lieu au moins toutes les deux semaines (`MI26-P127:P130`). Ces règles restent `UNKNOWN_VALIDATION` tant qu’un texte adopté et daté ne les confirme pas.

| Unité rapportée | Mission MI26 | Relation aux rapports 00-13 |
|---|---|---|
| Veille | opportunités, partenariats, compétitions, suivi | confirme `R03` |
| Technique | prototypes, fabrication, essais terrain | confirme `R03`, étend par la mémoire technologique |
| IT | site, centralisation, outils internes | confirme `R03` |
| Communication | communication interne/externe, visuels, newsletter, médias | confirme `R03` |
| Finances et Trésorerie | fonds, budgets, cotisations, rapports semestriels | **étend/contredit** la liste à sept pôles des rapports |
| Gestion | administration, partenariats, relations extérieures | confirme `R03`, frontière avec Finance à décider |
| Chimie | tests, analyses, formulation | confirme `R03` |
| Organisation | logistique événements, formations, activités | confirme `R03` |

L’image d’organigramme confirme la hiérarchie haute et les huit pôles, mais ses quatre cartes projet inférieures comportent du texte corrompu ou dupliqué, dont une carte « TERRASEN AQUATUS ». Elle ne peut pas être une source de vérité pour les équipes projet. La nomenclature doit être versionnée par saison avec alias, dates d’effet et décision, conformément à `R01` et `R03`.

## 8. Values and methodology

### Six valeurs

| Valeur | Sens rapporté | Comportement produit recommandé |
|---|---|---|
| Esprit d’équipe | réussite collective et synergie de compétences | contenu de référence ; ne pas produire un score individuel |
| Sens de la responsabilité | discipline et respect des engagements | relier engagements, tâches et preuves, sans profilage négatif public |
| Engagement | satisfaire les besoins des communautés | critère de revue de projet versionnable |
| Dynamisme | activité, énergie, efficacité | descriptif ; aucun classement automatique |
| Pugnacité | persévérance face aux objectifs | contenu éditorial et Academy |
| Excellence | recherche d’un haut niveau de qualité | principes de validation et d’amélioration, pas métrique de personne |

### Méthode en six étapes

| Ordre | Étape | Objet durable | Élément à versionner / automatiser |
|---:|---|---|---|
| 1 | Ciblage | identifier communauté et problème | fiche de besoin, hypothèses, critères et décision de passer à l’immersion |
| 2 | Immersion | confronter les hypothèses aux acteurs et bénéficiaires | mission, sites, consentement, notes minimisées, documents |
| 3 | Brainstorming | générer des options | atelier descriptif ; décisions et options retenues versionnées |
| 4 | Design thinking | prototyper/tester avec les usages | version de prototype, protocole, résultat, risque, validation |
| 5 | Transfert de technologie | transmettre solution et compétences | objet `TechnologyTransfer`, bénéficiaire institutionnel, technologie/version, formation, preuve |
| 6 | Recueil d’impact | mesurer quantitatif et qualitatif | instrument, période, population, claim, calcul, preuve, validation indépendante |

La séquence confirme PRJ-01, EVT-01, IMP-01 et OP-06/08/10/15. Elle doit être un **workflow configurable**, pas une progression imposée identique à tous les projets. Les valeurs sont surtout intemporelles ; la méthode est une référence versionnable ; les gates, formulaires et autorités sont des configurations saisonnières.

## 9. Canonical project history

Le tableau compte 15 entrées nommées. Il ne fusionne pas Deconaane+ avec Deconaane et ne transforme pas la production de masques, Water Race ou Impact at Work en projets autonomes.

Typage : nom → `PROJECT`; variante → `PROJECT_ALIAS`; filiation → `PROJECT_RELATIONSHIP`; période de présence → `PROJECT_SEASON`; état historique → `PROJECT_STATUS`; volet/produit → `PROJECT_COMPONENT`. Une période narrative n’est pas une saison applicative validée.

| # | Candidat canonique / alias | Période et état rapportés | Relations | Territoires / communautés | Composants, technologies, claims | Fiabilité et conflit |
|---:|---|---|---|---|---|---|
| 1 | Javelisel | 2015 ; historique | projet fondateur | Dakar, district de Pikine, marché Tilène, structures sanitaires | production eau+sel ; sensibilisation ; `IC-005:006` | récit MI26 ; « eau de mer » dans la chronologie contre « eau et sel » dans la fiche |
| 2 | Soukhali Gokh ; alias corpus `Soukhalii Gokh`, `Soukhali` | 2015 ; historique | projet fondateur | chronologie : Sébikotane ; fiche : Darou Thioub/Keur Massar | céréales, farine fortifiée, coopérative, formations ; `IC-007` | conflit territorial interne ; ministère cité sans preuve jointe |
| 3 | Kong’Serve ; alias `Kongserve` | 2019 ; historique | initiative distincte | Yoff Tonghor, Mballing, Mbour/Petite Côte | conservation du poisson fumé ; `IC-008` | aucune période de fin ni preuve d’impact |
| 4 | Deconaane | avant/pendant 2017-2018 ; historique/« continué » dans l’app | prédécesseur possible de Deconaane+ | Nord non précisé puis Sébikotane | filtre argile/naturel, moringa/nebeeday, stockage potou ndaa ; `IC-009:012` | dates de création et statut exacts absents |
| 5 | Deconaane+ | 2019 ; évolution rapportée | adaptation de technologies Deconaane dans l’extension Dimbali | Sinthiou Dimb | pompe, accès à l’eau, séchoirs | décider alias/version/sous-projet ; ne pas fusionner automatiquement |
| 6 | SunCuiz | 2016-2017 ; expérimentation puis évolution | évolution vers paniers thermiques | Sambé Nguinth, Diourbel | cuiseur solaire, paniers thermiques | statut de clôture absent |
| 7 | Ville Light | 2016-2017 ; déploiement à grande échelle abandonné | solution transformée en kits pédagogiques | territoire non précisé | éclairage alternatif, bouteilles solaires, kits | distinguer projet et actif pédagogique |
| 8 | MobiGel ; variante typographique `Mobigel` | 2020 ; historique | riposte Covid | Maristes/Dakar dans le détail | vélo, distributeur sans contact, compteur, haut-parleur solaire | pas de résultat quantifié MI26 |
| 9 | Diappeu Thi | 2020 ; historique | riposte Covid avec masques/MobiGel | communautés non précisées | sensibilisation, masques, gel | porteurs cités, pas de fiche ni impact validé |
| 10 | Dimbali | depuis 2017, fin de cycle 2022-2023 | extension à Ndiédieng ; reçoit adaptation Deconaane+ | Ngayène Sabakh, 23 villages, Ndiédieng, Sinthiou Dimb | dimb, transformation, compost, séchoirs, formation ; `IC-013:024` | historique riche ; chiffres non validés ; archivé dans `R04` |
| 11 | Mën Nañ ; alias `Mën Nan`, `Mën Nagn`, `MEUNE NAGN` | depuis 2019 ; maintien rapporté jusqu’en 2022-2023 | fusion fruits Casamance + lait Saré Yoba ; frontière CAJOR ouverte | Niaguiss, Saré Yoba Diéga, Sinthiou Dimb | trois zones, quatre pôles internes, GIE, transformation, pompes/séchoirs ; `IC-025:048` | nom, périmètre et statut courant à décider |
| 12 | SHERY ; alias corpus `Shery`, `Cherry` | depuis 2021 ; actif historique, statut 2026 conflictuel | aucune filiation établie | Pikine/Guédiawaye dans étude tierce ; cibles plus larges non localisées | serviette réutilisable, plateforme, sponsoring, tisanes ; `IC-049:054` | santé, sécurité et statut transfert/vente exigent validation |
| 13 | Terrasen ; alias `Terassen`, variante lieu `Khaffé/Haffé` | depuis 2022 ; activité 2024-2026 rapportée | intervient sur sites historiques Dimbali | Ndiedieng, Haffé, Ndiobène Tallène, Ngayène Sabakh, Passy, Yeumbeul, Mbour | micro-jardinage, goutte-à-goutte, ESP32, transformation ; `IC-055:071` ; quatre tables réalisées/transférées à Mbour en août 2026 (`FM-10`, `TT26` §§1, 3, 5.1) | mission Mbour corroborée par source ; agrégations/sites/périodes d’impact non réconciliés |
| 14 | Aquatus | depuis 2023 ; développement rapporté | site commun avec Dimbali/Terrasen, sans filiation | Ngayène Sabakh/Médina Sabakh, Kaolack | aquaponie, audit, recherche en sept étapes ; `IC-072:073` | conception et prix documentés, aucun impact réalisé quantifié |
| 15 | CAJOR | lancé 2022-2023 ; état courant inconnu | périmètre moringa/cajou potentiellement partagé avec Mën Nañ | territoires non attribués dans MI26 | procédés moringa/noix de cajou, presse | frontière fonctionnelle C-05 inchangée ; procédures à valider |

L’ancienne source `Histoire de Enactus ESP.pdf` allait seulement jusqu’à 2022-2023. MI26 l’étend avec 2024-2026, les fiches projet détaillées, les missions, le palmarès, les responsables et l’organisation. En sens inverse, MI26 omet ou neutralise plusieurs passages prospectifs de l’ancienne histoire : autonomisation en GIE/entreprise/start-up, partage éventuel de revenus avec le club, diversification vers Hult Prize/hackathons, éventuel changement de nom, vigilance réputationnelle, indépendance financière et relation avec l’école. Ces omissions ne prouvent ni abandon ni adoption ; elles restent des propositions historiques à arbitrer.

## 10. Territories

| Territoire MI26 | Liens supportés | Normalisation requise |
|---|---|---|
| Dakar | institution, Javelisel, MobiGel | distinguer ville, région, campus, sites |
| Pikine / marché Tilène | Javelisel | créer des `Place` hiérarchiques, ne pas géocoder automatiquement |
| Darou Thioub / Keur Massar | Soukhali Gokh dans la fiche détaillée | conflit avec Sébikotane |
| Sébikotane | Soukhali Gokh dans la chronologie ; Deconaane | conserver les deux assertions séparées |
| Thiès | présence globale seulement | projet/date inconnus |
| Diourbel / Sambé Nguinth | SunCuiz | orthographe et niveau administratif à vérifier |
| Kolda / Saré Yoba / Saré Yoba Diéga | Mën Nañ lait | harmoniser localité, commune et région |
| Bignarabé, Santankoy, Sanankoro, Saré Amidou | mission 2021/2022 | relations projet seulement candidates |
| Niaguiss / Ziguinchor | Mën Nañ fruits ; missions ; consolidation 2024-2025 | distinguer région, commune et site |
| Médina Yoro Foulah | présence globale | activité/projet inconnus |
| Sinthiou Dimb | Dimbali/Deconaane+, Mën Nañ zone 3 | ne pas confondre fruit « dimb » et lieu |
| Kaolack / Ndiedieng / Haffé / Ndiobène Tallène | Terrasen, missions, Aquatus/Dimbali selon sites | alias `Khaffé/Haffé`, limites administratives à vérifier |
| Ngayène Sabakh / Médina Sabakh | Dimbali, Terrasen, Aquatus, missions | site multi-projets ; éviter le double comptage |
| Fatick | plusieurs missions | projet candidat non affirmé |
| Passy | Terrasen et missions | région/commune à valider |
| Yeumbeul | Terrasen et mission 2025 | site précis/GIE à valider |
| Mbour / Mballing / Petite Côte | Kong’Serve historique | conservation du poisson fumé ; ne pas confondre avec la mission TERRASEN de 2026 |
| Mbour | TERRASEN, FM-10, 14–16 août 2026 | transfert réalisé auprès du GIE Adji Ba et du GIE Sope Babacar Sy ; quatre tables ; `HISTORICAL_REPORTED / CORROBORATED_BY_SOURCE` (`TT26` §§1, 3, 5.1) |
| Nord du Sénégal | Deconaane historique | catégorie trop vague pour géolocalisation |

Le minimum est `Place(id, canonical_name, type, parent_id, aliases, coordinates_status)` et `InterventionSite(place_id, project_id, community_label, valid_from, valid_to, source_assertion_id)`. Une communauté ou un GIE n’est pas un lieu et doit avoir son propre objet institutionnel. Aucun nom individuel de bénéficiaire n’est nécessaire.

## 11. Field missions and technology transfers

Les dix missions de la table MI26 sont reprises ci-dessous. Pour FM-01 à FM-09, les projets candidats sont des **inférences de rapprochement géographique**, pas des attributions présentes dans cette table source. Pour FM-10, l’attribution à TERRASEN et la réalisation sont corroborées par le rapport technique `TT26`, déjà cité dans `R04` et `R07`.

| ID | Début-fin | Nature exacte | Destinations / sites | Projets / attribution | Drapeaux | Source / statut |
|---|---|---|---|---|---|---|
| EV-023 / FM-01 | 2021-02-19—2021-02-20 | transfert de technologie, recueil d’impacts | Ngayène Sabakh | Dimbali | transfert, impact | `MI26-T10:R01`; exact, preuve de mission non jointe |
| EV-024 / FM-02 | 2021-06-09—2021-06-12 | immersion | Bignarabé, Kolda, Santankoy, Sanankoro, Saré Amidou ; Ngayène Sabakh ; Fatick | Mën Nañ, Dimbali, inconnus | immersion | `MI26-T10:R02`; destinations composites |
| EV-025 / FM-03 | 2022-05-31—2022-06-04 | transfert de technologie | Bignarabé/Kolda ; Saré Yoba Diéga ; Niaguiss | Mën Nañ | transfert | `MI26-T10:R03` |
| EV-026 / FM-04 | 2022-08-15—2022-08-16 | transfert de technologie | Ndiedieng, Haffé | Terrasen | transfert | `MI26-T10:R04` |
| EV-027 / FM-05 | 2023-03-18—2023-03-22 | transfert de technologie | Saré Yoba Diéga ; Niaguiss ; Ndiedieng/Haffé ; Fatick | Mën Nañ, Terrasen, inconnus | transfert | `MI26-T10:R05` |
| EV-028 / FM-06 | 2023-08-15—2023-08-19 | transfert de technologie, immersion | Ndiedieng, Haffé, Ndiobène Tallène ; Fatick | Terrasen, inconnus | transfert, immersion | `MI26-T10:R06` |
| EV-029 / FM-07 | 2023-09-09—2023-09-10 | recueil d’impacts | Ndiedieng, Haffé, Ndiobène Tallène ; Ngayène Sabakh | Terrasen, Dimbali/Aquatus candidats | impact | `MI26-T10:R07` |
| EV-030 / FM-08 | 2024-06-29—2024-07-03 | transfert de technologie | Ndiedieng/Haffé ; Ngayène Sabakh ; Passy | Terrasen, autres inconnus | transfert | `MI26-T10:R08` |
| EV-031 / FM-09 | 2025-03-14—2025-03-18 | immersion, transfert de technologie | Ziguinchor ; Niaguiss ; Ngayène Sabakh ; Passy ; Yeumbeul | Mën Nañ, Terrasen, Aquatus candidats | immersion, transfert | `MI26-T10:R09` |
| EV-032 / FM-10 | 2026-08-14—2026-08-16 | transfert de technologie | Mbour ; GIE Adji Ba et GIE Sope Babacar Sy | TERRASEN, attribution corroborée par `TT26` | transfert réalisé ; quatre tables de micro-jardinage réalisées/transférées, deux par GIE | `MI26-T10:R10`, `TT26` §§1, 3, 5.1 ; `HISTORICAL_REPORTED / CORROBORATED_BY_SOURCE` |

FM-10 est une mission réalisée documentée, non une mission planifiée. La discordance avec la mise à jour MI26 du 22/07/2026 relève uniquement de l’édition du document (C-12). Les appréciations d’appropriation et les effets qualitatifs décrits dans `TT26` §5.2 restent des observations rapportées, sans validation d’impact dans EnactSpace. Aucun nom de participant ou de membre n’est repris de `TT26` ; seuls les deux GIE sont nommés comme organisations bénéficiaires institutionnelles.

Le modèle minimal est :

- `FieldMission` : dates, nature, statut planifié/réalisé/annulé, objet, saison, source et validation ;
- `MissionSite` : mission, lieu, communauté/GIE institutionnel, ordre et notes publiques/restreintes ;
- `MissionProject` : relation explicite ou candidate, type de contribution et validateur ;
- `TechnologyTransfer` : technologie+version, transférant, organisation destinataire, formation, livrables, sécurité et preuve ;
- `ImpactCollection` : instrument/version, période observée, agrégat attendu, consentement/rétention et claim produit ;
- `MissionDocument` : proposition, budget, autorisation, rapport, preuve et statut canonique ;
- `MissionMedia` : fichier, légende, date/lieu, droits, consentement, visibilité et date d’expiration éventuelle.

Les participants nominaux ne doivent exister que pour la logistique et les droits, dans un périmètre restreint ; ils ne se déduisent jamais d’une photo ou d’un récit.

## 12. Technologies and institutional know-how

| Famille de savoir-faire | Projets/usage rapportés | Objet à conserver | Contrôle avant réutilisation |
|---|---|---|---|
| Séchoirs solaires | Dimbali, Mën Nañ, Terrasen | design, capacité, matériaux, versions et retours terrain | sécurité, performance, droits et contexte climatique |
| Cuiseurs solaires | SunCuiz | prototype et apprentissages | abandon/évolution, sécurité thermique |
| Paniers thermiques | évolution SunCuiz | actif technique distinct | protocole et validation d’usage |
| Filtration argile/naturelle | Deconaane | principe, prototype, tests | qualité de l’eau ; aucune consigne sanitaire non validée |
| Pompes communautaires | Deconaane+, Mën Nañ/Sinthiou Dimb | version, débit, coût et installation | preuve de performance, maintenance et sécurité |
| Potou ndaa / stockage | Deconaane | dispositif local | terminologie, matériaux, hygiène |
| Éclairage alternatif | Ville Light | prototype et kits pédagogiques | distinguer dispositif terrain et support pédagogique |
| Transformation agroalimentaire | Soukhali Gokh, Dimbali, Mën Nañ, Terrasen, CAJOR | recette/version, équipement, formation, contrôles | QHSE, réglementation, allergènes, durée de conservation |
| Conservation lait/poisson | Mën Nañ, Kong’Serve | procédé et contexte | chaîne du froid, preuves et validation sanitaire |
| Moringa/nebeeday/cajou | Deconaane, Mën Nañ, CAJOR | procédés, filiation et propriété | frontières projet, sécurité alimentaire/cosmétique |
| Micro-jardinage sur table | Terrasen | table, substrat, irrigation, formation | version, coût, maintenance et mesure d’eau |
| Irrigation ESP32 | Terrasen | BOM, firmware, capteur, relais, pompe, règles | calibration, sécurité électrique, licence et obsolescence |
| Aquaponie | Aquatus | hypothèses, architecture pilote, protocole de recherche | bien-être animal, eau, alimentation et preuve pilote |
| Protection menstruelle réutilisable | SHERY | couches, matériaux, cycle d’usage, formation | validation sanitaire, lavage, essais et consentement |
| Tisanes naturelles | SHERY | formulation historique | ne publier aucune promesse anti-inflammatoire/antalgique sans validation experte/réglementaire |
| MobiGel | MobiGel | mécanisme sans contact, compteur, diffusion audio/solaire | désinfection, sécurité mécanique et contexte Covid historique |

`Technology` doit être distinct de `TechnologyVersion`, `TestProtocol`, `TestResult`, `Transfer` et `SafetyApproval`. Une fiche historique peut montrer qu’un dispositif a existé ; elle ne l’autorise pas comme instruction de fabrication actuelle. Cette conclusion étend OP-15 sans créer un second registre concurrent.

### Détails opérationnels conservés

- Dimbali : les quatre volets sont transformation, compostage, séchage solaire et formation en approvisionnement, vente, management, caisse et QHSE (`MI26-P166`).
- Mën Nañ : les organisations nommées sont GIE Lumière à Niaguiss et GIE Aynobe à Saré Yoba Diéga. Les produits moringa/cajou comprennent huile pressée à froid, savon, sirop, lait et beurre de cajou, jus et vinaigre de pomme de cajou (`MI26-P186`). Ce sont des objets de savoir-faire, non des recettes approuvées.
- Niaguiss, mars 2025 : conservation du jus de pastèque dite résolue par pasteurisation/mise sous vide ; espace de séchage insuffisant ; étiquetage non conforme ; coût énergétique ; besoin d’Excel/inventaire ; B2B et demande FRA pour dix aliments (`MI26-P175`). Chaque problème/solution doit devenir une observation de mission, une décision ou une tâche, sans transformer la solution déclarée en validation sanitaire.
- SHERY : quatre couches décrites (contact, insert absorbant, imperméable, dos en wax), attaches pression ; plateforme de commande, localisation des ventes, sensibilisation et parrainage (`MI26-P194`). Le parrainage n’est pas une liste de bénéficiaires importable.
- Terrasen : cinq gammes détaillées : sirops/jus (menthe, betterave, carotte), infusions hibiscus/bissap, confiture de bissap, sauce verte et conserves de légumes (`MI26-P206:P211`). Les perspectives sont tests, panel micro-jardinage, formations COUD/UCAD et nouveaux ciblages (`P216`).
- Aquatus : sept étapes de recherche : identification, évaluation, hypothèses, plan d’entretiens experts, description de cible, collecte à distance/terrain, analyse du pilote (`MI26-P220`). L’existence d’une démarche ne démontre ni rendement ni impact.

## 13. Impact claims registry

### Règle de comptage

Le registre compte **101 claims numériques ou d’impact**, et non 101 résultats réalisés. Une ligne correspond soit à un indicateur tabulaire, soit à une assertion narrative étroitement liée. Les sous-valeurs inséparables d’une même phrase restent dans une ligne. Les répétitions du tableau global sont conservées et signalées, car elles constituent des assertions éditoriales distinctes. Les populations de contexte, budgets, quantités organisationnelles et estimations techniques sont inclus lorsqu’ils encadrent un impact ou pourraient être importés à tort comme résultat. Les dates/rangs sont inventoriés dans la chronologie et le palmarès ; les six valeurs, six étapes et identifiants ODD dans leurs sections dédiées.

**Résultat du contrôle EnactSpace : 0/101 `VERIFIED_IN_ENACTSPACE`.** Le code comporte des valeurs historiques statiques et des calculs de repli, mais ni l’existence en code ni un statut par défaut ne constitue une preuve de ces claims MI26. Aucune base de production n’a été consultée : ce résultat signifie qu’aucune preuve de validation n’a été établie par cette revue documentaire et de code, pas qu’une telle preuve ne pourrait exister ailleurs.

Abréviations : `HR` = `HISTORICAL_REPORTED`, `ER` = `EXTERNAL_SOURCE_REPORTED`, `PR` = `PROJECTION`, `ES` = `ESTIMATE`, `UV` = `UNKNOWN_VALIDATION`. Sauf mention contraire, MI26 ne donne ni protocole de calcul, ni fichier de preuve lié, ni validateur.

### Contexte mondial et projets fondateurs

| ID | Claim exact / valeur | Projet, territoire, période | Source indiquée / méthode / preuve | Classe et limites |
|---|---|---|---|---|
| IC-001 | 33 organisations nationales | Enactus mondial, édition MI26 | « données institutionnelles disponibles », sans lien/date | `ER`; actualiser depuis source officielle |
| IC-002 | plus de 1 000 programmes universitaires | Enactus mondial | idem | `ER` |
| IC-003 | environ 42 000 étudiants mobilisés par an | Enactus mondial | idem | `ER`; estimation annuelle |
| IC-004 | plus de 13 millions de vies impactées | Enactus mondial | idem | `ER`; définition et période absentes |
| IC-005 | 1 720 bouteilles d’eau de javel distribuées | Javelisel, Pikine/Tilène, période non donnée | `MI26-P142`; aucune pièce liée | `HR`; production, pas impact durable |
| IC-006 | accès facilité, pénuries réduites, recul du choléra et de la varicelle | Javelisel | `MI26-P143`; aucune mesure avant/après | `HR`; causalité et diagnostic non établis |
| IC-007 | nutrition améliorée, marché/revenus/capacités accrus | Soukhali Gokh, Darou Thioub | `MI26-P149`; aucun indicateur | `HR`; qualitatif |
| IC-008 | production, revenus et exportations de Kong fumé en hausse | Kong’Serve, Yoff Tonghor/Mballing | `MI26-P153`; aucun chiffre/méthode | `HR`; qualitatif |
| IC-009 | 5 emplois créés | Deconaane/+, territoire/période non donnés | `MI26-T02:R01` | `HR`; rattachement déduit de la position du tableau |
| IC-010 | 125 arbres de moringa plantés | Deconaane/+ | `MI26-T02:R02` | `HR`; survie et période absentes |
| IC-011 | revenus mensuels des bénéficiaires +52 % | Deconaane/+ | `MI26-T02:R03` | `HR`; base, échantillon et devise absents |
| IC-012 | chiffre d’affaires 515 670 FCFA en un mois | Deconaane/+ | `MI26-T02:R04` | `HR`; mois et comptabilité absents |

### Dimbali

| ID | Claim exact / valeur | Projet, territoire, période | Source indiquée / méthode / preuve | Classe et limites |
|---|---|---|---|---|
| IC-013 | environ 31 000 habitants | Dimbali, Ngayène Sabakh, depuis 2017 | `MI26-P165` | `UV`; population de contexte, source absente |
| IC-014 | environ 12 500 habitants | Dimbali, Ndiédieng, depuis 2022 | `MI26-P165` | `UV`; population de contexte |
| IC-015 | revenu journalier moyen 0,99 USD | zones Dimbali, période non donnée | `MI26-P165` | `HR`; population/méthode absentes |
| IC-016 | malnutrition des enfants de moins de 5 ans : 15 %, jusqu’à 17,03 % dans 23 villages | zones Dimbali | `MI26-P165` | `HR`; deux bases non réconciliées |
| IC-017 | malnutrition ramenée de 15 % à 0 % à Ngayène et 23 villages | Dimbali, période non donnée | `MI26-T03:R01` | `HR`; claim causal sensible, aucune étude liée |
| IC-018 | impact économique cumulé supérieur à 43 000 000 FCFA | Dimbali | `MI26-T03:R02` | `HR`; « impact » non défini |
| IC-019 | revenus +77 % en un an, soit 53,6 USD/mois et 647,7 USD/an | Dimbali | `MI26-T03:R03` | `HR`; arrondis/base/taux de change absents |
| IC-020 | 112 emplois créés | Dimbali | `MI26-T03:R04` | `HR`; direct/indirect et période absents |
| IC-021 | 1 400 femmes formées | Dimbali | `MI26-T03:R05` | `HR`; présence ne prouve pas résultat |
| IC-022 | 13 hectares de riz cultivés | Dimbali | `MI26-T03:R06` | `HR`; site et attribution absents |
| IC-023 | 7 partenariats, dont PLAN International et PRONASEF | Dimbali | `MI26-T03:R07` | `HR`; accords et dates absents |
| IC-024 | 125 521 USD de revenu annuel, 2021-2022 | Dimbali | `MI26-T03:R08` | `HR`; répété par `IC-080` |

### Mën Nañ — Niaguiss, Saré Yoba Diéga et Sinthiou Dimb

| ID | Claim exact / valeur | Projet, territoire, période | Source indiquée / méthode / preuve | Classe et limites |
|---|---|---|---|---|
| IC-025 | 60 à 70 % des fruits pourrissaient chaque année | Mën Nañ, Niaguiss | étude PADRC citée sans référence complète | `ER`; source primaire non jointe |
| IC-026 | formation à plus de 20 produits | Mën Nañ, Niaguiss | `MI26-P172` | `HR`; personnes/recettes/période absentes |
| IC-027 | sucre réduit de 25 % dans sirops/confitures | Mën Nañ, Niaguiss | `MI26-P173` | `HR`; référentiel et tests absents |
| IC-028 | séchoir : 1 600 tranches, séchage en 3 jours | Mën Nañ, Niaguiss | `MI26-P174` | `HR`; conditions d’essai absentes |
| IC-029 | 15 menuisiers formés | Mën Nañ, Niaguiss | `MI26-P174` | `HR`; preuve de formation absente |
| IC-030 | 31 emplois créés, surtout féminins | Mën Nañ, Niaguiss | `MI26-T04:R01` | `HR`; définition d’emploi absente |
| IC-031 | chiffre d’affaires cumulé 3 662 000 FCFA, 2019-2022 | Mën Nañ, Niaguiss | `MI26-T04:R02` | `HR`; comptabilité non liée |
| IC-032 | plus de 20 produits transformés | Mën Nañ, Niaguiss | `MI26-T04:R03` | `HR`; proche de `IC-026`, dédoublonnage requis |
| IC-033 | près de 250 millions de litres de lait perdus/an au Sénégal | Mën Nañ, contexte Saré Yoba | Confédération paysanne citée, sans référence | `ER`; contexte national, pas impact projet |
| IC-034 | une femme dans le bureau du GIE Aynobe | Mën Nañ, Saré Yoba | `MI26-P177` | `HR`; donnée de gouvernance agrégée, date absente |
| IC-035 | transformation du yaourt réduite de 24 h à 8 h | Mën Nañ, Saré Yoba | `MI26-P179` | `HR`; protocole absent |
| IC-036 | conservation portée d’une semaine à un mois | Mën Nañ, Saré Yoba | `MI26-P179` | `HR`; tests microbiologiques/conditions absents |
| IC-037 | 14 emplois créés | Mën Nañ, Saré Yoba | `MI26-T05:R01` | `HR` |
| IC-038 | bénéfice 23 552 USD, 2018-2020 | Mën Nañ, Saré Yoba | `MI26-T05:R02` | `HR`; devise/comptabilité absentes |
| IC-039 | 458 000 g de lait caillé et yaourt produits | Mën Nañ, Saré Yoba | `MI26-T05:R03` | `HR`; unité inhabituelle et période non explicitée dans la ligne |
| IC-040 | 828 habitants ; revenus 4 mois sur 12 ; 465 femmes au foyer inactives le reste de l’année | Mën Nañ, Sinthiou Dimb | `MI26-P183` | `HR`; données de contexte, sources/méthodes absentes |
| IC-041 | puits de 46 m | Mën Nañ, Sinthiou Dimb | `MI26-P183` | `HR`; mesure et localisation exactes absentes |
| IC-042 | pompe 10 L/min à un dixième du prix d’une pompe solaire | Mën Nañ, Sinthiou Dimb | `MI26-P184` | `HR`; coût de référence et essai absents |
| IC-043 | 97 emplois, dont 49 femmes entrepreneures | Mën Nañ global | `MI26-T06:R01` | `HR`; sous-totaux connus n’expliquent pas tout |
| IC-044 | panier GIE passé de 5 à plus de 25 produits | Mën Nañ global | `MI26-T06:R02` | `HR`; période et catalogue absents |
| IC-045 | chiffre d’affaires cumulé 4 218 375 FCFA | Mën Nañ global | `MI26-T06:R03` | `HR`; période/comptabilité absentes |
| IC-046 | plus d’une tonne de fruits transformés | Mën Nañ global | `MI26-T06:R04` | `HR`; période/sites absents |
| IC-047 | 1 351 litres de lait transformés | Mën Nañ global | `MI26-T06:R05` | `HR`; relation avec `IC-039` non expliquée |
| IC-048 | budget d’investissement estimé 10 152 644 FCFA | Mën Nañ global | `MI26-T06:R06` | `ES`; ne crée aucune dépense réelle |

### SHERY

| ID | Claim exact / valeur | Projet, territoire, période | Source indiquée / méthode / preuve | Classe et limites |
|---|---|---|---|---|
| IC-049 | 86,95 % utilisent des serviettes jetables | SHERY, étude Pikine/Guédiawaye, 2017 | Speak Up Africa citée sans rapport lié | `ER`; population/échantillon absents |
| IC-050 | 31,85 % n’ont pas de revenu | SHERY, même étude | idem | `ER` |
| IC-051 | financement par mère 30,37 %, mari 18,43 %, petit ami 29,33 % | SHERY, même étude | idem | `ER`; catégories/total non expliqués |
| IC-052 | produit à 4 couches, porté 4 à 6 heures avant lavage | SHERY | `MI26-P194` | `HR`; caractéristique/consigne, pas impact ; validation sanitaire absente |
| IC-053 | budget : prototypes importés 2 353 000 ; communication 275 000 ; tisane 60 000 ; packaging 70 000 FCFA | SHERY | `MI26-T07:R01:R04` | `ES`/budget ; prix, quantités et approbation absents |
| IC-054 | total budgétaire 2 758 000 FCFA | SHERY | `MI26-T07:R05`; somme arithmétique cohérente | `ES`; aucun paiement réel |

### Terrasen et Aquatus

| ID | Claim exact / valeur | Projet, territoire, période | Source indiquée / méthode / preuve | Classe et limites |
|---|---|---|---|---|
| IC-055 | six villages, plus de 33 000 habitants | Terrasen, commune de Ndiedieng | `MI26-P198` | `UV`; population/source absentes |
| IC-056 | Haffé : 1 226 habitants, 58 % de femmes, sans électricité, à 220 km de Dakar | Terrasen | `MI26-P198` | `UV`; données de contexte non sourcées |
| IC-057 | plus de 700 agriculteurs ; surfaces +50 % ; « jusqu’à cinq fois plus d’économies d’eau » | Terrasen, partenariat Ndiedieng | `MI26-P202` | `HR`; formulation conservée, référence et protocole absents |
| IC-058 | coût estimatif 17 200 FCFA par table | Terrasen, ESP32/micro-jardinage | `MI26-P205` | `ES`; date/prix/composants non chiffrés individuellement |
| IC-059 | carte ESP32 à moins de 5 USD | Terrasen | `MI26-P205` | `ES`; fournisseur/date/taux absents |
| IC-060 | Ngayène : 500 ha, 13 emplois, plus de 1 500 personnes impactées | Terrasen | `MI26-P213` | `HR`; période, causalité et population absentes |
| IC-061 | Haffé : rendement +40 % et environ 15 emplois | Terrasen, futur | `MI26-P213` | `PR`; explicitement anticipé, jamais à agréger au réalisé |
| IC-062 | 3 séchoirs, 12 menuisiers, plus de 3 tonnes sur plus de 2 ans | Terrasen | `MI26-P213` | `HR`; conflit avec `IC-064` (15 menuisiers) |
| IC-063 | plus de 80 femmes formées | Terrasen | `MI26-T09:R01` | `HR` |
| IC-064 | 15 menuisiers formés | Terrasen | `MI26-T09:R02` | `HR`; conflit 12/15 avec `IC-062` |
| IC-065 | plus de 50 emplois directs créés | Terrasen | `MI26-T09:R03` | `HR`; conflit/chevauchement possible avec `IC-060`/`IC-061` |
| IC-066 | 12,5 tonnes transformées, profit 41 300 USD | Terrasen | `MI26-T09:R04` | `HR`; produit, période et comptabilité absents |
| IC-067 | profit total annuel 55 600 USD | Terrasen | `MI26-T09:R05` | `HR`; année et relation avec `IC-066` absentes |
| IC-068 | 560 heures de travail | Terrasen | `MI26-T09:R06` | `HR`; périmètre absent |
| IC-069 | 8 100 miles parcourus | Terrasen | `MI26-T09:R07` | `HR`; incompatible sans explication avec `IC-086` en km |
| IC-070 | revenus des bénéficiaires +70 % | Terrasen | `MI26-T09:R08` | `HR`; base/méthode/période absentes |
| IC-071 | plus de 17 800 personnes directement impactées | Terrasen | `MI26-T09:R09` | `HR`; définition/dédoublonnage absents |
| IC-072 | site à 294 km de Dakar | Aquatus, Ngayène Sabakh/Médina Sabakh | `MI26-P219` | `UV`; donnée géographique, pas impact |
| IC-073 | démarche de recherche en sept étapes | Aquatus, depuis 2023 | `MI26-P220` | `UV`; méthode déclarée, aucun résultat mesuré |

### Consolidation globale Enactus ESP

| ID | Claim exact / valeur | Période | Source / doublon | Classe et limites |
|---|---|---|---|---|
| IC-074 | plus de 150 000 vies impactées | non donnée | `MI26-T12:R01` | `HR`; agrégation non reproductible |
| IC-075 | plus de 200 emplois créés | non donnée | `MI26-T12:R02` | `HR`; potentiels chevauchements inter-projets |
| IC-076 | 1 597 personnes formées | non donnée | `MI26-T12:R03` | `HR`; méthode de dédoublonnage absente |
| IC-077 | 39 produits développés | non donnée | `MI26-T12:R04` | `HR`; définition/version absentes |
| IC-078 | 36 640 heures de travail | non donnée | `MI26-T12:R05` | `HR`; registre d’heures absent |
| IC-079 | 11 ODD touchés | non donnée | `MI26-T12:R06`, détaillé `T13` | `HR`; contribution non équivalente à impact ODD validé |
| IC-080 | Dimbali : 125 521 USD de revenus, 2021-2022 | 2021-2022 | `MI26-T12:R07`, répète `IC-024` | `HR` |
| IC-081 | Mën Nañ : 47 672 USD de revenus, 2021-2022 | 2021-2022 | `MI26-T12:R08` | `HR`; non réconcilié aux chiffres FCFA |
| IC-082 | total annuel 173 193 USD | 2021-2022 | `MI26-T12:R09`; somme de `IC-080+081` cohérente | `HR`; pas de taux de change/comptabilité |
| IC-083 | revenus des bénéficiaires +77 % | non donnée | `MI26-T12:R10`, répète Dimbali `IC-019` | `HR`; présenté globalement sans périmètre |
| IC-084 | malnutrition de 15 % à 0 % | non donnée | `MI26-T12:R11`, répète `IC-017` | `HR`; claim de santé sensible |
| IC-085 | 1 425 arbres plantés | cumul non daté | `MI26-T12:R12` | `HR`; survie/sites/dédoublonnage absents |
| IC-086 | 8 949 km parcourus | cumul non daté | `MI26-T12:R13` | `HR`; `IC-069` équivaut à environ 13 036 km si même portée |

### Quantités complémentaires et assertions qualitatives à ne pas perdre

| ID | Claim exact / valeur | Projet, territoire, période | Source / méthode / preuve | Classe et limites |
|---|---|---|---|---|
| IC-087 | unité opérée par 84 femmes FAVEC, produisant deux farines fortifiées, farine pâtissière, nectar et confiture ; quatre volets | Dimbali, Ngayène | `MI26-P166`; transformation, compost, séchoirs, formation | `HR`; effectif et catalogue non vérifiés |
| IC-088 | constitution du GIE Lumière avec une productrice et 30 autres femmes | Mën Nañ, Niaguiss | `MI26-P171` | `HR`; ne pas assimiler automatiquement ces membres aux 31 emplois `IC-030` |
| IC-089 | demande de code FRA pour dix aliments | Mën Nañ, Niaguiss, recueil de mars 2025 | `MI26-P175` | `TARGET`; demande ≠ autorisation obtenue |
| IC-090 | deux transferts à Mbour, dans une pépinière et un GIE | club, période 2025-2026 ; rapprochement avec FM-10 TERRASEN | `MI26-P087` ; `TT26` §§1, 3, 5.1 | `HR`; FM-10 réalisée corroborée : deux GIE et quatre tables ; formulation « pépinière/GIE » à réconcilier avec ces organisations, sans confondre nombre de transferts et nombre de tables |
| IC-091 | serviettes moins chères que les jetables, adaptées à tous les flux | SHERY | `MI26-P194` | `HR`; comparaison de prix et tests absents |
| IC-092 | tisanes persil/gingembre pour soulager les douleurs menstruelles | SHERY | `MI26-P194` | `HR`; efficacité clinique non établie, ne pas réutiliser comme conseil |
| IC-093 | optimisation pour effets bactéricides, anti-inflammatoires et antalgiques | SHERY, perspectives | `MI26-P196` | `TARGET`; ni caractéristique acquise ni validation sanitaire |
| IC-094 | autonomisation de plusieurs centaines de femmes rurales | synthèse RSE ESP | `MI26-P233` | `HR`; définition, période et méthode absentes |
| IC-095 | méthode garantissant mesure systématique ; suivi documentaire rigoureux et régulier | synthèse RSE ESP | `MI26-P239` | `HR`; revendication de gouvernance, pas résultat d’audit |
| IC-096 | 3 membres au départ, 6 l’année suivante, près de 30 en 2016-2017 ; seulement 3 anciens actifs à un moment en 2019 | club | `MI26-P043`, `P050`, `P062` | `HR`; snapshots différents, aucun registre nominatif à recréer |
| IC-097 | 1 TL, 1 SG, 8 pôles, 4 équipes projet, 2 conseillers ; réunion au moins toutes les 2 semaines | organisation rapportée | `MI26-P127:P130`, `T00` | `UV`; schéma/cadence non approuvés dans la preuve disponible |
| IC-098 | quatre pôles internes et trois zones d’intervention | Mën Nañ | `MI26-P169:P189` | `HR`; transformation, marketing/communication, monitoring et IT ; distincts des pôles du club |
| IC-099 | étudiants de la première à la cinquième année | identité de l’équipe ESP | `MI26-P118` | `HR`; description, pas règle d’éligibilité validée |
| IC-100 | film institutionnel de 77 secondes | World Cup 2022, club | `MI26-P081` | `HR`; fichier, montage final et droits absents |
| IC-101 | cinq composants : ESP32, capteur d’humidité, relais 5 V, pompe 3–5 V, réservoir | Terrasen, irrigation | `MI26-T08` | `HR`; nomenclature technique, pas schéma électrique approuvé |

Les assertions RSE arrondies « plus de 1 500 personnes formées » et « plus de 170 000 USD en 2021-2022 » (`MI26-P233:P235`) répètent `IC-076` et `IC-082` sous une précision moindre ; elles n’ajoutent pas de population ni de revenu. Les formations maraîchage/vente et extensions prévues à Sinthiou Dimb (`MI26-P184`) sont `PROJECTION`; l’extension nationale de Dimbali (`P167`), l’e-commerce/FRA de Mën Nañ (`P189`), la formalisation SHERY (`P196`) et les nouveaux ciblages Terrasen (`P216`) sont des `TARGET`, sans impact réalisé associé.

### Conséquences de vérité

1. Toutes les valeurs doivent entrer comme `Claim(status=reported_unverified)`, jamais dans une table d’agrégats validés.
2. La source MI26 doit être reliée à l’assertion exacte ; les neuf sources citées par MI26 deviennent des sources candidates, pas des preuves implicitement présentes.
3. Les doublons (`IC-024/080`, `IC-019/083`, `IC-017/084`) doivent être des relations `repeats`, pas de nouvelles valeurs additionnées.
4. Une claim agrégée doit déclarer sa formule, ses claims membres, leurs périodes/sites et la règle de dédoublonnage.
5. Les valeurs de santé, sécurité alimentaire ou menstruelle requièrent une revue experte et éthique avant diffusion.

## 14. SDGs and RSE

| ODD rapporté | Projets associés par MI26 | Statut |
|---|---|---|
| 1 — Pas de pauvreté | Dimbali, Mën Nañ, Terrasen | contribution narrative |
| 2 — Faim zéro | Mën Nañ, Terrasen, Dimbali | contribution narrative |
| 3 — Bonne santé et bien-être | SHERY, Mën Nañ, Dimbali | revue santé obligatoire |
| 5 — Égalité entre les sexes | SHERY, Mën Nañ, Terrasen | contribution narrative |
| 6 — Eau propre et assainissement | Deconaane, Aquatus, Terrasen | Aquatus/Terrasen à justifier par outcome |
| 8 — Travail décent et croissance | Mën Nañ, SHERY, Terrasen | emplois/revenus non validés |
| 10 — Inégalités réduites | SHERY, Mën Nañ | contribution narrative |
| 12 — Consommation/production responsables | SHERY, Mën Nañ, Terrasen | la cellule source comporte une corruption de caractères après Terrasen |
| 13 — Mesures climat | SHERY, SunCuiz | causalité à expliciter |
| 15 — Vie terrestre | Dimbali/reboisement | survie des arbres non documentée |
| 17 — Partenariats | SHERY, Mën Nañ | accords/partenariats à relier |

La synthèse RSE reprend quatre volets : plus de 1 500 personnes formées et autonomisation de femmes ; plus de 200 emplois et plus de 170 000 USD en 2021-2022 ; arbres, séchage solaire, irrigation, réutilisable et zéro déchet ; gouvernance à huit pôles/quatre projets/deux conseillers et méthode en six étapes. Elle est utile comme **plan de narration RSE**, mais chaque phrase hérite du statut des claims sources. Le passage affirmant que la mise à jour de Mën Nañ en juin 2026 prouve la maturité du suivi est une interprétation éditoriale, pas une preuve.

Le produit doit modéliser `SDGContribution(project, sdg, rationale, outcome_claim_ids, period, status, reviewer)` ; cocher un ODD ne suffit pas. Un export RSE ne doit inclure que des contributions et claims au statut autorisé, avec notes de méthode et période.

## 15. Competitions and awards

### Palmarès rapporté

| ID | Année | Compétition/organisme | Participation distincte | Prix/résultat rapporté | Source / contrôle |
|---|---:|---|---|---|---|
| AW-01 | 2016 | Fondation Sonatel | événement non décrit | premier prix d’excellence | `MI26-T14:R01`; projet/date exacte à relier |
| AW-02 | 2016 | Enactus National Competition | participation nationale | vice-champion national | `MI26-T14:R02` |
| AW-03 | 2016 | Uhodari | participation | quatre prix sur cinq | `MI26-T14:R03`; nature des quatre prix absente |
| AW-04 | 2017 | Enactus National Competition | participation nationale | champion national après audit | `MI26-P055`, `T14:R04` |
| AW-05 | 2017 | Enactus World Cup Londres | qualification | **aucune présence effective**, visas refusés | `MI26-P055`; qualification ≠ participation |
| AW-06 | 2018 | Enactus National Competition | participation nationale | champion national | `MI26-T14:R05` |
| AW-07 | 2018 | Enactus World Cup, États-Unis | présence effective | demi-finaliste | `MI26-P060`, `T14:R06` |
| AW-08 | 2022 | Enactus World Cup | sélection sur dossier, visas et présence rapportés | résultat non donné | `MI26-P081`; lieu absent |
| AW-09 | 2023 | Enactus National Competition | participation nationale | champion national | `MI26-P083`, `T14:R07` |
| AW-10 | 2023 | Salon du Polytechnicien | SHERY | premier prix | `MI26-P196`, `T14:R08` |
| AW-11 | 2025 | Polytech’Innovation | Terrasen | premier prix | `MI26-P215`, `T14:R09` |
| AW-12 | 2025 | Polytech’Innovation | Aquatus | deuxième prix | `MI26-P221`, `T14:R10` |
| AW-13 | 2025 | SENAYSKILLS | Terrasen | deuxième prix | `MI26-P215`, `T14:R11` |

Le tableau source contient **11 distinctions** (`AW-01:04`, `AW-06:07`, `AW-09:13`) ; `AW-05` et `AW-08` sont ajoutés ici comme participations/qualifications nécessaires pour ne pas confondre les concepts.

Le claim « triple champion national en 2017, 2018 et 2023 » est cohérent avec le tableau. Le claim « représentant le pays à quatre reprises à la World Cup » ne l’est pas avec la narration disponible : MI26 établit une qualification sans voyage en 2017, une présence effective en 2018 et une présence rapportée en 2022 ; la quatrième occurrence n’est pas identifiée. Le modèle doit séparer `Competition`, `CompetitionEdition`, `Participation(status=qualified|registered|attended|withdrew|blocked)`, `Award` et `Evidence`.

## 16. Archives, media and gallery

MI26 contient deux logos institutionnels, une photo de groupe et un organigramme. Aucun fichier n’a de texte alternatif. La photo de groupe montre de nombreuses personnes identifiables ; elle est `CONSENT_OR_REVIEW_REQUIRED`. Les logos nécessitent un contrôle de marque/licence. L’organigramme est utile pour le schéma haut, mais inutilisable pour les cartes projet basses sans correction éditoriale.

La galerie prévoit six périodes : 2015-2016, 2017-2018, 2019-2020, 2021-2022, 2023-2024 et 2025-2026. Ce sont des espaces réservés, non des preuves de l’existence de photos. Les références médias L’Observateur, 2STV et RFI manquent de date, titre, URL, copie, auteur et droits ; elles doivent rester des notices à compléter.

Une galerie exploitable exige : fichier, SHA, date/période, lieu, légende, personnes éventuellement identifiées sous accès restreint, projet/génération/événement liés, auteur ou détenteur, base de diffusion, visibilité, texte alternatif, statut de validation et retrait. Les médias ne doivent pas être rendus publics parce qu’ils figurent dans un document interne.

Les neuf sources déclarées par MI26 sont : histoire interne, présentation/réalisations 2020, présentation 2026, documentation Mën Nañ juin 2026, présentation SHERY, présentation Terrasen juillet 2026, pitch anglais Terrasen, recherche Aquatus et tableau des voyages 2021-2025. Elles sont des références candidates ; MI26 ne fournit ni SHA, ni chemin stable, ni version, ni approbation.

Le glossaire `MI26-T23` est à conserver comme référence versionnée : AGR = Activité Génératrice de Revenus ; GIE = Groupement d’Intérêt Économique ; ODD = Objectifs de Développement Durable ; QHSE = Qualité, Hygiène, Sécurité, Environnement ; FAVEC = association regroupant les femmes de Ngayène selon la définition donnée ; World Cup = compétition mondiale Enactus ; RSE = Responsabilité Sociétale des Entreprises. FAVEC n’est pas développé comme acronyme complet dans la source : ne pas l’inventer.

## 17. Living-memory data model

### Cœur temporel et éditorial

| Objet | Champs minimaux | Relations/contraintes |
|---|---|---|
| `InstitutionalMemoryEdition` | titre, période couverte, version, owner_role, status, published_at | sélection éditoriale de sources/events, jamais source primaire |
| `SourceAssertion` | source_id, locator, text_digest, classification, confidence, reviewer | unité de traçabilité de tout fait |
| `HistoricalEvent` | type, date_precision, start/end, title, summary, status, visibility | liens projets, générations, lieux, missions, participations, assertions |
| `Person` | identité minimale, display policy, consent state | aucune création depuis un nom source sans revue |
| `Role` | nom canonique, catégorie, portée | versionnable, indépendant des personnes |
| `RoleTerm` | person, role, organization_unit, dates/précision, status | chevauchements permis ; source obligatoire |
| `Generation` | label, season, dates, narrative, snapshot status | membres uniquement sous autorisation |
| `OrganizationUnit` | type, nom, alias, parent, validité | pôles et équipes par saison |
| `MembershipHistory` | person, generation/unit, rôle, dates, visibility | privé par défaut |
| `Handover` | rôle/unité, sortant/entrant, checklist, assets, accepted_at | accès restreint et audit |
| `ProjectIdentity` | nom canonique, aliases, canonicalization_status | distinct de `ProjectSeason` |
| `ProjectRelationship` | source, cible, type merge/evolves/renamed/split | aucune fusion destructrice |
| `ProjectSeason` | project, season, lifecycle_state, owner, decision | statut daté, pas champ global écrasé |
| `Place` / `InterventionSite` | hiérarchie, alias, type, statut géocodage | communauté/GIE séparés |
| `FieldMission` et sous-objets | modèle section 11 | statut planifié/réalisé obligatoire |
| `Technology` / `TechnologyVersion` | nom, famille, version, sécurité, statut | tests, transferts et projets liés |
| `Claim` | valeur, unité, type, période, territoire, méthode, validation | peut être texte/intervalle ; zéro distinct de non renseigné |
| `ClaimEvidence` | claim, source/file, locator, rôle de preuve, access | validation séparée de l’upload |
| `SDGContribution` | projet, ODD, justification, période, statut | outcomes validés facultatifs mais explicités |
| `CompetitionEdition` / `Participation` / `Award` | édition, niveau, statut de présence, rang/prix | qualification ≠ présence ≠ prix |
| `MediaAsset` / `MediaRights` | fichier, légende, alt, droits, consentement, visibilité | retrait et échéance possibles |
| `EditorialDecision` | objet, décision, autorité, date, motif | audit et version précédente conservés |

### Workflow de mémoire vivante

| Déclencheur opérationnel | Écriture structurée | Automatique | Curaté/validé |
|---|---|---|---|
| réunion → décision → tâche | événement candidat avec liens | création du candidat et liens | titre/résumé/publication |
| nouveau mandat | `RoleTerm` | détection de transition après décision | dates, personne affichable, visibilité |
| création de projet | `ProjectIdentity` + `ProjectSeason` + événement | événement candidat | nom canonique et gate de lancement |
| changement de statut | transition + événement | journal immuable | motif, autorité, statut historique publiable |
| mission | `FieldMission`, sites, projets, documents | événement à la clôture | statut réalisé, légende et synthèse |
| transfert | `TechnologyTransfer` | lien mission/technologie | destinataire, version, sécurité, preuve |
| mesure d’impact | `Claim` + méthode + preuve | agrégation seulement après validation | contrôle qualité et diffusion |
| compétition/prix | participation puis award éventuel | événement candidat | niveau, présence, rang et preuve |
| clôture de saison | snapshot génération/projets/pôles | génération du brouillon | revue gouvernance et confidentialité |
| passation | `Handover` et archive | checklist/rappels | acceptation, exceptions, clôture d’accès |

Les automatismes créent des **candidats non publiés**. Aucune narration, identification de personne, claim d’impact ou attribution de prix ne devient publique sans décision éditoriale.

## 18. Heritage product UX

La rubrique « Mémoire / Héritage Enactus ESP » doit être une lecture reliée, filtrable et sourcée :

| Écran | Contenu | Réutilisation actuelle | Extension nécessaire |
|---|---|---|---|
| Overview | identité, chiffres uniquement validés, périodes clés, dernière édition | Archives/Hall of Fame | statut de preuve et édition mémoire |
| Timeline | événements 2015-2026, précision de date, filtres | cartes Hall of Fame | nouveau modèle/écran chronologique |
| Generations | snapshots de saison et albums | Seasons, Alumni | `Generation`, droits et snapshot |
| Leadership | mandats, rôles, transitions, passations | Users/Roles/Alumni | `RoleTerm`, dates et publication sélective |
| Projects through time | identité, alias, états par saison, filiation | Projects + ArchivedProject | identité canonique et relations temporelles |
| Territories | lieux/sites et projets/missions | champs location libres | `Place`, sites, vue liste avant cartographie |
| Field missions | dossier mission, sites, transferts, collectes | Events/Documents/Finance | modèles mission spécialisés |
| Technologies | versions, essais, projets, transferts | Documents/Projects | registre OP-15 étendu |
| Impact claims/evidence | claim, statut, période, méthode, preuve | Impact | supprimer fallbacks ; provenance claim-level |
| Competitions & awards | éditions, qualification, présence, prix | Archive competitions/awards | états de participation et preuve |
| Media & Gallery | collections, légendes, droits | ArchiveMedia | droits/consentement/alt/collections |
| Archives & Sources | document logique, version, SHA, assertions | Documents/Archives | provenance/canonicalité OP-02 |
| Values & Methodology | référence approuvée et version | Academy/Documents possibles | pages éditoriales/version de méthode |

Une fiche affiche toujours : « rapporté », « corroboré », « validé », « contesté » ou « projection ». Le public ne voit pas les preuves restreintes ; il voit la source institutionnelle publiable, la période et une note méthodologique. Les équipes internes peuvent naviguer du récit à l’assertion, puis à la preuve et à la décision.

## 19. Comparison with reports 00-13

### Conclusions par rapport

| Rapport | Classification de l’apport MI26 | Effet net |
|---|---|---|
| `R00` Synthèse | `CONFIRMS_EXISTING_FINDING` | confirme qu’il faut relier objets et preuves plutôt que republier des documents |
| `R01` Gouvernance | `EXTENDS_EXISTING_FINDING` | ajoute une troisième nomenclature : huit pôles avec Finances et Trésorerie, plus une cadence bimensuelle rapportée |
| `R02` Membres/leadership | `EXTENDS_EXISTING_FINDING` | apporte sept mandats, des pionniers et transitions ; confirme le besoin de passation |
| `R03` Pôles | `CONTRADICTS_EXISTING_FINDING` | les sept pôles observés deviennent huit dans MI26 ; la configuration saisonnière reste la bonne réponse |
| `R04` Projets | `EXTENDS_EXISTING_FINDING` | donne quinze identités/évolutions, filiation, territoires et détails historiques ; l’attribution de FM-10 à TERRASEN est corroborée par `TT26`, déjà référencé dans R04 |
| `R05` Finance/partenariats | `CONFIRMS_EXISTING_FINDING` | budgets et revenus historiques montrent le besoin de distinguer estimation, flux réel et preuve |
| `R06` Impact/compétitions | `CONFIRMS_EXISTING_FINDING` | les 101 claims renforcent l’exigence de méthode, période, preuve et séparation projection/réalisé |
| `R07` Communication/événements | `EXTENDS_EXISTING_FINDING` | consolide dix missions et trois références média non datées ; FM-10 correspond au transfert TERRASEN réalisé à Mbour en août 2026, documenté par `TT26` déjà référencé dans R07, sans reprise des identités individuelles |
| `R08` Archives | `EXTENDS_EXISTING_FINDING` | transforme l’archive documentaire en besoin de mémoire temporelle et éditoriale |
| `R09` Gap analysis | `EXTENDS_EXISTING_FINDING` | Archives existe davantage qu’un simple dépôt, mais timeline, mandats, missions, territoires et know-how manquent |
| `R10` Backlog 18 opportunités | `NEW_REQUIREMENT` | huit exigences mémoire complètent le backlog sans dupliquer OP-01/02/03/08/12/13/15 |
| `R11` Imports | `CONFIRMS_EXISTING_FINDING` | aucune valeur, identité ou photo MI26 ne doit être importée automatiquement |
| `R12` Conflits/décisions | `EXTENDS_EXISTING_FINDING` | 20 conflits/incertitudes et 24 décisions consolidées dans ce rapport |
| `R13` Couverture | `EXTENDS_EXISTING_FINDING` | MI26 est une source additionnelle hors catalogue ; les totaux 332/314 restent ceux du corpus antérieur |

### Vingt processus existants revisités

| Processus | Classification MI26 | Conséquence |
|---|---|---|
| GOV-01 réunion/décision | `CONFIRMS_EXISTING_FINDING` | source d’événements candidats et décisions traçables |
| GOV-02 nomination/passation | `EXTENDS_EXISTING_FINDING` | `RoleTerm`, génération et historique des mandats |
| MEM-01 recrutement | `ALREADY_IDENTIFIED` | ne pas convertir les pionniers en comptes |
| MEM-02 intégration/affectation | `ALREADY_IDENTIFIED` | snapshot saisonnier, pas historique reconstruit sans preuve |
| MEM-03 succession | `CONFIRMS_EXISTING_FINDING` | mémoire future explicitement conçue pour la transmission |
| POL-01 roadmap/revue | `CONFIRMS_EXISTING_FINDING` | restructuration 2025-2026 et cadence rapportée |
| POL-02 demande inter-pôles | `ALREADY_IDENTIFIED` | aucun changement de workflow imposé par MI26 |
| PRJ-01 création/validation | `EXTENDS_EXISTING_FINDING` | méthode six étapes et événement `PROJECT_CREATED` |
| PRJ-02 graduation/transfert/archive | `CONFIRMS_EXISTING_FINDING` | fin Dimbali, évolution Deconaane+, ancien idéal d’autonomie |
| FIN-01 budget projet/pôle | `CONFIRMS_EXISTING_FINDING` | budgets SHERY/Mën Nañ/ESP32 restent estimatifs |
| FIN-02 dépense/justificatif | `CONFIRMS_EXISTING_FINDING` | aucune dépense ne peut être créée depuis MI26 |
| FIN-03 fundraising/partenariat | `EXTENDS_EXISTING_FINDING` | partenaires historiques et dépôts RSE, dates/accords à relier |
| IMP-01 indicateur | `CONFIRMS_EXISTING_FINDING` | 101 cas d’essai pour le modèle de claim |
| IMP-02 dossier compétition | `EXTENDS_EXISTING_FINDING` | séparer édition, qualification, présence et prix |
| COM-01 campagne externe | `EXTENDS_EXISTING_FINDING` | galerie, médias et droits éditoriaux |
| EVT-01 mission terrain | `EXTENDS_EXISTING_FINDING` | dix lignes réelles définissent le modèle minimal |
| TRN-01 formation | `CONFIRMS_EXISTING_FINDING` | formations liées aux transferts et technologies/version |
| KM-01 référence canonique | `CONFIRMS_EXISTING_FINDING` | MI26 doit être une édition reliée à des assertions, non l’autorité unique |
| KM-02 passation annuelle | `EXTENDS_EXISTING_FINDING` | génération snapshot + mise à jour de mémoire |
| DATA-01 import en deux étapes | `CONFIRMS_EXISTING_FINDING` | preview, minimisation, dédoublonnage et double validation |

### Effet sur les 18 opportunités et huit exigences nouvelles

Les OP-01, 02, 03, 08, 10, 12, 13 et 15 sont **étendues** ; OP-04/05/06/07/11/14/16/17 sont **confirmées** ; OP-09 et OP-18 restent inchangées. Aucune opportunité n’est supprimée.

| ID | Nouvelle exigence | Priorité | Dépendances, sans doublon |
|---|---|---|---|
| NR-01 | chronologie institutionnelle avec précision de date et statut éditorial | P1 | OP-02, OP-03 |
| NR-02 | générations, mandats et historique d’appartenance | P1 | OP-12, Seasons, Roles |
| NR-03 | identité projet temporelle et relations merge/evolve/rename | P0 | extension OP-03 |
| NR-04 | référentiel lieux, sites et communautés/GIE séparés | P1 | OP-08 |
| NR-05 | assertion source et graphe claim→preuve→validation→agrégat | P0 | extension OP-01/02/10 |
| NR-06 | édition mémoire et workflow de curation/publication | P1 | Archives, KM-01/02 |
| NR-07 | éditions de compétition, participation et prix séparés | P1 | extension IMP-02 |
| NR-08 | droits média, consentement, texte alternatif et collections générationnelles | P1 | extension OP-13 |

## 20. Comparison with current EnactSpace

### Périmètre de code contrôlé

Le dépôt application a été vérifié au SHA `6e516950e820f74846a5065b6eb798b3993f2fb9`. Treize domaines backend ont été inspectés via modèles et routes : projects, seasons, alumni, archives, documents, impact, poles, events, finance, academy, recruitment, users/members et audit. Les familles frontend Projects, Archives, Alumni, Impact et Events, ainsi que `app_router.dart` et `app_shell.dart`, ont été contrôlées. Le statut Git est resté propre.

### Matrice mémoire → produit

| Exigence mémoire | Classification | Constat au SHA contrôlé |
|---|---|---|
| saisons | `EXISTING_SUFFICIENT` pour période simple | `Season` a nom, dates, courant, archivé ; pas snapshot génération |
| projets courants | `EXISTING_NEEDS_EXTENSION` | dates, saison, statut, problème/solution existent ; alias/filiation/statut par saison manquent |
| projets historiques | `EXISTING_NEEDS_EXTENSION` | `ArchivedProject` existe ; listes JSON et année unique ne forment pas une histoire relationnelle |
| archives génériques | `EXISTING_NEEDS_EXTENSION` | validation, visibilité, projet/pôle/document/fichier existent ; SHA, version logique et assertions manquent |
| prix | `EXISTING_NEEDS_EXTENSION` | `Award` existe ; preuve/validation propre et édition structurée manquent |
| compétitions | `EXISTING_NEEDS_EXTENSION` | `CompetitionRecord` existe ; qualification/présence distinctes manquent |
| médias/galerie | `EXISTING_NEEDS_EXTENSION` | `MediaArchive` existe ; droits, consentement, alt, personnes et collection manquent |
| Hall of Fame | `EXISTING_SUFFICIENT` comme vue éditoriale | ne doit pas devenir la source primaire d’événements |
| historique d’impact | `EXISTING_NEEDS_EXTENSION` et actuellement risqué | clé métrique unique et statut par défaut `validated`; période/site/méthode insuffisants |
| impact courant | `EXISTING_NEEDS_EXTENSION` et `PR-2C` obligatoire | profils/métriques/preuves/validation existent |
| impact de repli | `NEW_MODEL_REQUIRED` pour vérité | le code dérive bénéficiaires depuis statut/documents et impose des minima Terrasen : à supprimer |
| personnes/alumni | `EXISTING_NEEDS_EXTENSION` | profils et mentorats existent ; politique d’affichage historique et consentement manquent |
| rôles/mandats | `NEW_MODEL_REQUIRED` | `UserRole` n’a ni début, ni fin, ni saison/unité ; impossible de représenter sept mandats correctement |
| générations | `NEW_MODEL_REQUIRED` | Season n’est pas un snapshot éditorial de cohorte |
| pôles | `EXISTING_NEEDS_EXTENSION` | unité saisonnière existe ; alias/validité/décision canonique manquent |
| événements | `EXISTING_NEEDS_EXTENSION` | type, lieu, dates, projet/pôle/budget/rapport existent ; dossier mission et multi-sites manquent |
| missions/transferts/collectes | `NEW_MODEL_REQUIRED` | objets spécialisés absents |
| territoires/sites | `NEW_MODEL_REQUIRED` | `location` libre ne porte pas hiérarchie/alias/sites multi-projets |
| technologies/know-how | `NEW_MODEL_REQUIRED` | documents/projets peuvent héberger des fichiers, pas versions/tests/transferts/sécurité |
| timeline | `NEW_UI_REQUIRED` | quelques widgets utilisent une apparence de timeline, aucune chronologie institutionnelle |
| leadership/générations | `NEW_UI_REQUIRED` | annuaire Alumni ne remplace pas l’histoire des mandats |
| sources/provenance | `EXISTING_NEEDS_EXTENSION` | `source_label/source_url` partiels ; pas d’assertion/localisateur/SHA/graphe canonique |
| budgets et claims financiers | `EXISTING_NEEDS_EXTENSION` | Finance gère comptes, frais, paiements, allocations et transactions club liées aux projets/pôles ; pas de budget de mémoire versionné ni rapprochement claim→transaction |
| valeurs/méthode en Academy | `EXISTING_NEEDS_EXTENSION` | cours, leçons, ressources, rôles cibles et parcours existent ; réutiliser ces capacités et ajouter provenance/version/revue de sécurité |
| recrutement et futur historique | `EXISTING_SUFFICIENT` comme source opérationnelle | campagnes liées aux saisons, candidatures/avis/conversion existent ; aucune candidature historique à reconstituer depuis MI26 |
| comptes/membres | `EXISTING_NEEDS_EXTENSION` | annuaire, rôles, approbation/suspension/alumni existent ; un nom historique sans compte exige un objet Person séparé |
| audit des décisions mémoire | `EXISTING_NEEDS_EXTENSION` | AuditLog porte acteur, entité, ancienne/nouvelle valeur et date ; réutiliser avec minimisation et périmètres mémoire, pas comme chronologie publique brute |
| expérience Héritage | `NEW_UI_REQUIRED` | Archives offre déjà collections, projets, compétitions, médias et statistiques ; composition dédiée absente |
| cartographie avancée | `POST_V1` | commencer par listes/relations ; carte seulement après normalisation et consentement géographique |

Le backend Archives dispose de huit modèles et 34 endpoints, dont projets historiques, awards, compétitions, médias, documents, Hall of Fame et statistiques. Il embarque toutefois des valeurs initiales : 10 projets historiques, 6 awards, 5 compétitions, 5 entrées Hall of Fame et 9 totaux d’impact. Ces constantes sont des contenus de démonstration/héritage non probants. Plusieurs divergent de MI26 ou sont moins complets ; elles ne doivent pas être « validées » par simple rapprochement textuel.

## 21. Conflicts and uncertainties

Le registre consolide les huit conflits de `R12` et douze apports/raffinements MI26, soit **20 entrées ouvertes**.

C-12 reste ouverte comme incohérence de date éditoriale, et non comme doute sur la réalisation de FM-10 ; ce reclassement ne change pas le nombre d’entrées.

| ID | Conflit/incertitude | Effet requis |
|---|---|---|
| C-01 | texte local : six pôles annoncés/sept listés ; cadrage : sept ; MI26 : huit | décision par saison et alias |
| C-02 | Terrasen/Terassen, SHERY/Cherry, Mën Nañ/Nan/Nagn, Soukhali/Soukhalii | identité canonique sans fusion automatique |
| C-03 | SHERY actif dans cadrage, transfert/vente évoqué en 2026 | statut daté et type de transition |
| C-04 | statuts du portefeuille entre cadrage, PV 2026 et MI26 | revue projet par projet |
| C-05 | moringa/noix de cajou entre CAJOR et Mën Nañ | filiation, séparation ou propriété |
| C-06 | règles de participation/membre de sources non datées | politique courante adoptée |
| C-07 | résultats, projections et récits mêlés | modèle de claim et validation |
| C-08 | versions distinctes du cahier de cadrage | décision canonique inchangée |
| C-09 | introduction des voyages dit 2021-2025, table inclut la mission TERRASEN réalisée en août 2026 (`FM-10`, `TT26`) | corriger la portée chronologique annoncée, sans modifier le statut réalisé de FM-10 |
| C-10 | « quatre » représentations World Cup, mais 2017 non-participation, 2018 et 2022 seulement établies | retrouver la quatrième ou corriger le claim |
| C-11 | trois titres nationaux sont listés, mais le lien titres→qualifications/présences n’est pas complet | modéliser éditions et preuves séparément |
| C-12 | `EDITORIAL DATE INCONSISTENCY` : la mise à jour MI26 du 22/07/2026 précède le contenu relatif à FM-10, mission TERRASEN réalisée à Mbour du 14 au 16 août 2026 et corroborée par `TT26` | faire rectifier ou expliquer la date/version éditoriale de MI26 ; la réalisation de FM-10 n’est pas en suspens |
| C-13 | Soukhali Gokh : Sébikotane dans la chronologie, Darou Thioub/Keur Massar dans la fiche | conserver deux assertions jusqu’à arbitrage |
| C-14 | Javelisel : « eau de mer » puis « eau et sel » | préciser procédé/version sans correction silencieuse |
| C-15 | Terrasen : 12 menuisiers dans le récit, 15 dans la table | période/site/dédoublonnage |
| C-16 | 8 100 miles Terrasen contre 8 949 km global | unité/périmètre ou erreur à corriger |
| C-17 | organigramme : cartes projet basses corrompues/dupliquées | ne pas importer l’image comme structure |
| C-18 | chiffres Enactus mondial sans édition, URL ni date | vérification externe avant publication |
| C-19 | maturité de gouvernance déduite d’une mise à jour Mën Nañ de juin 2026 | retirer l’inférence ou ajouter preuve |
| C-20 | statistiques/fallbacks statiques EnactSpace ne correspondent pas à une validation des 101 claims | supprimer dérivation et réviser seeds |

## 22. Institutional decisions required

`SCHEMA_BLOCKER` bloque un modèle sûr ; `POPULATION_BLOCKER` permet le développement mais bloque l’import/publication ; `NON_BLOCKING` peut attendre une curation ultérieure.

| ID | Décision | Pourquoi / preuve | Conflit | Requise avant | Owner recommandé | Statut |
|---|---|---|---|---|---|---|
| D-01 | adopter le modèle claim/source/preuve/validation | 101 claims sans validation | C-07,C-20 | PR-2C | Impact + IT | `SCHEMA_BLOCKER` |
| D-02 | définir zéro, inconnu, estimation, projection et agrégation | fallbacks actuels et T12 | C-07,C-20 | PR-2C | Impact | `SCHEMA_BLOCKER` |
| D-03 | adopter identité projet + alias + états par saison | 15 noms/évolutions | C-02,C-04 | PR-2D | Gouvernance + projets | `SCHEMA_BLOCKER` |
| D-04 | adopter événement, précision de date et curation | années, plages, dates exactes | C-09,C-12 | PR-2D | Secrétariat/Archives | `SCHEMA_BLOCKER` |
| D-05 | adopter Person/Role/RoleTerm/Generation avec visibilité et périmètres FA/membre | sept mandats incomplets ; permissions FA et appartenance pôle/projet non arbitrées dans R12 | C-06 | schéma PR-2D ; politiques avant activation des droits | Gouvernance + privacy | `SCHEMA_BLOCKER` |
| D-06 | adopter Place/Site/Mission/Transfer/Collection | dix missions multi-sites | C-13 | PR-2D | Projets/Organisation/Impact | `SCHEMA_BLOCKER` |
| D-07 | désigner MI26 comme brouillon, référence ou édition canonique | source hors catalogue, assertions secondaires | — | peuplement mémoire | Archives/Gouvernance | `POPULATION_BLOCKER` |
| D-08 | valider la chronologie 2015-2026 | événements rapportés | C-09:C-12 | publication timeline | Archives + alumni mandatés | `POPULATION_BLOCKER` |
| D-09 | valider les sept mandats et dates exactes | `MI26-T22` | — | publication leadership | Gouvernance/FA | `POPULATION_BLOCKER` |
| D-10 | définir politique de publication des noms historiques | rôles/pionniers/porteurs | — | affichage public | Privacy + Gouvernance | `POPULATION_BLOCKER` |
| D-11 | adopter la version datée des textes locaux, les pôles et frontières Finance/Gestion | trois nomenclatures ; adoption du texte local non démontrée dans R01/R12 | C-01,C-06 | peuplement unités et règles opérationnelles | Gouvernance | `POPULATION_BLOCKER` |
| D-12 | fixer noms/alias/statuts des 15 projets, transfert SHERY et propriété des actifs à graduation | matrices MI26/R04 et décisions antérieures R12 | C-02:C-05 | import projets et toute transition réelle | Gouvernance + chefs projet | `POPULATION_BLOCKER` |
| D-13 | décider Deconaane→Deconaane+ | évolution ou projet distinct | C-14 connexe | relation projet | Archives + alumni | `POPULATION_BLOCKER` |
| D-14 | décider CAJOR↔Mën Nañ | recouvrement moringa/cajou | C-05 | import composants | Gouvernance/Chimie | `POPULATION_BLOCKER` |
| D-15 | arbitrer Soukhali et Javelisel | lieux/procédés divergents | C-13,C-14 | publication fiches | Archives + anciens responsables | `POPULATION_BLOCKER` |
| D-16 | valider les détails et autoriser le peuplement canonique en production des missions ; pour FM-10, valider les liens TERRASEN/sites/GIE/livrables/provenance, sans redemander si elle a eu lieu | FM-10 réalisée et corroborée par `TT26` ; détails MI26/TT26 à réconcilier, incohérences éditoriales à traiter séparément | C-09,C-12 | import canonique des missions en production | Organisation/Technique | `POPULATION_BLOCKER` |
| D-17 | valider participation World Cup et palmarès complet | quatrième présence absente | C-10,C-11 | publication palmarès | Veille + Gouvernance | `POPULATION_BLOCKER` |
| D-18 | corroborer les claims et adopter les paramètres/seuils d’approbation financiers actuels | 0/101 claim vérifiée ; R05/R12 laissent les seuils ouverts | C-07,C-15,C-16 | tout chiffre public et activation des règles Finance | Impact/Finance/Gouvernance | `POPULATION_BLOCKER` |
| D-19 | valider dictionnaire ODD et justification par période | 11 associations narratives | — | export RSE | Impact/RSE | `POPULATION_BLOCKER` |
| D-20 | soumettre claims santé/alimentaire/menstruelle à revue experte | Javelisel, Dimbali, SHERY, recettes | — | publication/réutilisation | FA + experts | `POPULATION_BLOCKER` |
| D-21 | définir droits, consentement, alt, retrait et durées de conservation par catégorie | photo identifiable, logos, presse ; rétention ouverte dans R12 | C-17 | import média/données historiques | Communication + privacy | `POPULATION_BLOCKER` |
| D-22 | décider retrait des métadonnées personnelles de fichiers | propriété Word personnelle | — | publication binaire | Archives + privacy | `POPULATION_BLOCKER` |
| D-23 | nommer owner et cadence de l’édition mémoire | espace de mise à jour futur | — | exploitation annuelle | Secrétariat/Archives | `NON_BLOCKING` |
| D-24 | décider si les ambitions omises de l’ancienne histoire restent actives | autonomie, revenus, compétitions, nom | — | stratégie post-V1 | Gouvernance | `NON_BLOCKING` |

Comptage : D-01 à D-06 = 6 `SCHEMA_BLOCKER`; D-07 à D-22 = 16 `POPULATION_BLOCKER`; D-23 à D-24 = 2 `NON_BLOCKING`. Le développement du schéma peut avancer sans résoudre le détail historique, mais aucune donnée litigieuse ne doit être publiée avant sa décision correspondante.

Les douze validations antérieures de `R12` ne sont pas abandonnées : texte adopté/date d’effet → D-11 ; pôles/alias → D-11 ; permissions Faculty Advisor → D-05 ; appartenance pôle/projet → D-05 ; noms/statuts projets → D-12 ; transfert SHERY → D-12 ; CAJOR/Mën Nañ → D-14 ; métriques/preuves → D-18 ; paramètres/seuils financiers → D-18 ; actifs à graduation → D-12 ; droits média → D-21 ; rétention → D-21. Les politiques de droits et de finance restent des prérequis à leur activation, même si le schéma peut être développé avant leur arbitrage.

## 23. V1 roadmap impact

| Étape | Changement recommandé |
|---|---|
| PR-2B Auth mobile / sessions / PostgreSQL | **aucun changement de périmètre** ; conserver IDs stables, migrations auditables et séparation des permissions pour préparer les objets mémoire |
| PR-2C Data Truth / Impact / Provenance | supprimer les calculs d’impact de repli et minima Terrasen ; rendre inconnu distinct de zéro ; ajouter période, lieu, type de claim, méthode, source assertion, preuve, validation, relations de répétition/agrégation ; neutraliser les valeurs historiques par défaut non prouvées |
| PR-2D Institutional Memory Core | livrer `HistoricalEvent`, `Generation`, `RoleTerm`, identité/alias/relations/saisons projet temporels, `Place/InterventionSite`, `CompetitionEdition/Participation/Award`, `InstitutionalMemoryEdition` ; schéma et relations minimaux de `FieldMission`, `TechnologyTransfer` et `ImpactCollection`, avec lectures sourcées du cœur mémoire |
| PR-3 Product Services Backend | devices/installations ; préférences de notification ; support/tickets/feedback ; versions de l’application, version minimale et mise à jour forcée ; mode maintenance |
| PR-4 Settings/Help/Legal/About | expliquer statuts de vérité, demandes de correction/retrait et politique mémoire/média |
| PR-5 Push | notifications de curation, validation et échéance de droits, après modèles |
| PR-6 Production readiness | migrations, sauvegarde, audit, permissions, volumes média et tests de non-divulgation |
| PR-6.5 Operational Integrity | workflows opérationnels de mission et de transfert de technologie, clôture de mission, réunion→décision→tâche, versionnement/réconciliation budgétaire, passation, snapshots de saison et validations opérationnelles ; événements candidats issus de ces transitions, sans publication automatique |
| PR-6.6 Memory / Heritage UI | expériences de lecture Héritage/Mémoire : Overview, timeline et filtres, générations, leadership, projets, territoires liste, missions, technologies, claims, palmarès, galerie, sources |
| PR-7 GitHub/CI/Pôle IT | contrôles schéma, fixtures non personnelles, validations de migrations et qualité de provenance |
| PR-8 Release Candidate | recette éditoriale, privacy, accessibilité, données vides, contestées et projections |

Frontière explicite : PR-2D porte le schéma, les relations et les lectures du cœur mémoire ; PR-6.5 porte l’exécution et la validation des workflows opérationnels ; PR-6.6 porte leurs expériences de lecture. PR-3 reste strictement Product Services Backend, sans responsabilité mémoire/timeline ni génération de candidats. La vérité des claims et la suppression des fallbacks restent en PR-2C.

**Réponse architecturale : aucun nouveau P0 avant PR-2B.** Les deux P0 nouveaux, NR-03 et NR-05, entrent dans PR-2C/PR-2D et doivent précéder tout import historique ou écran public, pas l’authentification mobile/session/PostgreSQL.

## 24. V1 vs V1.1

| V1 obligatoire | V1.1 / après stabilisation |
|---|---|
| vérité/provenance claim-level et suppression des fallbacks | cartographie géographique interactive |
| identité/alias/état projet par saison | recherche plein texte enrichie/OCR des archives |
| timeline interne sourcée et précision de date | narration multimédia avancée |
| RoleTerm + génération minimale | arbres de succession/visualisations complexes |
| missions multi-sites, documents, transfert/collecte minimaux | mode terrain hors ligne complet si non déjà priorisé |
| compétitions/participations/awards séparés | synchronisation calendrier externe |
| galerie avec droits/consentement/alt | reconnaissance/étiquetage assisté, jamais facial automatique |
| édition mémoire, workflow de curation et visibilité | traductions, visites publiques thématiques, storytelling automatisé contrôlé |
| vues listes pour territoires/technologies | graphe interactif complet des technologies et relations |

Le CRM partenaires (OP-09), le mode faible connexion (OP-17) et le calendrier externe (OP-18) gardent leurs priorités antérieures ; MI26 ne justifie pas de les déplacer en P0. La réconciliation historique complète des 101 claims peut se poursuivre en V1.1, à condition que V1 affiche correctement `reported_unverified` et n’agrège rien par défaut.

## 25. Privacy and import rules

### Résultat de la revue source

Le texte extrait de MI26 ne contient aucun courriel, numéro téléphonique, adresse web, mot de passe, jeton d’accès, donnée d’authentification confidentielle ou clé API. Il contient des noms liés à des rôles institutionnels et une photo de groupe comportant de nombreuses personnes identifiables. Les propriétés internes du DOCX contiennent aussi un nom personnel dans le champ « dernière modification ». Ce dernier n’est pas nécessaire à la mémoire publique et n’est pas reproduit ici. La corroboration par `TT26` n’ajoute aucune identité individuelle : sa liste de participants reste exclue, seuls les noms des deux GIE sont repris.

| Classe | Données MI26 | Règle |
|---|---|---|
| `SAFE_INSTITUTIONAL_HISTORY` | nom du club, dates/événements validés, projets, pôles, rôles sans profil, territoires non individuels, technologies, prix prouvés, sources institutionnelles | import éditorial après validation, avec provenance |
| `CONSENT_OR_REVIEW_REQUIRED` | noms de Team Leaders/pionniers/porteurs/advisors, photo de groupe, logos et médias, citations attribuées, détails de GIE, claims santé, fichiers sources avec métadonnées personnelles | minimiser, vérifier rôle public/base de diffusion, contrôler droits et visibilité |
| `DO_NOT_IMPORT` | métadonnée personnelle « last modified by », identités déduites d’images, listes nominatives de participants de mission, coordonnées privées, signatures, observations individuelles, bénéficiaires nominatifs, credentials éventuels | exclure de l’import et des index publics |

Règles : ne jamais créer un compte depuis un nom historique ; ne pas identifier les personnes d’une photo ; ne pas importer le binaire DOCX avant nettoyage des propriétés et revue des droits ; conserver les preuves sensibles hors index public ; agréger les bénéficiaires ; journaliser toute décision de publication/retrait.

## 26. Recommended next implementation sequence

1. Terminer PR-2B sans élargissement mémoire.
2. Dans PR-2C, supprimer les valeurs dérivées, définir les états de vérité et implémenter `SourceAssertion`, `Claim`, preuve, validation et agrégation traçable.
3. Faire adopter D-01 à D-06 ; ces décisions portent le schéma, pas la vérité historique détaillée.
4. Dans PR-2D, créer `HistoricalEvent`, `Generation`, `RoleTerm`, identité/alias/relations/saisons projet temporels, `Place/InterventionSite`, `CompetitionEdition/Participation/Award` et `InstitutionalMemoryEdition`.
5. Dans ce même cœur PR-2D, ajouter le schéma et les relations minimaux de `FieldMission`, `TechnologyTransfer` et `ImpactCollection` à Events/Documents/Archives ; les workflows opérationnels relèvent de PR-6.5, sans modules isolés concurrents.
6. Préparer un lot MI26 en **preview seulement** : 32 événements, 15 projets/évolutions, 10 missions, 13 enregistrements compétition/participation/award, 101 claims non vérifiés et références sources.
7. Résoudre D-07 à D-22 par lots ; chaque décision produit une trace, jamais une correction silencieuse du document.
8. Construire PR-6.5 : workflows de mission/transfert, clôture de mission, réunion→décision→tâche, versionnement/réconciliation budgétaire, passation, snapshots de saison et validation opérationnelle ; produire des événements candidats, jamais publiés automatiquement, avec tests de permissions et vérité.
9. Construire les expériences de lecture Héritage/Mémoire PR-6.6 sur les objets validés et les lectures du cœur PR-2D ; afficher états, sources et lacunes ; tester vide/contesté/projection. PR-3 conserve exclusivement son périmètre Product Services Backend défini en section 23.
10. Reporter cartes, visualisations complexes et enrichissements automatisés à V1.1.

Critère de sortie : une personne autorisée doit pouvoir partir d’une phrase publiée, atteindre l’événement ou claim, voir la source/localisation, la méthode, la preuve permise et la décision éditoriale, sans exposer de donnée personnelle inutile.

## 27. Traceability / source references

### Source primaire de cette analyse

- `MI26` — `Enactus_ESP_Memoire_Institutionnelle_2026.docx`, SHA-256 `617632ABF662181BAA274819855BEF991AEF6D657D8E8DBB5A6ADD760E77D66D`, source externe non cataloguée au moment de la revue.
- Couverture : `MI26-P000:P286`, `MI26-T00:T24`, quatre relations image et propriétés du package.
- Images : logo Enactus ESP à `P000`, sceau UCAD à `P007`, photo de groupe à `P017`, organigramme à `P132`.
- Limite : inspection structurelle complète, inspection visuelle des quatre images, mais pas de rendu page par page faute de moteur LibreOffice disponible.

### Rapports de connaissance comparés

- `R00` `docs/enactus_knowledge/analysis/00_executive_summary.md`
- `R01` `docs/enactus_knowledge/analysis/01_governance_organisation.md`
- `R02` `docs/enactus_knowledge/analysis/02_members_recruitment_leadership.md`
- `R03` `docs/enactus_knowledge/analysis/03_poles_operations.md`
- `R04` `docs/enactus_knowledge/analysis/04_projects_portfolio.md`
- `R05` `docs/enactus_knowledge/analysis/05_finance_fundraising_partnerships.md`
- `R06` `docs/enactus_knowledge/analysis/06_impact_reporting_competitions.md`
- `R07` `docs/enactus_knowledge/analysis/07_communication_events_training.md`
- `R08` `docs/enactus_knowledge/analysis/08_archives_knowledge_management.md`
- `R09` `docs/enactus_knowledge/analysis/09_enactspace_gap_analysis.md`
- `R10` `docs/enactus_knowledge/analysis/10_product_opportunities_backlog.md`
- `R11` `docs/enactus_knowledge/analysis/11_data_import_opportunities.md`
- `R12` `docs/enactus_knowledge/analysis/12_source_reliability_conflicts.md`
- `R13` `docs/enactus_knowledge/analysis/13_corpus_coverage.md`

### Source antérieure comparée

- `documents/ENACTUS ESP/Histoire de Enactus ESP.pdf`, SHA catalogué `1C07B258A6FB52E116C3F62A2E6D43899F170D7CDB6DD5C1B3D2B43F5A478855`, utilisé uniquement via sa normalisation existante pour identifier ajouts et omissions MI26.

### Source de corroboration FM-10

- `TT26` — `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf`, SHA-256 catalogué `7FA2ADD4DEAEA88704FBFFF30396FCDE6A46826B0294CBBA35AE974C98D522AD`, déjà référencé par `R04` et `R07`.
- Lecture via `docs/enactus_knowledge/normalized/by_sha/7F/7FA2ADD4DEAEA88704FBFFF30396FCDE6A46826B0294CBBA35AE974C98D522AD.md` existant, sans nouvelle extraction ni modification de source/catalogue.
- Localisateurs : couverture et §1, p. 1, pour TERRASEN, Mbour, 14–16 août 2026, GIE Adji Ba et GIE Sope Babacar Sy ; §3, p. 2–4, pour le déroulement réalisé ; §5.1, p. 8, pour quatre tables terminées, deux par GIE. Le §5.2, p. 9, rapporte l’appropriation sans constituer une validation d’impact EnactSpace. Pagination interne du rapport, hors couverture et sommaires.
- Seuls les faits institutionnels nécessaires à FM-10 sont repris ; aucun participant/membre, aucune observation individuelle ni pièce justificative sensible n’est importé.

### Code EnactSpace lu en lecture seule

- Modèles : `backend/app/models/archive.py`, `impact.py`, `project.py`, `season.py`, `role.py`, `alumni.py`, `event.py`, `document.py`, `pole.py`, ainsi que les modèles finance, academy, recruitment, user et audit.
- Routes principales : `backend/app/api/routes/archives.py`, `impact.py`, `projects.py`, `seasons.py`, `alumni.py`, `events.py`, `documents.py`, `poles.py`, plus finance, academy, recruitment, users et audit.
- Interfaces : `frontend/lib/features/{projects,archives,alumni,impact,events}/`, `frontend/lib/app/app_router.dart`, `frontend/lib/shared/layout/app_shell.dart`.
- SHA d’application contrôlé : `6e516950e820f74846a5065b6eb798b3993f2fb9` ; aucune modification.

### État d’intégration

Ce rapport n’ajoute MI26 ni à `sources.csv`, ni à `source_to_normalized.csv`, ni à `normalized/by_sha`. Il ne valide aucune claim, n’importe aucune identité et ne modifie aucun rapport `00` à `13`. Son seul effet attendu dans le dépôt est la création de ce fichier `14_institutional_memory_2015_2026.md`.
