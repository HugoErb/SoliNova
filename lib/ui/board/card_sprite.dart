import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/model/card.dart' as model;
import '../cards/card_painter.dart';
import '../theme/look.dart';

/// Carte affichée sur le plateau. Elle anime seule ses déplacements vers sa
/// position cible, son retournement, la secousse d'un coup refusé et la
/// distribution. Pendant un glisser, elle suit le doigt sans aucun délai.
class CardSprite extends StatefulWidget {
  const CardSprite({
    super.key,
    required this.card,
    required this.target,
    required this.look,
    required this.dragDelta,
    required this.dragging,
    required this.highlighted,
    required this.shakeSerial,
    required this.dealSerial,
    required this.dealOrigin,
    required this.dealDelay,
  });

  final model.Card card;
  final Rect target;
  final Look look;

  /// Décalage du doigt pendant un glisser (partagé par les cartes saisies).
  final ValueNotifier<Offset> dragDelta;
  final bool dragging;
  final bool highlighted;

  /// Change (valeur positive) quand cette carte doit être secouée.
  final int shakeSerial;
  final int dealSerial;
  final Rect dealOrigin;
  final Duration dealDelay;

  @override
  State<CardSprite> createState() => _CardSpriteState();
}

class _CardSpriteState extends State<CardSprite> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _flip = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _shake = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late Rect _from = widget.target;
  late Rect _to = widget.target;
  Curve _curve = Curves.easeOutCubic;
  double _lift = 0;
  bool _flipToFace = true;
  Timer? _dealTimer;

  Rect get _current {
    final t = _curve.transform(_move.value.clamp(0.0, 1.0));
    return Rect.lerp(_from, _to, t)!;
  }

  @override
  void initState() {
    super.initState();
    _move.value = 1;
    if (widget.highlighted) unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void didUpdateWidget(CardSprite old) {
    super.didUpdateWidget(old);
    final look = widget.look;

    if (widget.dealSerial != old.dealSerial) {
      _startDeal();
    } else if (old.dragging && !widget.dragging) {
      // Fin du glisser : on repart de la position sous le doigt.
      final released = old.target.shift(widget.dragDelta.value);
      _animateTo(widget.target, from: released, release: true);
    } else if (widget.target != old.target) {
      _animateTo(widget.target, from: _current);
    }

    if (widget.card.faceUp != old.card.faceUp && look.animationsEnabled) {
      _flipToFace = widget.card.faceUp;
      _flip.duration = look.scaled(const Duration(milliseconds: 240));
      unawaited(_flip.forward(from: 0));
    }

    if (widget.shakeSerial != old.shakeSerial &&
        widget.shakeSerial > 0 &&
        look.animationsEnabled) {
      _shake.duration = const Duration(milliseconds: 320);
      unawaited(_shake.forward(from: 0));
    }

    if (widget.highlighted != old.highlighted) {
      if (widget.highlighted) {
        unawaited(_pulse.repeat(reverse: true));
      } else {
        _pulse
          ..stop()
          ..value = 0;
      }
    }
  }

  void _animateTo(Rect to, {required Rect from, bool release = false}) {
    final look = widget.look;
    _dealTimer?.cancel();
    if (!look.animationsEnabled || from == to) {
      _from = to;
      _to = to;
      _move.value = 1;
      return;
    }
    _from = from;
    _to = to;
    final motion = look.motion;
    _curve = release && motion.curve == Curves.easeOutBack
        ? Curves.easeOutBack
        : motion.curve;
    _lift = motion.lift;
    // Durée proportionnelle à la distance, bornée.
    final dist = (to.center - from.center).distance;
    final base = look.scaled(motion.move).inMilliseconds;
    final ms = (base * (0.55 + math.min(1.0, dist / 500) * 0.6)).round();
    _move.duration = Duration(milliseconds: math.max(60, ms));
    unawaited(_move.forward(from: 0));
  }

  void _startDeal() {
    final look = widget.look;
    _dealTimer?.cancel();
    if (!look.animationsEnabled) {
      _from = widget.target;
      _to = widget.target;
      _move.value = 1;
      return;
    }
    _from = widget.dealOrigin;
    _to = widget.dealOrigin;
    _move.value = 1;
    _dealTimer = Timer(look.scaled(widget.dealDelay), () {
      if (!mounted) return;
      _from = widget.dealOrigin;
      _to = widget.target;
      _curve = Curves.easeOutCubic;
      _lift = 0;
      _move.duration = look.scaled(const Duration(milliseconds: 340));
      unawaited(_move.forward(from: 0));
    });
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    _move.dispose();
    _flip.dispose();
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.look.theme;
    final cardFace = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final t = _flip.value;
          final flipping = t < 1;
          final angle = flipping ? (1 - t) * math.pi : 0.0;
          final showFace = flipping
              ? (t >= 0.5 ? _flipToFace : !_flipToFace)
              : widget.card.faceUp;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle > math.pi / 2 ? angle - math.pi : angle),
            child: CustomPaint(
              painter: CardPainter(
                card: widget.card,
                look: widget.look,
                showFace: showFace,
              ),
              isComplex: true,
              willChange: false,
            ),
          );
        },
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_move, _shake, _pulse, widget.dragDelta]),
      builder: (context, child) {
        var rect = _current;
        var lift = 0.0;
        if (_move.isAnimating && _lift > 0) {
          lift = math.sin(_move.value * math.pi) * _lift;
        }
        if (widget.dragging) {
          rect = widget.target.shift(widget.dragDelta.value);
          lift = 1;
        }
        final shakeX = _shake.isAnimating
            ? math.sin(_shake.value * math.pi * 6) *
                  (1 - _shake.value) *
                  rect.width *
                  0.12
            : 0.0;
        final scale = 1 + lift * 0.05;
        final glow = widget.dragging && widget.look.effect == EffectStyle.glow;
        return Transform.translate(
          offset: Offset(rect.left + shakeX, rect.top - lift * 6),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: rect.width,
              height: rect.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(rect.width * 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16 + lift * 0.18),
                      blurRadius: 1.5 + lift * 14,
                      offset: Offset(0, 0.8 + lift * 6),
                    ),
                    if (glow)
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    if (widget.highlighted)
                      BoxShadow(
                        color: theme.highlight.withValues(
                          alpha: 0.45 + 0.4 * _pulse.value,
                        ),
                        blurRadius: 6 + 8 * _pulse.value,
                        spreadRadius: 1.5,
                      ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: cardFace,
    );
  }
}
