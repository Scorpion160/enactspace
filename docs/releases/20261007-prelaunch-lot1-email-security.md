# Préparation de mise en service — lot 1 du 7 octobre 2026

## Résultat du lot

Les messages candidats sont désormais préparés pour les changements importants, indépendamment de la création d’un compte. Ils comprennent les prochaines démarches, le code de suivi et, lorsqu’ils sont renseignés, la date UTC, le lieu et le lien d’entretien. Les notes du jury et les évaluations restent internes.

Un changement public de date, lieu ou lien renvoie une information au candidat. Une modification des seules notes internes ne le fait pas. Une notification interne associée à un compte ne génère pas un deuxième email transactionnel.

Le worker et le fournisseur SMTP contrôlent le destinataire de test immédiatement avant l’envoi. Une ancienne entrée de file est redirigée. Une boîte de test absente, invalide ou contenant une injection d’en-tête bloque l’envoi. Les préfixes de test ne sont pas ajoutés plusieurs fois.

## Validation

35 tests ciblés réussis : 10 nouveaux tests de cycle de vie et confinement, 14 tests d’email existants, 6 tests de préparation du recrutement et 5 tests de questionnaire.

Les tests ont utilisé un conteneur sans réseau, un fournisseur simulé et une base SQLite éphémère. Les fichiers modifiés étaient montés en lecture seule sur l’image existante. Aucun SMTP réel, aucun build d’application ou d’image, aucune écriture de données de production et aucun déploiement.

La première exécution a révélé des adresses fictives réservées incompatibles avec le schéma public de réponse. Les fixtures ont été corrigées ; la suite est ensuite passée. Les protections de production n’ont pas été modifiées pour contourner la validation.

La vérification du diff ne signale pas d’erreur de contenu.

## Revue de sécurité

Le registre initial contient 617 fichiers source/configuration et 198 484 lignes au moment du scan. Les empreintes sont conservées pour suivre les versions effectivement relues.

Le premier scan automatisé ciblait l’exécution dynamique, la désérialisation Python à risque, les appels shell explicites et les marqueurs de clé privée. Il n’a remonté aucun signal pour ces seules règles. Ce résultat ne constitue ni une revue manuelle complète ni une preuve d’absence de porte dérobée.

La revue fichier par fichier, les contrôles de permissions, les tests d’intrusion sur la recette isolée, les dépendances, les sessions et les accès aux fichiers restent à poursuivre.

## Nettoyage des essais

L’inventaire de production identifie une campagne active et ouverte avec trois candidatures, sans compte membre converti depuis ces candidatures.

La sélection précise est enregistrée dans un manifeste local ne contenant pas de coordonnées de candidats. Aucun élément n’a encore été supprimé. Le retrait de cette campagne, de ses candidatures, avis et fichiers associés interviendra après les tests et la sauvegarde ciblée. Les membres réels, les archives, les projets et les documents institutionnels sont préservés.

## Suite et point de validation

Le lot suivant porte sur les sessions, les droits par rôle et les accès aux pièces jointes, puis sur la revue structurée du reste du code. Le nettoyage de la campagne et la recette globale précèdent le build final regroupé.

Les emails et les push restent limités aux destinataires de test. Leur rétablissement normal fait partie de la bascule finale, après validation.

Le travail marque un arrêt à ce point conformément à la demande de validation à chaque lot. Le lot 1 est testé dans la recette isolée ; il n’est pas encore publié.
