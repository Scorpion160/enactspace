# Finance V1

La tranche Finance V1 présente les montants attendus, encaissés, restants et en attente, avec une lecture adaptée aux rôles.

Les paiements conservent les statuts API mais les affichent avec des libellés humains. Les actions de validation, rejet et annulation restent pilotées par les permissions renvoyées par l'API.

Les preuves sont limitées aux URL `http` et `https`. Les chemins relatifs sont résolus à partir de l'API locale. Les images sont prévisualisées dans l'application avec le jeton de session ; les documents affichent leur type et une action d'ouverture complète.

Le résumé Mobile Money est chargé séparément : une erreur locale ne masque pas les comptes, frais ni paiements.
