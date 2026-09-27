import '../../engine/game_result.dart';
import '../../engine/model/game_mode.dart';
import '../json.dart';

/// Position dans la courbe de niveaux.
final class LevelInfo {
  const LevelInfo(this.level, this.xpIntoLevel, this.xpForNextLevel);

  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get progress => xpIntoLevel / xpForNextLevel;
}

/// Règles d'XP. L'XP fait progresser le niveau et n'est jamais dépensée.
abstract final class XpRules {
  static const maxLevel = 99;

  /// XP de base d'une victoire, selon la difficulté du mode.
  static const Map<GameMode, int> winBase = {
    GameMode.klondike1: 40,
    GameMode.klondike3: 60,
    GameMode.spider1: 50,
    GameMode.spider2: 90,
    GameMode.spider4: 150,
    GameMode.freecell: 60,
  };

  /// 1 XP par tranche de 20 points de score.
  static const scorePerXp = 20;

  /// XP de consolation d'une défaite réellement jouée.
  static const lossXp = 5;
  static const lossMinMoves = 20;
  static const lossMinSeconds = 60;

  /// XP nécessaire pour passer du niveau [level] au suivant.
  static int xpToNext(int level) => 100 + 50 * (level - 1);

  static LevelInfo levelFor(int totalXp) {
    var level = 1;
    var remaining = totalXp;
    while (level < maxLevel && remaining >= xpToNext(level)) {
      remaining -= xpToNext(level);
      level++;
    }
    return LevelInfo(level, remaining, xpToNext(level));
  }

  static int forGame(GameResult r) {
    if (r.won) return winBase[r.mode]! + r.score.total ~/ scorePerXp;
    final played =
        r.moves >= lossMinMoves && r.elapsedMs >= lossMinSeconds * 1000;
    return played ? lossXp : 0;
  }
}

/// Progression du joueur : XP totale (le niveau en découle).
final class PlayerProgress {
  const PlayerProgress({this.totalXp = 0});

  final int totalXp;

  LevelInfo get levelInfo => XpRules.levelFor(totalXp);
  int get level => levelInfo.level;

  PlayerProgress addXp(int xp) => PlayerProgress(totalXp: totalXp + xp);

  Json toJson() => {'xp': totalXp};

  static PlayerProgress fromJson(Json j) =>
      PlayerProgress(totalXp: readInt(j, 'xp'));
}
