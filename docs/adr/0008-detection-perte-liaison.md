# ADR-0008 — Détection de perte de liaison : approches écartées

Statut : accepté (décision négative importante)

## Contexte
Panne réelle : liaison Bluetooth (RFCOMM) figée, plus de données, mais
Windows voit toujours le port ET le dongle en « OK ». Un arrêt/marche
(réouverture du port) rétablit la liaison.

## Options étudiées
1. Surveiller l'état PnP (port COM, périphérique, dongle). **Écartée** :
   les trois restent « OK » même liaison tombée (prouvé par journal).
2. Sonder la radio via un port virtuel dédié (commande CAT périodique).
   Techniquement fonctionnel, mais **dégrade le trafic** (collisions avec
   HRD/OpsLog). **Écartée** à la demande de l'utilisatrice.

## Décision
Pas de détection par sondage. On garde :
- bouton manuel « Réinitialiser la liaison » = réouverture du port ;
- réouverture automatique si hub4com meurt (timer 5 s) ;
- (voir ADR-0010) réinitialisation programmée identique au bouton manuel.

## Conséquences
- La panne « figée sans mort de hub4com » n'est pas auto-détectable ;
  l'utilisatrice clique le bouton, ou la réinit. programmée l'anticipe.
- Ne jamais réintroduire de sondage périodique de la radio.
