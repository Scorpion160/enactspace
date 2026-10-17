# Préparation à la mise en service — lot 3 : réinitialisation et recrutement

Date : 7 octobre 2026. Début : 10:45 UTC.

## Résultat

93 tests SQLite réussis en 43,075 secondes et 3 tests PostgreSQL réussis en 6,233 secondes. Les tests de ce lot et des lots antérieurs se recoupent : ces nombres ne constituent pas un total cumulatif de scénarios distincts. La découverte unittest a été corrigée pour éviter de compter plusieurs fois les classes de fixtures importées.

## Réinitialisation du mot de passe

Le code de réinitialisation accepte six chiffres ASCII et expire toujours après quinze minutes. Chaque challenge dispose maintenant de cinq essais incorrects au maximum. Le cinquième échec invalide le challenge ; le mot de passe reste inchangé. Un code utilisé correctement est consommé une fois, et les sessions existantes sont révoquées par le parcours déjà présent.

Les transactions verrouillent d'abord le compte, puis le challenge. Le compteur est enregistré même lorsqu'une réponse d'échec est renvoyée. Des connexions PostgreSQL indépendantes ont testé seize demandes incorrectes parallèles et deux demandes correctes simultanées.

La migration 20261007_0026 ajoute le compteur et sa contrainte sans modifier les codes existants. Son aller-retour a été testé dans une base PostgreSQL jetable. Elle reste à appliquer lors du déploiement final ; aucun changement de schéma en production n'a été effectué.

Une nouvelle demande de code ouvre un nouveau challenge. La limitation de ces demandes répétées, ainsi que celle des connexions et du suivi de candidature, reste un point à traiter dans le prochain lot.

## Permissions du recrutement

Vérifications HTTP sur données synthétiques :
- refus de la liste, du détail et de l'export des candidatures pour un membre ordinaire ;
- refus d'accès pour un Alumni même avec un rôle ou une appartenance Veille conservé ;
- accès pour Veille, SG et Team Leader ;
- refus de modifier ou supprimer l'évaluation d'un autre recruteur ; maintien de la permission administrative du Team Leader.

La lecture de recrutement.py est partielle : la revue exhaustive de ses 1 680 lignes reste à terminer.

## Proxy et limites restantes

La configuration Nginx active du serveur a été examinée par un relevé ne conservant que les chemins et les indicateurs techniques. Le domaine de l'API et le port loopback attendu ne figurent pas dans cette configuration. Ce relevé ne permet donc pas de conclure sur la protection du véritable point d'entrée public de l'API.

Prochain lot : identifier ce point d'entrée, vérifier la confiance accordée aux en-têtes du proxy, puis ajouter et tester les limites communes aux connexions, nouvelles demandes de code et recherches de candidature. La documentation officielle Uvicorn rappelle que les en-têtes transmis ne sont acceptés que pour les adresses de proxy autorisées : https://www.uvicorn.org/settings/

## État de livraison

Correctifs et tests enregistrés dans le dépôt Windows. Aucun build, déploiement, courriel réel, push réel ou effacement de données de production. SMTP de test toujours restreint. La revue complète, le nettoyage ciblé et la recette finale restent en cours.
