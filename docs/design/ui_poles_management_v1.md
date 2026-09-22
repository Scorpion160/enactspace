# UI Pôles management v1

## Périmètre

La phase 2F-B ajoute à l'interface Flutter la gestion des pôles et de leur
équipe. Elle réutilise les routes `/poles` et `/poles/:poleId`, ainsi que le
gateway injectable du portefeuille. Aucun widget n'effectue directement un
appel réseau et aucun contrat backend, fixture ou permission serveur n'est
modifié.

## Fonctions

- création d'un pôle depuis le portefeuille avec nom, sigle, type,
  description et objectifs ;
- édition depuis la fiche, suivie d'un rechargement des données mises en cache
  sans quitter la fiche ;
- recherche d'une personne active dans l'annuaire, ajout ou réintégration en
  tant que `membre` et désactivation des personnes déjà présentes dans
  l'équipe active ;
- nomination ou remplacement du chef (`chef_pole`) et de l'adjoint
  (`adjoint_chef_pole`) ;
- retrait logique d'un membre ou d'un responsable après confirmation ;
- prévention des doubles soumissions et restitution des erreurs dans chaque
  dialogue sans perdre les saisies ou la sélection.

Les libellés visibles traduisent `metier` par « Pôle cœur » et `support` par
« Pôle support ». Les positions techniques ne sont jamais présentées brutes.
Lors du remplacement d'un responsable, l'interface précise que l'ancien
titulaire redevient membre et reste dans l'équipe active. Le retrait d'un chef
ou d'un adjoint exige une confirmation renforcée et affiche : « Aucun
remplacement automatique ne sera effectué. » Le retrait est toujours décrit
comme une sortie de l'équipe active, jamais comme une suppression définitive.

## Permissions UI

| Profil | Créer | Modifier | Membres ordinaires | Nommer/retirer un responsable |
|---|---:|---:|---:|---:|
| Administrateur | Oui | Tous | Tous | Oui |
| Team Leader | Oui | Tous | Tous | Oui |
| Secrétaire générale | Oui | Tous | Tous | Oui |
| Chef actif du pôle | Non | Son pôle | Son pôle | Non |
| Adjoint actif du pôle | Non | Son pôle | Son pôle | Non |
| Autres profils | Non | Non | Non | Non |

Les contrôles frontend rendent les actions cohérentes avec ces droits, tandis
que le backend reste la source d'autorité finale.

## Architecture et état local

`PoleMutationDraft` centralise le payload des créations et éditions.
`PoleManagementPermissions` centralise la matrice de droits et
`PolePositionPresentation` les valeurs canoniques et leurs libellés. Le
gateway `PolesPortfolioGateway` expose l'utilisateur courant, l'annuaire et
les quatre mutations. Son implémentation API invalide les caches concernés
après succès ; les écrans rechargent ensuite le portefeuille ou la fiche.

Les composants de formulaire, d'équipe, de sélection de membre, de nomination
et de retrait sont regroupés dans `pole_management_widgets.dart`. Les écrans
restent injectables avec un gateway mémoire pour les tests widgets.

## Accessibilité et responsive

Les actions utilisent des boutons nommés, les retraits ordinaires possèdent un
tooltip contextualisé, les champs ont des libellés explicites et les états
d'envoi désactivent toutes les actions concurrentes. Les groupes d'actions se
replient avec `Wrap`, les contenus modaux sont défilables lorsque nécessaire et
la section équipe est vérifiée à 390 px sans débordement.

## Tests sans mutation réelle

La suite `poles_management_test.dart` couvre les droits globaux, locaux actifs
et la lecture seule, le payload et la validation du formulaire, les succès et
erreurs, la conservation des données, le double envoi, le filtrage de
l'annuaire, l'exclusion des comptes inactifs et alumni, la personne déjà
membre, l'ajout/réintégration, les remplacements chef et adjoint, les deux
niveaux de retrait, l'absence de remplacement automatique, les libellés
humanisés et le responsive 390 px.

Tous les scénarios de mutation utilisent des callbacks ou un gateway mémoire.
Ils n'émettent aucune requête applicative réelle :

```text
real_create_requests=0
real_patch_requests=0
real_member_post_requests=0
real_member_delete_requests=0
application_mutation_performed=false
```

## Limites

La phase ne crée ni suppression définitive, ni archivage de pôle, ni
historique local des changements. Les réponses d'autorisation et les règles
de réactivation restent garanties par le backend. Les captures de validation
visuelle sont volontairement reportées à l'étape séparée prévue.
