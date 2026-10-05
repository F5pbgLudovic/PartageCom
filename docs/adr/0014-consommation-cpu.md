# ADR-0014 — Consommation CPU minimale

Statut : accepté

## Décision
Application pilotée par événements. Seuls timers permanents :
surveillance de hub4com (5 s). Pas de polling de la radio (ADR-0008). Le
voyant d'état a été supprimé (il ne variait plus) pour éviter toute tâche
d'affichage périodique. Attentes non bloquantes via `Wait-Pump` (DoEvents).

## Conséquences
- Charge CPU négligeable au repos.
- Toute nouvelle tâche périodique doit rester légère et justifiée.
