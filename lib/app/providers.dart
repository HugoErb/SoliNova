import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../data/storage.dart';
import '../engine/game_result.dart';
import '../engine/session/game_session.dart';
import '../meta/achievements/achievements.dart';
import '../meta/profile/game_completion.dart';
import '../meta/profile/profile.dart';
import '../meta/settings/settings.dart';
import '../meta/shop/inventory.dart';
import '../meta/shop/shop_item.dart';
import '../ui/feedback/feedback_service.dart';
import '../ui/theme/look.dart';

/// Stockage local (surchargé au démarrage).
final storeProvider = Provider<KeyValueStore>((ref) => MemoryStore());

/// Données chargées au démarrage (surchargées dans `main`).
final initialProfileProvider = Provider<Profile>((ref) => const Profile());
final initialSessionProvider = Provider<GameSession?>((ref) => null);

final feedbackProvider = Provider<FeedbackService>((ref) => FeedbackService());

/// Profil du joueur : statistiques, progression, boutique, paramètres.
final profileProvider = NotifierProvider<ProfileController, Profile>(
  ProfileController.new,
);

class ProfileController extends Notifier<Profile> {
  DebouncedSaver<Profile>? _saver;

  @override
  Profile build() {
    final repo = ProfileRepository(ref.read(storeProvider));
    final saver = DebouncedSaver<Profile>(repo.save);
    _saver = saver;
    ref.onDispose(() => unawaited(saver.flush()));
    final profile = ref.read(initialProfileProvider);
    _syncFeedback(profile.settings);
    return profile;
  }

  void _set(Profile p) {
    state = p;
    _saver?.schedule(p);
    _syncFeedback(p.settings);
  }

  void _syncFeedback(Settings s) {
    ref.read(feedbackProvider)
      ..soundEnabled = s.sound
      ..masterVolume = s.soundVolume;
  }

  Future<void> flush() => _saver?.flush() ?? Future.value();

  void updateSettings(Settings Function(Settings) change) =>
      _set(state.copyWith(settings: change(state.settings)));

  /// Achat définitif d'un élément de boutique.
  (PurchaseOutcome, List<Achievement>) purchase(String id) {
    final (inventory, wallet, outcome) = state.inventory.purchase(
      id,
      state.wallet,
    );
    if (outcome != PurchaseOutcome.success) return (outcome, const []);
    var next = state.copyWith(inventory: inventory, wallet: wallet);
    final List<Achievement> unlocked;
    (next, unlocked) = GameCompletion.checkAchievements(next, DateTime.now());
    _set(next);
    ref.read(feedbackProvider).emit(FeedbackEvent.purchase);
    return (outcome, unlocked);
  }

  void equip(String id) => _set(state.copyWith(inventory: state.inventory.equip(id)));

  void followTheme(ShopCategory category) =>
      _set(state.copyWith(inventory: state.inventory.followTheme(category)));

  /// Enregistre une partie terminée et renvoie son bilan.
  GameReport recordGame(GameResult result) {
    final (next, report) = GameCompletion.apply(state, result);
    _set(next);
    unawaited(flush());
    return report;
  }
}

/// Luminosité du système (pour les thèmes ayant une variante sombre).
final platformBrightnessProvider =
    NotifierProvider<PlatformBrightness, Brightness>(PlatformBrightness.new);

class PlatformBrightness extends Notifier<Brightness> {
  @override
  Brightness build() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  void set(Brightness b) => state = b;
}

/// Apparence résolue, recalculée seulement si un élément visuel change.
final lookProvider = Provider<Look>((ref) {
  final inventory = ref.watch(profileProvider.select((p) => p.inventory));
  final settings = ref.watch(profileProvider.select((p) => p.settings));
  return Look.resolve(
    inventory: inventory,
    settings: settings,
    platformBrightness: ref.watch(platformBrightnessProvider),
  );
});

final settingsProvider = Provider<Settings>(
  (ref) => ref.watch(profileProvider.select((p) => p.settings)),
);
