# Reference V1 parametres et constantes

Date: 2026-07-03

## Application

| Parametre | Source | Valeur V1 |
| --- | --- | --- |
| Nom application | `backend/app/core/config.py` | `EnactSpace` |
| Environnement | `APP_ENV` | `development` par defaut |
| Debug | `APP_DEBUG` | `True` par defaut |
| Duree token | `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` minutes |
| Seed | `ENABLE_SEED` | Active uniquement en local/dev |

## Branding frontend

| Element | Source |
| --- | --- |
| Jaune Enactus | `AppTheme.enactusYellow` |
| Noir doux | `AppTheme.softBlack` |
| Logos | `BrandAssets` |
| Nom visible | `EnactSpace` |

## Roles

Source: `backend/app/core/roles.py`

- `enacteur`
- `alumni`
- `administrateur`
- `team_leader`
- `secretaire_generale`
- `financier`
- `chef_pole`
- `adjoint_chef_pole`
- `chef_projet`
- `adjoint_chef_projet`
- `faculty_advisor`
- roles recrutement / pole veille

Les groupes derives sont aussi centralises: Enacchefs, gestion globale, secretariat, finance, recrutement et demandes d'adhesion.

## Presence et sanctions

Source: `backend/app/api/routes/attendance.py` et table `attendance_settings`.

| Cle | Valeur par defaut |
| --- | --- |
| Absence non justifiee | `500` FCFA |
| Retard | `100` FCFA |
| Justification | statuts controles par `VALID_JUSTIFICATION_STATUSES` |

Les montants sont stockables en base via `AttendanceSetting` et ne doivent pas etre figes dans le frontend.

## Fichiers

Source: `backend/app/services/file_storage_service.py`

| Parametre | Valeur |
| --- | --- |
| Taille max | 500 Mo |
| Retention temporaire | 90 jours |
| Ephemere | `24h`, `7d`, `30d` |
| Scopes proteges | `official`, `archive` |
| Extensions bloquees | executables Windows/shell/scripts |

## Finance

| Parametre | Source | Valeur |
| --- | --- | --- |
| Devise | schemas/modeles finance | `FCFA` |
| Statuts frais | `VALID_FEE_STATUSES` | module finance |
| Exports | routes finance | CSV UTF-8 |

## Categories et statuts metier

| Domaine | Source |
| --- | --- |
| Documents | `VALID_DOCUMENT_CATEGORIES`, `DOCUMENT_STATUSES` |
| Impact | `VALID_IMPACT_STATUSES`, `VALID_METRIC_CATEGORIES`, `VALID_METRIC_UNITS` |
| Academy | categories/parcours dans `academy.py`, schemas Academy |
| Archives | `VALID_ARCHIVE_CATEGORIES`, `VALID_ARCHIVE_STATUSES`, `VALID_ARCHIVE_VISIBILITIES` |
| Recrutement | `VALID_APPLICATION_STATUSES` |
| Taches | `VALID_TASK_STATUSES` |
| Projets | `VALID_PROJECT_STATUSES` |

## Recommandations V1.1

- Deplacer progressivement les categories documents/impact/archives dans un fichier de constantes dedie par domaine.
- Ajouter `DEFAULT_CURRENCY` dans la configuration si une devise autre que FCFA devient necessaire.
- Exposer certains parametres modifiables via une UI Admin quand la gouvernance sera stabilisee.
