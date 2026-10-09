# Lot 35 — intégration Windows préparée
9 octobre 2026.

Le script tools/sync_prelaunch_audit_windows.ps1 intègre trois fichiers du commit 07633b573402d3618eaa416f061a8982ddfd0fe8 : garde-fou mock en production et ses tests, test Academy acceptant les ajouts aux archives. Chaque source locale doit correspondre au checkpoint ee5af1019a39194dacd399b920316b916201b44e ou à la version finale. Les trois téléchargements sont vérifiés avant remplacement. Les fichiers précédents sont copiés dans CodeRollback ; les remplacements disposent d’une restauration sur erreur. Aucun git pull/reset/checkout, build ni déploiement exécuté. La documentation des lots demeure sur GitHub ; le script ne la synchronise pas.

Relecture du script et git diff --check réussis. PowerShell absent ici : exécution Windows encore à confirmer. Les suites Python des correctifs ont réussi aux lots 33 et 34. ECC avait déjà été examiné au lot d’inventaire du 7 octobre ; aucun installateur ou hook tiers ajouté par ce lot.
