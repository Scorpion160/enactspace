# Lot 39 — APK Android et runner de recette ADB

Le résultat utilisateur confirme compilation release 1.0.11+14, 396,3 secondes, 247025203 octets, SHA256 2e42ac7345338575ba701a185dacc2f5f2e58c1b2e0d87c909f56a96cdd5657f. API choisie par l'utilisateur : https://api-enactspace.kerunjombor.net. Configuration Android extraite de google-services.json et comparée au projet Firebase web. Avertissements migration Kotlin présents, non bloquants pour cette compilation.

Installation ADB avec contrôle préalable SHA et mise à jour -r : Success. dumpsys confirme versionName 1.0.11, versionCode 14, minSdk 26, targetSdk 36, mise à jour 2026-10-09 16:13:06 sur Samsung SM_A065F R83XA0BB4FK. Le serveur n'a pas été mis à jour par ces opérations. Aucun parcours fonctionnel récent sur cet APK n'est encore validé.

Nouveau runner ADB guidé : contrôle version, navigation par libellé unique UI Automator, refus des clics ambigus, authentifications manuelles, 24 scénarios plus 6 workflows avec comptes fictifs. Rapports progressifs, scénarios non exécutés explicitement NOT_VERIFIED. Aucun secret saisi, aucune capture ou UI brute sauvegardée, aucun effacement des données. Les anciens scripts ne sont pas dans le checkpoint ; les rapports historiques décrivant UI Automator ont été consultés.

7 tests du runner passent sous Python Linux sur données synthétiques ; compilation Python et git diff --check réussis. PowerShell/ADB Windows et les scénarios sur téléphone restent à exécuter. Recette guidée, pas certification de tous les rôles ni de la sécurité serveur. PayDunya différé.
