# EnactSpace V1.1 - Rapport test recrutement

## Tranche: recrutement public

- Formulaire public enrichi.
- Code de suivi candidat ajouté.
- Suivi compatible avec code public ou ancienne référence UUID.
- Notifications internes conservées pour les responsables recrutement.
- Champs nouveaux ajoutés avec compatibilité base existante.

## Tranche: suivi candidature

- Date de soumission visible.
- Dernière mise à jour visible.
- Message public par statut.
- Bloc entretien prévu si statut `interview_scheduled`.
- Résultat final public pour `accepted`, `rejected`, `waiting_list` et `cancelled`.
- Notes internes, scores et avis non exposés au candidat.

## Tranche: évaluation et sélection

- Filtres backend ajoutés: pôle souhaité, projet d'intérêt, département, classe, genre et dates de soumission.
- Filtres frontend ajoutés: genre, pôle souhaité, projet, département et classe.
- Dialogue d'évaluation enrichi avec avis favorable/réservé/défavorable.
- Les cartes candidat affichent les critères utiles au tri quand ils sont disponibles.

## Vérifications à rejouer

- `flutter analyze --no-pub` : OK
- `backend/.venv/Scripts/python.exe -m compileall backend/app` : OK
- `git diff --check` : OK

## Note environnement local

`backend/.env` contient des lignes de syntaxe à vérifier avant une recette longue ou un déploiement stable. Les valeurs ne sont pas documentées ici pour éviter toute fuite de secret.

## Données sensibles

Aucune donnée candidat réelle n'est incluse dans ce rapport.
