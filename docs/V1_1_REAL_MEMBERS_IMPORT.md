# EnactSpace V1.1 - Import membres reels

Objectif: importer les Enacteurs, Enactrices et Alumni reels sans saisir chaque profil a la main.

## Regle de confidentialite

Ne jamais committer:

- CSV reel des membres;
- numeros de telephone reels;
- emails personnels reels;
- rapports contenant des donnees personnelles;
- mots de passe temporaires.

Le depot contient seulement:

```text
data/import/membres_enactus_template.csv
```

## Colonnes CSV

Colonnes obligatoires:

- `prenom`
- `nom`
- `email`

Colonnes optionnelles:

- `telephone`
- `genre`
- `role`
- `statut`
- `pole_coeur`
- `poles_support`
- `projet`
- `responsabilite`
- `date_adhesion`

Les colonnes recommandees dans l'ordre:

```text
prenom,nom,email,telephone,genre,role,statut,pole_coeur,poles_support,projet,responsabilite,date_adhesion
```

## Valeurs attendues

`statut`:

- `active`
- `pending`
- `alumni`
- `inactive`

`role` peut contenir plusieurs valeurs separees par `;`, `,` ou `|`.

Exemples:

```text
enacteur
chef_pole;enacteur
team_leader;enacteur
secretaire_generale;enacteur
financier;enacteur
alumni
```

`poles_support` peut contenir plusieurs poles:

```text
Communication;Veille
```

`date_adhesion` accepte:

- `YYYY-MM-DD`
- `DD/MM/YYYY`
- `DD-MM-YYYY`

## Commandes

Depuis `backend`:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
```

Verifier l'environnement Python:

```powershell
.\.venv\Scripts\pip.exe install -r requirements.txt
```

Dry-run obligatoire avant tout import reel:

```powershell
python -m app.scripts.import_members --file ..\data\import\membres_enactus.csv --dry-run
```

Application effective:

```powershell
python -m app.scripts.import_members --file ..\data\import\membres_enactus.csv --apply
```

Mettre a jour les comptes existants par email:

```powershell
python -m app.scripts.import_members --file ..\data\import\membres_enactus.csv --apply --update-existing
```

## Interface Admin

L'import est disponible depuis:

```text
Membres > Importer
```

Roles autorises:

- Administrateur
- Team Leader
- Secretaire generale

Roles interdits:

- membre simple
- alumni
- candidat

Fonctionnement:

1. Ouvrir `Membres`.
2. Cliquer `Importer`.
3. Charger ou copier le modele CSV.
4. Selectionner un CSV.
5. Lancer `Apercu`.
6. Lire le resume, les erreurs et les avertissements.
7. Corriger le CSV si necessaire.
8. Confirmer avec `Importer` uniquement si aucune erreur bloquante n'est presente.

Endpoints backend:

```text
GET  /api/members/import/template
POST /api/members/import/preview
POST /api/members/import/apply
```

Le backend reste la source de verite: l'UI ne fait qu'afficher les rapports.

## Lecture des erreurs

Une erreur bloque l'import definitif.

Exemples:

- pole coeur manquant;
- pole inconnu;
- role inconnu;
- email invalide;
- telephone deja utilise par un autre compte;
- doublon email ou telephone dans le CSV.

## Lecture des avertissements

Un avertissement n'empeche pas forcement l'import, mais demande une verification.

Exemples:

- email manquant: un identifiant interne temporaire est propose;
- telephone manquant;
- statut manquant: `active` est utilise par defaut;
- utilisateur existant ignore sans `--update-existing`.

## Ce que fait le script

1. Lit le CSV en UTF-8.
2. Verifie les colonnes obligatoires.
3. Normalise noms, emails, telephones et roles.
4. Detecte les doublons email dans le CSV.
5. Detecte les doublons telephone dans le CSV.
6. Verifie les telephones deja utilises en base.
7. Cree les utilisateurs absents.
8. Peut mettre a jour les utilisateurs existants avec `--update-existing`.
9. Assigne les roles existants.
10. Lie le membre au pole coeur si le pole existe.
11. Lie les poles support si les poles existent.
12. Lie le projet si le projet existe.
13. Produit un rapport d'erreurs et warnings.

## Mots de passe

Le script genere un mot de passe aleatoire non affiche pour chaque nouveau compte.

La procedure recommandee est ensuite:

1. verifier l'email du membre;
2. activer l'envoi email si disponible;
3. demander au membre d'utiliser "mot de passe oublie";
4. ou envoyer un lien d'activation dans une tranche ulterieure.

## Preparation des donnees

Avant `--apply`:

1. Sauvegarder la base.
2. Verifier que les roles existent.
3. Verifier que les poles existent.
4. Verifier que les projets existent.
5. Lancer le dry-run.
6. Corriger le CSV.
7. Relancer le dry-run.
8. Appliquer uniquement quand le rapport ne contient aucune erreur.

## Conversion du fichier ODS reel

Le fichier reel local est:

```text
C:\Users\DIOP\Documents\Enactus\documents\listes_enacteurs.ods
```

Il contient des donnees personnelles et ne doit jamais etre copie dans le depot.

Convertir vers un CSV ignore par Git:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace
python tools\convert_members_ods_to_csv.py `
  --input C:\Users\DIOP\Documents\Enactus\documents\listes_enacteurs.ods `
  --output data\import\private\membres_enactus_import.csv
```

Le dossier suivant est ignore par Git:

```text
data/import/private/
```

Mapping applique:

```text
Nom -> nom
Prenoms -> prenom
Sexe -> genre
Classse/Classe -> niveau_etude
Telephone -> telephone
Email -> email
Pole coeur -> pole_coeur
Com/Orga/Veille -> poles_support
Projet principal -> projet
Fonction / responsabilite -> responsabilite + roles
Statut -> statut
```

Normalisations:

- `M` devient `masculin`.
- `F` devient `feminin`.
- `Actif` devient `active`.
- `Inactif` devient `inactive`.
- `Com=Oui` ajoute `Communication`.
- `Orga=Oui` ajoute `Organisation`.
- `Veille=Oui` ajoute `Veille`.

Le convertisseur detecte automatiquement la ligne d'en-tetes dans l'ODS.

## Exemple minimal

```csv
prenom,nom,email,telephone,genre,role,statut,pole_coeur,poles_support,projet,responsabilite,date_adhesion
Awa,Fall,awa.fall@example.com,+221771234567,femme,enacteur,active,IT,Communication;Veille,Terrasen,membre,2026-01-15
```

## Limites V1.1

- Le CSV reel reste manipule hors depot.
- Le script ne cree pas automatiquement les poles ou projets manquants.
- Les mots de passe temporaires ne sont pas affiches pour eviter les fuites.
- L'interface admin d'import est prevue dans la tranche suivante.
