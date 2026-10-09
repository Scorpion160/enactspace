# Recette Android guidée avec ADB

## Périmètre

`tools/android_acceptance_adb.py` utilise Python 3.12 et ADB, sans dépendance Python externe. Il vérifie l'autorisation ADB, la version installée 1.0.11+14 et ouvre l'activité principale. UI Automator extrait temporairement les libellés accessibles, et le script touche uniquement un libellé de navigation identifié de façon unique. Si l'écran n'est pas identifiable, l'opérateur navigue manuellement. Le XML temporaire est supprimé du téléphone ; XML, captures et journaux bruts ne sont pas sauvegardés.

24 scénarios guidés couvrent authentification, biométrie, premier accès, profil, Academy, recrutement, tâches, Veille, justificatifs, partage Android, archives, impact, projets, alumni, documents, communication, aide, notifications, mise en page et reprise. Six autres scénarios permettent de vérifier les enregistrements avec comptes et campagne fictifs uniquement.

Les authentifications et la saisie des secrets se font exclusivement sur le téléphone par l'opérateur. Aucun effacement des données, installation, build, changement de configuration serveur, manipulation des empreintes ni contournement d'authentification. Le script ne change pas automatiquement réseau, thème, taille du texte ou orientation. L'opérateur les rétablit après chaque essai.

## Exécution

```powershell
python tools/android_acceptance_adb.py --serial R83XA0BB4FK --output "$env:LOCALAPPDATA\EnactSpace\DeviceAcceptance\essai-unique"
```

Le dossier de sortie doit être nouveau. Pour chaque scénario : O signifie vérifié et réussi, E échec, N non vérifié, Q arrêt. Décrire une observation courte sans identité, secret ou autre donnée personnelle. Les mots de passe ne doivent jamais être copiés dans le terminal.

Le script contrôle les nouveaux blocs du journal de crash qui mentionnent le package, ainsi que la présence du processus. La présence du processus seule ne prouve pas le bon fonctionnement ; son absence après une sortie volontaire ne suffit pas à conclure à un crash. Le journal Android peut ne pas capturer tous les blocages, erreurs Flutter, crashes natifs ou pertes de processus : cette surveillance est complémentaire à l'observation.

Le rapport JSON et Markdown est sauvegardé à chaque étape et lors d'un arrêt. Les réussites fonctionnelles sont des observations de l'opérateur, distinctes du précontrôle automatique et de la navigation ADB. Un scénario sauté reste NOT_VERIFIED. Le mode sans écriture laisse les six workflows d'enregistrement non vérifiés, donc le résultat global reste PARTIAL même si ses 24 scénarios réussissent.

## Scénarios avec enregistrement

Ajouter `--include-write-scenarios` seulement avec comptes et campagne fictifs, et redirection de tous les courriels vérifiée. L'opérateur doit confirmer explicitement `TEST UNIQUEMENT`. Cette confirmation est enregistrée comme déclaration de l'opérateur, pas comme vérification indépendante du serveur. Chaque changement de compte/role et action enregistrée se fait manuellement ; ne pas réaliser ces scénarios sur des profils réels. PayDunya et paiements réels exclus.

## Limites

Ce runner est une recette guidée avec navigation ADB, pas une suite entièrement autonome. Il ne teste pas le navigateur web, iOS, tous les profils serveur, les intrusions ou tous les écrans possibles. Les 910 succès Flutter de la suite complète suivis des 39 succès du fichier corrigé sont consignés séparément ; ils ne sont pas réexécutés par ce script. La configuration actuelle du backend doit être contrôlée séparément.

Les rapports historiques du 5 octobre décrivent UI Automator, mais les anciens scripts de téléphone n'ont pas été retrouvés dans le checkpoint. Ce runner reproduit cette méthode et n'est pas présenté comme une modification de scripts Windows non disponibles.
