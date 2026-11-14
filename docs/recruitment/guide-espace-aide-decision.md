# EnactSpace — espace d'aide à la décision du recrutement

## Portée
Fonctionne avec chaque campagne créée dans EnactSpace. Les vues d'analyse ne modifient jamais les notes, les décisions, les conditions d'éligibilité, les quotas ou les dates. Les paramètres d'évaluation (nombre minimal d'avis, seuil de désaccord) restent configurables **par campagne** par les responsables autorisés.

## Parcours recommandé
1. Dans **Recrutement → Candidatures**, choisir explicitement la campagne.
2. Lire les indicateurs **Présélection des dossiers** (prêts, à compléter, avis enregistrés, décisions).
3. Faire traiter d'abord les candidatures ayant le moins d'avis. Les jurés non gestionnaires conservent ce tri par défaut.
4. Utiliser **Classement indicatif des dossiers** pour examiner les dossiers prêts, classés selon la moyenne décroissante des notes valides. Les évaluations incomplètes n'y figurent **pas par défaut**.
5. Comparer au besoin les départements, niveaux et groupes d'avancement ; réinitialiser les filtres après consultation.
6. Pour chaque candidature, décider explicitement dans la fiche, en conservant la possibilité de discuter les désaccords au jury.
7. Vérifier le calendrier, les conditions de publication et la totalité des décisions avant d'utiliser **Publier**.

## Filtres de la liste
- **Campagne** : ne comparer que des candidatures de la même campagne.
- **Département et niveau** : choix issus des données réelles de la campagne, sans liste figée.
- **Poursuite du cursus (indicative)** : estimation à partir du niveau et des durées usuelles. Un diplôme ou une formation atypique peut ne pas correspondre à cette estimation. **Cette catégorie n'est ni une règle d'inéligibilité, ni une cause automatique de rejet.**
- **Tri** : les avis manquants restent prioritaires par défaut ; les responsables peuvent afficher les notes décroissantes ou croissantes, les références et les dépôts récents.

Les valeurs des filtres ne changent ni la campagne ni le contenu de la base de données.

## Délibération et règles internes

### Préparation du tri

1. Choisir la campagne, puis consulter **À étudier** pour les dossiers de la tranche intermédiaire sans décision.
2. Contrôler les dossiers **Avis à compléter** : le nombre minimal d'évaluations peut être augmenté lorsqu'un désaccord nécessite une nouvelle appréciation.
3. Repérer les écarts importants, puis lire les motivations, disponibilités et avis associés à chaque dossier, dans l'espace accessible aux responsables.
4. Délibérer dossier par dossier, y compris sur les exceptions. Une note ou un filtre n'enregistre jamais une décision à la place du jury.
5. Vérifier les décisions préparées avant toute publication des résultats. L'envoi d'invitations aux entretiens reste une opération distincte.

### Repères retenus pour le tri 2026–2027

- **Note strictement inférieure à 10/20** : dossier non retenu pour un entretien selon la décision du jury.
- **Note de 10 inclus à 15 exclu** : examen complémentaire en délibération.
- **Note supérieure ou égale à 15/20** : dossier retenu pour un entretien selon la décision du jury.

Ces repères **décrivent la méthode de la présente délibération**. Ils ne constituent ni une décision automatique ni une règle à reprendre sans adaptation lors des campagnes ultérieures. Les deux seuils peuvent être ajustés dans l'affichage des prochaines campagnes. Les candidats proches d'un seuil ou faisant l'objet d'avis divergents méritent une lecture détaillée.

Les dossiers sont affichés par défaut avec leurs évaluations complètes. Utiliser le filtre **Tous les dossiers** ou l'action **À étudier** pour voir aussi les évaluations en attente. Le filtre **Écart entre jurés** repère les divergences d'au moins cinq points sur vingt, sans changer le seuil métier qui impose des avis complémentaires.

### Affichage de la note

En présence de notes numériques du jury, la moyenne est sur 20. Pour une campagne utilisant uniquement une grille structurée sur 100, le tableau peut afficher l'équivalent sur 20, signalé dans le dossier. Un résultat provisoire doit être confirmé par les évaluations prévues avant la décision.

## Comparaison anonymisée
- Les noms, adresses e-mail, téléphones et documents confidentiels ne sont pas intégrés au tableau de classement.
- Les dossiers avec évaluations complètes apparaissent avant les dossiers provisoires.
- Le classement ne publie rien et ne prépare aucune décision. Les notes provisoires ne doivent jamais servir seules à décider.
- Les filtres facultatifs département/niveau permettent d'examiner différents besoins de l'équipe ; le classement reste indépendant de ces catégories.
- Le champ **Estimer un effectif** sert uniquement à comparer un effectif hypothétique au nombre de dossiers suffisamment évalués dans le filtre courant. Il ne crée aucun quota et n'est pas sauvegardé.

## Statistiques et confidentialité
La page **Campagne en chiffres** conserve ses répartitions globales. Seuls les responsables habilités à gérer le jury voient également :
- Dossiers prêts et non prêts.
- Dossiers sans note ou avec au moins un avis.
- Nombre total d'évaluations enregistrées.
- Désaccords importants selon le seuil configuré.
- Nombre d'avis restant à recueillir.
- Décisions préparées.

Aucun identifiant de candidat n'est transmis dans cet agrégat. Le panneau de comparaison détaillée conserve les protections d'accès de l'espace interne de sélection.

## Garantie de réutilisation
Aucune référence à l'année de recrutement, à une promotion ciblée, à un quota fixe, à un département favorisé ou à une date de publication ne doit être codée en dur dans ces fonctionnalités. Tout choix contextuel doit rester réversible et initié par un responsable.

## Recette avant déploiement
- Tester une campagne anonymisée avec dossiers à 0, 1, 2, 3 et 4 avis, et un désaccord dépassant le seuil.
- Vérifier que les dossiers à avis incomplets n'apparaissent pas dans le classement par défaut.
- Vérifier le tri décroissant sur les dossiers prêts ; note manquante = dernière position si la liste est élargie.
- Vérifier les filtres par département et niveau, les valeurs inconnues et la réinitialisation.
- Vérifier l'accès du gestionnaire, du juré simple et du membre non autorisé.
- Vérifier les vues Web large, mobile et mode sombre.
- Vérifier qu'aucun des choix consultatifs ne change les décisions et que la publication reste explicitement confirmée.
- Exécuter les tests unitaires backend et Flutter, puis la recette sur campagne de démonstration.

Le déploiement de la version production et la modification de la campagne active sont des opérations distinctes.
