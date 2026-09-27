import '../daily/daily_challenge.dart';
import '../economy/wallet.dart';
import '../json.dart';
import '../progression/player_progress.dart';
import '../settings/settings.dart';
import '../shop/inventory.dart';
import '../stats/statistics.dart';

/// Toutes les données persistantes du joueur (hors partie en cours).
///
/// Le format JSON est versionné : c'est aussi la base d'un futur
/// export/import de sauvegarde.
final class Profile {
  const Profile({
    this.stats = const Statistics(),
    this.progress = const PlayerProgress(),
    this.wallet = const Wallet(),
    this.inventory = const Inventory(),
    this.achievements = const {},
    this.dailies = const DailyChallengeLog(),
    this.settings = const Settings(),
  });

  static const schemaVersion = 1;

  final Statistics stats;
  final PlayerProgress progress;
  final Wallet wallet;
  final Inventory inventory;

  /// Succès débloqués : identifiant → date de déblocage.
  final Map<String, DateTime> achievements;
  final DailyChallengeLog dailies;
  final Settings settings;

  Profile copyWith({
    Statistics? stats,
    PlayerProgress? progress,
    Wallet? wallet,
    Inventory? inventory,
    Map<String, DateTime>? achievements,
    DailyChallengeLog? dailies,
    Settings? settings,
  }) => Profile(
    stats: stats ?? this.stats,
    progress: progress ?? this.progress,
    wallet: wallet ?? this.wallet,
    inventory: inventory ?? this.inventory,
    achievements: achievements ?? this.achievements,
    dailies: dailies ?? this.dailies,
    settings: settings ?? this.settings,
  );

  Json toJson() => {
    'v': schemaVersion,
    'stats': stats.toJson(),
    'progress': progress.toJson(),
    'wallet': wallet.toJson(),
    'inventory': inventory.toJson(),
    'achievements': {
      for (final e in achievements.entries)
        e.key: e.value.toIso8601String(),
    },
    'dailies': dailies.toJson(),
    'settings': settings.toJson(),
  };

  static Profile fromJson(Json j) {
    final ach = <String, DateTime>{};
    readMap(j, 'achievements').forEach((k, v) {
      final date = v is String ? DateTime.tryParse(v) : null;
      if (date != null) ach[k] = date;
    });
    return Profile(
      stats: Statistics.fromJson(readMap(j, 'stats')),
      progress: PlayerProgress.fromJson(readMap(j, 'progress')),
      wallet: Wallet.fromJson(readMap(j, 'wallet')),
      inventory: Inventory.fromJson(readMap(j, 'inventory')),
      achievements: ach,
      dailies: DailyChallengeLog.fromJson(readMap(j, 'dailies')),
      settings: Settings.fromJson(readMap(j, 'settings')),
    );
  }
}
