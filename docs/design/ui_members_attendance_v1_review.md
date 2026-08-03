# Revue visuelle - Membres et presences V1

## Resultat

Les dix captures ont ete produites sur `http://127.0.0.1:18080` avec
l'API d'audit `http://127.0.0.1:18002` et des donnees synthetiques uniquement.
Les polices sont chargees et les vues sont lisibles aux trois formats testes.

## Elements confirmes

- A 1440 px, Membres bascule vers des cartes a deux colonnes pour conserver les
  actions `Voir le profil` et `Modifier` dans le viewport.
- Le mobile conserve une hierarchie courte : en-tete, recherche, filtres
  repliables, actions puis cartes de membres.
- Le profil presente Contact, Organisation, Parcours et Etat du compte dans une
  feuille adaptative.
- L'edition affiche les vraies valeurs connues avant tout enregistrement.
- Presences distingue nettement Gestion et Mon suivi, avec des statistiques et
  sessions lisibles sur desktop, tablette et mobile.
- La session ouverte montre son pilotage, ses compteurs et ses actions NFC/QR.
- La capture QR montre un code effectivement genere, sa rotation et ses
  compteurs de pointage.
- Le NFC informe clairement de la contrainte materielle sur Windows.

## Controle fonctionnel

- `flutter analyze --no-pub` : OK.
- `flutter test --no-pub --reporter expanded -j 1 --timeout 45s` : 2 tests OK.
- `flutter build web --release --pwa-strategy=none` : OK.
- Generation QR de la session `Session audit 2` : OK.
- NFC : interface et appels de lecture charges; test physique bloque par
  l'absence de lecteur NFC Android dans l'environnement d'audit.

## Points a garder pour la tranche suivante

1. Decider explicitement si les membres simples doivent acceder a
   `/attendance` pour leur suivi personnel, puis ajuster les permissions dans
   une tranche dediee.
2. Valider le scan QR avec la camera d'un telephone reel.
3. Valider enrolement et pointage NFC sur un telephone Android NFC.
