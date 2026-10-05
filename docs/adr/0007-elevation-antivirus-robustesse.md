# ADR-0007 — Élévation, robustesse, antivirus

Statut : accepté

## Contexte
com0com exige les droits admin. Les premières versions se fermaient sans
message en cas d'erreur, et l'écriture d'exe depuis un .bat déclenche
Bitdefender (Advanced Threat Defense).

## Décision
- Relance automatique en admin (UAC), paramètre `/auto` propagé.
- Journal fichier `PartageCOM.log` + boîte d'erreur si échec avant l'UI ;
  la console reste visible en dernier recours.
- Exécution du PowerShell en mémoire (ADR-0002) pour réduire les alertes.
- Documenter les exclusions Bitdefender (fichier .bat + dossier com0com) ;
  alternative : installer com0com séparément.

## Conséquences
- Erreurs toujours visibles/traçables.
- L'antivirus peut exiger une exclusion unique à la première installation.
