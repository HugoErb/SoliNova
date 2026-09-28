import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/model/card.dart' as model;
import '../../engine/model/suit.dart';
import '../theme/look.dart';
import '../theme/nova_theme.dart';
import 'seasonal_motifs.dart';
import 'suit_paths.dart';

/// Cache des textes mis en forme (les mêmes index reviennent sans cesse).
final class _TextCache {
  static final Map<(String, double, int, int, FontWeight), TextPainter> _cache =
      {};

  static TextPainter get(
    String text,
    double size,
    Color color,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    final key = (
      text,
      (size * 4).roundToDouble() / 4,
      color.toARGB32(),
      (letterSpacing * 100).round(),
      weight,
    );
    return _cache.putIfAbsent(key, () {
      if (_cache.length > 600) _cache.clear();
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: key.$2,
            fontWeight: weight,
            color: color,
            height: 1,
            letterSpacing: letterSpacing,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

/// Couleurs d'une face : fond, encre et liseré.
typedef FaceColors = ({Color paper, Color ink, Color edge});

const _white = Color(0xFFFFFFFF);

/// Couleurs d'une carte selon son enseigne et le style de face. Les styles
/// « classiques » gardent le papier du thème ; les autres imposent le leur.
FaceColors faceColors(Suit suit, CardFacePalette face, FaceStyle style) {
  FaceColors on(
    Color paper,
    Color ink, [
    Color edge = const Color(0x33000000),
  ]) => (paper: paper, ink: ink, edge: edge);
  return switch (style) {
    FaceStyle.fourColor => on(face.paper, switch (suit) {
      Suit.spades => face.black,
      Suit.hearts => face.red,
      Suit.diamonds => const Color(0xFF1F66C9),
      Suit.clubs => const Color(0xFF16804A),
    }, face.edge),
    FaceStyle.solid => on(
      suit.isRed ? const Color(0xFFC8324A) : const Color(0xFF232A3A),
      _white,
    ),
    FaceStyle.solidFour => on(switch (suit) {
      Suit.spades => const Color(0xFF232A3A),
      Suit.hearts => const Color(0xFFC8324A),
      Suit.diamonds => const Color(0xFF1F5FB8),
      Suit.clubs => const Color(0xFF16784A),
    }, _white),
    FaceStyle.colored => switch (suit) {
      Suit.spades => on(const Color(0xFFE4E7EE), const Color(0xFF1B2233)),
      Suit.hearts => on(const Color(0xFFFBE0E6), const Color(0xFFB0243C)),
      Suit.diamonds => on(const Color(0xFFDDEBFA), const Color(0xFF1A56A8)),
      Suit.clubs => on(const Color(0xFFDDF3E6), const Color(0xFF136B3E)),
    },
    // Rouges en tons chauds, noires en tons froids.
    FaceStyle.neon => on(const Color(0xFF0E0F14), switch (suit) {
      Suit.hearts => const Color(0xFFFF4F8B),
      Suit.diamonds => const Color(0xFFFF9A3C),
      Suit.spades => const Color(0xFF3FE6FF),
      Suit.clubs => const Color(0xFF8FA8FF),
    }, const Color(0x40FFFFFF)),
    FaceStyle.retro => on(
      const Color(0xFFF3E9D2),
      suit.isRed ? const Color(0xFFA8321F) : const Color(0xFF1F2F4F),
      const Color(0x4D5A4632),
    ),
    FaceStyle.classic ||
    FaceStyle.large ||
    FaceStyle.minimal ||
    FaceStyle.elegant => on(
      face.paper,
      suit.isRed ? face.red : face.black,
      face.edge,
    ),
  };
}

/// Hauteur de la bande d'index en haut de la carte : c'est la partie qui
/// doit rester visible quand les cartes se chevauchent.
double indexStripHeight(double width, FaceStyle style) {
  final fs = _indexFontSize(width, style);
  return fs * 1.08 + width * 0.1;
}

double _indexFontSize(double width, FaceStyle style) => switch (style) {
  FaceStyle.large => width * 0.46,
  FaceStyle.minimal => width * 0.34,
  _ => width * 0.38,
};

/// Peint la face ou le dos d'une carte.
final class CardPainter extends CustomPainter {
  const CardPainter({required this.card, required this.look, this.showFace});

  final model.Card card;
  final Look look;

  /// Force la face ou le dos (animation de retournement).
  final bool? showFace;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.1);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    if (showFace ?? card.faceUp) {
      paintFace(canvas, size, rrect, card, look);
    } else {
      paintBack(canvas, size, rrect, look.back);
    }
  }

  static void paintFace(
    Canvas canvas,
    Size size,
    RRect rrect,
    model.Card card,
    Look look,
  ) {
    final style = look.faceStyle;
    final colors = faceColors(card.suit, look.theme.face, style);
    final ink = colors.ink;
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(rrect, Paint()..color = colors.paper);
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = colors.edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (style == FaceStyle.retro) {
      // Double filet ancien.
      final line = Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.01);
      canvas
        ..drawRRect(rrect.deflate(w * 0.045), line)
        ..drawRRect(rrect.deflate(w * 0.07), line);
    }
    if (style == FaceStyle.elegant) {
      canvas.drawRRect(
        rrect.deflate(w * 0.06),
        Paint()
          ..color = const Color(0xFFC9A24A).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, w * 0.012),
      );
    }

    // Bande d'index : valeur à gauche, enseigne à droite, même ligne.
    final fs = _indexFontSize(w, style);
    final weight = switch (style) {
      FaceStyle.minimal => FontWeight.w500,
      FaceStyle.elegant => FontWeight.w700,
      _ => FontWeight.w800,
    };
    final pad = w * 0.09;
    final rankText = _TextCache.get(
      card.rank.short,
      card.rank.short.length > 1 ? fs * 0.9 : fs,
      ink,
      weight,
      letterSpacing: card.rank.short.length > 1 ? -fs * 0.08 : 0,
    );
    final top = w * 0.07;
    rankText.paint(canvas, Offset(pad * 0.9, top));
    final small = fs * (style == FaceStyle.large ? 0.72 : 0.8);
    final smallRect = Rect.fromLTWH(
      w - pad - small,
      top + (rankText.height - small) / 2,
      small,
      small,
    );
    canvas.drawPath(
      SuitPaths.inRect(card.suit, smallRect),
      Paint()..color = ink,
    );

    // Centre : grande enseigne, ou monogramme pour les figures.
    final strip = indexStripHeight(w, style);
    final bodyTop = strip;
    final bodyH = h - strip - w * 0.08;
    final center = Offset(w / 2, bodyTop + bodyH / 2);
    final value = card.rank.value;
    if (value >= 11) {
      final letter = _TextCache.get(
        card.rank.short,
        math.min(bodyH * 0.62, w * 0.62),
        ink,
        style == FaceStyle.minimal ? FontWeight.w400 : FontWeight.w700,
      );
      final suitSize = w * 0.2;
      final total = letter.height + suitSize * 0.9;
      final y0 = center.dy - total / 2;
      letter.paint(canvas, Offset(center.dx - letter.width / 2, y0));
      canvas.drawPath(
        SuitPaths.inRect(
          card.suit,
          Rect.fromCenter(
            center: Offset(center.dx, y0 + letter.height + suitSize * 0.45),
            width: suitSize,
            height: suitSize,
          ),
        ),
        Paint()..color = ink.withValues(alpha: 0.9),
      );
    } else {
      final big =
          math.min(bodyH * 0.78, w * 0.56) *
          (style == FaceStyle.large ? 0.8 : 1);
      canvas.drawPath(
        SuitPaths.inRect(
          card.suit,
          Rect.fromCenter(center: center, width: big, height: big),
        ),
        Paint()..color = ink.withValues(alpha: value == 1 ? 1 : 0.92),
      );
      if (value == 1) {
        // L'As porte l'étoile Nova en filigrane.
        canvas.drawPath(
          SuitPaths.star(center, big * 0.16),
          Paint()..color = colors.paper.withValues(alpha: 0.9),
        );
      }
    }
  }

  static void paintBack(
    Canvas canvas,
    Size size,
    RRect rrect,
    CardBackStyle back,
  ) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(rrect, Paint()..color = back.base);
    canvas.save();
    canvas.clipRRect(rrect);
    final ink = Paint()
      ..color = back.ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, w * 0.014);
    final fill = Paint()..color = back.ink.withValues(alpha: 0.22);
    switch (back.pattern) {
      case BackPattern.nova:
        break;
      case BackPattern.lines:
        final step = w * 0.09;
        for (var x = -h; x < w + h; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x + h, h), ink);
        }
      case BackPattern.dots:
        final step = w * 0.14;
        for (var y = step / 2; y < h; y += step) {
          for (var x = step / 2; x < w; x += step) {
            canvas.drawCircle(Offset(x, y), w * 0.025, fill);
          }
        }
      case BackPattern.waves:
        final c = Offset(w * 0.5, h * 1.05);
        for (var r = w * 0.12; r < h * 1.3; r += w * 0.11) {
          canvas.drawCircle(c, r, ink);
        }
      case BackPattern.diamonds:
        final step = w * 0.22;
        for (var x = -h; x < w + h; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x + h * 0.6, h), ink);
          canvas.drawLine(Offset(x + h * 0.6, 0), Offset(x, h), ink);
        }
      case BackPattern.gold:
        canvas.drawRRect(
          rrect.deflate(w * 0.12),
          Paint()
            ..color = back.ink.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.7, w * 0.012),
        );
      case BackPattern.motif:
        // Petits symboles en quinconce.
        final step = w * 0.26;
        final small = w * 0.13;
        var row = 0;
        for (var y = step * 0.4; y < h + step; y += step * 0.8, row++) {
          for (var x = row.isEven ? 0.0 : step / 2; x < w + step; x += step) {
            canvas.drawPath(
              MotifPaths.inRect(
                back.motif!,
                Rect.fromCenter(
                  center: Offset(x, y),
                  width: small,
                  height: small,
                ),
              ),
              fill,
            );
          }
        }
    }
    canvas.restore();

    // Cadre intérieur et étoile Nova.
    canvas.drawRRect(
      rrect.deflate(w * 0.065),
      Paint()
        ..color = back.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.018),
    );
    final c = Offset(w / 2, h / 2);
    if (back.pattern == BackPattern.motif) {
      // Grand symbole central sur une pastille de la couleur du fond.
      final side = w * 0.46;
      canvas.drawCircle(
        c,
        side * 0.62,
        Paint()..color = back.base.withValues(alpha: 0.92),
      );
      canvas.drawPath(
        MotifPaths.inRect(
          back.motif!,
          Rect.fromCenter(center: c, width: side, height: side),
        ),
        Paint()..color = back.ink.withValues(alpha: 0.95),
      );
      return;
    }
    final starR = w * (back.pattern == BackPattern.nova ? 0.24 : 0.14);
    if (back.pattern == BackPattern.nova || back.pattern == BackPattern.gold) {
      canvas.drawCircle(
        c,
        starR * 1.25,
        Paint()..color = back.base.withValues(alpha: 0.9),
      );
    }
    canvas.drawPath(
      SuitPaths.star(c, starR),
      Paint()..color = back.ink.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(CardPainter old) =>
      old.card != card || old.look != look || old.showFace != showFace;
}

/// Emplacement vide (fondation, cellule, colonne).
final class SlotPainter extends CustomPainter {
  const SlotPainter({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.06));
    if (label != null) {
      final t = _TextCache.get(
        label!,
        size.width * 0.34,
        color,
        FontWeight.w700,
      );
      t.paint(
        canvas,
        Offset((size.width - t.width) / 2, (size.height - t.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(SlotPainter old) =>
      old.color != color || old.label != label;
}
