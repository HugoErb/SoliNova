import '../../engine/game_result.dart';
import '../../engine/model/game_mode.dart';
import '../../engine/rng/seeded_random.dart';
import '../../engine/solver/winnable_deals.dart';
import '../json.dart';

enum ChallengeDifficulty {
  easy('Facile', 40, 30),
  medium('Intermédiaire', 80, 60),
  hard('Difficile', 150, 120);

  const ChallengeDifficulty(this.label, this.rewardXp, this.rewardPoints);

  final String label;
  final int rewardXp;
  final int rewardPoints;
}

/// Contraintes à respecter en plus de la victoire.
final class ChallengeObjective {
  const ChallengeObjective({
    this.maxSeconds,
    this.maxMoves,
    this.noHints = false,
    this.noUndo = false,
  });

  final int? maxSeconds;
  final int? maxMoves;
  final bool noHints;
  final bool noUndo;

  bool isMetBy(GameResult r) =>
      r.won &&
      (maxSeconds == null || r.elapsedMs <= maxSeconds! * 1000) &&
      (maxMoves == null || r.moves <= maxMoves!) &&
      (!noHints || !r.usedAssistance) &&
      (!noUndo || r.undos == 0);

  /// Description lisible : « Gagner en moins de 6 min, sans indice ».
  String describe() {
    final parts = <String>[];
    if (maxSeconds != null) {
      final m = maxSeconds! ~/ 60;
      final s = maxSeconds! % 60;
      parts.add('en moins de ${s == 0 ? '$m min' : '$m min $s s'}');
    }
    if (maxMoves != null) parts.add('en $maxMoves coups maximum');
    if (noHints) parts.add('sans indice');
    if (noUndo) parts.add('sans annuler');
    return parts.isEmpty ? 'Gagner la partie' : 'Gagner ${parts.join(', ')}';
  }
}

/// Défi du jour : mode, donne, objectif et récompense fixés par la date.
final class DailyChallenge {
  const DailyChallenge({
    required this.date,
    required this.difficulty,
    required this.mode,
    required this.seed,
    required this.objective,
  });

  /// Date au format AAAA-MM-JJ (heure locale).
  final String date;
  final ChallengeDifficulty difficulty;
  final GameMode mode;
  final int seed;
  final ChallengeObjective objective;

  String get id => '$date-${mode.name}-${difficulty.name}';
  int get rewardXp => difficulty.rewardXp;
  int get rewardPoints => difficulty.rewardPoints;
}

/// Génération 100 % locale et déterministe des défis d'une journée.
abstract final class DailyChallengeGenerator {
  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Temps limites (secondes) par mode pour les défis chronométrés.
  static const _timeLimits = {
    GameMode.klondike1: 360,
    GameMode.klondike3: 480,
    GameMode.spider1: 540,
    GameMode.spider2: 1080,
    GameMode.spider4: 1800,
    GameMode.freecell: 420,
  };

  /// Nombre de coups maximum par mode pour les défis de précision.
  static const _moveLimits = {
    GameMode.klondike1: 150,
    GameMode.klondike3: 180,
    GameMode.spider1: 220,
    GameMode.spider2: 300,
    GameMode.spider4: 400,
    GameMode.freecell: 120,
  };

  /// Tous les défis d'une journée : trois par mode de jeu.
  static List<DailyChallenge> forDay(DateTime day) => [
    for (final mode in GameMode.values) ...forDayAndMode(day, mode),
  ];

  /// Les trois défis (facile, intermédiaire, difficile) d'un mode.
  static List<DailyChallenge> forDayAndMode(DateTime day, GameMode mode) =>
      _forDate(dateKey(day), mode);

  static List<DailyChallenge> _forDate(String date, GameMode mode) => [
    for (final d in ChallengeDifficulty.values) _make(date, mode, d),
  ];

  static DailyChallenge _make(
    String date,
    GameMode mode,
    ChallengeDifficulty difficulty,
  ) {
    final rng = SeededRandom(
      SeededRandom.hashString('SoliNova|$date|${mode.name}|${difficulty.name}'),
    );
    final objective = switch (difficulty) {
      ChallengeDifficulty.easy => const ChallengeObjective(),
      ChallengeDifficulty.medium => switch (rng.nextInt(3)) {
        0 => ChallengeObjective(maxSeconds: _timeLimits[mode]),
        1 => ChallengeObjective(maxMoves: _moveLimits[mode]),
        _ => const ChallengeObjective(noHints: true),
      },
      ChallengeDifficulty.hard => switch (rng.nextInt(3)) {
        0 => ChallengeObjective(
          maxSeconds: _timeLimits[mode]! * 3 ~/ 4,
          noHints: true,
        ),
        1 => ChallengeObjective(maxMoves: _moveLimits[mode], noUndo: true),
        _ => const ChallengeObjective(noHints: true, noUndo: true),
      },
    };
    // Donne gagnable choisie par date + mode + difficulté.
    final seed = WinnableDeals.seedFor(
      mode,
      SeededRandom.hashString('deal|$date|${mode.name}|${difficulty.name}'),
    );
    return DailyChallenge(
      date: date,
      difficulty: difficulty,
      mode: mode,
      seed: seed,
      objective: objective,
    );
  }

  /// Retrouve un défi à partir de son identifiant
  /// (`AAAA-MM-JJ-mode-difficulté`).
  static DailyChallenge? byId(String id) {
    if (id.length < 12) return null;
    final date = id.substring(0, 10);
    final parts = id.substring(11).split('-');
    if (parts.length != 2 || DateTime.tryParse(date) == null) return null;
    final mode = GameMode.tryParse(parts[0]);
    final diff = ChallengeDifficulty.values
        .where((d) => d.name == parts[1])
        .firstOrNull;
    if (mode == null || diff == null) return null;
    return _forDate(date, mode)[diff.index];
  }
}

enum ChallengeStatus { notStarted, inProgress, succeeded }

/// Suivi d'un défi : tentatives et réussite.
final class ChallengeProgress {
  const ChallengeProgress({
    this.attempts = 0,
    this.succeeded = false,
    this.bestTimeMs,
  });

  final int attempts;
  final bool succeeded;
  final int? bestTimeMs;

  ChallengeStatus get status => succeeded
      ? ChallengeStatus.succeeded
      : (attempts > 0
            ? ChallengeStatus.inProgress
            : ChallengeStatus.notStarted);

  Json toJson() => {'a': attempts, 's': succeeded, 'b': bestTimeMs};

  static ChallengeProgress fromJson(Json j) => ChallengeProgress(
    attempts: readInt(j, 'a'),
    succeeded: readBool(j, 's', false),
    bestTimeMs: readIntOrNull(j, 'b'),
  );
}

/// Historique des défis, indexé par identifiant de défi.
final class DailyChallengeLog {
  const DailyChallengeLog([this.entries = const {}]);

  static const keepDays = 30;

  final Map<String, ChallengeProgress> entries;

  ChallengeProgress of(String id) => entries[id] ?? const ChallengeProgress();

  int get totalSucceeded => entries.values.where((e) => e.succeeded).length;

  /// Défis réussis à [date], éventuellement limités à un [mode].
  int succeededOn(String date, [GameMode? mode]) => entries.entries
      .where(
        (e) =>
            e.key.startsWith(mode == null ? date : '$date-${mode.name}-') &&
            e.value.succeeded,
      )
      .length;

  bool hardSucceeded() => entries.entries.any(
    (e) =>
        e.key.endsWith('-${ChallengeDifficulty.hard.name}') &&
        e.value.succeeded,
  );

  /// Enregistre une tentative terminée. Renvoie aussi si le défi vient
  /// d'être réussi pour la première fois (récompense unique).
  (DailyChallengeLog, bool) recordAttempt(
    DailyChallenge challenge,
    GameResult r,
  ) {
    final before = of(challenge.id);
    final success = challenge.objective.isMetBy(r);
    final firstSuccess = success && !before.succeeded;
    final best = r.won
        ? (before.bestTimeMs == null || r.elapsedMs < before.bestTimeMs!
              ? r.elapsedMs
              : before.bestTimeMs)
        : before.bestTimeMs;
    final updated = ChallengeProgress(
      attempts: before.attempts + 1,
      succeeded: before.succeeded || success,
      bestTimeMs: best,
    );
    return (
      DailyChallengeLog({...entries, challenge.id: updated})
          ._pruned(r.finishedAt),
      firstSuccess,
    );
  }

  DailyChallengeLog _pruned(DateTime now) {
    final limit = DailyChallengeGenerator.dateKey(
      now.subtract(const Duration(days: keepDays)),
    );
    return DailyChallengeLog({
      for (final e in entries.entries)
        if (e.key.compareTo(limit) >= 0) e.key: e.value,
    });
  }

  Json toJson() => {for (final e in entries.entries) e.key: e.value.toJson()};

  static DailyChallengeLog fromJson(Json j) => DailyChallengeLog({
    for (final e in j.entries)
      if (e.value is Map)
        e.key: ChallengeProgress.fromJson(
          (e.value! as Map).cast<String, Object?>(),
        ),
  });
}
