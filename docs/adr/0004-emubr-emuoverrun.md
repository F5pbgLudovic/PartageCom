# ADR-0004 — Réglages EmuBR / EmuOverrun des paires

Statut : accepté (remplace les choix intermédiaires)

## Contexte
- `EmuOverrun=yes` jette les octets non lus assez vite → trames tronquées,
  déconnexions dans OpsLog.
- `EmuBR=yes` simule la vitesse en bauds → latence de cadencement inutile.

## Décision
Créer les paires en `EmuBR=no, EmuOverrun=no`. `Ensure-Pair` corrige
automatiquement les paires existantes vers ces valeurs.

## Conséquences
- Plus de perte d'octets, latence com0com minimale.
- Historique : on était passé par EmuOverrun=no (fiabilité) en gardant
  EmuBR=yes, puis EmuBR=no a été retenu pour la latence. Sur Bluetooth le
  gain reste modeste (la pile RFCOMM domine).
