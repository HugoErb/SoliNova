import 'dart:math' as math;

import '../model/game_mode.dart';
import '../rng/seeded_random.dart';
import 'winnable_seeds.g.dart';

/// Donnes dont une solution a été trouvée et vérifiée hors ligne
/// (`tool/generate_deals.dart`). Les solutions sont livrées dans
/// `assets/deals/<mode>.txt`.
abstract final class WinnableDeals {
  static List<int> seedsOf(GameMode mode) => winnableSeeds[mode] ?? const [];

  /// Donne gagnable tirée au hasard.
  static int randomSeed(GameMode mode) {
    final seeds = seedsOf(mode);
    if (seeds.isEmpty) return SeededRandom.randomSeed();
    return seeds[math.Random().nextInt(seeds.length)];
  }

  /// Donne gagnable déterminée par [hash] (défis quotidiens).
  static int seedFor(GameMode mode, int hash) {
    final seeds = seedsOf(mode);
    if (seeds.isEmpty) return hash == 0 ? 1 : hash;
    return seeds[hash % seeds.length];
  }
}
