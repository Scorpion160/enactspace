# Academy : proportions, palettes et bannières

Référence : 713762c63eb7736335883ac81c2e9b9fce028b1f, analyse et 35 tests validés par Windows. Captures après redémarrage reçues le 17 octobre, 19 h 17 UTC.

Diagnostic : les dimensions disponibles dans la fenêtre (sidebar et zoom inclus) restent inférieures aux seuils de 1100 pixels ; la bannière/progression et les filtres restaient empilés. Le choix des variantes graphiques dépendait de la largeur de chaque carte, ce qui sélectionnait les images mobiles sur desktop.

Corrections : seuil de 850 pixels disponibles pour le duo bannière/progression, 900 pour les filtres ; repli aux grands textes conservé. Variante graphique basée sur le viewport. Huit vraies bannières panoramiques clair/sombre issues des original_crops/web du pack de l'utilisateur, converties en WebP sans perte sans changer les pixels ni ajouter du texte. Leurs textes restent dans Flutter. Palette bleu nuit/turquoise locale à Academy : les autres écrans ne sont pas modifiés. Espacements de page réduits.

Les tests couvrent maintenant aussi 1024 pixels et les huit nouvelles bannières. Syntaxe préparée via tree-sitter ; compilation/analyse Flutter et validation visuelle à exécuter sur Windows. Pas de build ou déploiement dans le script.

Les fiches de formation, parcours détaillés et lecteur ne sont pas refondus par cette étape et restent à traiter, à partir des maquettes livrées. Toutes les actions pédagogiques et données restent inchangées.
