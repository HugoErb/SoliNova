import '../../engine/game_result.dart';
import '../../engine/model/game_mode.dart';
import '../daily/daily_challenge.dart';
import '../progression/player_progress.dart';
import '../shop/inventory.dart';
import '../stats/statistics.dart';

/// Rang du badge associé à un succès.
enum BadgeTier {
  bronze('Bronze'),
  silver('Argent'),
  gold('Or');

  const BadgeTier(this.label);
  final String label;
}

/// Données disponibles pour évaluer les succès.
final class AchievementContext {
  const AchievementContext({
    required this.stats,
    required this.progress,
    required this.dailies,
    required this.inventory,
    this.lastResult,
  });

  final Statistics stats;
  final PlayerProgress progress;
  final DailyChallengeLog dailies;
  final Inventory inventory;
  final GameResult? lastResult;
}

/// Définition d'un succès : condition, objectif chiffré et récompenses.
final class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.target,
    required this.measure,
    this.rewardXp = 0,
    this.rewardPoints = 0,
    this.rewardItem,
  });

  final String id;
  final String title;
  final String description;
  final BadgeTier tier;

  /// Valeur à atteindre.
  final int target;

  /// Valeur actuelle de la progression vers [target].
  final int Function(AchievementContext) measure;

  final int rewardXp;
  final int rewardPoints;

  /// Élément cosmétique offert, s'il y en a un.
  final String? rewardItem;

  int progressOf(AchievementContext ctx) {
    final v = measure(ctx);
    return v > target ? target : v;
  }

  bool isReached(AchievementContext ctx) => measure(ctx) >= target;
}

int _event(AchievementContext ctx, bool Function(GameResult r) test) {
  final r = ctx.lastResult;
  return r != null && r.won && test(r) ? 1 : 0;
}

/// Liste des succès de SoliNova.
abstract final class AchievementCatalog {
  static final List<Achievement> all = [
    Achievement(
      id: 'first_win',
      title: 'Première victoire',
      description: 'Gagner une partie.',
      tier: BadgeTier.bronze,
      target: 1,
      measure: (c) => c.stats.global.wins,
      rewardXp: 20,
      rewardPoints: 20,
    ),
    Achievement(
      id: 'wins_10',
      title: 'Habitué',
      description: 'Gagner 10 parties.',
      tier: BadgeTier.bronze,
      target: 10,
      measure: (c) => c.stats.global.wins,
      rewardXp: 50,
      rewardPoints: 50,
    ),
    Achievement(
      id: 'wins_50',
      title: 'Confirmé',
      description: 'Gagner 50 parties.',
      tier: BadgeTier.silver,
      target: 50,
      measure: (c) => c.stats.global.wins,
      rewardXp: 150,
      rewardPoints: 150,
    ),
    Achievement(
      id: 'wins_100',
      title: 'Expert',
      description: 'Gagner 100 parties.',
      tier: BadgeTier.gold,
      target: 100,
      measure: (c) => c.stats.global.wins,
      rewardXp: 300,
      rewardPoints: 300,
      rewardItem: 'back.geo',
    ),
    Achievement(
      id: 'wins_500',
      title: 'Légende',
      description: 'Gagner 500 parties.',
      tier: BadgeTier.gold,
      target: 500,
      measure: (c) => c.stats.global.wins,
      rewardXp: 1000,
      rewardPoints: 1000,
    ),
    Achievement(
      id: 'no_hint',
      title: 'Autonome',
      description: 'Gagner une partie sans utiliser d\'indice.',
      tier: BadgeTier.bronze,
      target: 1,
      measure: (c) => _event(c, (r) => r.hints == 0),
      rewardXp: 30,
      rewardPoints: 30,
    ),
    Achievement(
      id: 'purist',
      title: 'Puriste',
      description: 'Gagner sans indice et sans annuler.',
      tier: BadgeTier.silver,
      target: 1,
      measure: (c) => _event(c, (r) => r.hints == 0 && r.undos == 0),
      rewardXp: 60,
      rewardPoints: 60,
    ),
    Achievement(
      id: 'streak_5',
      title: 'Sur la lancée',
      description: 'Enchaîner 5 victoires.',
      tier: BadgeTier.silver,
      target: 5,
      measure: (c) => c.stats.global.longestStreak,
      rewardXp: 80,
      rewardPoints: 80,
    ),
    Achievement(
      id: 'streak_10',
      title: 'Inarrêtable',
      description: 'Enchaîner 10 victoires.',
      tier: BadgeTier.gold,
      target: 10,
      measure: (c) => c.stats.global.longestStreak,
      rewardXp: 200,
      rewardPoints: 200,
      rewardItem: 'back.waves',
    ),
    Achievement(
      id: 'fast_win',
      title: 'Éclair',
      description: 'Gagner un Klondike en moins de 3 minutes.',
      tier: BadgeTier.silver,
      target: 1,
      measure: (c) => _event(
        c,
        (r) => r.mode.family == GameFamily.klondike && r.elapsedMs < 180000,
      ),
      rewardXp: 60,
      rewardPoints: 60,
    ),
    Achievement(
      id: 'few_moves',
      title: 'Économe',
      description: 'Gagner un Klondike en 100 coups ou moins.',
      tier: BadgeTier.silver,
      target: 1,
      measure: (c) => _event(
        c,
        (r) => r.mode.family == GameFamily.klondike && r.moves <= 100,
      ),
      rewardXp: 60,
      rewardPoints: 60,
    ),
    Achievement(
      id: 'high_score',
      title: 'Virtuose',
      description: 'Obtenir un score de 2 500 ou plus.',
      tier: BadgeTier.gold,
      target: 1,
      measure: (c) => _event(c, (r) => r.score.total >= 2500),
      rewardXp: 100,
      rewardPoints: 100,
    ),
    Achievement(
      id: 'spider4',
      title: 'Tisseur',
      description: 'Gagner un Spider 4 couleurs.',
      tier: BadgeTier.gold,
      target: 1,
      measure: (c) => c.stats.of(GameMode.spider4).wins,
      rewardXp: 150,
      rewardPoints: 150,
    ),
    Achievement(
      id: 'all_modes',
      title: 'Polyvalent',
      description: 'Gagner au moins une fois dans chaque mode.',
      tier: BadgeTier.silver,
      target: GameMode.values.length,
      measure: (c) =>
          GameMode.values.where((m) => c.stats.of(m).wins > 0).length,
      rewardXp: 150,
      rewardPoints: 150,
    ),
    for (final mode in GameMode.values)
      Achievement(
        id: 'master_${mode.name}',
        title: 'Maîtrise : ${mode.fullName}',
        description: 'Gagner 25 parties en ${mode.fullName}.',
        tier: BadgeTier.gold,
        target: 25,
        measure: (c) => c.stats.of(mode).wins,
        rewardXp: 200,
        rewardPoints: 200,
      ),
    Achievement(
      id: 'daily_1',
      title: 'Premier défi',
      description: 'Réussir un défi quotidien.',
      tier: BadgeTier.bronze,
      target: 1,
      measure: (c) => c.stats.challengesSucceeded,
      rewardXp: 30,
      rewardPoints: 30,
    ),
    Achievement(
      id: 'daily_10',
      title: 'Assidu',
      description: 'Réussir 10 défis quotidiens.',
      tier: BadgeTier.silver,
      target: 10,
      measure: (c) => c.stats.challengesSucceeded,
      rewardXp: 120,
      rewardPoints: 120,
    ),
    Achievement(
      id: 'daily_30',
      title: 'Incontournable',
      description: 'Réussir 30 défis quotidiens.',
      tier: BadgeTier.gold,
      target: 30,
      measure: (c) => c.stats.challengesSucceeded,
      rewardXp: 300,
      rewardPoints: 300,
      rewardItem: 'fx.sparkle',
    ),
    Achievement(
      id: 'daily_hard',
      title: 'Téméraire',
      description: 'Réussir un défi Difficile.',
      tier: BadgeTier.silver,
      target: 1,
      measure: (c) => c.dailies.hardSucceeded() ? 1 : 0,
      rewardXp: 100,
      rewardPoints: 100,
    ),
    Achievement(
      id: 'daily_trio',
      title: 'Journée parfaite',
      description: 'Réussir les trois défis d\'une même journée.',
      tier: BadgeTier.gold,
      target: 3,
      measure: (c) {
        final r = c.lastResult;
        final id = r?.challengeId;
        if (id == null) return 0;
        return c.dailies.succeededOn(id.substring(0, 10));
      },
      rewardXp: 150,
      rewardPoints: 150,
    ),
    Achievement(
      id: 'level_10',
      title: 'Niveau 10',
      description: 'Atteindre le niveau 10.',
      tier: BadgeTier.bronze,
      target: 10,
      measure: (c) => c.progress.level,
      rewardPoints: 100,
    ),
    Achievement(
      id: 'level_25',
      title: 'Niveau 25',
      description: 'Atteindre le niveau 25.',
      tier: BadgeTier.silver,
      target: 25,
      measure: (c) => c.progress.level,
      rewardPoints: 250,
    ),
    Achievement(
      id: 'level_50',
      title: 'Niveau 50',
      description: 'Atteindre le niveau 50.',
      tier: BadgeTier.gold,
      target: 50,
      measure: (c) => c.progress.level,
      rewardPoints: 500,
    ),
    Achievement(
      id: 'collector',
      title: 'Collectionneur',
      description: 'Posséder 5 éléments achetés en boutique.',
      tier: BadgeTier.silver,
      target: 5,
      measure: (c) => c.inventory.owned.length,
      rewardPoints: 150,
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
