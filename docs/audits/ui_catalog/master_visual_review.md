# EnactSpace master visual review - corrected typography

## Correction context

The first master catalogue was visually invalid for text-based findings. The
fresh Edge audit profile now allows only GET/OPTIONS to
`fonts.googleapis.com` and `fonts.gstatic.com`, with replacement request
headers that carry no cookie, token or Authorization header. All other
external browser domains remain blocked. The 42 replacement captures report
`font_loaded=true`, `font_source=google_fonts_audit_allowlist` and
`text_render_verified=true`.

## Three visual controls

- 01: `Connexion des comptes valides`, Email, Mot de passe and Se connecter
  are readable.
- 09: the dashboard title, Audit Admin, card titles, values, subtitles and
  labelled navigation are readable.
- 33: the conversation name, participant names, messages, times/statuses and
  message composer are readable.

## Reclassification of the first review

| Capture | View | Corrected reading | Status of former finding |
| --- | --- | --- | --- |
| 01 | Connexion mobile | Texte lisible, hierarchie claire, champs et CTA identifies. | Cause: police non chargee; ancien constat texte absent infirme. |
| 02 | Connexion tablette | Composition centree lisible mais beaucoup d'espace vide. | Cause: police non chargee pour le texte; densite a approfondir. |
| 03 | Connexion desktop | Connexion complete et lisible; echelle desktop sobre. | Cause: police non chargee; ancien constat contenu absent infirme. |
| 04 | Erreur connexion | Alerte, explication et parcours de reprise lisibles. | Cause: police non chargee; ancien constat alerte illisible infirme. |
| 05 | Mot de passe oublie | Vue de recuperation lisible. | Cause: police non chargee; confort de la composition a approfondir. |
| 06 | Shell membre mobile | Titre, libelles du dock et badges visibles. | Cause: police non chargee; ancien constat navigation icon-only infirme. |
| 07 | Shell admin desktop | Rail libelle et role Administration visibles. | Cause: police non chargee; largeur/densite du rail a approfondir. |
| 08 | Shell finance tablette | Titre, role et cartes lisibles; hero contient des actions blanches sans texte. | Confirme: CTA hero sans libelle; navigation illisible infirmee. |
| 09 | Dashboard admin | Identite Audit Admin, cartes, chiffres et nav lisibles. | Cause: police non chargee; anciens constats contenu/noms absents infirmes. Confirme: deux CTA hero blancs sans texte. |
| 10 | Dashboard membre | Contenu personnel et cartes lisibles. | Cause: police non chargee; densite mobile a approfondir. |
| 11 | Dashboard finance | Valeurs et sous-titres lisibles. | Cause: police non chargee; actions hero sans libelle a approfondir. |
| 12 | Dashboard chef pole | Role et blocs operationnels lisibles. | Cause: police non chargee; hierarchie specifique pole a approfondir. |
| 13 | Liste membres desktop | Recherche, filtres et identites visibles. | Cause: police non chargee; ancien constat liste vide infirme. |
| 14 | Liste membres mobile | Identites et statuts lisibles; filtres prennent beaucoup de hauteur. | Confirme: densite mobile faible avant la liste. |
| 15 | Profil membre | Information de profil lisible. | Cause: police non chargee; hierarchie du profil a approfondir. |
| 16 | Modification membre | Sous-vue indisponible; vue la plus proche capturee. | Confirme: action Modifier indisponible dans le produit/audit. |
| 17 | Gestion presences | Libelles et etats lisibles. | Cause: police non chargee; flux complet a approfondir. |
| 18 | Suivi personnel | Sous-vue indisponible; vue parente conservee. | Confirme: onglet Mon suivi indisponible. |
| 19 | Session ouverte | Sous-vue et informations de session visibles. | Cause: police non chargee; ergonomie scan a approfondir. |
| 20 | QR/NFC | Vue capturee avec texte lisible. | A approfondir: signal reseau inattendu, pas de faux etat fabrique. |
| 21 | Taches mobile | Taches et statuts lisibles. | Cause: police non chargee; densite de liste a approfondir. |
| 22 | Taches desktop | Donnees denses lisibles. | Cause: police non chargee; scanabilite table a approfondir. |
| 23 | Finance generale | Montants, sections et filtres lisibles. | Cause: police non chargee; vides des sections a approfondir. |
| 24 | Actions paiement | Menu Valider/Rejeter/Annuler lisible. | Cause: police non chargee; ancien constat menu ambigu infirme. |
| 25 | Rejet paiement | Dialogue lisible. | Cause: police non chargee; confirmation destructive a approfondir. |
| 26 | Mobile Money | Sous-vue indisponible; vue parente conservee. | Confirme: action Mobile Money indisponible. |
| 27 | Recrutement | Campagnes, filtres et criteres lisibles. | A approfondir: console inattendue; visuellement deux capsules hero sans texte. |
| 28 | Detail candidature | Sous-vue indisponible; vue parente conservee. | Confirme: detail candidature indisponible. |
| 29 | Bibliotheque documents | Bibliotheque et metadonnees lisibles. | Cause: police non chargee; apercu et densite a approfondir. |
| 30 | Depot document | Sous-vue indisponible; vue parente conservee. | Confirme: action Ajouter indisponible. |
| 31 | Fil publications | Auteurs et contenu visibles. | Cause: police non chargee; hierarchie de feed a approfondir. |
| 32 | Conversations desktop | Noms, extraits et etats lisibles. | Cause: police non chargee; densite du split view a approfondir. |
| 33 | Conversation mobile | Conversation audit 7, auteurs, messages, heures et champ lisibles. | Cause: police non chargee; ancien constat chat illisible infirme. Confirme: pieces jointes indisponibles dans les fixtures. |
| 34 | Groupe discussion | Titre et messages de groupe lisibles. | Cause: police non chargee; moderation/groupe a approfondir. |
| 35 | Liste poles | Cartes et informations de poles lisibles. | Cause: police non chargee; rythme mobile a approfondir. |
| 36 | Fiche pole | Objectifs et donnees visibles. | Cause: police non chargee; dashboard pole a approfondir. |
| 37 | Liste projets | Projets et statuts lisibles. | Cause: police non chargee; densite desktop a approfondir. |
| 38 | Detail projet | Details et progression visibles. | Cause: police non chargee; ordre de l'information a approfondir. |
| 39 | Academy mobile | Parcours et progression visibles. | Cause: police non chargee; cadence des cartes a approfondir. |
| 40 | Alumni desktop | Contenu alumni lisible. | Cause: police non chargee; personnalisation editoriale a approfondir. |
| 41 | Impact dashboard | Indicateurs et labels lisibles. | Cause: police non chargee; lisibilite comparative des metriques a approfondir. |
| 42 | Archive DIMBALI | Recit, impact, prix, partenaires et modal sont lisibles. | Cause: police non chargee; ancien constat archive vide infirme. Confirme: modal tres dense et etiquettes tronquees. |

## 20 confirmed visual problems

1. The dashboard hero contains blank white CTA capsules in the admin, finance and pole variants.
2. The mobile/tablet dashboard hero consumes a disproportionate amount of the first viewport.
3. Mobile member filtering consumes most of the screen before the first useful list item.
4. The desktop rail is information-rich but too tall and wide for the available content area.
5. Long labels and participant lists truncate abruptly without an exposed full value.
6. Secondary text and muted metadata are sometimes too pale on white or dark surfaces.
7. Empty finance sections retain full card height instead of using compact empty states.
8. The recruitment hero includes two blank outlined capsules with no visible action.
9. Repeated rounded cards flatten the visual distinction between operational modules.
10. Card spacing is generous on desktop where data views need faster scanning.
11. Many metrics use the same card hierarchy even when urgency differs.
12. Sidebar notification badges compete visually with destination labels.
13. Mobile top bars combine hamburger, logo, page title and utilities in a cramped band.
14. Chat attachment fixtures render as `Piece jointe indisponible` rather than meaningful media.
15. Chat participant subtitle truncates too early on narrow mobile.
16. Payment action menu is detached from enough visible payment context when opened.
17. Archive DIMBALI modal is visually dense and contains several truncated chips.
18. Archive detail relies on text chips where proof images, awards and impact media would be stronger.
19. Role dashboards share too much of the same hero/card composition.
20. Seven expected actions/subviews remain unavailable or carry a runtime signal: 16, 18, 20, 26, 27, 28 and 30.

## Problems invalidated by typography correction

1. Application-wide missing text, names, labels and numbers: caused by unloaded fonts.
2. Unreadable login form: caused by unloaded fonts.
3. Unlabelled desktop and mobile navigation: caused by unloaded fonts.
4. Blank admin, finance and member dashboard metrics: caused by unloaded fonts.
5. Unreadable member directory and profile identity: caused by unloaded fonts.
6. Unreadable finance filters and action menu: caused by unloaded fonts.
7. Unreadable conversation names, messages, times and composer: caused by unloaded fonts.
8. Unreadable recruitment criteria and filters: caused by unloaded fonts.
9. Empty project, pole, Academy, alumni and impact information: caused by unloaded fonts.
10. Missing DIMBALI story, awards and partners: caused by unloaded fonts.

## 10 recurrent inconsistencies

1. Hero height and density vary without a clear role-based rationale.
2. Some hero controls are blank while equivalent actions elsewhere are labelled.
3. Modules reuse near-identical rounded cards despite different task types.
4. Wide desktop layouts retain mobile-like whitespace.
5. Mobile lists begin too far below their filtering controls.
6. Chip labels truncate differently across archive, filters and participant metadata.
7. Dark hero surfaces, white content cards and pale warning surfaces do not share a single spacing rhythm.
8. Badge prominence varies independently of destination importance.
9. Empty states use large containers rather than compact, contextual messages.
10. Role dashboards differ mainly in text/data, not in their action hierarchy.

## 10 elements to retain

1. The EnactSpace logo and Enactus yellow/soft-black/white identity.
2. Poppins-based typography once correctly loaded.
3. Clear, labelled desktop rail.
4. Labelled mobile bottom navigation.
5. Legible card titles, values and secondary lines.
6. Strong dashboard metric patterns for quick operational scanning.
7. Finance filters and explicit payment-action labels.
8. Chat layout, composer, delivery state and compact bottom navigation.
9. Recruitment filtering and objective-selection presentation.
10. DIMBALI archive content model: timeline, impact, awards, partners and expansion.

## 10 priority redesign screens

1. Shared dashboard hero and quick-action treatment.
2. Mobile member directory/filter workflow.
3. Desktop navigation rail and responsive tablet shell.
4. Chat message/media attachments and participant header.
5. Finance empty states and contextual payment-action flow.
6. Recruitment hero, campaign list and candidate detail.
7. Member profile and currently unavailable edit flow.
8. Attendance personal follow-up and QR/NFC state.
9. Mobile Money declaration/payment flow and document deposit.
10. DIMBALI archive detail and its evidence/media presentation.

## Device-specific recommendations

- Mobile: reduce hero height, collapse filters into a clear filter sheet, protect long labels, and keep the labelled bottom dock.
- Tablet: use a compact labelled rail or drawer, two-column data layouts and less vertical hero space.
- Desktop: reduce card voids, keep a labelled rail but make it denser, group utility controls, and prioritize contextual split views.

## Capture integrity

- Exactly 42 PNG files replace the previous master series.
- 42/42 have font_loaded=true and text_render_verified=true.
- 35/42 reached their requested state without an unexpected signal.
- 16, 18, 26, 28 and 30 are unavailable actions/subviews; 20 retains an unexpected network signal; 27 retains an unexpected console signal.
- No application file under frontend/lib or backend/app was changed, and the 131-scenario pilot was not run.
