# EnactSpace 1.0.0 — patrimoine public et présentation responsive
Date de vérification : 3 octobre 2026 (UTC).

## Contenu intégré
- Deux photographies retrouvées dans les assets de la première version : trophées nationaux et Sonatel 2016, et UHODARI 2016. Les inscriptions visibles confirment l’année et les distinctions.
- Seize fichiers photographiques téléchargés depuis le site officiel Enactus ESP : quatre projets, trois actualités 2025 et neuf images de galerie. Une image de galerie identique à AQUATUS est conservée dans le manifeste mais évitée dans le catalogue.
- Catalogue de 24 entrées publiques : photographies, articles et quatre liens officiels. Chaque entrée documente sa provenance ; la galerie sans date reste sans date.
- Sources : https://www.enactusesp.com/ ; articles de l’ESP sur la World Cup 2018 et Dimbali (2021) ; publication Enactus ESP relayée sur LinkedIn pour la demi-finale World Cup 2022.
- Instagram https://www.instagram.com/enact.us_polytech/ et TikTok https://www.tiktok.com/@enactus.esp sont vérifiés via https://linktr.ee/Enactus.esp. L’accès aux publications Instagram et TikTok était limité : aucun contenu de publication inaccessible n’a été inventé ou importé.
- Polytech’Innovation 2025 : Terrasen premier prix et Aquatus deuxième prix, selon l’article officiel du 25 avril 2025.
- Les objectifs SHERY restent des objectifs. Les résultats Dimbali 2021 sont présentés avec leur localité et leur période ; les chiffres cumulatifs institutionnels approuvés ne sont pas écrasés.

Le manifeste 20261003-public-media-manifest.json contient les URL originales, les URL de téléchargement, les tailles et les SHA-256 des seize fichiers.

## Présentation
Les collections utilisent une grille de une, deux ou trois colonnes selon la largeur, avec hauteur naturelle des cartes. Sur mobile, les huit rubriques se choisissent dans un menu ; les chiffres complets disposent d’une rubrique dédiée. Les photographies conservent leur cadrage entier et s’ouvrent dans une visionneuse avec zoom. Les sources publiques s’ouvrent par un bouton distinct.
Une chronologie vérifiée vide et sans filtre ouvre automatiquement la mémoire institutionnelle pour les membres validés. Les filtres et la revue des responsables conservent leur comportement.

## Validation
- Backend : 57 tests réussis dans un conteneur isolé, réseau désactivé et base SQLite de test. Les tests vérifient notamment les filtres, les slugs de projet, les sources HTTPS, l’idempotence et la confidentialité des archives privées.
- Flutter : suite complète, 654 tests réussis ; 15 nouveaux tests de galerie, zoom, navigation et accès membre.
- Tailles de galerie testées : 360 × 800, 390 × 844, 768 × 1024, 1440 × 900, 1920 × 1080 ; thèmes clair et sombre. Texte à 200 % vérifié à 360 et 1440 px.
- Analyse Flutter globale sans problème. git diff --check réussi.
- Une capture exploratoire par RepaintBoundary a rencontré le chargement réseau des polices dans runAsync ; ce script temporaire a été supprimé. Ses captures avec police de test ne constituent pas une validation visuelle typographique. La suite de tests normale est réussie ; les contrôles visuels de production sont consignés séparément ci-dessous.
- Finition supplémentaire : suppression de la deuxième poignée de glissement dans la feuille d’inscription, puis nouvelle analyse et nouveaux builds.

## Déploiement backend
Image : enactspace-backend:public-heritage-20261003
SHA-256 : c634f044e15e34a79c5a6ec1a6861c952566804860c2253f566cfbba79e1a112.
Déployé le 3 octobre 2026 à 22:08:36 UTC.
Backend, email-worker et push-worker recréés ; aucun changement de base, de migration ou de Jitsi.
Sauvegarde : /opt/enactspace/backups/public-heritage-20261003-220836/backend-source.tgz.
Image précédente : enactspace-backend:before-public-heritage-20261003-220836.
Contrôle public /health : ok, environnement production ; conteneur healthy.

## Déploiement web
URL : https://enactspace.kerunjombor.net/
Première mise en ligne à 22:19:20 UTC. Sauvegarde : /opt/enactspace/backups/web-public-heritage-20261003-221920/web-before.tgz.
Les photos de trophées et l’image Polytech’Innovation renvoient HTTP 200. Le JavaScript principal reçoit les en-têtes no-cache.
Les valeurs publiques Firebase et VAPID de la version précédente sont conservées et comparées au JavaScript déployé sans exposer les valeurs.
Contrôle visuel dans le navigateur : connexion, guide débutant et inscription affichés correctement ; le double indicateur de glissement observé à l’inscription a été corrigé. La session cloud reste non authentifiée : les Archives connectées sont vérifiées sur le Samsung et dans les tests Flutter.

## Contrôle Android
Samsung SM_A065F, Android ADB R83XA0BB4FK.
Une première version patrimoine a été installée avec succès ; session membre existante conservée.
Navigation réelle Archives → Médias → trophée national : photographie affichée en entier, ouverture plein écran et fermeture contrôlées. Les inscriptions 2016 et Sonatel sont lisibles.
Le profil personnel n’a reçu aucune photographie choisie arbitrairement.
La signature APK v2 est vérifiée. La ressource dropbox_app_key reste disabled.

## Livraison finale
Les empreintes et les derniers contrôles sont ajoutés après publication de la finition d’inscription.

- Nouvelle analyse après la finition : aucun problème (27,4 s).
- Parcours public de candidature : 12 tests existants réussis après la finition.
- APK final : C:\Users\DIOP\Downloads\EnactSpace-1.0.0-release-20261003-heritage.apk ; SHA-256 3B117F3D331583E76D82D2E5EEF6A74BB8A2F3E1B6D990A86BC1B882C046EE1A ; signature v2 vérifiée.
- Archive web finale : enactspace-web-heritage-20261003.tgz ; SHA-256 467EF6686F273FEA7718CDE6086D9CBA9A8B0F93EB6D44D03BEA64ED07163220.
- Contrôle Android complémentaire : UHODARI puis carte Polytech’Innovation 2025 visibles dans Médias ; titre, description et source présents. Le bouton Consulter la source ouvre le domaine officiel www.enactusesp.com dans le navigateur Android.

- APK final installé sur le Samsung : adb install -r renvoie Success (54 s), données de session conservées.
- Web final publié à 22:30:35 UTC ; HTTP 200 pour la page et la photographie officielle ; /health public ok.
- Sauvegarde de la publication intermédiaire avant finition : /opt/enactspace/backups/web-public-heritage-final-20261003-223035/web-before.tgz. La sauvegarde de 22:19:20 conserve la version antérieure à tout ce chantier patrimoine.
- SHA-256 main.dart.js final : 14781d3d16e7bd95e6128929ecc5408627e4b629d1dcfaea056dec0cb46d2e20 ; les paramètres publics Firebase et VAPID sont toujours vérifiés.
- Contrôle visuel web final : la feuille d’inscription présente une seule poignée ; tous les champs et les boutons sont visibles à 1363 × 936. Le formulaire est fermé sans soumission.
- L’article officiel Polytech’Innovation 2025 est chargé dans le navigateur Android : titre, date du 25 avril 2025 et sous-titre sur la double victoire observés.
- Relance Android après l’installation finale : accueil connecté de Cheikh Tidiane DIOP affiché ; EnactMeet affiche ses rendez-vous existants ; Mon profil affiche la position Chef du pôle Veille. Aucune réunion lancée ou modifiée pendant ce contrôle.
- Commit d’intégration : ee6563e sur recovery/final-20260927. Une ancienne sauvegarde email_worker.py.before-model-registration-fix préexistante reste hors du commit. Aucun push GitHub exécuté.
