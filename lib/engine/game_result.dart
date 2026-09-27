import 'model/game_mode.dart';
import 'scoring/score_calculator.dart';

/// Issue d'une partie commencée (gagnée, ou abandonnée = défaite).
final class GameResult {
  const GameResult({
    required this.mode,
    required this.seed,
    required this.won,
    required this.score,
    required this.elapsedMs,
    required this.moves,
    required this.hints,
    required this.undos,
    required this.finishedAt,
    this.challengeId,
  });

  final GameMode mode;
  final int seed;
  final bool won;
  final ScoreBreakdown score;
  final int elapsedMs;
  final int moves;
  final int hints;
  final int undos;
  final DateTime finishedAt;
  final String? challengeId;
}
