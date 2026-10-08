# EnactSpace 1.0.10+13 — Alumni et parcours actif d’évaluation

## Corrections

La capture reçue le 6 octobre montrait une panne de l’annuaire Alumni. Le modèle attendait `alumni_profiles.enactus_join_year`, absent de la base alors que sa révision Alembic était déjà supérieure à celle qui avait introduit le champ. Le serveur renvoyait une erreur 500 ; le navigateur affichait une exception réseau brute.

La réparation additive `20261006_0024` ajoute le champ nullable seulement s’il manque. Elle conserve les années déjà renseignées et ne supprime pas ce champ lors d’un retour à la révision précédente, puisque la révision 0011 en reste propriétaire. Aucun parcours ou année d’adhésion n’a été inventé.

La commande de contrôle `python -m app.db.schema_validation` compare les tables et colonnes attendues aux éléments réellement présents. Elle échoue en cas d’absence, même si la révision Alembic paraît à jour. Le contrôle de production porte sur les noms des tables et colonnes ; il ne constitue pas un audit complet de tous les types, contraintes ou index.

Les erreurs de l’annuaire, des fiches et des actions Alumni utilisent des messages humains. Les textes d’exception, adresses d’API et diagnostics serveur ne sont plus affichés dans ces écrans. Le bouton Réessayer reste fonctionnel en mode clair et sombre, à 360 et 1440 pixels.

L’essai natif du jury a aussi révélé que la grille humaine était raccordée à un ancien écran, mais pas à la fiche candidat réellement utilisée. La section Évaluations propose maintenant Évaluer, ou Modifier mon avis. La fenêtre passe par le gateway actif et le service authentifié existant. Un niveau et un exemple sont obligatoires pour les cinq critères. Le propre avis de l’évaluateur est restauré ; une annulation ne crée aucun avis. Après enregistrement, la fiche et la liste reçoivent le nouvel indice sans changement automatique du statut. Une erreur d’enregistrement conserve le brouillon.

## Vérification serveur

- 51 tests du lot réparation/lifecycle/intégrité : réussite, avec un test PostgreSQL ignoré dans le lot SQLite isolé (50 exécutés).
- 4 tests de réparation et contrôle de schéma dans un environnement PostgreSQL dédié : réussite, sans test dans les données de production.
- Sauvegarde PostgreSQL avant migration : `/opt/enactspace/backups/alumni-repair-20261006/database.dump`.
- Les empreintes et effectifs des lignes historiques des 110 tables métier restent identiques après migration. Une seule colonne nullable a été ajoutée ; sa valeur reste NULL pour les lignes préexistantes.
- Après réparation : 110 tables attendues, aucune table ou colonne attendue manquante.
- Contrôles authentifiés en lecture seule avec le décideur existant : annuaire, filtre mentors, recherche et mentorats en HTTP 200, en-têtes CORS présents. Accès sans session refusé. Aucun profil présent à ouvrir dans la base actuelle.
- Aucun compte, profil, avis, statut de candidature ou statut de membre réel créé ou modifié par les contrôles.

## Vérification Flutter

872 tests : réussite. Analyse statique : aucun problème. Le parcours actif de jury est vérifié depuis la fiche réelle : ouverture, refus d’une grille incomplète, annulation par retour système, restauration, passage au gateway, actualisation de la fiche et maintien du statut. L’erreur de sauvegarde laisse la fenêtre ouverte et ne dévoile aucun diagnostic technique. Les changements ultérieurs d’accolades et d’annotations servent uniquement à respecter l’analyse statique.

## Essais physiques avant installation du build 13

Samsung SM-A065F, Android 16. Sur le build 12 : neuf parcours initiaux passent (photo de profil, recrutement, ouverture de fiche, historique, fermeture, Academy, Continuer, lecture de leçon, accueil). L’essai de grille a identifié le raccordement manquant, corrigé dans le build 13.

Après réparation serveur, l’annuaire vide et l’onglet Mentorat s’ouvrent correctement sur le téléphone. La galerie Dimbali ouvre et ferme une photo réelle, puis Retour Android restaure la collection. Le dossier SHERY s’ouvre, une page suivante est consultée, le PDF est réellement enregistré via le sélecteur Android, puis la fermeture et Retour restaurent la collection. Le téléchargement QA correspond à l’empreinte du PDF original ; seul ce fichier temporaire QA est retiré. Le téléchargement existant de l’utilisateur reste conservé. Les paramètres temporaires de maintien d’écran sont restaurés.

## Livraison et essai final

Web 1.0.10+13 publié : neuf routes, 14 photos et quatre PDF vérifiés. SHA-256 JavaScript : a2769ae7eb64aaed0d1942f3524d1103fd2a160a165951d19a9e73ceb90383ad.

APK signé avec le certificat existant, installé par mise à jour sur le Samsung sans réinitialisation : C:\Users\DIOP\Downloads\EnactSpace-1.0.10-release-20261006-alumni.apk ; 246565907 octets ; SHA-256 : 5405076caffffc9de39a085d86fa1f3f6d2d89aa7176a504ce21e9a2dc658072.

Les 13 essais natifs du build 13 passent : aperçu de photo, recrutement, fiche candidat, historique, fermeture, Academy, Continuer, lecture de leçon, accueil, Alumni/mentorat, ouverture des cinq critères avec annulation sans enregistrement, galerie Dimbali et Retour, puis dossier SHERY avec téléchargement contrôlé et Retour. Les résultats d’instrumentation sont frais et chaque test annonce OK. Les paramètres de maintien d’écran sont restaurés. Aucun avis ni statut réel n’est modifié.

Sauvegarde web : /opt/enactspace/backups/alumni-web-20261006. Retour aux exécutables précédents possible sans supprimer les nouvelles colonnes ou restaurer les données anciennes par-dessus les données actuelles. Le dépôt est sauvegardé par commit local ; aucun git push effectué.

Les contrôles ne sont pas une certification exhaustive de tous les appareils ou de chaque action de production. Aucun essai iOS ou quiz Academy complet sur téléphone n’est attesté par ce lot.
