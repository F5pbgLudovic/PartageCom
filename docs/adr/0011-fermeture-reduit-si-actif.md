# ADR-0011 — La croix réduit la fenêtre si le partage est actif

Statut : accepté

## Décision
`FormClosing` : si la fermeture vient de l'utilisateur (`UserClosing`) ET que
le partage tourne, annuler la fermeture et réduire la fenêtre. Sinon (partage
arrêté, ou fermeture Windows), fermer normalement (en arrêtant le partage).

## Conséquences
- On ne coupe pas la liaison par un clic involontaire sur la croix.
- Pour quitter pendant un partage : ARRÊT puis croix.
