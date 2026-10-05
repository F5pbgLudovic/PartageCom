# PartageCOM

Partage d'un port série physique (émetteur radio) vers plusieurs ports série
virtuels, pour piloter la même radio depuis HRD et OpsLog simultanément.
Fichier unique auto-contenu (com0com + hub4com embarqués). Indicatif : F5PBG.

## Utilisation
Double-cliquer sur `dist/PartageCOM.bat`, accepter l'élévation, choisir le port
de l'émetteur, les ports virtuels et le débit, puis MARCHE.

## Développement
- Éditer `src/gui.ps1`.
- `python3 build.py` → régénère `dist/PartageCOM.bat`.
- Lire `CLAUDE.md` (conventions, pièges) et `docs/adr/` (décisions).
