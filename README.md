# SoliNova

Solitaire moderne pour smartphones Android, en mode portrait, entièrement hors ligne : pas de compte, pas de publicité, pas d'achat réel.

Modes de jeu : Klondike (tirage 1 et 3), Spider (1, 2 et 4 couleurs) et FreeCell.

## Stack

- Flutter 3.47 / Dart 3.13, avec le moteur de rendu Impeller.
- Riverpod pour l'état de l'application.
- Sauvegarde en fichiers JSON versionnés, avec écriture atomique.
- `audioplayers` pour les effets sonores. L'application n'utilise aucune vibration.

## Architecture

```
lib/
  engine/      Moteur de jeu en Dart pur, sans Flutter
    model/     Card, Suit, Rank, Deck, Pile (fondations, tableau, cellules…), Move, GameState, GameMode
    rng/       Générateur à graine (Mulberry32), stable entre versions
    rules/     GameRules → KlondikeRules, SpiderRules, FreeCellRules, et RulesRegistry
    session/   GameSession : historique, Annuler, compteurs, sérialisation
    scoring/   Points de jeu et score final (ScoreCalculator)
  meta/        Progression, en Dart pur
    stats/ progression/ economy/ achievements/ daily/ shop/ settings/ profile/
  data/        Stockage clé → JSON (fichier ou mémoire), dépôts, sauvegarde différée
  app/         Fournisseurs Riverpod, GameController, application racine
  ui/          Thèmes, rendu vectoriel des cartes, plateau, écrans
```

Pour ajouter une variante (Pyramid, TriPeaks, Yukon…) :

1. implémenter `GameRules` ;
2. ajouter l'entrée correspondante dans `GameMode` et `GameFamily` ;
3. placer ses piles dans `BoardGeometry`.

## Règles métier clés

- **Partie commencée :** une partie commence au premier coup valide. Si elle est abandonnée ou remplacée par une autre, elle compte comme une défaite.
- **Score, XP et points :** trois systèmes séparés. La page « Comment le score est calculé » lit directement les constantes du code, elle reste donc toujours exacte.
- **Défis quotidiens :**
  - la graine est dérivée de la date, du mode et de la difficulté ;
  - les tentatives sont illimitées ;
  - la récompense n'est versée qu'une seule fois.

## Commandes

```
flutter test                               # moteur, méta, persistance, géométrie, écrans
flutter analyze
flutter build apk --release
flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
  --target=integration_test/drag_perf_test.dart   # mesure de fluidité sur appareil
python tool/generate_sounds.py             # régénère les sons
python tool/generate_icons.py              # régénère les icônes
```

La compilation en release est actuellement signée avec la clé de debug. Il faudra configurer une clé de signature avant toute publication.
