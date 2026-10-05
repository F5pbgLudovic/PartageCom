# ADR-0012 — Rétention du journal : 7 jours

Statut : accepté

## Contexte
`PartageCOM.log` grossissait indéfiniment.

## Décision
`Prune-Log` au démarrage : ne conserver que les lignes des 7 derniers jours
(les lignes de continuation suivent le sort de leur ligne horodatée).

## Conséquences
- Journal borné à ~une semaine glissante, sans impact pendant l'usage.
