# Promotion et découverte d’Enactus ESP — 17 octobre 2026

## Formulaire
Promotion facultative au format AAAA-AAAA, deux années consécutives (1900 à 2199 pour la première année). Exemple 2025-2026. Le niveau d’études reste séparé. Le sens précis de la promotion est celui de la campagne ; le formulaire ne présume pas une année de diplôme ni une année d’entrée.

Un canal principal de découverte est proposé : réseaux sociaux, activités ou événements, membre, enseignant/cours, affiche/support imprimé, site/recherche en ligne, autre. Autre exige une précision de 200 caractères maximum. Si la campagne contient une question associée au champ historique known_enactus_from, le même sélecteur est utilisé à cet endroit ; les obligations de la campagne sont conservées. Sinon le canal reste facultatif dans Parcours.

Les libellés sont uniformes pour comparer les réponses des nouvelles candidatures. Une réponse vide reste non renseignée ; les réponses libres historiques ne sont pas reclassées automatiquement et ne doivent pas être mélangées aux canaux identifiés sans examen. Il s’agit du canal principal déclaré, pas d’une mesure d’attribution publicitaire.

## Contrat et stockage
Le client transmet class_name et known_enactus_from pour les API antérieures, et les champs supplémentaires promotion_academic_year, discovery_channel et discovery_other pour la validation des nouvelles API. Le schéma ApplicationCreate normalise les valeurs vers les colonnes existantes. Aucun changement de base requis. Les canaux sont persistés sous leur libellé canonique, Autre sous Autre : précision ; les codes stables sont des valeurs du contrat d’entrée, pas de nouvelles colonnes SQL.

Le chemin JSON et le chemin multipart avec pièces jointes passent par le même schéma. La route revérifie les métadonnées après la reprise des réponses de campagne et avant la création SQL. La lecture de candidature conserve class_name/known_enactus_from. Les écrans internes montrent Promotion et Découverte d’Enactus ESP. L’intégration membre reprend déjà Application.class_name vers User.promotion. Les anciennes candidatures et anciens profils restent inchangés.

## Vérifications et limites
Trois tests backend exécutés ici avec succès : années et format, canaux et autre, incohérences et compatibilité historique. Syntaxe Python contrôlée. Les tests Flutter sont à exécuter sur Windows via tools/sync_recruitment_metadata_windows.ps1 : parcours complet, Autre obligatoire et conservé au retour, formats d’année, contrat JSON et multipart, régressions mobile/thème et gestion interne. Le script teste également les schémas candidats dans un processus Python isolé du conteneur existant, en mémoire, sans modifier les fichiers de production ni accéder à la base.

Aucun build ni déploiement. Les sources backend doivent être incluses dans la prochaine image : la validation serveur supplémentaire ne devient active qu’après déploiement. Les colonnes et chaînes compatibles permettent cependant au formulaire de transmettre les valeurs aux API précédentes. Revue visuelle et validation de bout en bout sur une campagne de test restent requises avant publication. Le rappel répété dans l’introduction Motivations est retiré.
