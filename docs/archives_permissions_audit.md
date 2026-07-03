# Audit permissions Archives / Hall of Fame

Date: 2026-07-03

## Perimetre verifie

- Archives generiques et elements mis en avant.
- Projets historiques.
- Prix, competitions et distinctions.
- Medias et documents historiques lies au stockage fichier.
- Hall of Fame.
- Statistiques historiques et export CSV.
- Workflow brouillon, soumission, validation, refus et archivage.

## Roles et acces attendus

| Role | Acces attendu | Etat |
| --- | --- | --- |
| Administrateur | Gestion globale, validation, refus, exports | OK |
| Team Leader | Gestion globale, validation, refus, exports | OK |
| SG | Validation archives officielles, refus motive, exports | OK |
| Enacchef | Proposition et gestion des archives selon responsabilite | OK, perimetre fin a renforcer |
| Enacteur | Consultation des archives internes validees | OK |
| Alumni | Consultation des archives alumni/public validees | OK |
| Candidat | Aucun acces aux archives internes avant validation | OK |

## Regles backend verifiees

- Les routes `/archives/items` exigent un utilisateur actif et valide.
- Les candidats non valides sont bloques par `get_current_active_validated_user`.
- La creation/modification d'archives, projets historiques, prix, competitions, medias et documents exige un role Enacchef/Admin.
- La validation, le refus, l'archivage et l'export CSV exigent SG, Team Leader ou Admin via `SECRETARIAT_ROLES`.
- Les refus exigent un motif.
- Les auteurs sont notifies apres validation ou refus.
- Les archives non validees restent visibles seulement a leur auteur ou aux validateurs.
- Les archives alumni/public doivent etre explicitement marquees avec une visibilite compatible.
- Les fichiers attaches passent dans le scope `archive`, deviennent non temporaires et restent proteges par les permissions FileStorage.

## Regles frontend verifiees

- L'ecran Archives reste en cartes responsives, sans tableau large.
- La recherche couvre projet, impact, prix, ODD et lecons.
- Les filtres par statut, annee et expansion utilisent des chips responsifs.
- Les cartes projet, details et Hall of Fame contraignent les textes longs avec ellipsis.
- Les documents officiels affichent des libelles simples sans MIME, chemin technique ou identifiant fichier.

## Points ouverts

- Ajouter une interface Flutter admin pour creer, soumettre, valider et refuser les archives.
- Ajouter le telechargement CSV natif cote Flutter apres choix web/mobile.
- Restreindre finement les propositions Enacchef au pole/projet concerne.
- Ajouter une moderation publique si certaines archives doivent sortir vers une vitrine externe.
