# EnactSpace V1.1 - Interface admin import membres

Objectif: importer les membres reels depuis l'application avec controle avant validation.

## Acces

Page:

```text
Membres > Importer
```

Roles autorises:

- Administrateur
- Team Leader
- Secretaire generale

Le backend protege aussi les endpoints via les memes permissions.

## Parcours utilisateur

1. Telecharger ou copier le modele CSV.
2. Choisir un fichier CSV.
3. Activer `Mettre a jour les comptes existants` si l'import doit corriger des comptes deja presents.
4. Lancer `Apercu`.
5. Verifier le resume:
   - lignes totales;
   - lignes valides;
   - erreurs;
   - avertissements;
   - doublons;
   - comptes crees ou mis a jour;
   - affectations poles/projets.
6. Corriger les erreurs bloquantes.
7. Confirmer l'import definitif.

## Regles UX mobile

- Le panneau s'ouvre en bottom sheet responsive.
- Les lignes valides sont affichees en cartes compactes.
- Les erreurs et avertissements sont limites visuellement pour eviter les longs ecrans illisibles.
- Les boutons sont en `Wrap` afin d'eviter les overflows.

## Securite

- Aucun CSV reel n'est stocke par l'app dans le depot.
- Le fichier envoye est analyse en memoire par le backend.
- `preview` fait un rollback systematique.
- `apply` reexecute la meme logique backend avant commit.
- Les donnees personnelles ne sont pas ecrites dans les logs applicatifs.

## Tests minimum

1. Compte Admin: bouton visible.
2. Compte Team Leader: bouton visible.
3. Compte SG: bouton visible.
4. Membre simple: bouton absent.
5. Alumni: bouton absent.
6. Candidat: bouton absent.
7. CSV avec pole inconnu: erreur visible.
8. CSV avec email manquant: avertissement visible.
9. CSV avec doublon: erreur visible.
10. CSV valide fictif: import possible apres confirmation.

## Test local fichier reel

Le preview API a ete teste localement avec le CSV prive genere depuis `listes_enacteurs.ods`.

Resultat agrege:

- 26 lignes totales.
- 26 lignes valides.
- 0 erreur.
- 16 avertissements.
- 0 doublon.

Le rapport complet, sans donnees personnelles, est dans:

```text
docs/V1_1_REAL_MEMBERS_IMPORT_TEST_REPORT.md
```
