# Profils, mémoire institutionnelle et Impact — 3 octobre 2026

## Source et commits

Dépôt Windows : C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927
Branche : recovery/final-20260927.

- f8854c3 : sauvegarde des travaux récupérés.
- 90bed7e : photo de profil et libellés « Chef du pôle … ».
- cfc93ba : mémoire et impact institutionnels validés par Enactus ESP.
- ac2d808 : constante de provenance initialisée avant les tableaux Archives ; tests de cycle de vie des photos ; tests Impact adaptés à la validation institutionnelle.
- 6a5818e : lecture des enveloppes API Archives, navigation historique, nombres en français et actualisation par glissement.

Les chiffres historiques sont validés par Enactus ESP selon la confirmation explicite de Cheikh.
Ils restent accompagnés de leur provenance et de leur période ; ils ne sont pas additionnés aux mesures opérationnelles actuelles des projets.

## Contrôle initial sur Samsung SM_A065F

L'APK du 2 octobre a été installé le 3 octobre à 12:51:31.
Le fichier extrait du téléphone correspond exactement au build validé :
DEB528E4F6BCCB8F801AAD4998CB711EDB984805BA8DE80F0E5AE199E66A6865.

Le profil affiche « Chef du pôle Veille ».
Le formulaire de photo ouvre le sélecteur Android Galerie / Photos.
Aucune photo personnelle n'a été choisie ni enregistrée durant ce contrôle.
Le démarrage ne produit aucune entrée dans le journal Android de crash.

Le backend actif était antérieur aux commits profil et mémoire.
Le contrat API des collections utilisait projects, awards, competitions et statistics,
alors que le lecteur Dart n'acceptait que items / data : les listes étaient silencieusement vides.

## Backend livré en production

Six fichiers ont été comparés au code actif puis mis à jour :

- backend/app/api/routes/users.py
- backend/app/api/routes/files.py
- backend/app/api/routes/archives.py
- backend/app/api/routes/impact.py
- backend/app/services/file_storage_service.py
- backend/app/services/impact_pdf_service.py

L'image a été construite à partir de l'image de production existante, avec remplacement de ces six fichiers seulement.
Aucune migration de base n'était requise.
Les tests ont été exécutés dans une image isolée, sans réseau, avec SQLite en mémoire.
Les données de production n'ont pas été utilisées pour les tests.

Validation : 53 tests réussis (photos, mémoire institutionnelle, héritage, règles Impact et PDF).
Le chargement de app.main et la présence des routes photo ont également été contrôlés avant la livraison.

Image déployée : enactspace-backend:profile-memory-ac2d808.
ID : sha256:c543b1628671bca5ef3407d49e3952238991b3ecf88cc8452d1a67f28899684a.
Les services backend, email-worker et push-worker ont été recréés.
Backend, PostgreSQL et Web ont ensuite été constatés healthy.

Sauvegarde :
/opt/enactspace/backups/profile-memory-20261003-203521/backend-source.tgz

Image précédente :
enactspace-backend:before-profile-memory-20261003-203521

En cas de retour arrière, restaurer les six sources depuis l'archive,
retaguer cette image précédente en enactspace-backend:local,
puis exécuter depuis /opt/enactspace/app :

```sh
docker compose -f deploy/docker-compose.vps.yml up -d --no-deps backend email-worker push-worker
```

Les routes publiques OpenAPI confirment POST et DELETE /api/users/me/photo
et GET /api/files/{file_id}/profile-photo.

## Vérification Impact après livraison

Les chiffres ont été observés sur le Samsung :

- plus de 150 000 vies impactées ;
- plus de 200 emplois et 1 597 personnes formées ;
- 1 425 arbres plantés et 8 949 km parcourus ;
- 173 193 USD de revenus sur 2021–2022 ;
- 39 produits, 11 ODD et 36 640 heures investies.

La lecture des photos dans le Chat utilise déjà photo_url et normalise les URLs relatives avec ApiClient.serverUrl.

## Correctif frontend Archives

Les réponses nommées des collections API sont prises en charge.
Le parcours propose Vue d’ensemble, Projets, Palmarès, Compétitions, Hall of Fame, Documents et Médias.
Les nombres n'affichent plus de « .0 » ; les minimums conservent « Plus de ».
L'écran historique peut être rechargé par glissement vers le bas.

Validation ciblée : 37 tests Archives réussis, dont trois nouveaux tests de contrat API et d'interface.

## Statut final de validation Android

Analyse Flutter globale : No issues found (163,2 s).
Suite Flutter complète : 639 tests réussis, aucun échec (77 s).
Le PDF a aussi été généré avec le jeu réel de données institutionnelles : 55 702 octets, en-tête PDF valide.
Le contrôle de texte avec pdftotext n'a pas été réalisé, cet outil étant absent de l'image backend.

Nouvel APK release signé construit en 188,6 s :
C:\Users\DIOP\Downloads\EnactSpace-1.0.0-release-20261003-archives.apk

SHA-256 :
5A0E73206ADBA1114B6E0A46DD05B744CF7CD588E382DE7B8A13367A3980321E

La signature v2 est valide et dropbox_app_key=disabled est conservé dans l'APK.
L'URL API de production, le projet Firebase et l'identifiant d'application Firebase Android ont été retrouvés dans lib/arm64-v8a/libapp.so de l'APK final.

Le Samsung n'était plus visible dans ADB à la fin du build.
L'installation et la validation physique du nouvel écran Archives restent à effectuer.
Le test visuel d'une photo réellement choisie et de son affichage dans le Chat reste également à effectuer avec l'utilisateur.
