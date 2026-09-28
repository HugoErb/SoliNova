import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/model/suit.dart';
import '../cards/suit_paths.dart';
import '../theme/look.dart';
import '../theme/nova_theme.dart';

/// Animation de célébration jouée une fois à la victoire.
class VictoryFx extends StatefulWidget {
  const VictoryFx({super.key, required this.look});

  final Look look;

  @override
  State<VictoryFx> createState() => _VictoryFxState();
}

class _Particle {
  _Particle({
    required this.p,
    required this.v,
    required this.color,
    required this.size,
    required this.spin,
    required this.delay,
    this.suit,
  });

  Offset p;
  Offset v;
  final Color color;
  final double size;
  final double spin;
  final double delay;
  final Suit? suit;
}

class _VictoryFxState extends State<VictoryFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  List<_Particle>? _particles;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    if (widget.look.animationsEnabled) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<_Particle> _spawn(Size size) {
    final rnd = math.Random(7);
    final t = widget.look.theme;
    final palette = [
      t.accent,
      t.highlight,
      t.face.red,
      t.face.paper,
      t.onSurface,
    ];
    Color pick() => palette[rnd.nextInt(palette.length)];
    switch (widget.look.victory) {
      case VictoryStyle.cascade:
        return [
          for (var i = 0; i < 28; i++)
            _Particle(
              p: Offset(size.width * (0.1 + 0.8 * rnd.nextDouble()), -60),
              v: Offset(
                (rnd.nextDouble() - 0.5) * 180,
                60 + rnd.nextDouble() * 120,
              ),
              color: t.face.paper,
              size: 30 + rnd.nextDouble() * 14,
              spin: (rnd.nextDouble() - 0.5) * 3,
              delay: i * 0.025,
              suit: Suit.values[i % 4],
            ),
        ];
      case VictoryStyle.confetti:
        return [
          for (var i = 0; i < 140; i++)
            _Particle(
              p: Offset(
                size.width * rnd.nextDouble(),
                -20 - rnd.nextDouble() * 200,
              ),
              v: Offset(
                (rnd.nextDouble() - 0.5) * 60,
                140 + rnd.nextDouble() * 160,
              ),
              color: pick(),
              size: 5 + rnd.nextDouble() * 6,
              spin: (rnd.nextDouble() - 0.5) * 12,
              delay: rnd.nextDouble() * 0.25,
            ),
        ];
      case VictoryStyle.stars:
        return [
          for (var i = 0; i < 22; i++)
            _Particle(
              p: Offset(size.width * (rnd.nextDouble() * 1.2 - 0.1), -40),
              v: Offset(
                -120 - rnd.nextDouble() * 120,
                260 + rnd.nextDouble() * 200,
              ),
              color: i.isEven ? t.accent : t.highlight,
              size: 6 + rnd.nextDouble() * 10,
              spin: 0,
              delay: rnd.nextDouble() * 0.6,
            ),
        ];
      case VictoryStyle.fireworks:
        final out = <_Particle>[];
        for (var b = 0; b < 6; b++) {
          final center = Offset(
            size.width * (0.2 + 0.6 * rnd.nextDouble()),
            size.height * (0.15 + 0.35 * rnd.nextDouble()),
          );
          final color = pick();
          for (var i = 0; i < 36; i++) {
            final a = i / 36 * math.pi * 2;
            final speed = 90 + rnd.nextDouble() * 60;
            out.add(
              _Particle(
                p: center,
                v: Offset(math.cos(a) * speed, math.sin(a) * speed),
                color: color,
                size: 2.4,
                spin: 0,
                delay: b * 0.12,
              ),
            );
          }
        }
        return out;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.look.animationsEnabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          if (_particles == null || _size != c.biggest) {
            _size = c.biggest;
            _particles = _spawn(_size);
          }
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _FxPainter(
                particles: _particles!,
                t: _c.value * _c.duration!.inMilliseconds / 1000,
                style: widget.look.victory,
                paper: widget.look.theme.face,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.particles,
    required this.t,
    required this.style,
    required this.paper,
  });

  final List<_Particle> particles;
  final double t;
  final VictoryStyle style;
  final CardFacePalette paper;

  @override
  void paint(Canvas canvas, Size size) {
    const total = 3.4;
    final fadeAll = t > total - 0.6 ? ((total - t) / 0.6).clamp(0.0, 1.0) : 1.0;
    for (final p in particles) {
      final lt = t - p.delay * total;
      if (lt <= 0) continue;
      switch (style) {
        case VictoryStyle.cascade:
          // Chute avec gravité et rebonds amortis.
          var y = p.p.dy + p.v.dy * lt + 0.5 * 900 * lt * lt;
          final floor = size.height - p.size * 1.4;
          var bounce = 0;
          var vy = p.v.dy + 900 * lt;
          while (y > floor && bounce < 4) {
            y = floor - (y - floor) * 0.55;
            vy = -vy * 0.55;
            bounce++;
          }
          final x = p.p.dx + p.v.dx * lt;
          _drawMiniCard(canvas, Offset(x, y), p, lt, fadeAll);
        case VictoryStyle.confetti:
          final x = p.p.dx + p.v.dx * lt + math.sin(lt * 3 + p.spin) * 18;
          final y = p.p.dy + p.v.dy * lt;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(lt * p.spin);
          canvas.scale(1, math.cos(lt * p.spin * 1.3).abs() * 0.8 + 0.2);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.55,
            ),
            Paint()..color = p.color.withValues(alpha: fadeAll),
          );
          canvas.restore();
        case VictoryStyle.stars:
          final pos = p.p + p.v * lt;
          final tail = pos - p.v * 0.12;
          canvas.drawLine(
            tail,
            pos,
            Paint()
              ..shader = LinearGradient(
                colors: [
                  p.color.withValues(alpha: 0),
                  p.color.withValues(alpha: 0.8 * fadeAll),
                ],
              ).createShader(Rect.fromPoints(tail, pos))
              ..strokeWidth = p.size * 0.35
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawPath(
            SuitPaths.star(pos, p.size),
            Paint()..color = p.color.withValues(alpha: fadeAll),
          );
        case VictoryStyle.fireworks:
          final life = (lt / 1.6).clamp(0.0, 1.0);
          if (life >= 1) continue;
          final drag = 1 - math.pow(1 - life, 2);
          final pos =
              p.p + p.v * (drag * 1.6).toDouble() + Offset(0, 40 * life * life);
          canvas.drawCircle(
            pos,
            p.size * (1 - life * 0.5),
            Paint()..color = p.color.withValues(alpha: (1 - life) * fadeAll),
          );
      }
    }
  }

  void _drawMiniCard(
    Canvas canvas,
    Offset c,
    _Particle p,
    double lt,
    double fade,
  ) {
    final w = p.size;
    final h = w * 1.42;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(lt * p.spin * 0.6);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 2)),
        Radius.circular(w * 0.1),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18 * fade),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.1)),
      Paint()..color = paper.paper.withValues(alpha: fade),
    );
    final suit = p.suit!;
    canvas.drawPath(
      SuitPaths.inRect(
        suit,
        Rect.fromCenter(center: Offset.zero, width: w * 0.5, height: w * 0.5),
      ),
      Paint()
        ..color = (suit.isRed ? paper.red : paper.black).withValues(
          alpha: fade,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FxPainter old) => old.t != t;
}
