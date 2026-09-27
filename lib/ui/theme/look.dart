import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../meta/settings/settings.dart';
import '../../meta/shop/inventory.dart';
import '../../meta/shop/shop_item.dart';
import 'nova_theme.dart';

/// Style des faces de cartes, relié à l'identifiant de la boutique.
enum FaceStyle {
  classic('face.classic'),
  large('face.large'),
  fourColor('face.fourColor'),
  minimal('face.minimal'),
  elegant('face.elegant'),
  solid('face.solid'),
  solidFour('face.solidFour'),
  colored('face.colored'),
  neon('face.neon'),
  retro('face.retro');

  const FaceStyle(this.shopId);

  final String shopId;

  static FaceStyle fromShopId(String? id) =>
      values.where((f) => f.shopId == id).firstOrNull ?? classic;
}

/// Style de mouvement des cartes.
@immutable
final class MotionStyle {
  const MotionStyle({
    required this.move,
    required this.curve,
    this.lift = 0,
  });

  final Duration move;
  final Curve curve;

  /// Élévation visuelle pendant le trajet (0..1).
  final double lift;

  static const smooth = MotionStyle(
    move: Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
  );
  static const snappy = MotionStyle(
    move: Duration(milliseconds: 170),
    curve: Curves.easeOutQuart,
  );
  static const bouncy = MotionStyle(
    move: Duration(milliseconds: 380),
    curve: Curves.easeOutBack,
  );
  static const floaty = MotionStyle(
    move: Duration(milliseconds: 320),
    curve: Curves.easeInOutCubic,
    lift: 1,
  );
}

enum VictoryStyle { cascade, confetti, stars, fireworks }

enum EffectStyle { none, glow, sparkle }

/// Apparence résolue : thème équipé, variantes claire/sombre et éléments
/// cosmétiques choisis. Seule source de vérité visuelle de l'interface.
@immutable
final class Look {
  const Look({
    required this.theme,
    required this.table,
    required this.back,
    required this.faceStyle,
    required this.motion,
    required this.victory,
    required this.effect,
    required this.animationFactor,
  });

  final NovaTheme theme;
  final TableStyle table;
  final CardBackStyle back;
  final FaceStyle faceStyle;
  final MotionStyle motion;
  final VictoryStyle victory;
  final EffectStyle effect;

  /// 0 = animations désactivées.
  final double animationFactor;

  bool get animationsEnabled => animationFactor > 0;

  /// Variante pour les aperçus de la boutique.
  Look copyWith({
    NovaTheme? theme,
    TableStyle? table,
    CardBackStyle? back,
    FaceStyle? faceStyle,
    MotionStyle? motion,
    EffectStyle? effect,
  }) => Look(
    theme: theme ?? this.theme,
    table: table ?? this.table,
    back: back ?? this.back,
    faceStyle: faceStyle ?? this.faceStyle,
    motion: motion ?? this.motion,
    victory: victory,
    effect: effect ?? this.effect,
    animationFactor: animationFactor,
  );

  Duration scaled(Duration d) => Duration(
    microseconds: (d.inMicroseconds * animationFactor).round(),
  );

  static Look resolve({
    required Inventory inventory,
    required Settings settings,
    required Brightness platformBrightness,
  }) {
    var theme = ThemeCatalog.byId(inventory.equippedIn(ShopCategory.theme));
    final variant = theme.variantId == null
        ? null
        : ThemeCatalog.byId(theme.variantId);
    if (variant != null) {
      final wantDark = switch (settings.darkMode) {
        DarkModePreference.system => platformBrightness == Brightness.dark,
        DarkModePreference.light => false,
        DarkModePreference.dark => true,
      };
      if (wantDark != theme.isDark) theme = variant;
    }
    final tableId = inventory.equippedIn(ShopCategory.table);
    final backId = inventory.equippedIn(ShopCategory.cardBack);
    return Look(
      theme: theme,
      table: ThemeCatalog.tables[tableId] ?? theme.table,
      back: ThemeCatalog.backs[backId] ?? theme.back,
      faceStyle: FaceStyle.fromShopId(
        inventory.equippedIn(ShopCategory.cardFace),
      ),
      motion: switch (inventory.equippedIn(ShopCategory.animation)) {
        'anim.snappy' => MotionStyle.snappy,
        'anim.bouncy' => MotionStyle.bouncy,
        'anim.float' => MotionStyle.floaty,
        _ => MotionStyle.smooth,
      },
      victory: switch (inventory.equippedIn(ShopCategory.victory)) {
        'win.confetti' => VictoryStyle.confetti,
        'win.stars' => VictoryStyle.stars,
        'win.fireworks' => VictoryStyle.fireworks,
        _ => VictoryStyle.cascade,
      },
      effect: switch (inventory.equippedIn(ShopCategory.effect)) {
        'fx.glow' => EffectStyle.glow,
        'fx.sparkle' => EffectStyle.sparkle,
        _ => EffectStyle.none,
      },
      animationFactor: settings.animations.factor,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Look &&
      other.theme == theme &&
      other.table == table &&
      other.back == back &&
      other.faceStyle == faceStyle &&
      other.motion == motion &&
      other.victory == victory &&
      other.effect == effect &&
      other.animationFactor == animationFactor;

  @override
  int get hashCode => Object.hash(
    theme,
    table,
    back,
    faceStyle,
    motion,
    victory,
    effect,
    animationFactor,
  );
}
