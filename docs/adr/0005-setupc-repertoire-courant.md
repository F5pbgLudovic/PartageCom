# ADR-0005 — Lancer setupc depuis le dossier com0com

Statut : accepté

## Contexte
En admin, le processus démarre dans `C:\Windows\System32`. `setupc.exe` y
cherchait ses `.inf` et échouait : `SetupOpenInfFile(...cncport.inf) ERROR: 2`.
Copier les .inf dans System32 ne faisait que déplacer le problème.

## Décision
Toujours exécuter `setupc` via `Run-Setupc`, qui fait `Push-Location $dir`
(dossier com0com) avant l'appel, en mode `--silent`.

## Conséquences
- Création/modification des paires fiable, sans boîtes Recommencer/Annuler.
- Les messages de setupc partent dans le journal.
