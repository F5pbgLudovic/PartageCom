# ADR-0010 — Réinitialisation programmée = réouverture (identique au bouton)

Statut : accepté (remplace le comportement initial de la réinit. programmée)

## Contexte
La réinit. automatique faisait d'abord le cycle complet du dongle (disable
20 s / enable). Le bouton manuel, lui, se contente de rouvrir le port — et
il fonctionne parfaitement chez l'utilisatrice.

## Décision
La case « Réinitialisation automatique Bluetooth toutes les N h » exécute
**strictement** la même action que le bouton « Réinitialiser la liaison » :
réouverture du port (kill + relance de hub4com). Nom de la case et menu des
heures (1–12) inchangés.

## Conséquences
- Comportement cohérent et prévisible entre manuel et automatique.
- Le cycle du dongle reste disponible en escalade (ADR-0008/0009).
