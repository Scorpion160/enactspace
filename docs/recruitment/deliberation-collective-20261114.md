# EnactSpace — délibération collégiale de présélection

## Situation vérifiée le 14 novembre 2026

Campagne 2026–2027 : 95 candidatures, 301 évaluations individuelles,
64 décisions « entretien » et 31 décisions « non retenu ». Sur ces 95 dossiers,
33 avaient trois avis et une décision de jury, mais le moteur exigeait
automatiquement un quatrième avis en cas de divergence. Le jury a délibéré
collectivement sur ces 33 cas et confirmé ses décisions.

## Nouveau mécanisme

En tant que responsable habilité, ouvrir **Recrutement > Présélection des
dossiers** puis **Valider la délibération du jury (N)**, disponible uniquement
si toutes les décisions sont enregistrées et chaque dossier comporte au moins
trois avis individuels. Une confirmation explicite précède l'enregistrement.

- Chaque cas éligible conserve ses notes, ses avis et sa décision existante.
- L'API n'enregistre qu'une validation d'arbitrage collectif, datée et
  attribuée au responsable connecté dans le journal d'audit.
- Le dossier devient « prêt » malgré l'avis complémentaire théorique.
- Une modification ultérieure de la décision ou des évaluations invalide
  cette validation : une nouvelle délibération sera alors nécessaire.
- Le minimum de trois évaluations réelles est toujours obligatoire.
- Aucun quota, seuil de notes, résultat ou campagne n'est codé en dur.
- L'action ne publie rien, n'envoie aucun e-mail, ne dévoile aucune identité
  et n'affecte aucun entretien.

La publication reste une commande distincte, bloquée avant la date de
publication du calendrier (15 novembre 2026 pour la campagne actuelle).
Les affectations aux jurys d'entretien et les créneaux sont gérés séparément.

## Points de contrôle

Avant de valider, vérifier dans le bilan : 95 décisions, zéro manquante,
33 dossiers à délibérer ; 20 de ces dossiers sont présélectionnés et 13 non.
Après confirmation : 95 dossiers prêts, 33 validations collégiales tracées,
toujours 301 notes individuelles, 64/31 décisions inchangées,
aucune publication et aucun e-mail de résultat.
Le contrôle doit être répété sur la base de production, et non seulement
déduit des tests de code.

Ne pas substituer des notes fictives ni relever artificiellement le seuil
de désaccord pour contourner le contrôle.
