# Démonstration Alumni Day — écrans natifs

La page `/demo` conserve le choix des deux profils, accessible depuis la connexion et le QR de l’affiche. Les routes `/demo/enacteur` et `/demo/alumni` montent désormais `DemoNativeExperience`, les écrans de production et le véritable `AppShell`.

Le profil Enacteur représente une responsable de projet afin de montrer aussi les pôles, les équipes, les tâches, l’Impact et le recrutement. Le profil Alumni conserve la navigation communautaire et ses restrictions réelles. Les gardes de production ne sont pas modifiées. La candidature publique reste essayable pour les deux profils.

## Données et interactions

`DemoNativeRuntime` fournit explicitement chaque dépendance. Les services et les parseurs de production travaillent sur `DemoNativeApi`, un transport exclusivement local, sans client réseau utilisable ni authentification réelle. Chaque visite possède son propre `DemoNativeData`. Les messages, événements, tâches, profils et réglages modifiés restent dans cette instance.

Les formulaires, filtres, fiches, menus et composants sont ceux de l’application. Les noms de personnes et les chiffres sont fictifs. Les 40 photos et les dossiers des projets sont les ressources publiques déjà embarquées. L’écran Archives ouvre la mémoire historique pour mettre les souvenirs en avant ; la chronologie reste accessible.

Le recrutement utilise les vrais écrans de campagne, le formulaire en six étapes, le suivi et l’espace de traitement, alimentés par des dossiers fictifs. Aucune candidature ni conversion de compte n’est transmise. Les réunions et les jeux présentent leurs vrais écrans ; aucune session multijoueur ou visioconférence réelle n’est ouverte.

Les paiements réels, la caméra, le microphone, le NFC, les notifications push et les envois de fichiers par les assistants de production sont désactivés. Les médias choisis dans le chat restent en mémoire ; son cache, ses favoris et sa file d’envoi ne touchent pas les conversations ou les préférences enregistrées. Les réglages ne déclenchent aucune opération sur la session réelle du navigateur.

La navigation interne utilise un routeur distinct et ne publie pas ses chemins dans l’URL du navigateur. Le lien du QR reste `https://enactspace.kerunjombor.net/#/demo`. Quitter ou changer de profil détruit la visite. La page de sélection permet ensuite de revenir à la connexion.

## Validation et publication

La version précédente 1.0.18+21 a été publiée avec succès selon le journal Windows transmis. Cette révision vise 1.0.19+22. L’analyse Dart de tout `lib` et des deux suites de démonstration est effectuée avec les sources Flutter et les versions verrouillées des dépendances. Un contrôle exécutable autonome valide 156 conversions vers les modèles de production, les deux profils, les 40 archives, la pagination, l’isolation, les modifications locales et le refus des chemins non autorisés.

Les tests Flutter de navigation, affichage et interactions doivent encore passer sous Windows. Le script vérifie les sources locales, conserve leur sauvegarde, lance l’analyse et les tests, puis construit et publie uniquement si tous ces contrôles réussissent. Le backend, Android et PayDunya restent inchangés.
