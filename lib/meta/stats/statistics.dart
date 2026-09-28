import '../../engine/game_result.dart';
import '../../engine/model/game_mode.dart';
import '../json.dart';

/// Statistiques d'un mode (ou globales).
///
/// Meilleur score, score moyen, temps et coups sont calculés sur les parties
/// **gagnées** : une défaite n'a pas de temps ni de coups significatifs.
final class ModeStats {
  const ModeStats({
    this.games = 0,
    this.wins = 0,
    this.bestScore,
    this.totalWinScore = 0,
    this.bestTimeMs,
    this.totalWinTimeMs = 0,
    this.fewestMoves,
    this.totalWinMoves = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.timePlayedMs = 0,
    this.totalMoves = 0,
    this.hintsUsed = 0,
    this.assistedMovesUsed = 0,
    this.undosUsed = 0,
  });

  final int games;
  final int wins;
  final int? bestScore;
  final int totalWinScore;
  final int? bestTimeMs;
  final int totalWinTimeMs;
  final int? fewestMoves;
  final int totalWinMoves;
  final int currentStreak;
  final int longestStreak;
  final int timePlayedMs;
  final int totalMoves;
  final int hintsUsed;
  final int assistedMovesUsed;
  final int undosUsed;

  int get losses => games - wins;
  double get winRate => games == 0 ? 0 : wins / games;
  int? get averageScore => wins == 0 ? null : (totalWinScore / wins).round();
  int? get averageTimeMs => wins == 0 ? null : totalWinTimeMs ~/ wins;
  int? get averageMoves => wins == 0 ? null : (totalWinMoves / wins).round();

  /// Enregistre une partie commencée.
  ModeStats record(GameResult r) {
    final score = r.score.total;
    final streak = r.won ? currentStreak + 1 : 0;
    return ModeStats(
      games: games + 1,
      wins: wins + (r.won ? 1 : 0),
      bestScore: r.won ? _max(bestScore, score) : bestScore,
      totalWinScore: totalWinScore + (r.won ? score : 0),
      bestTimeMs: r.won ? _min(bestTimeMs, r.elapsedMs) : bestTimeMs,
      totalWinTimeMs: totalWinTimeMs + (r.won ? r.elapsedMs : 0),
      fewestMoves: r.won ? _min(fewestMoves, r.moves) : fewestMoves,
      totalWinMoves: totalWinMoves + (r.won ? r.moves : 0),
      currentStreak: streak,
      longestStreak: streak > longestStreak ? streak : longestStreak,
      timePlayedMs: timePlayedMs + r.elapsedMs,
      totalMoves: totalMoves + r.moves,
      hintsUsed: hintsUsed + r.hints,
      assistedMovesUsed: assistedMovesUsed + r.assistedMoves,
      undosUsed: undosUsed + r.undos,
    );
  }

  static int _max(int? a, int b) => a == null || b > a ? b : a;
  static int _min(int? a, int b) => a == null || b < a ? b : a;

  Json toJson() => {
    'games': games,
    'wins': wins,
    'bestScore': bestScore,
    'totalWinScore': totalWinScore,
    'bestTime': bestTimeMs,
    'totalWinTime': totalWinTimeMs,
    'fewestMoves': fewestMoves,
    'totalWinMoves': totalWinMoves,
    'streak': currentStreak,
    'longestStreak': longestStreak,
    'timePlayed': timePlayedMs,
    'totalMoves': totalMoves,
    'hints': hintsUsed,
    'assistedMoves': assistedMovesUsed,
    'undos': undosUsed,
  };

  static ModeStats fromJson(Json j) => ModeStats(
    games: readInt(j, 'games'),
    wins: readInt(j, 'wins'),
    bestScore: readIntOrNull(j, 'bestScore'),
    totalWinScore: readInt(j, 'totalWinScore'),
    bestTimeMs: readIntOrNull(j, 'bestTime'),
    totalWinTimeMs: readInt(j, 'totalWinTime'),
    fewestMoves: readIntOrNull(j, 'fewestMoves'),
    totalWinMoves: readInt(j, 'totalWinMoves'),
    currentStreak: readInt(j, 'streak'),
    longestStreak: readInt(j, 'longestStreak'),
    timePlayedMs: readInt(j, 'timePlayed'),
    totalMoves: readInt(j, 'totalMoves'),
    hintsUsed: readInt(j, 'hints'),
    assistedMovesUsed: readInt(j, 'assistedMoves'),
    undosUsed: readInt(j, 'undos'),
  );
}

/// Records battus par une partie, pour l'écran de victoire.
final class NewRecords {
  const NewRecords({
    this.bestScore = false,
    this.bestTime = false,
    this.fewestMoves = false,
    this.longestStreak = false,
  });

  final bool bestScore;
  final bool bestTime;
  final bool fewestMoves;
  final bool longestStreak;

  bool get any => bestScore || bestTime || fewestMoves || longestStreak;
}

/// Ensemble des statistiques persistantes.
final class Statistics {
  const Statistics({
    this.global = const ModeStats(),
    this.perMode = const {},
    this.challengesFinished = 0,
    this.challengesSucceeded = 0,
    this.pointsEarned = 0,
  });

  /// Statistiques tous modes confondus (la série globale compte les
  /// victoires consécutives quel que soit le mode).
  final ModeStats global;
  final Map<GameMode, ModeStats> perMode;

  /// Parties de défi terminées (gagnées ou perdues).
  final int challengesFinished;

  /// Défis dont l'objectif a été atteint (une fois par défi).
  final int challengesSucceeded;

  /// Total des points de boutique gagnés depuis le début.
  final int pointsEarned;

  ModeStats of(GameMode mode) => perMode[mode] ?? const ModeStats();

  (Statistics, NewRecords) record(GameResult r) {
    final before = of(r.mode);
    final after = before.record(r);
    final records = NewRecords(
      bestScore:
          r.won &&
          before.bestScore != null &&
          after.bestScore! > before.bestScore!,
      bestTime:
          r.won &&
          before.bestTimeMs != null &&
          after.bestTimeMs! < before.bestTimeMs!,
      fewestMoves:
          r.won &&
          before.fewestMoves != null &&
          after.fewestMoves! < before.fewestMoves!,
      longestStreak:
          r.won &&
          after.longestStreak > before.longestStreak &&
          after.longestStreak > 1,
    );
    return (
      _copy(
        global: global.record(r),
        perMode: {...perMode, r.mode: after},
        challengesFinished:
            challengesFinished + (r.challengeId != null ? 1 : 0),
      ),
      records,
    );
  }

  Statistics withChallengeSucceeded() =>
      _copy(challengesSucceeded: challengesSucceeded + 1);

  Statistics withPointsEarned(int points) =>
      _copy(pointsEarned: pointsEarned + points);

  Statistics _copy({
    ModeStats? global,
    Map<GameMode, ModeStats>? perMode,
    int? challengesFinished,
    int? challengesSucceeded,
    int? pointsEarned,
  }) => Statistics(
    global: global ?? this.global,
    perMode: perMode ?? this.perMode,
    challengesFinished: challengesFinished ?? this.challengesFinished,
    challengesSucceeded: challengesSucceeded ?? this.challengesSucceeded,
    pointsEarned: pointsEarned ?? this.pointsEarned,
  );

  Json toJson() => {
    'global': global.toJson(),
    'modes': {for (final e in perMode.entries) e.key.name: e.value.toJson()},
    'challengesFinished': challengesFinished,
    'challengesSucceeded': challengesSucceeded,
    'pointsEarned': pointsEarned,
  };

  static Statistics fromJson(Json j) {
    final modes = readMap(j, 'modes');
    return Statistics(
      global: ModeStats.fromJson(readMap(j, 'global')),
      perMode: {
        for (final e in modes.entries)
          ?GameMode.tryParse(e.key): ModeStats.fromJson(
            e.value is Map ? (e.value! as Map).cast<String, Object?>() : {},
          ),
      },
      challengesFinished: readInt(j, 'challengesFinished'),
      challengesSucceeded: readInt(j, 'challengesSucceeded'),
      pointsEarned: readInt(j, 'pointsEarned'),
    );
  }
}
