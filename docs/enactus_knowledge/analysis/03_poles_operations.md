# Pôles et opérations

## Cartographie observée

| Pôle | Pièces uniques liées par chemin | Activités observées | Fiabilité |
|---|---:|---|---|
| Chimie | 57 | tests, recettes, rapports, budgets, CAJOR, transferts et nombreux PV | `POLE_SPECIFIC`, surtout 2024-2025 |
| Technique | 22 | équipements, irrigation, granuleuse, micro-jardinage, missions Terrasen | `POLE_SPECIFIC` et `ESP_CURRENT_EVIDENCE` en 2026 |
| Gestion | 13 | stratégie, finance, partenariat, commercialisation et PV | `POLE_SPECIFIC` |
| Communication | 10 | feuille de route, budget, salon, tâches hebdomadaires et PV | texte limité par plusieurs images sans OCR |
| Veille | 8 | compétitions, plans d’action, suivi des tâches/échéances et bilans 2026 | `ESP_CURRENT_EVIDENCE` pour mai-juin 2026 |
| Organisation | 7 | logistique, voyages, dotations et réunions | `POLE_SPECIFIC` |
| IT | 5 | cahier des charges, backlog, PV et bilan de tâches | `POLE_SPECIFIC` |

Les décomptes sont multi-étiquettes : un même SHA peut documenter un pôle et un projet, notamment CAJOR ou Terrasen. Sources principales : `documents/Enactus 2025/Pôle Chimie/Bilans/PÔLE CHIMIE - BILAN ANNUEL 2024-2025.pdf`, `documents/Pole Tech 2026/rapport_voyage_pole_technique_terrasen_2026.pdf`, `Pole Veille/Bilan Pole Veille/juin/bilan_pole_veille_juin_2026_enactus.pdf`.

## Lecture opérationnelle

- **Chimie :** corpus le plus dense, avec une forte mémoire de réunions et de protocoles. La priorité produit est de relier test, version de recette, résultat, validation et projet sans transformer un document ancien en procédure sanitaire actuelle.
- **Technique :** les pièces couvrent conception, budget, plan de voyage, répartition du travail, transfert et rapport. Le rapport 2026 montre une chaîne terrain complète, réutilisable comme modèle de mission.
- **Gestion :** les fonctions finance, commercialisation et partenariat sont visibles, mais leurs objets restent dans des documents séparés.
- **Communication :** les tâches hebdomadaires existent souvent sous forme d’image ; sans OCR validé, seules leur présence et leurs métadonnées sont établies.
- **Veille :** les bilans 2026 décrivent explicitement un suivi Excel, des relances et une consolidation mensuelle. Les résultats individuels ne doivent jamais être repris dans un rapport public.
- **Organisation :** la logistique des voyages et achats peut être modélisée autour d’un événement, d’un budget et d’une validation.
- **IT :** la coexistence d’un backlog produit et de PV justifie une séparation claire entre demandes, décisions et tâches techniques.

## Processus POL-01 — Roadmap et revue mensuelle d’un pôle

- **PROCESS:** planifier, suivre et rendre compte de l’activité mensuelle d’un pôle.
- **ACTORS:** responsable de pôle, adjoint, membres, Pôle Veille, gouvernance destinataire.
- **INPUTS:** objectifs de saison, décisions, tâches, événements, contraintes, bilan précédent.
- **STEPS:** définir les objectifs ; décomposer en livrables ; assigner ; suivre ; relancer ; identifier les blocages ; consolider le bilan ; soumettre ; décider des ajustements.
- **APPROVALS:** roadmap approuvée par le responsable ; bilan accepté par le rôle de gouvernance prévu ; données sensibles exclues de la diffusion large.
- **OUTPUTS:** roadmap versionnée, tâches, indicateurs d’exécution, blocages, décisions et bilan.
- **DATA:** période, objectif, livrable, responsable de rôle, échéance, état, preuve, commentaire de validation.
- **CURRENT_MANUAL_TOOLS:** Excel, PDF, listes et messagerie.
- **PAIN_POINTS:** double saisie, relances manuelles, formats variables, statistiques individuelles à risque.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** modèle mensuel, agrégation des tâches, rappels, validation et export institutionnel anonymisé.

Sources : `Pole Veille/Bilan Pole Veille/mai/bilan_pole_veille_enactus.pdf`, `Pole Veille/Bilan Pole Veille/juin/bilan_pole_veille_juin_2026_enactus.pdf`, `documents/Enactus 2025/Pôle Comm/Feuille de route/Feuille de route COM 2025.pdf`.

## Processus POL-02 — Demande inter-pôles

- **PROCESS:** demander une contribution spécialisée à un autre pôle et en suivre la livraison.
- **ACTORS:** pôle demandeur, pôle contributeur, responsable projet, validateur si budget ou risque.
- **INPUTS:** besoin, spécification, projet lié, échéance, ressources et critères d’acceptation.
- **STEPS:** soumettre ; qualifier ; accepter ou négocier ; affecter ; produire ; faire tester ; accepter ; archiver la preuve.
- **APPROVALS:** acceptation par les deux responsables ; validation supplémentaire pour dépense, communication externe ou produit sensible.
- **OUTPUTS:** demande tracée, livrable, résultat de test et décision d’acceptation.
- **DATA:** pôles, projet, catégorie, description, priorité, coût prévu/réel, statut, preuve.
- **CURRENT_MANUAL_TOOLS:** PV, messages, documents techniques et budgets.
- **PAIN_POINTS:** responsabilité diffuse, dépendances invisibles, duplication des cahiers des charges.
- **ENACTSPACE_AUTOMATION_OPPORTUNITY:** ticket inter-pôles relié au projet, jalons, approbations et vue des dépendances.

Sources : `documents/Enactus 2025/Pôle Chimie/CAJOR/Cahier des charges presse.pdf`, `documents/Enactus 2025/Pôle Tech/Projets en cours/Cahier des charges presse.pdf`, `documents/Enactus 2025/PROJETS/Terrasen/Budgets/Budgetisation syst irrigation.pdf`.

## Contrôles recommandés

- Les tableaux de pôle présentent des agrégats ; les observations individuelles restent dans un espace restreint.
- Une recette ou procédure technique ancienne exige une validation de version avant réutilisation.
- Une tâche issue d’un PV conserve le lien vers la décision source.
- Les indicateurs ne sont jamais déduits de la simple présence d’un document.
- La nomenclature des pôles est administrable par saison et gère les alias historiques.
