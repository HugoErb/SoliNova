import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../engine/model/suit.dart';
import '../theme/nova_theme.dart';
import 'suit_paths.dart';

/// Motifs saisonniers dessinés en vectoriel dans un carré unité (0..1),
/// partagés par les dos de cartes et les tapis. Chaque motif est une seule
/// silhouette pleine : les détails (visage, bandes) sont évidés.
abstract final class MotifPaths {
  static final Map<Motif, Path> _cache = {};

  static Path unit(Motif motif) =>
      _cache.putIfAbsent(motif, () => _build(motif));

  /// Motif mis à l'échelle et centré dans [rect].
  static Path inRect(Motif motif, Rect rect) {
    final side = rect.shortestSide;
    final dx = rect.left + (rect.width - side) / 2;
    final dy = rect.top + (rect.height - side) / 2;
    final m = Float64List.fromList([
      side, 0, 0, 0, //
      0, side, 0, 0,
      0, 0, 1, 0,
      dx, dy, 0, 1,
    ]);
    return unit(motif).transform(m);
  }

  static Path _build(Motif motif) => switch (motif) {
    Motif.blossom => _blossom(),
    Motif.sun => _sun(),
    Motif.leaf => _leaf(),
    Motif.snowflake => _snowflake(),
    Motif.tree => _tree(),
    Motif.pumpkin => _pumpkin(),
    Motif.heart => SuitPaths.unit(Suit.hearts),
    Motif.egg => _egg(),
  };

  static const _c = Offset(0.5, 0.5);

  /// Rotation de [path] autour du centre du carré unité.
  static Path _rotated(Path path, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final m = Float64List.fromList([
      cos, sin, 0, 0, //
      -sin, cos, 0, 0,
      0, 0, 1, 0,
      _c.dx - cos * _c.dx + sin * _c.dy,
      _c.dy - sin * _c.dx - cos * _c.dy,
      0,
      1,
    ]);
    return path.transform(m);
  }

  static Path _polygon(List<Offset> points) =>
      Path()..addPolygon(points, true);

  static Path _blossom() {
    final petals = Path();
    final petal = Path()
      ..addOval(Rect.fromCenter(center: const Offset(0.5, 0.27), width: 0.28, height: 0.4));
    for (var k = 0; k < 5; k++) {
      petals.addPath(_rotated(petal, k * 2 * math.pi / 5), Offset.zero);
    }
    final heart = Path()..addOval(Rect.fromCircle(center: _c, radius: 0.07));
    return Path.combine(PathOperation.difference, petals, heart);
  }

  static Path _sun() {
    final p = Path()..addOval(Rect.fromCircle(center: _c, radius: 0.21));
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      Offset at(double r, double da) =>
          Offset(0.5 + r * math.cos(a + da), 0.5 + r * math.sin(a + da));
      p.addPolygon([at(0.28, -0.2), at(0.47, 0), at(0.28, 0.2)], true);
    }
    return p;
  }

  static Path _leaf() {
    const right = [
      Offset(0.5, 0.04),
      Offset(0.58, 0.22),
      Offset(0.69, 0.15),
      Offset(0.66, 0.36),
      Offset(0.9, 0.29),
      Offset(0.84, 0.45),
      Offset(0.94, 0.52),
      Offset(0.7, 0.61),
      Offset(0.75, 0.71),
      Offset(0.54, 0.67),
      Offset(0.53, 0.96),
    ];
    return _polygon([
      ...right,
      for (final p in right.reversed) Offset(1 - p.dx, p.dy),
    ]);
  }

  static Path _snowflake() {
    final arm = Path()
      ..addPolygon(const [
        Offset(0.475, 0.5),
        Offset(0.475, 0.04),
        Offset(0.525, 0.04),
        Offset(0.525, 0.5),
      ], true);
    final branch = Path()
      ..addPolygon(const [
        Offset(0.48, 0.24),
        Offset(0.52, 0.2),
        Offset(0.64, 0.1),
        Offset(0.67, 0.14),
      ], true)
      ..addPolygon(const [
        Offset(0.52, 0.24),
        Offset(0.48, 0.2),
        Offset(0.36, 0.1),
        Offset(0.33, 0.14),
      ], true);
    final one = Path()
      ..addPath(arm, Offset.zero)
      ..addPath(branch, Offset.zero);
    final p = Path()..addOval(Rect.fromCircle(center: _c, radius: 0.07));
    for (var k = 0; k < 6; k++) {
      p.addPath(_rotated(one, k * math.pi / 3), Offset.zero);
    }
    return p;
  }

  static Path _tree() {
    final p = _polygon(const [
      Offset(0.5, 0.14),
      Offset(0.72, 0.4),
      Offset(0.28, 0.4),
    ])
      ..addPolygon(const [
        Offset(0.5, 0.28),
        Offset(0.8, 0.62),
        Offset(0.2, 0.62),
      ], true)
      ..addPolygon(const [
        Offset(0.5, 0.46),
        Offset(0.87, 0.84),
        Offset(0.13, 0.84),
      ], true)
      ..addRect(const Rect.fromLTRB(0.43, 0.83, 0.57, 0.96))
      ..addPath(SuitPaths.star(const Offset(0.5, 0.1), 0.1, waist: 0.4), Offset.zero);
    return p;
  }

  static Path _pumpkin() {
    final body = Path()
      ..addOval(const Rect.fromLTRB(0.06, 0.3, 0.56, 0.9))
      ..addOval(const Rect.fromLTRB(0.44, 0.3, 0.94, 0.9))
      ..addOval(const Rect.fromLTRB(0.27, 0.27, 0.73, 0.92))
      ..addPolygon(const [
        Offset(0.45, 0.31),
        Offset(0.47, 0.12),
        Offset(0.58, 0.1),
        Offset(0.55, 0.31),
      ], true);
    final face = _polygon(const [
      Offset(0.28, 0.54),
      Offset(0.42, 0.54),
      Offset(0.35, 0.43),
    ])
      ..addPolygon(const [
        Offset(0.58, 0.54),
        Offset(0.72, 0.54),
        Offset(0.65, 0.43),
      ], true)
      ..addPolygon(const [
        Offset(0.26, 0.64),
        Offset(0.74, 0.64),
        Offset(0.67, 0.77),
        Offset(0.59, 0.71),
        Offset(0.5, 0.8),
        Offset(0.41, 0.71),
        Offset(0.33, 0.77),
      ], true);
    return Path.combine(PathOperation.difference, body, face);
  }

  static Path _egg() {
    final egg = Path()
      ..moveTo(0.5, 0.05)
      ..cubicTo(0.76, 0.05, 0.87, 0.48, 0.87, 0.62)
      ..cubicTo(0.87, 0.84, 0.7, 0.96, 0.5, 0.96)
      ..cubicTo(0.3, 0.96, 0.13, 0.84, 0.13, 0.62)
      ..cubicTo(0.13, 0.48, 0.24, 0.05, 0.5, 0.05)
      ..close();
    final band = _polygon([
      for (var i = 0; i <= 10; i++) Offset(i / 10, i.isEven ? 0.5 : 0.56),
      for (var i = 10; i >= 0; i--) Offset(i / 10, i.isEven ? 0.6 : 0.66),
    ]);
    return Path.combine(PathOperation.difference, egg, band);
  }
}
