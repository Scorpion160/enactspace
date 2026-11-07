# Restauration des refontes Alumni, Archives et correctifs EnactMeet

## Origine de la régression

Lors de la réconciliation entre le backend de production et la branche GitHub,
les refontes **validées le 4 novembre 2026** sont restées dans deux PR séparées :

- PR #16 Alumni — `ecab02937807c9c0d318a70e29fe60cd022cb012`
- PR #17 Archives — `f9355b90fea8228433815ed448dfb06b356f5618`

Le JavaScript Web publié correspondait bien au code de la PR #21 mais ne
contenait pas ces dernières refontes. Le SHA256 du Web public observé avant
cette correction était
`FA19F83AE52EE3F88EC6EA7C1D1EC68B5C7F527D7B231BCE0DDAA49486E130A7`.

## Fichiers restaurés

- Les 18 fichiers du frontend Alumni/Archives issus de la PR #17 ;
- Les 12 illustrations clair/sombre, dont quatre dans
  `assets/heritage/` et huit dans `assets/heritage/illustrations/` ;
- Le service de normalisation des recherches avec accents et la comparaison
  alphabétique par nom puis prénom ;
- Le formulaire de mentorat individuel, les listes et les fiches Alumni ;
- Le contrôle de transition Enacteur vers Alumni et la réparation sécurisée de
  fiche, sans supprimer les protections de comptes de la PR #21 ;
- Les tests d'acceptation des deux refontes, notamment les documents d'Archives
  protégés et les recherches en version mobile.

**EnactMeet :** garder les correctifs les plus récents de la PR #21, notamment
la création de réunion simplifiée et les réglages avancés dans la page dédiée.
Ne pas substituer les fichiers EnactMeet de l'ancienne PR #17.

## Vérifications

- Analyse Dart complète des sources et des tests : réussie.
- 226 tests ciblés Alumni/Archives/EnactMeet/recrutement et membres : réussis.
- Les nouvelles API du mentorat individuel et du contrôle Alumni existent dans
  le backend de l'intégration ; les privilèges restent gérés par le serveur.
- Aucun test n'a créé de candidature sur la base de production.
- Aucun build APK Android.
- Le build Web doit être validé avec
  `ENACTSPACE_API_URL=https://api-enactspace.kerunjombor.net`.

## Conditions avant nouvelle publication

1. Faire passer les vérifications Web GitHub et vérifier les ressources
   illustrations des deux modes.
2. Sauvegarder la version actuelle du site et vérifier son SHA256 avant toute
   copie de fichiers.
3. Déployer d'abord une prévisualisation HTTPS puis tester Postuler, Alumni,
   Archives, EnactMeet et Campagne en chiffres.
4. Garder le backend et les candidatures strictement inchangés.
5. Ne pas supprimer le service worker Firebase de production ou ses paramètres
   générés lors d'une mise à jour du frontend.
6. Prévoir un retour arrière atomique en cas de régression.
7. Ne pas fusionner dans main tant que la CI backend générale n'est pas verte.

La livraison n'est **pas considérée comme déployée** tant que le contrôle
public HTTPS et l'empreinte des fichiers publiés ne sont pas confirmés.

## Preuves de compilation Web

- SHA256 public avant correctif : `fa19f83ae52ee3f88ec6ea7c1d1ec68b5c7f527d7b231bce0ddaa49486e130a7`.
- SHA256 nouveau paquet validé : `501e7f399d23b3f826c1553da25e38e32f6cbdfe636c66003d6e071a0e714cbb`.
- Le nouveau build Web est distinct du fichier actuellement publié.
- Le site public n'a pas été modifié pendant cette préparation.
