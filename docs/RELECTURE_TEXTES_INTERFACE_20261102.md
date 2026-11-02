# Relecture des textes de l’interface — 2 novembre 2026

Les textes du recrutement expliquent désormais l’action à réaliser, les informations attendues et la suite du parcours. Les répétitions sur la lecture des réponses ou la « décision humaine » sont retirées. La relecture couvre aussi les formulations techniques et les consignes de développement repérées dans les autres rubriques.

## Principales corrections

| Écran | Correction |
| --- | --- |
| Évaluer la candidature | Consigne pour choisir un niveau de 0 à 4 et ajouter une observation du dossier ou de l’entretien ; descriptions et repères plus directs. |
| Questionnaire de préparation | Présentation de son objectif, de l’enregistrement des réponses et des personnes qui pourront les consulter ; suppression des commentaires répétés sur l’admission et la validation de la traduction. |
| Formulaire et suivi candidat | Aides plus courtes, confirmation d’envoi claire, synthèse des réponses et mises en situation nommées simplement. |
| Intégration d’un candidat | Explication des affectations à préparer ; suppression des références au serveur et des commentaires sur le mot de passe absent du résultat. |
| Paiement et justificatifs | Instructions pour payer et vérifier le reçu ; retrait du texte sur les liens non documentés, du terme OCR et des erreurs brutes dans l’aperçu. |
| Messagerie | Envoi de fichiers décrit simplement ; retrait des champs manuels Base64, MIME et taille en octets. La sélection du fichier continue de renseigner ces informations pour l’envoi. |
| Présences | « Code de pointage » et consigne de scan à la place du jeton et du QR signé. |
| Archives | Présentation de l’histoire et des résultats du club sans commentaire sur une lecture « humaine, strictement fondée ». Les sources restent consultables. |
| Academy | Messages d’enregistrement et de reprise compréhensibles ; retrait des formulations sur la validation « côté Academy » ou la réponse du serveur. |
| Projets, pôles et tâches | Indicateurs de suivi et dates nommés simplement ; suppression d’une annonce de prochaine mise à jour dans le journal du projet. |
| Veille | Présentation des engagements, livrables et difficultés ; méthode de calcul raccourcie. Les étapes de traitement et la possibilité de réexamen restent expliquées. |
| Aide, réglages et démonstration | Consignes plus courtes et messages d’échec reformulés. Le caractère démonstratif des exemples reste identifiable. |

La consigne principale de l’évaluation devient :

> Choisis un niveau de 0 à 4 pour chaque critère et ajoute une observation tirée du dossier ou de l’entretien. Si un point reste flou, demande une précision avant de le noter.

## Données déjà enregistrées

Le recrutement conserve des versions de questionnaires et des textes de campagne. Un remplacement au seul affichage reconnaît 35 anciennes formulations standard pour présenter leur nouvelle rédaction. Les réponses, notes et versions enregistrées ne sont pas réécrites. Les textes personnalisés qui ne correspondent pas à ces formulations restent affichés tels quels.

La même approche s’applique à l’ancien paragraphe standard de calcul des bilans Veille. Les anciennes phrases présentes comme clés de correspondance dans le code ne sont pas les textes rendus à l’écran.

Les identifiants des critères et des questions, les niveaux, les calculs, les droits d’accès et les transitions de candidature sont conservés. Les exemples recevables dans la grille incluent toujours les expériences scolaires, personnelles, familiales et associatives.

## Lien de suivi dans les e-mails

Les messages de candidature et d’invitation au questionnaire utilisent :

`https://enactspace.kerunjombor.net/#/application-tracking`

Le bouton HTML de l’invitation mène aussi au suivi lorsque l’objet ne contient pas le mot « candidature ». Le code de suivi et l’adresse e-mail ne sont pas ajoutés à l’URL.

## Vérifications effectuées

- Inventaire automatisé des chaînes du frontend et du backend, suivi d’une revue des passages repérés dans leur contexte d’affichage. Les commentaires, diagnostics de développement, contenus pédagogiques et mentions juridiques utiles sont distingués des textes d’interface.
- 114 tests backend réussis : e-mails en français, grille, questionnaire de candidature, jury et personnalité, cycle de campagne, Veille, sessions et sondages de messagerie. Ces tests utilisent des données isolées et désactivent les envois d’e-mails et de notifications.
- Analyse syntaxique des 55 fichiers Dart modifiés, sans erreur, et des fichiers Python modifiés. Cette vérification ne remplace pas l’analyse Flutter ni ses tests de widgets.
- Vérification du script de synchronisation PowerShell : contrôle des chemins et empreintes, reconnaissance des fins de ligne Windows, conservation de modifications locales inconnues, refus d’un téléchargement altéré et restauration après une erreur de copie. Dart, Flutter et le téléchargement sont simulés uniquement dans ce test du script.
- Extension du test de réouverture d’évaluation pour vérifier l’affichage d’une ancienne consigne sans modifier la grille enregistrée ni les notes existantes. Son exécution Flutter reste à effectuer.

Commande backend exécutée :

```bash
python -m unittest test_email_french_copy test_recruitment_rubric test_recruitment_questionnaire test_recruitment_jury_personality test_recruitment_campaign_lifecycle test_veille test_auth_sessions test_chat_polls -q
```

## Validation et publication à poursuivre

Le script `tools/sync_interface_copy_windows.ps1`, appelé avec le commit précis de cette correction, prépare la validation sur le poste Windows disposant de Flutter :

1. Vérifier les empreintes et le code local avant tout remplacement ; conserver les différences inconnues dans une archive et interrompre l’opération.
2. Sauvegarder les sources reconnues, installer les corrections et les deux définitions publiques backend utilisées par les tests de correspondance.
3. Formater les fichiers Dart concernés, lancer l’analyse Flutter et la suite complète de tests.
4. Générer les 52 captures du parcours recrutement et les regrouper dans une archive pour la relecture visuelle.

Le script ne publie pas l’application et ne lance aucun processus backend. Les deux fichiers backend copiés localement servent à la correspondance des définitions avec les tests Flutter.

À ce stade, les corrections sont dans les sources. L’analyse Flutter, les tests de widgets, la relecture des nouvelles captures et la publication sont encore à confirmer. Le build public 1.0.23+26 précédemment vérifié précède cette correction. Les nouveaux textes d’e-mails nécessiteront également la mise à jour du backend.

## Reprise après la première analyse Windows

La synchronisation du commit `575bd5ba7b75d70b8f240fe4a67735b7936c11c8` a créé une sauvegarde et formaté les 55 fichiers Dart concernés. L’analyse Flutter a ensuite signalé un seul diagnostic : `curly_braces_in_flow_control_structures` dans `archives_api_service.dart`. Les tests et les captures n’ont pas été lancés.

La condition de contrôle du type de réponse est maintenant entourée d’accolades. Son comportement et son message restent identiques. Le manifeste prend la version déjà installée comme référence et reconnaît aussi ses fichiers Dart formatés, pour permettre la relance des vérifications avec la correction. L’analyse Flutter doit de nouveau terminer sans diagnostic avant de poursuivre les tests et les captures.

## Reprise après la suite complète de tests Windows

Le contrôle du commit `fd5a20a220734d15eac6e3a414e893d94dd15b4b` a terminé l’analyse Flutter sans diagnostic. La suite complète a ensuite compté 1 113 réussites et 32 échecs ; aucune capture ni publication n’a suivi.

Les 32 cas signalés se répartissent ainsi :

- 17 attentes portant sur les anciens libellés des tâches, du retrait de responsable, de l’intégration, de l’acceptation et de la FAQ candidat. Elles utilisent maintenant les textes corrigés ; les assertions sur les boutons, confirmations, droits et mutations restent présentes.
- 12 variantes du test de photos, sur trois largeurs, deux tailles de texte et les deux thèmes. L’accueil présente trois récits illustrés depuis la refonte. Le test vérifie désormais les trois photos identifiées, ainsi que l’accès aux pièces jointes et aux outils d’équipe, au lieu d’attendre quatre photos.
- Deux vérifications de restauration qui dépendaient d’un ancien nom de classe et d’une disposition de sélecteur remplacée par la barre de filtres commune. Les contrôles conservent l’absence d’en-tête ajouté aux dialogues, le thème commun et une disposition encadrant les sélecteurs.
- Un chargement du recrutement en démonstration qui créait les nouveaux outils de campagne avec les services d’authentification habituels. Ces outils reçoivent maintenant explicitement le transport et l’authentification de démonstration. Les lectures d’accès, de jury et de questionnaire utilisent des réponses locales ; leurs mutations restent bloquées par le transport de démonstration.

Le test des services de démonstration inclut ces nouvelles lectures sous interception des accès réseau et vérifie le refus d’une invitation au questionnaire. Le test d’écran exige aussi la présence de la liste des candidatures, pour qu’un écran d’erreur ne puisse pas être considéré comme un chargement réussi.

Aucun test ni aucune variante de largeur, de thème ou de taille de texte n’est retiré. Le nouveau manifeste inclut les huit fichiers de tests concernés et les deux fichiers de démonstration corrigés. Sa référence est la version déjà installée. La syntaxe Dart et les contrôles PowerShell ont été vérifiés ici ; l’analyse et la suite Flutter doivent être relancées sur Windows pour confirmer le résultat.

## Validation Windows réussie

L’opération `b39a52771da8498a98aca4b94efa1aca` a validé le commit `de640506fe8d07bd93f19528ebf0a6d8a488ebcb`. L’analyse Flutter termine sans diagnostic et les 1 145 tests passent. Les quatre séries à 390 et 1440 pixels, en clair et en sombre, produisent les 52 captures dans `enactspace-interface-rendu-b39a52771da8498a98aca4b94efa1aca.zip`. Le journal confirme la génération de l’archive. La relecture visuelle attend sa réception.

Le lanceur `tools/build_interface_copy_web_windows.ps1` prépare la version 1.0.24, build 27. Il vérifie le reçu Windows, les sources du manifeste utilisées par la compilation et le fichier de configuration déjà utilisé pour Firebase. La compilation et l’archive sont produites dans un nouveau dossier `WebInterfaceBuilds`. Le reçu `build.json` donne la version et les empreintes du JavaScript et de l’archive pour préparer la publication.

Le lanceur a passé une vérification avec Flutter et le contrôle de version publique simulés. La génération Firebase et la création de l’archive ont été exécutées sur des fichiers de test. Les refus d’une modification des sources, d’une autre version publique et d’un reçu de validation incomplet ont aussi été vérifiés.

## Compilation web 1.0.24 (27)

Le reçu Windows de l’opération `aa0f9b4affa14551bd69b5ce0d7fd873` confirme la compilation Flutter Web et la création de `web-release.tar.gz`.

| Fichier | SHA-256 |
| --- | --- |
| `main.dart.js` | `18847f88b8026e344f47ab93e8f776b8caa95e8ed5fb1ae1277256a80485d875` |
| `web-release.tar.gz` | `87ca43801e44dccb336ae3e873862ab92f76af1cd273ea93817561b8cdadbd73` |

Le lanceur `tools/publish_interface_copy_web_windows.ps1` vérifie le reçu et l’archive d’origine. Le mode de publication transfère cette archive au VPS, vérifie les empreintes après transfert et contrôle que la version 1.0.23 (26) attendue est encore en place avant la bascule. Il vérifie ensuite la version et le JavaScript servis en HTTPS. Le VPS conserve un dossier de retour arrière.

Les six tests du programme de publication passent. La simulation du lanceur PowerShell confirme le refus d’une archive modifiée localement ou après transfert, le déroulement de la bascule et le contrôle lors d’une relance après publication.

## Relecture des captures Flutter

Les 52 captures de l’opération `b39a52771da8498a98aca4b94efa1aca` couvrent 13 vues à 390 et 1440 pixels, chacune en clair et en sombre. La revue confirme l’affichage intégral de la description de campagne après « Lire la suite », la lisibilité des statuts observés, des consignes d’évaluation et des actions de suivi. Les captures utilisent les données fictives du scénario de test.

À 390 pixels, le sélecteur fermé du jury coupe la fin du nom de campagne. Les champs du titre et de la description dans l’éditeur montrent la fin du texte saisi et permettent de faire défiler le contenu. Ces observations ne bloquent pas la mise en ligne de cette version.

## Publication web confirmée le 2 novembre 2026

Le journal Windows `0eedd66f14a54f1595943ebae3f64811` confirme la publication web **1.0.24 (27)**. Le VPS sert les cinq fichiers vérifiés et les routes `/academy`, `/archives`, `/recruitment/apply` et `/application-tracking`. Le contrôle HTTPS suivant confirme le numéro de build, l’empreinte du JavaScript et la disponibilité du point de contrôle de l’API. Le répertoire de retour arrière est `/opt/enactspace/releases/web-previous-1d7ef5d77dce4c919f6e5ef7c07401cc`.

Les textes serveur font partie d’une livraison distincte. Les versions antérieures des neuf fichiers concernés concordent avec les quatre fichiers du manifeste de publication du backend 1.0.21 et les cinq fichiers correspondants de l’image de base.

## Recette de l’image serveur

Le contrôle en lecture seule confirme la version API 1.0.21 et les quatre services sur l’image `sha256:415403e80c33ab717337d3e742bfea544dcc3651fc147da107450d76582bcc04`. Quatre empreintes concordent directement. Les cinq autres concordent à l’octet près après conversion des fins de ligne en CRLF. Le manifeste fixe les neuf empreintes brutes observées sur le VPS.

Le lanceur `tools/rehearse_interface_copy_backend_windows.ps1` transfère les neuf fichiers serveur du commit `575bd5ba7b75d70b8f240fe4a67735b7936c11c8` et les fichiers de test. L’image candidate est dérivée de l’image en service avec un contexte de construction limité aux neuf fichiers serveur. Les tests s’exécutent dans un conteneur en lecture seule, sans réseau, avec SQLite et les e-mails et notifications désactivés. Le compte rendu vérifie les empreintes, le schéma Alembic 0033, les 114 tests et l’état des services après la recette.

Les simulations locales couvrent le transfert, le refus d’une empreinte inattendue et le déroulement de la recette. L’opération `09775840a54d4fee88a1fbb1108d598d` confirme ensuite sur le VPS les 114 tests réussis, sans échec, erreur ni test sauté, et le schéma candidat `20261031_0033`. L’image validée est `sha256:c39192c6670c08b4a1c1552061b95fb0290d974e01e0e5cef248c6689a72866d`.

## Publication serveur préparée

Le lanceur `tools/publish_interface_copy_backend_windows.ps1` vise l’API 1.0.22 avec l’image vérifiée. Il contrôle le reçu et les empreintes, compare les configurations Compose résolues, puis déclenche le service de sauvegarde vérifiée avant la bascule. La comparaison autorise les quatre identifiants d’image et la version de l’API. Le schéma PostgreSQL est vérifié en lecture seule avant et après la bascule. En cas d’échec des contrôles après bascule, le lanceur rétablit la configuration et les services précédents.

Les sept nouveaux tests de publication et les vingt-neuf tests du lanceur précédent passent en local. La simulation PowerShell couvre le contrôle préalable, le refus d’une empreinte distante altérée, la remontée d’un blocage et le contrôle HTTPS après réception du compte rendu. La publication réelle reste à lancer sur le VPS.
