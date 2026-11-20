# Tri de présélection — interface de délibération réutilisable

## Règles de travail décidées par le jury, 13–14 novembre 2026

La campagne Enactus ESP 2026–2027 comporte 95 dossiers, 301 évaluations enregistrées. Le jury a appliqué les repères **moins de 10/20** (non retenu), **15/20 ou plus** (entretien envisagé), **de 10 inclus à 15 exclu** (délibération complémentaire). Les décisions sont humaines et distinctes des notes et de leur affichage.

Vérification de production en lecture seule au 14 novembre :
- 17 dossiers sous 10/20 : 17 décisions `not_shortlisted`.
- 41 dossiers entre 10 inclus et 15 exclu : 39 sans décision, 2 `shortlisted` déjà préparés.
- 37 dossiers à partir de 15 : 37 `shortlisted` déjà préparés.
- Soit 56 décisions préparées, 39 sans décision. Aucun résultat publié.

## Nouvelle interface

Depuis **Recrutement > Candidatures**, choisir la campagne et déplier **Préselection des dossiers**, puis **Classement indicatif des dossiers** (ouvert par défaut pendant la présélection).

- Bouton **À étudier sans décision (N)** : combine la tranche intermédiaire et les dossiers sans décision, **en incluant les dossiers dont la notation doit être complétée**. Les dossiers avec une évaluation supplémentaire requise apparaissent d'abord.
- Trois tranches de notes avec effectifs ; filtre par décision préparée (sans décision, présélectionnés, non présélectionnés).
- Filtre supplémentaire sur les écarts de notes des jurés : **5 points ou plus sur 20**.
- Filtres déjà présents : campagne, département, niveau, état de la notation ; ouverture directe de la fiche pour examiner les motivations, disponibilités, notes et avis.
- Seuils 10 et 15 ajustables pour un autre contexte (valeurs décimales acceptées, bornes contrôlées). Ces changements servent **uniquement à la consultation** : ils ne modifient ni la politique de la campagne ni la base.
- Réinitialisation, classement, 25 premières entrées avec possibilité d'afficher toutes les lignes.

Quand les notes numériques `ApplicationReview.score` existent, leur moyenne sur 20 est affichée. Pour les futures campagnes qui utilisent exclusivement les appréciations structurées, EnactSpace affiche l'équivalent sur 20 du barème sur 100, avec indication de cette origine. Les deux modes sont distincts et ne déclenchent aucune décision automatique. Aucun seuil ne déclenche un rejet, une invitation ou un e-mail automatique.

## Confidentialité et règles

L'API `GET /recruitment/campaigns/{id}/selection` est réservée aux responsables habilités à gérer le jury. La réponse ne révèle que les codes anonymes et les caractéristiques nécessaires au tri (département, niveau, compteurs, moyenne, écarts, décision préparée) : **aucun nom, e-mail, téléphone ou pièce jointe**.

Les 56 décisions déjà préparées restent inchangées. Aucune décision n'est publiée et aucune campagne suivante n'hérite d'une décision de la précédente.

La condition d'un avis supplémentaire en cas de désaccord appartient à la politique de sélection de la campagne ; elle est différente du filtre informatif « écart de 5 points sur 20 ». L'un peut empêcher de considérer une évaluation comme complète, l'autre sert à repérer des cas à discuter.

## Recette

- Limites strictes : note 9,999 sous 10 ; 10 et 14,999 en tranche intermédiaire ; 15 dans la tranche haute.
- Dossier avec décision existante exclu de la file « sans décision », mais toujours consultable.
- Dossier incomplet présent dans cette file et prioritaire à l'affichage.
- Test d'une campagne future avec seuils modifiés, sans écriture ni décision automatique.
- Vérifier sur un compte gestionnaire la différence entre notes /20 et barème /100, les filtres combinés, les droits et la lecture mobile.

Ce correctif est préparé pour la candidate **1.0.30+38** ; il ne correspond pas à une publication de production tant que les conteneurs Web et API ne sont pas effectivement mis à jour.
