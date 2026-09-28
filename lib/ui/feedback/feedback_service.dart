import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Événements sonores. SoliNova n'utilise aucune vibration.
enum FeedbackEvent {
  move('move', 0.45),
  flip('flip', 0.4),
  deal('deal', 0.3),
  invalid('invalid', 0.35),
  foundation('foundation', 0.3),
  win('win', 0.45),
  purchase('purchase', 0.4),
  levelUp('level_up', 0.45),
  achievement('achievement', 0.4);

  const FeedbackEvent(this.file, this.volume);
  final String file;

  /// Volume relatif du son, multiplié par le volume choisi par le joueur.
  final double volume;
}

/// Effets sonores discrets, réglables dans les paramètres.
class FeedbackService {
  FeedbackService();

  bool soundEnabled = true;
  double masterVolume = 0.7;

  final Map<FeedbackEvent, AudioPool> _pools = {};
  bool _loading = false;
  DateTime _lastDeal = DateTime.fromMillisecondsSinceEpoch(0);

  /// Précharge les sons en arrière-plan (ne ralentit pas le démarrage).
  Future<void> preload() async {
    if (_loading) return;
    _loading = true;
    for (final e in FeedbackEvent.values) {
      try {
        _pools[e] = await AudioPool.createFromAsset(
          path: 'sounds/${e.file}.wav',
          maxPlayers: e == FeedbackEvent.move || e == FeedbackEvent.deal
              ? 4
              : 2,
        );
      } on Object catch (error) {
        debugPrint('Son indisponible (${e.file}) : $error');
      }
    }
  }

  void emit(FeedbackEvent event) {
    if (!soundEnabled || masterVolume <= 0) return;
    if (event == FeedbackEvent.deal) {
      // Limite la cadence pendant la distribution.
      final now = DateTime.now();
      if (now.difference(_lastDeal).inMilliseconds < 45) return;
      _lastDeal = now;
    }
    final pool = _pools[event];
    if (pool == null) return;
    unawaited(
      pool
          .start(volume: event.volume * masterVolume)
          .then((_) {}, onError: (Object _) {}),
    );
  }
}
