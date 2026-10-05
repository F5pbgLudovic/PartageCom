# ADR-0013 — Encodage UTF-8 sans BOM

Statut : accepté

## Contexte
Ajout d'accents dans l'interface (libellés, titre). L'ASCII ne suffit plus.

## Décision
Écrire le .bat en UTF-8 **sans BOM**. L'en-tête .bat reste ASCII ; cmd
s'arrête sur `exit /b` avant les octets accentués. Le PowerShell est lu par
`[IO.File]::ReadAllLines` (UTF-8 par défaut sans BOM).

## Conséquences
- Accents corrects dans l'interface.
- Interdiction d'un BOM (casserait `@echo off` côté cmd).
