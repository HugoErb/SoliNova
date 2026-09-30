import '../../engine/game_result.dart';
import '../../engine/scoring/score_calculator.dart';
import '../../engine/session/game_session.dart';
import '../achievements/achievements.dart';
import '../daily/daily_challenge.dart';
import '../economy/wallet.dart';
import '../shop/inventory.dart';
import '../progression/player_progress.dart';
import '../stats/statistics.dart';
import 'profile.dart';

/// Bilan complet d'une partie, affiché sur l'écran de fin.
final class GameReport {
  const GameReport({
    required this.result,
    required this.xpFromGame,
    required this.pointsFromGame,
    required this.challenge,
    required this.challengeProgress,
    required this.challengeCompletedNow,
    required this.unlocked,
    required this.levelBefore,
    required this.levelAfter,
    required this.levelUpPoints,
    required this.records,
    required this.streak,
  });

  final GameResult result;
  final int xpFromGame;
  final int pointsFromGame;
  final DailyChallenge? challenge;
  final ChallengeProgress? challengeProgress;
  final bool challengeCompletedNow;
  final List<Achievement> unlocked;
  final LevelInfo levelBefore;
  final LevelInfo levelAfter;
  final int levelUpPoints;
  final NewRecords records;

  /// Série de victoires actuelle dans le mode.
  final int streak;

  int get xpFromChallenge => challengeCompletedNow ? challenge!.rewardXp : 0;
  int get pointsFromChallenge =>
      challengeCompletedNow ? challenge!.rewardPoints : 0;
  int get xpFromAchievements => unlocked.fold(0, (s, a) => s + a.rewardXp);
  int get pointsFromAchievements =>
      unlocked.fold(0, (s, a) => s + a.rewardPoints);

  int get totalXp => xpFromGame + xpFromChallenge + xpFromAchievements;
  int get totalPoints =>
      pointsFromGame +
      pointsFromChallenge +
      pointsFromAchievements +
      levelUpPoints;
  int get levelsGained => levelAfter.level - levelBefore.level;
}

/// Orchestration de fin de partie : score, statistiques, XP, points,
/// défis et succès. Fonction pure : facile à tester.
abstract final class GameCompletion {
  /// Construit le résultat d'une session commencée.
  static GameResult resultOf(
    GameSession session,
    Profile profile, {
    required bool won,
    required DateTime now,
  }) {
    final previousStreak = profile.stats.of(session.mode).currentStreak;
    return GameResult(
      mode: session.mode,
      seed: session.seed,
      won: won,
      score: ScoreCalculator.compute(
        mode: session.mode,
        won: won,
        gamePoints: session.state.points,
        elapsedMs: session.elapsedMs,
        moves: session.moveCount,
        previousStreak: previousStreak,
      ),
      elapsedMs: session.elapsedMs,
      moves: session.moveCount,
      hints: session.hintsUsed,
      assistedMoves: session.assistedMovesUsed,
      undos: session.undoCount,
      finishedAt: now,
      challengeId: session.challengeId,
    );
  }

  /// Applique le résultat au profil. Une session jamais commencée ne doit
  /// pas être transmise ici (voir [GameSession.started]).
  static (Profile, GameReport) apply(Profile profile, GameResult result) {
    final levelBefore = profile.progress.levelInfo;

    // 1. Statistiques.
    var (stats, records) = profile.stats.record(result);

    // 2. Défi quotidien.
    var dailies = profile.dailies;
    DailyChallenge? challenge;
    var challengeDone = false;
    if (result.challengeId != null) {
      challenge = DailyChallengeGenerator.byId(result.challengeId!);
      if (challenge != null) {
        (dailies, challengeDone) = dailies.recordAttempt(challenge, result);
        if (challengeDone) stats = stats.withChallengeSucceeded();
      }
    }

    // 3. XP et points de la partie (et du défi).
    final xpGame = XpRules.forGame(result);
    final pointsGame = PointsRules.forGame(result);
    var progress = profile.progress.addXp(
      xpGame + (challengeDone ? challenge!.rewardXp : 0),
    );
    var wallet = profile.wallet.credit(
      pointsGame + (challengeDone ? challenge!.rewardPoints : 0),
    );
    var inventory = profile.inventory;

    // 4. Succès.
    final unlockedState = _unlock(
      _Rewards(progress, wallet, inventory, {...profile.achievements}),
      stats: stats,
      dailies: dailies,
      result: result,
      now: result.finishedAt,
    );
    final unlocked = unlockedState.unlocked;
    progress = unlockedState.rewards.progress;
    wallet = unlockedState.rewards.wallet;
    inventory = unlockedState.rewards.inventory;
    final achievements = unlockedState.rewards.achievements;

    // 5. Points de montée de niveau.
    final levelAfter = progress.levelInfo;
    final levelUpPoints =
        (levelAfter.level - levelBefore.level) * PointsRules.perLevelUp;
    wallet = wallet.credit(levelUpPoints);

    final earned = wallet.balance - profile.wallet.balance;
    stats = stats.withPointsEarned(earned);

    final report = GameReport(
      result: result,
      xpFromGame: xpGame,
      pointsFromGame: pointsGame,
      challenge: challenge,
      challengeProgress: challenge == null ? null : dailies.of(challenge.id),
      challengeCompletedNow: challengeDone,
      unlocked: unlocked,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      levelUpPoints: levelUpPoints,
      records: records,
      streak: stats.of(result.mode).currentStreak,
    );
    return (
      profile.copyWith(
        stats: stats,
        progress: progress,
        wallet: wallet,
        inventory: inventory,
        achievements: achievements,
        dailies: dailies,
      ),
      report,
    );
  }

  /// Vérifie les succès hors partie (ex. après un achat).
  static (Profile, List<Achievement>) checkAchievements(
    Profile profile,
    DateTime now,
  ) {
    final out = _unlock(
      _Rewards(profile.progress, profile.wallet, profile.inventory, {
        ...profile.achievements,
      }),
      stats: profile.stats,
      dailies: profile.dailies,
      result: null,
      now: now,
    );
    if (out.unlocked.isEmpty) return (profile, const []);
    var wallet = out.rewards.wallet;
    final levelUps = out.rewards.progress.level - profile.progress.level;
    wallet = wallet.credit(levelUps * PointsRules.perLevelUp);
    return (
      profile.copyWith(
        progress: out.rewards.progress,
        wallet: wallet,
        inventory: out.rewards.inventory,
        achievements: out.rewards.achievements,
        stats: profile.stats.withPointsEarned(
          wallet.balance - profile.wallet.balance,
        ),
      ),
      out.unlocked,
    );
  }

  /// Débloque en boucle : un succès peut faire monter de niveau et donc
  /// débloquer un succès de niveau.
  static ({_Rewards rewards, List<Achievement> unlocked}) _unlock(
    _Rewards start, {
    required Statistics stats,
    required DailyChallengeLog dailies,
    required GameResult? result,
    required DateTime now,
  }) {
    var r = start;
    final unlocked = <Achievement>[];
    var changed = true;
    while (changed) {
      changed = false;
      final ctx = AchievementContext(
        stats: stats,
        progress: r.progress,
        dailies: dailies,
        inventory: r.inventory,
        lastResult: result,
      );
      for (final a in AchievementCatalog.all) {
        if (r.achievements.containsKey(a.id) || !a.isReached(ctx)) continue;
        r.achievements[a.id] = now;
        unlocked.add(a);
        r = _Rewards(
          r.progress.addXp(a.rewardXp),
          r.wallet.credit(a.rewardPoints),
          a.rewardItem == null ? r.inventory : r.inventory.grant(a.rewardItem!),
          r.achievements,
        );
        changed = true;
      }
    }
    return (rewards: r, unlocked: unlocked);
  }
}

final class _Rewards {
  _Rewards(this.progress, this.wallet, this.inventory, this.achievements);

  final PlayerProgress progress;
  final Wallet wallet;
  final Inventory inventory;
  final Map<String, DateTime> achievements;
}
