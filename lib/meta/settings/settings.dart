import '../json.dart';

/// Préférence de luminosité, appliquée si le thème propose les deux variantes.
enum DarkModePreference {
  system('Selon le système'),
  light('Clair'),
  dark('Sombre');

  const DarkModePreference(this.label);
  final String label;
}

/// Vitesse des animations (1.0 = normale).
enum AnimationSpeed {
  off('Désactivées', 0),
  fast('Rapides', 0.6),
  normal('Normales', 1);

  const AnimationSpeed(this.label, this.factor);
  final String label;
  final double factor;
}

/// Paramètres du joueur.
final class Settings {
  const Settings({
    this.sound = true,
    this.soundVolume = 0.7,
    this.animations = AnimationSpeed.normal,
    this.autoMove = true,
    this.tapToMove = true,
    this.darkMode = DarkModePreference.system,
    this.showScore = true,
    this.showTimer = true,
    this.confirmAbandon = true,
  });

  final bool sound;

  /// Volume des effets sonores (0..1).
  final double soundVolume;
  final AnimationSpeed animations;

  /// Envoie automatiquement en fondation les cartes qui ne servent plus.
  final bool autoMove;

  /// Un toucher simple joue le meilleur coup (sinon : double toucher
  /// vers la fondation uniquement).
  final bool tapToMove;
  final DarkModePreference darkMode;
  final bool showScore;
  final bool showTimer;
  final bool confirmAbandon;

  Settings copyWith({
    bool? sound,
    double? soundVolume,
    AnimationSpeed? animations,
    bool? autoMove,
    bool? tapToMove,
    DarkModePreference? darkMode,
    bool? showScore,
    bool? showTimer,
    bool? confirmAbandon,
  }) => Settings(
    sound: sound ?? this.sound,
    soundVolume: soundVolume ?? this.soundVolume,
    animations: animations ?? this.animations,
    autoMove: autoMove ?? this.autoMove,
    tapToMove: tapToMove ?? this.tapToMove,
    darkMode: darkMode ?? this.darkMode,
    showScore: showScore ?? this.showScore,
    showTimer: showTimer ?? this.showTimer,
    confirmAbandon: confirmAbandon ?? this.confirmAbandon,
  );

  Json toJson() => {
    'sound': sound,
    'soundVolume': soundVolume,
    'animations': animations.name,
    'autoMove': autoMove,
    'tapToMove': tapToMove,
    'darkMode': darkMode.name,
    'showScore': showScore,
    'showTimer': showTimer,
    'confirmAbandon': confirmAbandon,
  };

  static Settings fromJson(Json j) {
    const d = Settings();
    return Settings(
      sound: readBool(j, 'sound', d.sound),
      soundVolume: _volume(j['soundVolume'], d.soundVolume),
      animations: readEnum(
        j,
        'animations',
        AnimationSpeed.values,
        d.animations,
      ),
      autoMove: readBool(j, 'autoMove', d.autoMove),
      tapToMove: readBool(j, 'tapToMove', d.tapToMove),
      darkMode: readEnum(
        j,
        'darkMode',
        DarkModePreference.values,
        d.darkMode,
      ),
      showScore: readBool(j, 'showScore', d.showScore),
      showTimer: readBool(j, 'showTimer', d.showTimer),
      confirmAbandon: readBool(j, 'confirmAbandon', d.confirmAbandon),
    );
  }

  static double _volume(Object? v, double fallback) =>
      v is num ? v.toDouble().clamp(0.0, 1.0) : fallback;
}
