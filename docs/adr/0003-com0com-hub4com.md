# ADR-0003 — com0com + hub4com pour le partage 1→N

Statut : accepté

## Contexte
HRD et OpsLog doivent piloter la même radio (un seul port physique).

## Décision
hub4com lit le port réel et le duplique vers plusieurs ports virtuels créés
par com0com. Chaque logiciel ouvre l'extrémité « COMxx » d'une paire ;
hub4com ouvre l'extrémité « HUBxx ». Route : `--route=0:All --route=All:0`,
avec `--octs=off --odsr=off --ox=off --ix=off`.

## Conséquences
- hub4com seul ne suffit pas : com0com est requis pour créer les paires.
- Les extrémités côté hub4com sont nommées HUBxx (pas de numéro COM
  consommé, invisibles dans HRD/OmniRig).
- Plusieurs maîtres sur un même bus peuvent provoquer des collisions CAT
  (espacer le polling).
