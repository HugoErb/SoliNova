import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../engine/model/suit.dart';

/// Enseignes dessinées en vectoriel dans un carré unité (0..1), pour un
/// rendu net à toutes les tailles, sans dépendre des glyphes du système.
abstract final class SuitPaths {
  static final Map<Suit, Path> _cache = {};

  static Path unit(Suit suit) => _cache.putIfAbsent(suit, () => _build(suit));

  /// Enseigne mise à l'échelle et centrée dans [rect].
  static Path inRect(Suit suit, Rect rect) {
    final side = rect.shortestSide;
    final dx = rect.left + (rect.width - side) / 2;
    final dy = rect.top + (rect.height - side) / 2;
    final m = Float64List.fromList([
      side, 0, 0, 0, //
      0, side, 0, 0,
      0, 0, 1, 0,
      dx, dy, 0, 1,
    ]);
    return unit(suit).transform(m);
  }

  static Path _build(Suit suit) => switch (suit) {
    Suit.hearts => _heart(),
    Suit.diamonds => _diamond(),
    Suit.spades => _spade(),
    Suit.clubs => _club(),
  };

  static Path _heart() => Path()
    ..moveTo(0.5, 0.92)
    ..cubicTo(0.34, 0.78, 0.04, 0.58, 0.04, 0.33)
    ..cubicTo(0.04, 0.16, 0.17, 0.06, 0.3, 0.06)
    ..cubicTo(0.4, 0.06, 0.47, 0.12, 0.5, 0.2)
    ..cubicTo(0.53, 0.12, 0.6, 0.06, 0.7, 0.06)
    ..cubicTo(0.83, 0.06, 0.96, 0.16, 0.96, 0.33)
    ..cubicTo(0.96, 0.58, 0.66, 0.78, 0.5, 0.92)
    ..close();

  static Path _diamond() => Path()
    ..moveTo(0.5, 0.03)
    ..quadraticBezierTo(0.66, 0.3, 0.88, 0.5)
    ..quadraticBezierTo(0.66, 0.7, 0.5, 0.97)
    ..quadraticBezierTo(0.34, 0.7, 0.12, 0.5)
    ..quadraticBezierTo(0.34, 0.3, 0.5, 0.03)
    ..close();

  static Path _spade() {
    final body = Path()
      ..moveTo(0.5, 0.04)
      ..cubicTo(0.66, 0.2, 0.95, 0.38, 0.95, 0.6)
      ..cubicTo(0.95, 0.76, 0.83, 0.84, 0.71, 0.84)
      ..cubicTo(0.62, 0.84, 0.55, 0.8, 0.52, 0.73)
      ..lineTo(0.48, 0.73)
      ..cubicTo(0.45, 0.8, 0.38, 0.84, 0.29, 0.84)
      ..cubicTo(0.17, 0.84, 0.05, 0.76, 0.05, 0.6)
      ..cubicTo(0.05, 0.38, 0.34, 0.2, 0.5, 0.04)
      ..close();
    final stem = Path()
      ..moveTo(0.5, 0.62)
      ..quadraticBezierTo(0.52, 0.86, 0.66, 0.96)
      ..lineTo(0.34, 0.96)
      ..quadraticBezierTo(0.48, 0.86, 0.5, 0.62)
      ..close();
    return Path.combine(PathOperation.union, body, stem);
  }

  static Path _club() {
    final p = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.28), radius: 0.2))
      ..addOval(Rect.fromCircle(center: const Offset(0.27, 0.57), radius: 0.2))
      ..addOval(Rect.fromCircle(center: const Offset(0.73, 0.57), radius: 0.2))
      ..addRect(const Rect.fromLTRB(0.4, 0.4, 0.6, 0.6));
    final stem = Path()
      ..moveTo(0.5, 0.5)
      ..quadraticBezierTo(0.52, 0.86, 0.66, 0.96)
      ..lineTo(0.34, 0.96)
      ..quadraticBezierTo(0.48, 0.86, 0.5, 0.5)
      ..close();
    return Path.combine(PathOperation.union, p, stem);
  }

  /// Étoile SoliNova à quatre branches.
  static Path star(Offset center, double radius, {double waist = 0.22}) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? radius : radius * waist;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }
}
