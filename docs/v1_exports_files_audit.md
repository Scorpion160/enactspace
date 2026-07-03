# Audit V1 exports et fichiers

Date: 2026-07-03

## Perimetre verifie

- Exports CSV presences, finance, impact, academy et archives.
- Telechargement et preview via `/api/files/{id}/download` et `/preview`.
- Stockage temporaire, scopes, visibilites et nettoyage.
- Pieces jointes documents, posts, chat, impact, academy et archives.

## Exports verifies

| Export | Route | Protection | Etat |
| --- | --- | --- | --- |
| Presences mensuelles | `/attendance/monthly-export` | SG/Admin/Team Leader ou perimetre autorise | OK |
| Finance frais | `/finance/export/fees.csv` | Financier/Admin/Team Leader | OK |
| Finance paiements | `/finance/export/payments.csv` | Financier/Admin/Team Leader | OK |
| Impact projets | `/impact/export/projects.csv` | Enacchef/Admin | OK |
| Impact projet | `/impact/export/projects/{project_id}.csv` | Enacchef/Admin | OK |
| Academy progression | `/academy/admin/export/progress.csv` | Enacchef/Admin | OK |
| Archives | `/archives/export/items.csv` | SG/Team Leader/Admin | OK |

## Fichiers verifies

- Upload centralise par `FileStorageService`.
- Limite fichier: 500 Mo.
- Extensions executables bloquees.
- Scopes supportes: chat, document, post, project, pole, impact, recruitment, academy, archive, official, temporary.
- Visibilites supportees: private, participants, pole_only, project_only, enacchef_only, internal, public_club, alumni_only.
- Les fichiers expires retournent `410 Gone`.
- Les fichiers absents retournent une erreur propre.
- Les routes download/preview verifient le proprietaire, les roles globaux ou le contexte visible.
- Les chemins systeme ne sont pas exposes dans les payloads utilisateur.

## Correction appliquee

- Harmonisation du media type CSV en `text/csv; charset=utf-8` pour finance, impact, academy et archives.

## Points ouverts

- Le montage statique `/uploads` existe encore pour compatibilite; l'app doit privilegier les routes `/api/files`.
- Ajouter une UI Flutter de telechargement natif pour exports selon cible web/mobile.
- Ajouter une suite de tests automatisee avec utilisateurs par role pour verifier les fichiers non autorises.
