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
