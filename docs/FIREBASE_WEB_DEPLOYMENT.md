# Configuration Firebase du navigateur

Le worker `frontend/web/firebase-messaging-sw.js` est un fichier généré pour le déploiement. Il reste sur le PC, mais ne fait pas partie du code publié. Son modèle et son générateur sont versionnés dans `tools/`. Cette séparation ne sécurise pas Firebase à elle seule : la configuration cliente devient accessible au navigateur lors du déploiement.

La migration conserve le worker local et une copie privée de sa configuration dans `%LOCALAPPDATA%\EnactSpace\FirebaseWeb\<identifiant>\firebase-web-client-defines.json`. Cette copie contient seulement les six paramètres Firebase du worker. Elle ne remplace pas la configuration complète d'une release et ne contient ni URL API ni clé publique VAPID.

## Préparer le prochain build web

Utiliser un fichier de configuration complet, conservé hors de Git. Il doit contenir l'URL HTTPS de l'API, la clé publique VAPID et les six paramètres suivants :

- `ENACTSPACE_FIREBASE_API_KEY_WEB`
- `ENACTSPACE_FIREBASE_APP_ID_WEB`
- `ENACTSPACE_FIREBASE_MESSAGING_SENDER_ID`
- `ENACTSPACE_FIREBASE_PROJECT_ID`
- `ENACTSPACE_FIREBASE_AUTH_DOMAIN_WEB`
- `ENACTSPACE_FIREBASE_STORAGE_BUCKET_WEB`

Depuis la racine du dépôt, lancer le build autorisé :

```powershell
& .\tools\build_web_with_firebase.ps1 -DefinesPath 'C:\chemin-prive\release-defines.json'
```

Le script valide la configuration, génère le worker avec la même configuration Firebase que l'application et construit le web. Il conserve les versions SDK présentes lors de la migration. Les options supplémentaires de Flutter peuvent être fournies avec `-FlutterArgs`; elles ne peuvent pas remplacer les paramètres du fichier de configuration.

Pour régénérer uniquement le worker, sans build :

```powershell
python .\tools\generate_firebase_web_worker.py --defines 'C:\chemin-prive\release-defines.json'
```

Un build Flutter direct doit être précédé de cette génération et utiliser le même fichier de configuration. Ne pas déployer un build dont le worker est absent ou correspond à un autre projet Firebase.

## Contrôle de la sauvegarde GitHub

Le contrôle des secrets reste actif sur le code et la documentation. L'unique exclusion supplémentaire porte sur le worker de déploiement. Avant de l'exclure, l'outil vérifie que sa structure est limitée aux deux imports SDK officiels, à l'objet de configuration Firebase attendu et à l'initialisation du messaging. Il vérifie aussi sa cohérence avec le modèle. Toute instruction supplémentaire bloque la sauvegarde.

```powershell
python .\tools\publish_prelaunch_checkpoint.py --repo (Get-Location).Path --publish
```

La sauvegarde utilise un index temporaire et une nouvelle branche de checkpoint. Elle ne change pas la branche de travail, ne fusionne rien et ne déploie pas l'application. Les fichiers privés et l'historique local non publié ne sont pas envoyés.

## Contrôles avant mise en service

Les restrictions de la clé cliente dans Google Cloud restent à vérifier. La clé doit être dédiée aux API Firebase nécessaires. Vérifier également les règles d'accès aux produits Firebase réellement utilisés et les protections applicables. Aucun compte de service, clé privée, secret SMTP ou token d'accès ne doit entrer dans la compilation cliente.

La migration et le scan GitHub ne constituent pas une recette des notifications. Tester ensuite, avec les identités de recette autorisées, l'inscription du navigateur, la réception en premier plan et arrière-plan, l'ouverture au clic et la suppression de l'installation à la déconnexion. Ne pas envoyer de notifications aux membres pendant les tests.

Références officielles : https://firebase.google.com/docs/projects/api-keys et https://firebase.google.com/docs/cloud-messaging/web/receive-messages.
