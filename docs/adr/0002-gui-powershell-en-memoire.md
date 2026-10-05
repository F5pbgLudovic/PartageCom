# ADR-0002 — Interface PowerShell/WinForms exécutée en mémoire

Statut : accepté

## Contexte
Besoin d'une interface graphique sans dépendance externe, dans un .bat.

## Décision
Interface en PowerShell + WinForms. L'en-tête .bat extrait le script entre
`#PS_BEGIN`/`#PS_END` et l'exécute via `[scriptblock]::Create`, **sans écrire
de fichier .ps1 temporaire**.

## Conséquences
- Aucune trace .ps1 sur disque (moins de faux positifs antivirus).
- Impossible d'exécuter/tester sous Windows depuis l'environnement de dev :
  on valide par équilibrage d'accolades, hashes des binaires, relecture.
- PS2EXE envisagé pour un .exe mais écarté (non signé = plus d'alertes, et
  n'offre pas de vraie protection du code).
