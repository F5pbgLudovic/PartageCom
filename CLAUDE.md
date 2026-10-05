# CLAUDE.md — règles de travail sur PartageCOM

Ce fichier consigne les conventions à respecter pour modifier ce projet.
Il s'adresse à toute personne (ou IA) qui reprend le code.

## Ce qu'est le projet

PartageCOM partage un port série physique (l'émetteur radio) vers plusieurs
ports série virtuels, pour que HRD et OpsLog pilotent la même radio en même
temps. Il s'appuie sur **com0com** (pilote de paires de ports virtuels) et
**hub4com** (duplication du port réel vers N ports virtuels), tous deux du
projet com0com.

Le livrable est **un seul fichier** : `dist/PartageCOM.bat`. Il embarque, en
base64, l'installeur signé com0com 3.0.0.0 (x64 et x86) et `hub4com.exe`, plus
une interface graphique PowerShell/WinForms. L'utilisateur double-clique
dessus, rien d'autre à télécharger.

## Structure du dépôt

- `src/gui.ps1` — la seule source à éditer (le script PowerShell de l'appli).
- `vendor/` — les binaires embarqués (com0com x64/x86, hub4com). Ne pas les
  modifier ; ce sont les binaires officiels signés.
- `build.py` — assemble `dist/PartageCOM.bat` à partir de `src/gui.ps1` et de
  `vendor/`. **Toujours régénérer après avoir édité `gui.ps1`.**
- `dist/PartageCOM.bat` — artefact généré (versionné pour traçabilité).
- `docs/adr/` — décisions d'architecture (une par fichier).
- `CHAT.md` — historique des échanges ayant conduit au code.

## Processus de build

1. Éditer `src/gui.ps1`.
2. `python3 build.py`.
3. Vérifier (voir « Vérifications » plus bas).
4. Commiter `src/gui.ps1` ET `dist/PartageCOM.bat` ensemble.

## Règles impératives (pièges déjà rencontrés)

- **Encodage** : sortie UTF-8 **sans BOM**. L'en-tête `.bat` doit rester en
  ASCII pur ; cmd s'arrête sur `exit /b` avant d'atteindre les octets
  accentués du PowerShell. Ne jamais ajouter de BOM (cmd casserait sur
  `@echo off`).
- **`setupc.exe` se lance depuis son propre dossier.** Il cherche ses `.inf`
  (`com0com.inf`, `cncport.inf`, `comport.inf`) dans le **répertoire courant**.
  Lancé ailleurs (ex. `C:\Windows\System32` quand on est admin), il échoue avec
  `SetupOpenInfFile(...) ERROR: 2`. Toujours passer par la fonction
  `Run-Setupc` qui fait `Push-Location $dir`.
- **Chemins périphériques** : le préfixe est `\\.\` (deux antislashs, point,
  un antislash). En PowerShell double-quote : `"\\.\COM5"`. Attention au
  sur-échappement quand on génère ce code via un script Python.
- **`$args` est réservé** en PowerShell : ne pas nommer une variable `$args`
  (utiliser `$hubArgs`, etc.).
- **Guillemets dans `-ArgumentList`** : PowerShell n'échappe pas avec `\"`.
  Pour passer des arguments à un exe (ex. USBDeview), utiliser un **tableau** :
  `-ArgumentList @("/RunAsAdmin", $op, $id)`. Ne pas construire une seule
  chaîne avec des guillemets internes.
- **Élévation** : le script se relance en admin (nécessaire à com0com). Le
  paramètre `/auto` est propagé lors de la relance.
- **Exécution en mémoire** : l'en-tête extrait le PowerShell entre `#PS_BEGIN`
  et `#PS_END` et l'exécute via `scriptblock` — pas de fichier temporaire .ps1
  (réduit les faux positifs antivirus).

## Latence

Seul levier côté logiciel : les paires com0com sont créées en
`EmuBR=no,EmuOverrun=no` (latence minimale). `Ensure-Pair` corrige
automatiquement les paires existantes vers ces valeurs. Sur une liaison
Bluetooth, l'essentiel de la latence vient de la pile RFCOMM, pas de
com0com : ne pas promettre de gains spectaculaires.

## Détection de perte de liaison — NE PAS refaire

Deux pistes ont été essayées et **écartées** (voir ADR-0008) :
1. Surveiller l'état PnP du port/dongle : inutile, Windows laisse tout en
   « OK » même liaison tombée.
2. Sonder la radio via un port dédié (commande CAT périodique) : **dégrade le
   trafic** (collisions avec HRD/OpsLog). Rejeté par l'utilisateur.

La seule récupération retenue :
- bouton **« Réinitialiser la liaison »** = réouverture du port (kill + relance
  de hub4com) ;
- **réouverture automatique** si hub4com meurt (timer 5 s) ;
- **réinitialisation automatique** programmée (1–12 h) = strictement identique
  au bouton manuel (réouverture) ;
- escalade éventuelle vers le cycle du dongle (USBDeview/PnP) seulement en cas
  de chute répétée dans la minute.

Ne pas réintroduire de sondage périodique de la radio.

## Produit / nommage

- Titre de fenêtre : `PartageCOM V1.00 @F5PBG 2026 - Partage de port série`.
- Ne pas renommer les commandes/libellés visibles sans accord explicite
  (ex. « Réinitialisation automatique Bluetooth », « Réinitialiser la
  liaison », « Périphérique Bluetooth à redémarrer si nécessaire »).

## Comportements UI à préserver

- Croix de fermeture : réduit la fenêtre si le partage est actif ; ferme sinon.
- Démarrage automatique avec Windows via tâche planifiée (`/auto`), fenêtre
  réduite, partage lancé seul.
- Journal `PartageCOM.log` à côté du .bat ; purge au démarrage des lignes de
  plus de 7 jours.
- Consommation CPU minimale : pas de polling superflu ; timers espacés
  (hub4com : 5 s). Toute nouvelle tâche périodique doit rester légère.

## Vérifications avant de livrer (on ne peut pas exécuter Windows ici)

- Équilibre des accolades/parenthèses du bloc PowerShell.
- Les trois binaires embarqués ont le même SHA-256 que ceux de `vendor/`.
- L'en-tête (200 premiers octets) est décodable en ASCII et pas de BOM.
- Le build reproduit un `.bat` cohérent (taille ~1,3 Mo).
