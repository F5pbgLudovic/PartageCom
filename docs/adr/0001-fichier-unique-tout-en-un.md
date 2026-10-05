# ADR-0001 — Livrable en fichier unique auto-contenu

Statut : accepté

## Contexte
L'utilisatrice voulait, au départ, un simple .bat pour piloter hub4com, puis
une application intégrée, puis « ne plus rien avoir à télécharger ». com0com
(pilote noyau) et hub4com ne peuvent pas être recréés par un script.

## Décision
Produire un unique `PartageCOM.bat` qui embarque, en base64, l'installeur
signé com0com 3.0.0.0 (x64 et x86) et `hub4com.exe`, plus l'interface. Au
premier MARCHE, les composants manquants sont extraits et installés.

## Conséquences
- Rien à télécharger pour l'utilisatrice.
- Fichier volumineux (~1,3 Mo) mais autonome.
- Peut déclencher l'antivirus (un .bat qui écrit des exe) : voir ADR-0007.
- Le build doit assembler l'en-tête + le PowerShell + les 3 blocs base64.
