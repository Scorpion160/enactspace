# EnactSpace — Parcours public Recrutement v1

## Objectif

Le parcours public Recrutement permet à une personne non connectée de découvrir les campagnes ouvertes, déposer une candidature en plusieurs étapes, conserver son code de suivi et consulter l’avancement de son dossier. L’expérience est distincte de l’interface interne `/recruitment` et reprend la direction éditoriale « EnactSpace — L’impact en mouvement ».

## Routes publiques

- `/recruitment/apply` : découverte des campagnes actuellement ouvertes.
- `/recruitment/apply/:campaignId` : candidature progressive pour une campagne sélectionnée.
- `/application-tracking` : suivi public avec code et adresse e-mail.

Ces routes sont explicitement reconnues comme publiques par le routeur. Depuis la connexion, « Postuler » ouvre `/recruitment/apply` et « Suivre ma candidature » ouvre `/application-tracking`. L’ancien enchaînement de boîtes de dialogue a été retiré.

## Parcours candidat

La page de découverte appelle le contrat public des campagnes et distingue quatre états : chargement local, une campagne ouverte, plusieurs campagnes ouvertes, absence de campagne et erreur de chargement. Une erreur réseau ou serveur n’est jamais assimilée à une liste vide et aucune exception technique n’est affichée.

Le choix « Commencer ma candidature » ouvre une page complète. Le brouillon est conservé en mémoire pendant les déplacements Retour/Suivant. Chaque étape valide uniquement les champs nécessaires avant d’autoriser la suite.

Après vérification, la personne doit cocher une confirmation puis choisir « Envoyer ma candidature ». Pendant l’envoi, l’action est désactivée. Une erreur conserve le brouillon et permet de réessayer. Un succès remplace le formulaire par une vue dédiée contenant la campagne, l’e-mail et un code sélectionnable et copiable.

## Six étapes

1. **Identité** : prénom, nom, e-mail, téléphone et genre facultatif.
2. **Parcours** : formation ou niveau, département, classe, expérience associative, pôle préféré et projet d’intérêt.
3. **Motivations** : motivation, découverte d’Enactus, connaissance du mouvement, contribution, idée de projet, travail en équipe et autres engagements.
4. **Disponibilité** : disponibilités et contraintes ou précisions existantes.
5. **Documents** : liens facultatifs vers CV, lettre et document complémentaire. Aucun faux téléversement n’est présenté.
6. **Vérification** : résumé par section avec actions « Modifier » et confirmation avant envoi.

## Composants

Le parcours public est découpé en écrans, passerelle injectable et composants réutilisables :

- `PublicRecruitmentCampaignsScreen` ;
- `PublicApplicationFlowScreen` ;
- `TrackingSearchForm` et `TrackingResultView` ;
- `PublicRecruitmentShell` ;
- `CampaignPublicCard` ;
- `PublicRecruitmentEmptyState` et `PublicRecruitmentErrorState` ;
- `ApplicationStepHeader` ;
- `ApplicationReviewSection` ;
- `ApplicationSuccessView` ;
- `ApplicationTimeline`.

`PublicRecruitmentGateway` sépare les écrans du transport. La production délègue au service Recrutement existant ; les tests substituent une implémentation en mémoire et ne font aucune requête réelle.

## Statuts publics

`ApplicationStatusPresentation` centralise les libellés, explications, prochaines actions, icônes et position dans la chronologie.

| Statut API | Présentation publique |
|---|---|
| `submitted` | Reçue |
| `under_review` | En cours d’étude |
| `interview_scheduled` | Entretien programmé |
| `accepted` | Candidature retenue |
| `rejected` | Candidature non retenue |
| `waiting_list` | Liste d’attente |
| `cancelled` | Candidature clôturée |

Les anciens alias reçus du contrat sont normalisés vers la présentation canonique. Une valeur inconnue reçoit une présentation sûre « Reçue » : l’enum brut n’est jamais montré au candidat.

## Chronologie

La chronologie comporte : candidature reçue, étude du dossier, entretien et décision. Elle associe icône, texte et progression afin de ne pas dépendre uniquement de la couleur. Les états rejeté, liste d’attente et clôturé utilisent une présentation terminale spécifique sans suggérer que toutes les étapes ont été réussies. Pour un entretien programmé, le détail fourni par le contrat affiche notamment la date et le lieu.

## Responsive

Le parcours est mobile-first : une seule colonne sous 680 px, barre Retour/Suivant toujours disponible en bas, indicateur textuel « Étape n sur 6 » et largeur de contenu plafonnée sur desktop. La découverte et le suivi passent d’une pile mobile à une composition plus large sans dialogue improvisé. Les formats visés sont 390×844, 768×1024, 1366×768 et 1440×900.

## Accessibilité

Des sémantiques dédiées décrivent les campagnes, la progression, les actions Retour/Suivant, l’envoi, le code de suivi, la copie, le statut et la chronologie. Le code de suivi est sélectionnable. Les champs emploient des types de clavier et des hints d’autofill adaptés. Les contrôles reposent sur les composants Material, conservent le focus clavier Web et respectent une cible tactile minimale.

## Tests

Les tests widgets utilisent exclusivement une passerelle simulée. Ils couvrent : routes publiques, chargement et campagne ouverte, états vide et erreur distincts, validation bloquante, navigation dans les six étapes, conservation du brouillon, vérification sans envoi automatique, succès simulé, erreur simulée avec données conservées, code visible, largeur 390 px, sept statuts humanisés, entretien avec date et lieu et absence d’enum brut.

## Limites du contrat actuel

- Les documents sont des URL facultatives ; aucun endpoint de téléversement Recrutement n’existe.
- Le brouillon n’est pas persisté après fermeture ou rechargement de la page.
- Le contrat ne fournit pas de mécanisme de récupération d’un code perdu.
- Le détail d’entretien arrive sous forme de texte public agrégé ; le frontend ne crée aucune donnée supplémentaire.
- La correction d’une candidature après envoi n’est pas supportée.
- La décision et l’historique métier restent limités aux informations renvoyées par le suivi public.

## Contrôles runtime en lecture seule

Les fixtures prévues pour le contrôle post-refactor sont la campagne
`AUDIT-REC-CAMPAIGN-OPEN` et les suivis `AUDIT-REC-TRACK-001`,
`AUDIT-REC-INTERVIEW-001`, `AUDIT-REC-ACCEPTED-001`,
`AUDIT-REC-REJECTED-001`, `AUDIT-REC-WAITING-001` et
`AUDIT-REC-CANCELLED-001`.

Le contrôle final post-refonte du 21 août 2026 a confirmé la campagne publique
et les six suivis via l’environnement `ui_audit`. Les réponses ont toutes été
reçues en HTTP 200, avec les statuts attendus avant et après les captures. Les
résultats détaillés sont consignés dans `runtime_check.json`.

Les consultations de suivi utilisent normalement le
`POST /api/recruitment/applications/track` existant, qui est une opération de
lecture fonctionnelle malgré sa méthode HTTP. Aucune soumission, décision,
conversion ou autre mutation métier n’a été exécutée pendant ce contrôle. La
vue de succès utilise un service local simulé qui bloque la création réelle et
renvoie uniquement un code synthétique de capture.
