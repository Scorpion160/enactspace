# Préproduction — lot 23 : Alumni et mentorat

Date : 7 octobre 2026. Correctifs dans le dépôt Windows, sans build ni déploiement.

## Résultat

Les demandes Alumni en attente, les comptes suspendus ou non vérifiés et les profils incohérents ne figurent plus dans l'annuaire validé. Les accès directs à leurs fiches suivent cette règle. Un Alumni peut modifier son propre profil, mais ses anciens rôles de direction ne lui permettent plus de gérer ceux des autres ni les mentorats.

Les modifications de profils et de mentorats relisent les comptes concernés sous verrou, dans l'ordre de leurs UUID. L'autorisation est recalculée après l'attente éventuelle. Une suspension, une perte de rôle ou un changement de disponibilité déjà validé ne peut donc pas être ignoré par une action en attente.

Un chef de pôle ou de projet et son adjoint ne peuvent gérer que les mentorats rattachés aux structures où ils exercent réellement une responsabilité active. Un changement de rattachement contrôle la structure initiale et la nouvelle. Si un mentorat lie à la fois un pôle et un projet, le responsable local doit être autorisé dans chacun. Les structures sont vérifiées et verrouillées en lecture pour préserver leurs références.

La création d'un mentorat exige un Alumni actif, vérifié, disponible et dont le profil est accessible à l'auteur. La confidentialité du profil s'applique également à la liste, au détail, à la modification, à la clôture et à la suppression des mentorats. Un profil privé ne peut pas être contourné par une affectation locale. Un mentor devenu indisponible peut encore voir son mentorat mis en pause ou clôturé par le responsable habilité ; sa réactivation exige de nouveau sa disponibilité.

La suppression d'un profil qui porte un mentorat, même historique, est refusée. La visibilité et la disponibilité permettent de retirer son exposition sans casser ce lien. La suppression explicite d'un mentorat reste possible pour un responsable autorisé ; ce lot ne rend pas l'historique immuable.

Les identifiants malformés, références absentes, dates inversées, textes trop longs et valeurs nulles interdites sont rejetés proprement. Les liens de profils doivent utiliser HTTP ou HTTPS, sans identifiants embarqués. Les champs personnels facultatifs peuvent être effacés explicitement. L'année d'entrée est exposée dans la fiche Alumni et sa correction synchronise le compte utilisateur.

## Fonctionnement par personne

| Personne | Accès couvert |
|---|---|
| Alumni actif et vérifié | Gestion de son propre profil et consultation selon les visibilités ; aucun pouvoir de gestion conservé par ses anciens rôles. |
| Enacteur ou Enactrice actif et vérifié | Consultation des profils internes ; aucun droit de modification sur le profil d'autrui. |
| Administrateur, Team Leader ou SG opérationnel | Gestion des profils Alumni, accès aux profils privés au titre de l'administration et gestion globale des mentorats. |
| Financier opérationnel | Gestion globale des mentorats au titre d'EnacChef, sans droit administratif général sur les profils privés. |
| Chef ou adjoint de pôle/projet opérationnel | Gestion des mentorats dans ses structures actives ; consultation des fiches selon leur visibilité. |
| Compte non opérationnel ou incohérent | Actions couvertes refusées, même avec un ancien rôle. |

## Vérification finale

- SQLite : **74 tests réussis en 45.777 secondes**.
- PostgreSQL : **44 tests réussis en 99.569 secondes**.
- Quinze scénarios fonctionnels ajoutés et quatre courses PostgreSQL ajoutées ; aucun test ignoré.
- Après le dernier ajout du contrôle de confidentialité aux actions de modification, clôture et suppression, les deux cas concernés ont été revérifiés sur SQLite (**1.586 secondes**) et PostgreSQL (**9.233 secondes**). Ils se recoupent avec les suites ; la suite complète n'a pas été répétée après ce dernier ajout ciblé.
- L'instrumentation des deux courses de modification de profil a été corrigée pour observer le verrou dans le service qui l'exécute réellement, puis la suite PostgreSQL complète a réussi.
- Courses nouvelles : suspension du propriétaire pendant une modification en attente ; retrait du rôle SG pendant une modification en attente ; indisponibilité du mentor pendant une création en attente ; suppression du profil et création du mentorat simultanées.
- Les suites reprennent également les contrôles antérieurs de responsabilités, structures, années et comptes. Les nombres se recoupent et ne représentent pas des scénarios indépendants cumulables.
- Un premier essai SQLite avait réutilisé un membre requis actif par les tests de gouvernance. La préparation crée désormais un Alumni synthétique distinct.
- Un premier banc PostgreSQL avait omis le montage de la route Alumni actualisée. Le montage a été corrigé puis l'ensemble de cette suite a été réexécuté.
- Syntaxe et git diff --check réussis. Les conteneurs et le réseau nommés PostgreSQL du lot sont absents après les essais.
- Données synthétiques uniquement, courriels et push désactivés. Aucun courriel, paiement ou changement de production.

## Limites et suite

Ce lot contrôle les routes backend Alumni et mentorat. Il ne remplace pas la recette de leurs écrans Android/web ni celle de l'application entière. Les autres routes privilégiées et interactions entre modules restent à auditer. La revue manuelle intégrale du dépôt et la restauration complète d'une sauvegarde réelle restent ouvertes.

Aucune migration supplémentaire, aucun build, déploiement ou push Git. Le head source reste 20261007_0029. La production demeure en 20261006_0025 et la redirection des courriels de test reste conservée.
