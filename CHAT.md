# CHAT.md — historique des échanges

Journal chronologique des demandes et de ce qui a été fait. Les décisions
d'architecture correspondantes sont dans `docs/adr/`.

1. **Explication de com0com + usage avec HRD et OpsLog.**
   Rappel du rôle de com0com (paires de ports série virtuels) et de la
   nécessité de hub4com pour partager un port physique vers deux logiciels.
   → ADR-0003.

2. **« Je n'ai besoin que de hub4com ? »**
   Non : hub4com ne crée pas de ports, com0com reste requis. Explication du
   montage paire par paire (COMxx côté logiciel, HUBxx côté hub4com).

3. **Premiers .bat.** Création des ports (COM14↔HUB14, COM15↔HUB15) + partage
   de COM5. D'abord deux fichiers, puis un seul .bat auto-élévé.

4. **Débit réglé à 38400.**

5. **Où télécharger com0com/hub4com + config.** Liens SourceForge et miroir
   GitHub ; version signée obligatoire. → ADR-0006.

6. **Application intégrée** avec sélection de port, débit, bouton MARCHE/ARRÊT.
   Interface PowerShell/WinForms. → ADR-0002.

7. **Tout dans un seul fichier cliquable.** Embarquement base64 de com0com
   (x64/x86) et hub4com dans le .bat. → ADR-0001.

8. **Ajout de l'indicatif F5PBG** dans l'interface (coin de fenêtre, titre,
   boîtes d'erreur).

9. **« Je n'ai plus rien à télécharger ? »** Confirmé.

10. **Erreur `SetupOpenInfFile(...com0com.inf) ERROR: 2`.** Diagnostic : setupc
    doit tourner dans son dossier. → ADR-0005.

11. **Antivirus (Bitdefender) bloque.** Faux positif ; exclusions + exécution
    en mémoire. → ADR-0007.

12. **Fenêtre qui se ferme aussitôt.** Ajout d'un journal fichier, erreurs
    visibles, exécution en mémoire sans fichier temporaire.

13. **Laisser com0com.sys dans System32 ?** Oui (inerte, le vrai pilote est
    dans `drivers\`).

14. **Ça marche.** Paires créées, hub4com actif.

15. **Ports 14/15 absents du Gestionnaire.** Normal (catégorie « com0com -
    serial port emulators »).

16. **COM14 absent de HRD.** Redémarrer HRD, vérifier GetPortNames, saisie
    manuelle possible ; option « use Ports class ».

17. **Lancement à chaque redémarrage ?** Oui pour hub4com ; proposition de
    démarrage automatique.

18. **Démarrage automatique** via tâche planifiée (admin, `/auto`, fenêtre
    réduite).

19. **Exclusions antivirus** (fichier .bat + dossier com0com) ; les exceptions
    System32 étaient une fausse piste.

20. **3e, puis 4e et 5e ports virtuels** optionnels (0 = aucun).

21. **Listes déroulantes filtrées** : exclure < COM11, ports physiques déjà
    pris, le port radio, les doublons ; menu pour les ports.

22. **Déconnexions OpsLog avec 15/16.** Correctif `EmuOverrun=no`. → ADR-0004.

23. **FT-2000 en direct (pas OmniRig).** Appliquer le correctif ; conseils
    CAT RTS / polling.

24. **Voyant vert/rouge** à côté du port émetteur (ajouté, puis synchronisé
    30 s, puis agrandi/jaune clignotant, puis supprimé — voir plus bas).

25. **Réactivité / EmuBR.** Passage EmuBR=no envisagé, annulé puis rétabli par
    la suite pour la latence. → ADR-0004.

26. **Surveillance + redémarrage Bluetooth** si perte, avec case « Surveiller »
    et champ périphérique. Détection d'abord par état du port, puis dongle.

27. **30 s au lieu de 3 s** pour la surveillance.

28. **Exe illisible ?** Expliqué : PS2EXE n'offre pas de vraie protection et
    aggrave l'antivirus ; proposition déclinée.

29. **Détection du dongle USB parent** (`Get-UsbAncestor`), bouton « Détecter »
    qui remplit la case ; choix direct si un seul candidat ; filtrage sur le
    port COM sélectionné. → ADR-0009.

30. **Détection auto au clic sur « Surveiller ».**

31. **USBDeview mal appelé** (guillemets cassés) → arguments en tableau.
    Détection fiabilisée. → ADR-0009.

32. **Le voyant reste vert** même dongle coupé : l'état PnP ne bouge pas.
    Bascule sur l'état du dongle, puis journalisation de diagnostic.

33. **Preuve par le journal** : port, périphérique et dongle restent « OK »
    liaison coupée. La vraie panne est une connexion RFCOMM figée ;
    arrêt/marche la rétablit. → ADR-0008.

34. **Sonde CAT** (port dédié, commande `ID;`) : fonctionne mais ralentit la
    liaison → **abandonnée**. → ADR-0008.

35. **Repli** : suppression de toute vérification périodique. Bouton de
    réouverture + réouverture auto si hub4com meurt ; voyant simplifié.

36. **Suppression du voyant** (il ne variait plus) et accents dans les
    libellés → encodage UTF-8 sans BOM. → ADR-0013, ADR-0014.

37. **Case « Surveiller » retirée** : réouverture auto rendue permanente ;
    champ périphérique conservé.

38. **Latence** : EmuBR=no appliqué partout. **Réinitialisation automatique
    Bluetooth** (case + menu 1–12 h) ajoutée (cycle dongle 20 s à l'origine).
    → ADR-0004.

39. **Titre de fenêtre** : `PartageCOM V1.00 @F5PBG 2026 - Partage de port
    série`.

40. **Croix de fermeture** : réduit si partage actif, ferme sinon. → ADR-0011.

41. **Réinit. automatique = bouton manuel.** La réinit. programmée fait
    désormais strictement la réouverture du port. → ADR-0010.

42. **Journal de la réinit. auto** visible dans la fenêtre et dans
    `PartageCOM.log`.

43. **Rétention du journal : 7 jours.** `Prune-Log` au démarrage. → ADR-0012.

44. **Mise en place du dépôt git**, de ce CHAT.md, des ADR et de CLAUDE.md.
