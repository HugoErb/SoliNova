import 'package:flutter/material.dart';

/// Motif léger appliqué au tapis.
enum TablePattern { none, grain, dots, lines, vignette }

/// Symboles des thèmes saisonniers et de fêtes (dos de cartes et tapis).
enum Motif { blossom, sun, leaf, snowflake, tree, pumpkin, heart, egg }

/// Décor du tapis de jeu.
@immutable
final class TableStyle {
  const TableStyle({
    required this.center,
    required this.edge,
    this.pattern = TablePattern.grain,
    this.patternOpacity = 0.05,
    this.motif,
    this.motifOpacity = 0.07,
  });

  final Color center;
  final Color edge;
  final TablePattern pattern;
  final double patternOpacity;

  /// Symbole semé discrètement sur le tapis, en plus du motif.
  final Motif? motif;
  final double motifOpacity;
}

/// Motifs de dos de cartes.
enum BackPattern { nova, lines, dots, waves, diamonds, gold, motif }

@immutable
final class CardBackStyle {
  const CardBackStyle({
    required this.pattern,
    required this.base,
    required this.ink,
    this.motif,
  }) : assert(pattern != BackPattern.motif || motif != null);

  final BackPattern pattern;
  final Color base;
  final Color ink;

  /// Symbole dessiné quand [pattern] vaut [BackPattern.motif].
  final Motif? motif;
}

/// Couleurs des faces de cartes.
@immutable
final class CardFacePalette {
  const CardFacePalette({
    required this.paper,
    required this.black,
    required this.red,
    this.edge = const Color(0x1A000000),
  });

  final Color paper;
  final Color black;
  final Color red;
  final Color edge;
}

/// Thème SoliNova : ambiance complète, indépendante du moteur de jeu.
@immutable
final class NovaTheme {
  const NovaTheme({
    required this.id,
    required this.brightness,
    required this.table,
    required this.back,
    required this.face,
    required this.surface,
    required this.surfaceHigh,
    required this.onSurface,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.slot,
    required this.highlight,
    required this.danger,
    this.animatedTable = false,
    this.variantId,
  });

  final String id;
  final Brightness brightness;
  final TableStyle table;
  final CardBackStyle back;
  final CardFacePalette face;

  /// Surfaces d'interface posées sur le tapis (feuilles, barres).
  final Color surface;
  final Color surfaceHigh;
  final Color onSurface;
  final Color muted;
  final Color accent;
  final Color onAccent;

  /// Contour des emplacements vides.
  final Color slot;

  /// Surbrillance d'indice et de sélection.
  final Color highlight;
  final Color danger;

  /// Tapis au dégradé animé (thème Aurore).
  final bool animatedTable;

  /// Identifiant de la variante claire/sombre, si le thème en possède une.
  final String? variantId;

  bool get isDark => brightness == Brightness.dark;

  ThemeData toMaterial() {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceHigh,
      onSurfaceVariant: muted,
      outline: muted.withValues(alpha: 0.4),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Manrope',
      brightness: brightness,
      scaffoldBackgroundColor: table.edge,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
        fontFamily: 'Manrope',
      ),
      dividerColor: muted.withValues(alpha: 0.15),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(
          color: onSurface,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onAccent : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent
              : muted.withValues(alpha: 0.2),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

const _porcelain = CardFacePalette(
  paper: Color(0xFFF6F7F9),
  black: Color(0xFF1B2233),
  red: Color(0xFFC8324A),
);

// Dos saisonniers : utilisés par les thèmes et vendus séparément.
const _backBlossom = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.blossom,
  base: Color(0xFFD9748F),
  ink: Color(0xFFFFF0F4),
);
const _backSun = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.sun,
  base: Color(0xFF0E5D73),
  ink: Color(0xFFFFD166),
);
const _backLeaf = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.leaf,
  base: Color(0xFF6B2E12),
  ink: Color(0xFFF29A4A),
);
const _backSnowflake = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.snowflake,
  base: Color(0xFF2C5A85),
  ink: Color(0xFFE8F4FF),
);
const _backTree = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.tree,
  base: Color(0xFFA3202E),
  ink: Color(0xFFF3D27A),
);
const _backPumpkin = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.pumpkin,
  base: Color(0xFF1C1127),
  ink: Color(0xFFFF8A1F),
);
const _backHeart = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.heart,
  base: Color(0xFFC63B62),
  ink: Color(0xFFFFE3EA),
);
const _backEgg = CardBackStyle(
  pattern: BackPattern.motif,
  motif: Motif.egg,
  base: Color(0xFF7FB0DE),
  ink: Color(0xFFFFF6D6),
);

/// Catalogue visuel des thèmes (les identifiants correspondent à la
/// boutique).
abstract final class ThemeCatalog {
  static const emerald = NovaTheme(
    id: 'theme.emerald',
    brightness: Brightness.dark,
    table: TableStyle(center: Color(0xFF12634F), edge: Color(0xFF072A22)),
    back: CardBackStyle(
      pattern: BackPattern.nova,
      base: Color(0xFF0B3B31),
      ink: Color(0xFFE2B659),
    ),
    face: _porcelain,
    surface: Color(0xF2082620),
    surfaceHigh: Color(0xFF123D33),
    onSurface: Color(0xFFF1F5F2),
    muted: Color(0xFFA3BDB4),
    accent: Color(0xFFE2B659),
    onAccent: Color(0xFF231A05),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFD36B),
    danger: Color(0xFFFF7A7A),
  );

  static const midnight = NovaTheme(
    id: 'theme.midnight',
    brightness: Brightness.dark,
    table: TableStyle(center: Color(0xFF1C3A6B), edge: Color(0xFF070F22)),
    back: CardBackStyle(
      pattern: BackPattern.waves,
      base: Color(0xFF14254A),
      ink: Color(0xFF8FB4FF),
    ),
    face: _porcelain,
    surface: Color(0xF20A1430),
    surfaceHigh: Color(0xFF18284D),
    onSurface: Color(0xFFEFF3FF),
    muted: Color(0xFF9DAACB),
    accent: Color(0xFF8FB4FF),
    onAccent: Color(0xFF071230),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFD36B),
    danger: Color(0xFFFF8A8A),
  );

  static const minimal = NovaTheme(
    id: 'theme.minimal',
    brightness: Brightness.light,
    table: TableStyle(
      center: Color(0xFFF4F6F8),
      edge: Color(0xFFDDE2E8),
      pattern: TablePattern.dots,
      patternOpacity: 0.06,
    ),
    back: CardBackStyle(
      pattern: BackPattern.lines,
      base: Color(0xFF2E3A4F),
      ink: Color(0xFFDDE4EE),
    ),
    face: CardFacePalette(
      paper: Color(0xFFFFFFFF),
      black: Color(0xFF1B2233),
      red: Color(0xFFC8324A),
      edge: Color(0x24000000),
    ),
    surface: Color(0xF7FFFFFF),
    surfaceHigh: Color(0xFFE9EDF2),
    onSurface: Color(0xFF1B2233),
    muted: Color(0xFF5E6A7D),
    accent: Color(0xFF2E3A4F),
    onAccent: Color(0xFFFFFFFF),
    slot: Color(0x2E1B2233),
    highlight: Color(0xFFE59A1A),
    danger: Color(0xFFC8324A),
    variantId: 'theme.minimal.dark',
  );

  static const minimalDark = NovaTheme(
    id: 'theme.minimal.dark',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF262B33),
      edge: Color(0xFF15181D),
      pattern: TablePattern.dots,
      patternOpacity: 0.05,
    ),
    back: CardBackStyle(
      pattern: BackPattern.lines,
      base: Color(0xFF3A4556),
      ink: Color(0xFFCBD3DF),
    ),
    face: _porcelain,
    surface: Color(0xF516191E),
    surfaceHigh: Color(0xFF2A3038),
    onSurface: Color(0xFFEDEFF3),
    muted: Color(0xFF9AA3B2),
    accent: Color(0xFFDDE3EC),
    onAccent: Color(0xFF15181D),
    slot: Color(0x2EFFFFFF),
    highlight: Color(0xFFFFC857),
    danger: Color(0xFFFF8A8A),
    variantId: 'theme.minimal',
  );

  static const oled = NovaTheme(
    id: 'theme.oled',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF000000),
      edge: Color(0xFF000000),
      pattern: TablePattern.none,
    ),
    back: CardBackStyle(
      pattern: BackPattern.diamonds,
      base: Color(0xFF15161A),
      ink: Color(0xFF7CF0D4),
    ),
    face: CardFacePalette(
      paper: Color(0xFFE9EBEF),
      black: Color(0xFF101318),
      red: Color(0xFFD02F4A),
    ),
    surface: Color(0xFA000000),
    surfaceHigh: Color(0xFF16171B),
    onSurface: Color(0xFFF2F3F5),
    muted: Color(0xFF8C9099),
    accent: Color(0xFF7CF0D4),
    onAccent: Color(0xFF00241C),
    slot: Color(0x2EFFFFFF),
    highlight: Color(0xFF7CF0D4),
    danger: Color(0xFFFF7A8A),
  );

  static const modern = NovaTheme(
    id: 'theme.modern',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF3A3D44),
      edge: Color(0xFF1C1E22),
      pattern: TablePattern.lines,
      patternOpacity: 0.04,
    ),
    back: CardBackStyle(
      pattern: BackPattern.diamonds,
      base: Color(0xFFFF6F59),
      ink: Color(0xFFFFE3DC),
    ),
    face: CardFacePalette(
      paper: Color(0xFFF7F7F5),
      black: Color(0xFF22252B),
      red: Color(0xFFE5483A),
    ),
    surface: Color(0xF41C1E22),
    surfaceHigh: Color(0xFF34373E),
    onSurface: Color(0xFFF4F4F2),
    muted: Color(0xFFA9ACB3),
    accent: Color(0xFFFF6F59),
    onAccent: Color(0xFF2A0A04),
    slot: Color(0x2EFFFFFF),
    highlight: Color(0xFFFFB86B),
    danger: Color(0xFFFF7A7A),
  );

  static const pastel = NovaTheme(
    id: 'theme.pastel',
    brightness: Brightness.light,
    table: TableStyle(
      center: Color(0xFFE9E3FA),
      edge: Color(0xFFCFE8E0),
      pattern: TablePattern.dots,
      patternOpacity: 0.07,
    ),
    back: CardBackStyle(
      pattern: BackPattern.dots,
      base: Color(0xFFB9A6F2),
      ink: Color(0xFFFFE1CF),
    ),
    face: CardFacePalette(
      paper: Color(0xFFFFFCFA),
      black: Color(0xFF3B3558),
      red: Color(0xFFD9546E),
      edge: Color(0x223B3558),
    ),
    surface: Color(0xF5FFFBFF),
    surfaceHigh: Color(0xFFF0EAFB),
    onSurface: Color(0xFF3B3558),
    muted: Color(0xFF7C7596),
    accent: Color(0xFF7E62D9),
    onAccent: Color(0xFFFFFFFF),
    slot: Color(0x333B3558),
    highlight: Color(0xFFFF9F6E),
    danger: Color(0xFFD9546E),
    variantId: 'theme.pastel.dark',
  );

  static const pastelDark = NovaTheme(
    id: 'theme.pastel.dark',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF3D3560),
      edge: Color(0xFF1E2A33),
      pattern: TablePattern.dots,
      patternOpacity: 0.05,
    ),
    back: CardBackStyle(
      pattern: BackPattern.dots,
      base: Color(0xFF8D78D8),
      ink: Color(0xFFFFE1CF),
    ),
    face: CardFacePalette(
      paper: Color(0xFFFBF8FF),
      black: Color(0xFF3B3558),
      red: Color(0xFFD9546E),
    ),
    surface: Color(0xF5211D33),
    surfaceHigh: Color(0xFF363052),
    onSurface: Color(0xFFF3EFFF),
    muted: Color(0xFFB5ADD3),
    accent: Color(0xFFC4B2FF),
    onAccent: Color(0xFF201646),
    slot: Color(0x2EFFFFFF),
    highlight: Color(0xFFFFB38A),
    danger: Color(0xFFFF8FA3),
    variantId: 'theme.pastel',
  );

  static const wood = NovaTheme(
    id: 'theme.wood',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF7A4A2A),
      edge: Color(0xFF2E1A0E),
      pattern: TablePattern.lines,
      patternOpacity: 0.07,
    ),
    back: CardBackStyle(
      pattern: BackPattern.gold,
      base: Color(0xFF4A2A18),
      ink: Color(0xFFE8C07A),
    ),
    face: CardFacePalette(
      paper: Color(0xFFF8F1E3),
      black: Color(0xFF2B2118),
      red: Color(0xFFB03A2E),
      edge: Color(0x262B2118),
    ),
    surface: Color(0xF4281810),
    surfaceHigh: Color(0xFF4A2F1F),
    onSurface: Color(0xFFF8EEDC),
    muted: Color(0xFFCDB394),
    accent: Color(0xFFE8C07A),
    onAccent: Color(0xFF2B1A08),
    slot: Color(0x33FFE9C7),
    highlight: Color(0xFFFFD27A),
    danger: Color(0xFFFF8A70),
  );

  static const aurora = NovaTheme(
    id: 'theme.aurora',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF2B1D5C),
      edge: Color(0xFF071A24),
      pattern: TablePattern.vignette,
      patternOpacity: 0.3,
    ),
    back: CardBackStyle(
      pattern: BackPattern.nova,
      base: Color(0xFF1E1447),
      ink: Color(0xFF6FF2D8),
    ),
    face: _porcelain,
    surface: Color(0xF20D1030),
    surfaceHigh: Color(0xFF231C4D),
    onSurface: Color(0xFFF0EEFF),
    muted: Color(0xFFA9A3D6),
    accent: Color(0xFF6FF2D8),
    onAccent: Color(0xFF042A22),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFF6FF2D8),
    danger: Color(0xFFFF8FA3),
    animatedTable: true,
  );

  // Saisons.
  static const spring = NovaTheme(
    id: 'theme.spring',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF4E8F6A),
      edge: Color(0xFF1B3A2A),
      motif: Motif.blossom,
    ),
    back: _backBlossom,
    face: _porcelain,
    surface: Color(0xF2173326),
    surfaceHigh: Color(0xFF2A5241),
    onSurface: Color(0xFFF3FAF5),
    muted: Color(0xFFB2CFC0),
    accent: Color(0xFFF6A5C0),
    onAccent: Color(0xFF3A0B1C),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFD6E3),
    danger: Color(0xFFFF8A8A),
  );

  static const summer = NovaTheme(
    id: 'theme.summer',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF1C8FA6),
      edge: Color(0xFF0A3545),
      pattern: TablePattern.none,
      motif: Motif.sun,
      motifOpacity: 0.06,
    ),
    back: _backSun,
    face: _porcelain,
    surface: Color(0xF20A2E3A),
    surfaceHigh: Color(0xFF16495A),
    onSurface: Color(0xFFF0FAFC),
    muted: Color(0xFFA5CBD6),
    accent: Color(0xFFFFD166),
    onAccent: Color(0xFF2E2200),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFE08A),
    danger: Color(0xFFFF8A7A),
  );

  static const autumn = NovaTheme(
    id: 'theme.autumn',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF8A4B22),
      edge: Color(0xFF2E160A),
      motif: Motif.leaf,
    ),
    back: _backLeaf,
    face: CardFacePalette(
      paper: Color(0xFFFAF3E6),
      black: Color(0xFF2B2118),
      red: Color(0xFFB8321E),
      edge: Color(0x262B2118),
    ),
    surface: Color(0xF22A1409),
    surfaceHigh: Color(0xFF4F2A15),
    onSurface: Color(0xFFFBEFE2),
    muted: Color(0xFFD6B79A),
    accent: Color(0xFFF29A4A),
    onAccent: Color(0xFF2E1300),
    slot: Color(0x33FFE9C7),
    highlight: Color(0xFFFFC46B),
    danger: Color(0xFFFF8A70),
  );

  static const winter = NovaTheme(
    id: 'theme.winter',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF5E8DB5),
      edge: Color(0xFF1B3550),
      pattern: TablePattern.none,
      motif: Motif.snowflake,
      motifOpacity: 0.09,
    ),
    back: _backSnowflake,
    face: _porcelain,
    surface: Color(0xF2142C44),
    surfaceHigh: Color(0xFF274A6B),
    onSurface: Color(0xFFF2F8FF),
    muted: Color(0xFFB0C8DE),
    accent: Color(0xFFBFE3FF),
    onAccent: Color(0xFF0B2238),
    slot: Color(0x40FFFFFF),
    highlight: Color(0xFFE4F3FF),
    danger: Color(0xFFFF8A8A),
  );

  // Fêtes.
  static const christmas = NovaTheme(
    id: 'theme.christmas',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF1E6B3A),
      edge: Color(0xFF0A2614),
      motif: Motif.snowflake,
      motifOpacity: 0.08,
    ),
    back: _backTree,
    face: _porcelain,
    surface: Color(0xF20B2414),
    surfaceHigh: Color(0xFF1D4A2C),
    onSurface: Color(0xFFF5F8F2),
    muted: Color(0xFFB7CDB9),
    accent: Color(0xFFE8C45A),
    onAccent: Color(0xFF2A1E02),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFD86B),
    danger: Color(0xFFFF7A7A),
  );

  static const halloween = NovaTheme(
    id: 'theme.halloween',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF3A2352),
      edge: Color(0xFF110A1B),
      pattern: TablePattern.vignette,
      patternOpacity: 0.3,
      motif: Motif.pumpkin,
      motifOpacity: 0.06,
    ),
    back: _backPumpkin,
    face: CardFacePalette(
      paper: Color(0xFFF7F3EC),
      black: Color(0xFF1E1528),
      red: Color(0xFFB8391A),
    ),
    surface: Color(0xF2150D20),
    surfaceHigh: Color(0xFF2F1E42),
    onSurface: Color(0xFFF6F0FF),
    muted: Color(0xFFBBA9D1),
    accent: Color(0xFFFF8A1F),
    onAccent: Color(0xFF2A1200),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFA64D),
    danger: Color(0xFFFF7A7A),
  );

  static const valentine = NovaTheme(
    id: 'theme.valentine',
    brightness: Brightness.dark,
    table: TableStyle(
      center: Color(0xFF8E2344),
      edge: Color(0xFF2E0814),
      motif: Motif.heart,
      motifOpacity: 0.06,
    ),
    back: _backHeart,
    face: _porcelain,
    surface: Color(0xF22A0A16),
    surfaceHigh: Color(0xFF4D1829),
    onSurface: Color(0xFFFFF0F4),
    muted: Color(0xFFE0AFC0),
    accent: Color(0xFFFF8FAB),
    onAccent: Color(0xFF3A0716),
    slot: Color(0x33FFFFFF),
    highlight: Color(0xFFFFC2D1),
    danger: Color(0xFFFFB86B),
  );

  static const easter = NovaTheme(
    id: 'theme.easter',
    brightness: Brightness.light,
    table: TableStyle(
      center: Color(0xFFEAF4DF),
      edge: Color(0xFFC3DDB3),
      pattern: TablePattern.none,
      motif: Motif.egg,
      motifOpacity: 0.08,
    ),
    back: _backEgg,
    face: CardFacePalette(
      paper: Color(0xFFFFFFFF),
      black: Color(0xFF2F3A2C),
      red: Color(0xFFB83A57),
      edge: Color(0x222F3A2C),
    ),
    surface: Color(0xF5FBFFF6),
    surfaceHigh: Color(0xFFE8F2DF),
    onSurface: Color(0xFF2F3A2C),
    muted: Color(0xFF6E7F68),
    accent: Color(0xFF6F9BD1),
    onAccent: Color(0xFFFFFFFF),
    slot: Color(0x332F3A2C),
    highlight: Color(0xFFF2A65A),
    danger: Color(0xFFD14F6B),
  );

  static const all = [
    emerald,
    midnight,
    minimal,
    minimalDark,
    oled,
    modern,
    pastel,
    pastelDark,
    wood,
    aurora,
    spring,
    summer,
    autumn,
    winter,
    christmas,
    halloween,
    valentine,
    easter,
  ];

  static NovaTheme byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return emerald;
  }

  /// Fonds de table vendus séparément.
  static const tables = <String, TableStyle>{
    'table.graphite': TableStyle(
      center: Color(0xFF45484F),
      edge: Color(0xFF1B1D21),
    ),
    'table.sand': TableStyle(
      center: Color(0xFFC9B08A),
      edge: Color(0xFF7D6446),
      patternOpacity: 0.08,
    ),
    'table.slate': TableStyle(
      center: Color(0xFF4F6275),
      edge: Color(0xFF1D2733),
      pattern: TablePattern.lines,
      patternOpacity: 0.05,
    ),
    'table.velvet': TableStyle(
      center: Color(0xFF7A1F35),
      edge: Color(0xFF2A0812),
      pattern: TablePattern.vignette,
      patternOpacity: 0.35,
    ),
    'table.ocean': TableStyle(
      center: Color(0xFF138A9E),
      edge: Color(0xFF06303F),
      pattern: TablePattern.none,
    ),
  };

  /// Dos de cartes vendus séparément.
  static const backs = <String, CardBackStyle>{
    'back.nova': CardBackStyle(
      pattern: BackPattern.nova,
      base: Color(0xFF1B2233),
      ink: Color(0xFFE2B659),
    ),
    'back.lines': CardBackStyle(
      pattern: BackPattern.lines,
      base: Color(0xFF274C77),
      ink: Color(0xFFB9D3F0),
    ),
    'back.dots': CardBackStyle(
      pattern: BackPattern.dots,
      base: Color(0xFF3E7C59),
      ink: Color(0xFFD9F2E3),
    ),
    'back.waves': CardBackStyle(
      pattern: BackPattern.waves,
      base: Color(0xFF5B3A8C),
      ink: Color(0xFFE3D6FF),
    ),
    'back.geo': CardBackStyle(
      pattern: BackPattern.diamonds,
      base: Color(0xFF9C3D2E),
      ink: Color(0xFFFFD9C9),
    ),
    'back.gold': CardBackStyle(
      pattern: BackPattern.gold,
      base: Color(0xFF14151A),
      ink: Color(0xFFE2B659),
    ),
    'back.blossom': _backBlossom,
    'back.sun': _backSun,
    'back.leaf': _backLeaf,
    'back.snowflake': _backSnowflake,
    'back.tree': _backTree,
    'back.pumpkin': _backPumpkin,
    'back.heart': _backHeart,
    'back.egg': _backEgg,
  };
}
