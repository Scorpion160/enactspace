# Audit permissions Impact

Date: 2026-07-02

## Perimetre verifie

- Fiches impact liees aux projets.
- Indicateurs impact.
- Preuves impact liees aux fichiers stockes.
- Dashboard global.
- Exports CSV et rapport synthese.
- Validation/refus des donnees et preuves.

## Roles et acces attendus

| Role | Acces attendu | Etat |
| --- | --- | --- |
| Administrateur | Gestion globale, validation, rejet, exports | OK |
| Team Leader | Gestion globale, validation, rejet, exports | OK |
| SG | Consultation globale utile aux rapports via acces Enacchef | OK |
| Chef projet | Contribution aux donnees impact via acces Enacchef | OK, perimetre fin a renforcer |
| Adjoint projet | Contribution via acces Enacchef | OK, perimetre fin a renforcer |
| Chef pole | Consultation/contribution via acces Enacchef | OK, perimetre pole a renforcer |
| Enacteur | Pas d'acces interne Impact si role simple uniquement | OK |
| Alumni | Pas d'acces interne Impact par defaut | OK |
| Candidat | Aucun acces au module interne | OK |

## Regles backend verifiees

- Les endpoints `/impact/projects`, `/impact/summary`, `/impact/records`, `/impact/export/*` et `/impact/report/summary` exigent un utilisateur valide avec role Enacchef/Admin.
- Les fiches impact sont liees a un projet existant.
- Une seule fiche impact principale est autorisee par projet.
- Les indicateurs imposent une categorie et une unite connues.
- Les preuves peuvent etre liees a un indicateur, mais seulement si l'indicateur appartient a la meme fiche impact.
- Les rejets de fiche, indicateur ou preuve exigent un motif.
- Les validations/refus de fiche, indicateur et preuve sont reserves a Admin/Team Leader.
- Les auteurs sont notifies apres validation ou refus.
- Les responsables sont notifies lorsqu'une donnee ou preuve est soumise.

## Regles frontend verifiees

- L'ecran Impact reste en cartes responsives, sans tableau horizontal.
- Les noms de projet, responsables et lignes longues utilisent `maxLines`/ellipsis.
- Les preuves sont resumees sans afficher URL, MIME, chemin technique ou identifiant fichier.
- Les ODD, beneficiaires, methodologie, projections et indicateurs environnementaux sont lisibles dans la fiche projet.
- Les exports sont prepares cote backend; le branchement telechargement natif Flutter peut etre ajoute apres choix web/mobile.

## Points ouverts

- Restreindre finement les chefs de projet a leur projet et les chefs de pole a leur pole.
- Ajouter une UI de creation/modification des fiches Impact depuis Flutter.
- Ajouter une generation PDF lorsque le modele de rapport est valide.
- Ajouter une strategie publique pour afficher certains impacts aux alumni/candidats sans exposer les donnees internes.
