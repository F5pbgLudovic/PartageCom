# ADR-0006 — com0com 3.0.0.0 signé, miroir GitHub

Statut : accepté

## Contexte
Depuis Windows 10 1607, les pilotes noyau non signés ne se chargent plus
(sinon mode test). SourceForge pas toujours commode à scripter.

## Décision
Embarquer l'installeur **signé** com0com 3.0.0.0 (x64 et x86) et hub4com
2.1.0.0 récupérés sur le miroir `BrickBot/Archive`. Installer en silencieux
(`/S`) puis `setupc preinstall`.

## Conséquences
- Installation sans mode test.
- Binaires officiels, intégrité vérifiée par SHA-256 au build.
