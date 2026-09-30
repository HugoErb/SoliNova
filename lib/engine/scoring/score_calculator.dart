import '../model/game_mode.dart';

/// Paramètres de score propres à chaque mode.
final class ModeScoring {
  const ModeScoring({
    required this.difficultyBonus,
    required this.referenceSeconds,
    required this.referenceMoves,
  });

  /// Bonus fixe reflétant la difficulté du mode.
  final int difficultyBonus;

  /// Temps de référence : chaque seconde gagnée sous ce temps rapporte.
  final int referenceSeconds;

  /// Nombre de coups de référence : chaque coup économisé rapporte.
  final int referenceMoves;
}

/// Détail du score d'une partie, affiché tel quel au joueur.
final class ScoreBreakdown {
  const ScoreBreakdown({
    required this.gamePoints,
    required this.victoryBonus,
    required this.difficultyBonus,
    required this.speedBonus,
    required this.movesBonus,
    required this.streakBonus,
  });

  final int gamePoints;
  final int victoryBonus;
  final int difficultyBonus;
  final int speedBonus;
  final int movesBonus;
  final int streakBonus;

  int get total {
    final raw =
        gamePoints +
        victoryBonus +
        difficultyBonus +
        speedBonus +
        movesBonus +
        streakBonus;
    return raw < 0 ? 0 : raw;
  }
}

/// Calcul du score de partie. Indépendant de l'XP et des points de boutique.
abstract final class ScoreCalculator {
  static const victoryBonus = 500;
  static const speedPerSecond = 2;
  static const speedMax = 600;
  static const movesPerMove = 5;
  static const movesMax = 400;
  static const streakPerWin = 50;
  static const streakMax = 500;

  static const Map<GameMode, ModeScoring> modes = {
    GameMode.klondike1: ModeScoring(
      difficultyBonus: 0,
      referenceSeconds: 300,
      referenceMoves: 130,
    ),
    GameMode.klondike3: ModeScoring(
      difficultyBonus: 200,
      referenceSeconds: 420,
      referenceMoves: 160,
    ),
    GameMode.spider1: ModeScoring(
      difficultyBonus: 0,
      referenceSeconds: 480,
      referenceMoves: 180,
    ),
    GameMode.spider2: ModeScoring(
      difficultyBonus: 400,
      referenceSeconds: 900,
      referenceMoves: 260,
    ),
    GameMode.spider4: ModeScoring(
      difficultyBonus: 900,
      referenceSeconds: 1500,
      referenceMoves: 340,
    ),
    GameMode.freecell: ModeScoring(
      difficultyBonus: 150,
      referenceSeconds: 360,
      referenceMoves: 110,
    ),
  };

  /// Score affiché pendant la partie : points de jeu. Annuler, indice et coup
  /// assisté ne coûtent rien.
  static int live({required int gamePoints}) =>
      gamePoints < 0 ? 0 : gamePoints;

  /// Score final. [previousStreak] = victoires consécutives dans ce mode
  /// avant cette partie.
  static ScoreBreakdown compute({
    required GameMode mode,
    required bool won,
    required int gamePoints,
    required int elapsedMs,
    required int moves,
    required int previousStreak,
  }) {
    final m = modes[mode]!;
    final seconds = elapsedMs ~/ 1000;
    int clamp(int v, int max) => v < 0 ? 0 : (v > max ? max : v);
    return ScoreBreakdown(
      gamePoints: gamePoints,
      victoryBonus: won ? victoryBonus : 0,
      difficultyBonus: won ? m.difficultyBonus : 0,
      speedBonus: won
          ? clamp((m.referenceSeconds - seconds) * speedPerSecond, speedMax)
          : 0,
      movesBonus: won
          ? clamp((m.referenceMoves - moves) * movesPerMove, movesMax)
          : 0,
      streakBonus: won ? clamp(previousStreak * streakPerWin, streakMax) : 0,
    );
  }
}
