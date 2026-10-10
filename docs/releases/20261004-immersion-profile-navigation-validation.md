# EnactSpace 1.0.0 — immersion, aperçu photo, retours et biométrie
Vérification : 4 octobre 2026 UTC. Demande reçue le 3 octobre à 23:42 UTC.

## Corrections
L’avatar de Mon profil et des profils membres ouvre une photo entière en plein écran, avec zoom jusqu’à 5×, indicateur de chargement, message d’erreur et bouton de fermeture. Un profil sans photo ne propose pas de visionneuse vide. L’aperçu ne modifie ni l’image ni le profil.

Les pages internes de détail disposent d’un bouton Retour dans la barre mobile et la barre web. Les ouvertures depuis les Archives utilisent une navigation empilée pour retrouver la collection précédente. Une URL ouverte directement propose un retour vers son module. Le parcours public de candidature dispose aussi d’une barre avec Retour, y compris Suivre ma candidature.

Les 16 projets disposent de récits développés : contexte, besoin, solution et héritage, selon les éléments documentés. Les 8 compétitions disposent de sections explicatives ; les 11 distinctions relient le prix à son histoire et, lorsque l’association est connue, au projet concerné. De nouvelles routes /archives/competitions/:recordId et /archives/awards/:recordId ouvrent ces fiches. Les récits sont limités à une largeur de lecture confortable sur grand écran. Les cartes restent synthétiques et donnent accès aux détails.

Les mentions génériques de validation et les badges Historique validé / Mémoire historique Enactus ESP sont retirés des présentations historiques. Les états de workflow nécessaires aux responsables restent fonctionnels. La source des trophées devient exactement Photothèque Enactus ESP, sans référence à une première version d’EnactSpace.

La biométrie est rétablie dans le formulaire avec un bouton permettant de réessayer. Une session sauvegardée sur un appareil mobile disposant de biométrie enregistrée déclenche le déverrouillage au démarrage même si l’identifiant mémorisé manque. L’identifiant peut être repris du profil en cache ; aucun mot de passe n’est enregistré. L’annulation conserve l’écran de connexion ; une réussite biométrique doit encore restaurer une session valide. Une session expirée demande une reconnexion. Le web et les appareils sans biométrie restaurent normalement leur session.

## Fidélité du contenu
Les récits utilisent la mémoire institutionnelle déjà fournie et les publications publiques référencées lors de la livraison précédente. Ils n’ajoutent aucun résultat chiffré et ne remplacent pas les bilans d’impact. Les résultats Dimbali 2021 conservent leur localité et leur période ; les objectifs SHERY restent des objectifs. CAJOR reste situé dans le cycle 2022–2023 et au pôle Chimie, sans procédé ni résultat inventé.
La World Cup 2018 est située à San José et reliée à DIMBALI et DECONAANE ; celle de 2022 à Porto Rico et à DIMBALI/MËN NAÑ. Les nouvelles fiches de concours donnent accès aux projets associés.

## Vérification
- 669 tests Flutter réussis, dont 15 nouveaux tests pour la visionneuse, le retour depuis un lien direct, la conservation de la recherche, le suivi de candidature, les récits à 360/1440 px et à 100/200 %, et les parcours biométriques.
- Analyse Flutter : aucun problème.
- 60 tests backend réussis en conteneur isolé sans réseau et avec SQLite de test. Trois tests supplémentaires vérifient les récits, leurs liens, leur idempotence, la conservation des chiffres d’impact et le libellé de la photothèque.
- Les deux attentes de contrat de source mises à jour correspondent au service biométrique extrait et aux deux nouvelles routes ; les tests de session et de confidentialité restent présents.
- Android conserve FlutterFragmentActivity et la permission biométrique existante.
- Le contrôle biométrique physique utilise uniquement la demande Android normale : aucune simulation de réussite sur le téléphone.

## Backend
Image : enactspace-backend:ux-details-20261004.
SHA-256 : fc424e05d00f3ecf62b362d848fceb883cc004543a70b3c7ce07a2c942c33443.
Sauvegarde : /opt/enactspace/backups/ux-details-20261004-000723/backend-source.tgz.
Image précédente : enactspace-backend:before-ux-details-20261004-000723.
Backend et workers recréés ; aucune migration ou écriture de données métier pendant la validation.
Le catalogue importe correctement 16 projets et 8 compétitions. /health répond ok.

## Livraison et contrôle réel
Les empreintes des builds finaux, la publication web et les observations sur le Samsung sont consignées ci-dessous après vérification.


### Builds et publication
- APK final : `C:\Users\DIOP\Downloads\EnactSpace-1.0.0-release-20261004-immersion.apk` ; SHA-256 `5C5E9CB38AFF565C9DBA8BCA3F8FCB6D0637EDE7B47320A2A5D9F30644676307`. Signature APK v2 vérifiée. Installation de mise à jour sur le Samsung R83XA0BB4FK : Success.
- Archive web : `enactspace-web-immersion-20261004.tgz` ; SHA-256 `E1A8EABC24750185D05597831FC174E3DA932BD8C4CAA4ED487769F926D1B28B`.
- `main.dart.js` local, déployé et téléchargé depuis l’URL publique : SHA-256 `87f77d6e770e556db6570e14ca3155e5c0e8a7049d977bbb60cd520f5f8daef3`.
- La phrase narrative finale du bandeau Archives a été vérifiée dans les deux binaires. Le premier APK de contrôle a été remplacé par le build final après cette dernière correction de texte.
- Les 7 paramètres publics Firebase web/VAPID, le service worker et les 16 photos de patrimoine restent présents dans le build web.
- Sauvegarde web avant publication : `/opt/enactspace/backups/web-ux-details-20261004-001721/web-before.tgz`.
- Publication : https://enactspace.kerunjombor.net/ ; API `/health` répond ok en production. Backend et web healthy, workers actifs.

### Observations réelles
Dans le navigateur, la page Suivre ma candidature présente le bouton Retour, la mise en page en deux colonnes est lisible et le bouton retourne effectivement à la connexion. Aucune candidature n’a été envoyée. Le contrôle des fiches protégées dans ce navigateur reste couvert par les tests widgets, sans récupération de jetons de session du téléphone.

Sur le Samsung, la demande Android normale « Déverrouiller votre session EnactSpace » a été observée après installation du build de contrôle. Le build final a ensuite été installé avec succès. Au contrôle suivant, le téléphone était verrouillé au niveau Android : l’inspection du profil personnel et des fiches avec la session réelle reste à reprendre après le déverrouillage par l’utilisateur. La visionneuse et les récits ont passé les tests widgets ; aucune réussite biométrique physique n’est déclarée sans observation.
