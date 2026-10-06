# ADR-0015 — Option « Garder la fenêtre au premier plan »

Statut : accepté

## Contexte
L'utilisatrice souhaite pouvoir garder la fenêtre PartageCOM visible au-dessus
des autres applications (HRD, OpsLog, WSJT-X).

## Décision
Case à cocher « Garder la fenêtre au premier plan » agissant sur `TopMost` de
la fenêtre principale ; réglage mémorisé (`TopMost` dans PartageCOM.json). La
boîte de sélection du périphérique (Détecter) est elle aussi `TopMost` pour ne
pas repasser derrière la fenêtre principale quand celle-ci est au premier plan.

## Conséquences
- Confort d'usage ; aucun impact sur le partage.
