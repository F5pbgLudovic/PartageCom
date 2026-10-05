# ADR-0009 — Cycle du dongle Bluetooth (USBDeview / PnP natif)

Statut : accepté

## Contexte
Pour réinitialiser le Bluetooth, l'utilisatrice cyclait le dongle USB via
USBDeview (`/disable` puis `/enable`). L'auto-détection sélectionnait à tort
le port série Bluetooth (`BTHENUM\...`) au lieu du dongle USB parent.

## Décision
- `Get-UsbAncestor` remonte la chaîne PnP jusqu'au périphérique `USB\...`
  (le dongle) et le propose en premier (« recommandé »).
- `Set-BTDevice` utilise `C:\USBDeview.exe` s'il est présent (arguments en
  **tableau**), sinon `Disable-PnpDevice`/`Enable-PnpDevice` natifs.
- Le champ « Périphérique Bluetooth à redémarrer si nécessaire » conserve
  l'identifiant ; bouton « Détecter » (choix direct si un seul candidat).

## Conséquences
- Le cycle du dongle fonctionne avec ou sans USBDeview.
- Utilisé seulement en escalade (chute répétée) et dans l'ancienne réinit.
  programmée — désormais ramenée à la simple réouverture (ADR-0010).
