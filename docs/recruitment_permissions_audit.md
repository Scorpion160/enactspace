# Audit permissions recrutement

## Routes publiques

| Route | Accès | Données exposées |
| --- | --- | --- |
| `GET /api/recruitment/campaigns/public` | Public | Campagnes ouvertes uniquement |
| `POST /api/recruitment/applications` | Public | Création candidature sans compte interne |
| `POST /api/recruitment/applications/track` | Public avec email + code | Statut, dates, prochaine étape, entretien public, résultat public |

## Routes internes

| Surface | Protection | Commentaire |
| --- | --- | --- |
| Campagnes | `require_recruitment_access` | Réservé recrutement / Enacchefs autorisés |
| Liste candidatures | `require_recruitment_access` | Membre simple et alumni non autorisés exclus |
| Export CSV | `require_recruitment_access` | Export protégé, aucune route publique |
| Évaluations | `require_recruitment_access` | Notes internes non exposées au suivi candidat |
| Entretiens | `require_recruitment_access` | Note interne conservée côté interne |
| Conversion compte | `require_sg_or_admin` | Action limitée SG / Team Leader / Admin |

## Vérifications

- Candidat: voit uniquement son suivi avec email + code.
- Candidat: ne voit pas notes internes, scores, avis, jury interne détaillé ou export.
- Membre simple: ne doit pas accéder à la gestion recrutement.
- Alumni: ne doit pas accéder à la gestion recrutement sauf rôle explicite.
- Pôle Veille / recrutement: peut gérer candidatures, évaluations, entretiens et exports.
- SG / Team Leader / Admin: peuvent convertir les candidats acceptés en membres.
- Export CSV: reste derrière authentification et rôles recrutement.

## Responsive

- Formulaire public: champs empilés via `_AdaptiveFieldRow` sur petit écran.
- Suivi candidat: disposition une colonne mobile, deux colonnes desktop.
- Liste candidatures: cartes responsive en `Wrap`, pas de tableau large.
- Filtres: champs en `Wrap`, largeur pleine sur mobile.
- Actions nombreuses: boutons en `Wrap`, retour à la ligne au lieu d'overflow.

## Points à surveiller en recette

- Tester un compte membre simple contre `/api/recruitment/applications`.
- Tester un alumni sans rôle recrutement contre `/api/recruitment/applications/export.csv`.
- Tester une conversion avec pôle/projet sur base réelle.
- Tester le formulaire public sur téléphone Android étroit.
