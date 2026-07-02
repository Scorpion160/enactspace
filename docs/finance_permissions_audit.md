# Audit permissions Finance

Date: 2026-07-02

## Perimetre verifie

- Comptes financiers membres.
- Frais, cotisations et penalites.
- Paiements, preuves, validation, rejet, annulation.
- Recu de paiement.
- Statistiques et exports.

## Roles et acces attendus

| Role | Acces attendu | Etat |
| --- | --- | --- |
| Administrateur | Vue globale, creation frais, validation/rejet paiements, exports | OK |
| Team Leader | Supervision globale, validation/rejet paiements, exports | OK |
| Financier | Gestion finance globale, validation/rejet paiements, exports | OK |
| SG | Pas de gestion finance par defaut, sauf role finance explicite | OK |
| Chef pole/projet | Pas de vue finance globale par defaut | A etendre plus tard si perimetre finance pole/projet active |
| Enacteur | Ses comptes, frais et paiements uniquement | OK |
| Alumni | Acces personnel uniquement si compte actif et valide | OK |
| Candidat | Aucun acces finance interne | OK via utilisateur valide requis |

## Regles backend verifiees

- Les routes globales `/finance/accounts`, `/finance/fees`, `/finance/payments`, `/finance/transactions`, `/finance/stats` et `/finance/export/*` exigent un role finance/admin.
- Les routes personnelles `/finance/accounts/me`, `/finance/fees/me`, `/finance/payments/me` et `/finance/stats/me` exigent un utilisateur actif valide.
- Un membre ne peut declarer un paiement que pour lui-meme, sauf role finance.
- Un paiement avec preuve peut etre valide ou rejete uniquement cote backend.
- Un financier ne peut pas valider/rejeter son propre paiement, sauf administrateur ou Team Leader.
- Le rejet d'un paiement exige un motif.
- Un paiement valide ne peut pas etre annule directement.
- Un frais paye ne peut pas etre annule.
- Les cotisations groupees utilisent une cle de source pour limiter les doublons.
- Les sanctions issues des presences restent liees a leur source afin d'eviter les doublons.

## Regles frontend verifiees

- Un membre simple charge uniquement les endpoints personnels.
- Les actions de creation frais sont masquees si `canManageFinance` est faux.
- Les actions paiement s'affichent selon `can_validate`, `can_reject` et `can_cancel` renvoyes par le backend.
- Les listes utilisent des menus d'actions compacts pour eviter les boutons multiples en ligne.
- Les noms, libelles et motifs longs sont tronques avec ellipsis pour limiter les overflows mobiles.

## Points ouverts

- Ajouter une vue finance limitee par pole/projet si Enactus ESP decide de donner ce droit aux chefs de pole/projet.
- Ajouter une generation PDF du recu si le besoin devient prioritaire.
- Brancher les exports CSV sur un bouton de telechargement natif cote Flutter lorsque la strategie mobile/web est arretee.
