import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
import '../../engine/model/game_mode.dart';
import '../../engine/model/game_state.dart';
import '../../engine/model/move.dart';
import '../../engine/model/pile.dart';
import '../../engine/session/game_session.dart';
import '../cards/card_painter.dart';
import '../screens/shop_screen.dart' show SparkleBurst;
import '../theme/look.dart';
import 'board_layout.dart';
import 'card_sprite.dart';

/// Glisser en cours.
final class _Drag {
  _Drag({
    required this.pointer,
    required this.from,
    required this.index,
    required this.count,
    required this.ids,
    required this.start,
    required this.baseRect,
  });

  final int pointer;
  final PileRef from;
  final int index;
  final int count;
  final List<int> ids;
  final Offset start;

  /// Rectangle de la première carte saisie au début du geste.
  final Rect baseRect;
  bool active = false;
}

/// Plateau de jeu interactif.
class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key});

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  static const _dragSlop = 6.0;
  static const _doubleTapWindow = Duration(milliseconds: 320);

  final ValueNotifier<Offset> _dragDelta = ValueNotifier(Offset.zero);
  _Drag? _drag;
  Set<int> _dragIds = const {};

  // Mémo de la géométrie : recalculée seulement si l'état ou la taille change.
  GameState? _geoState;
  Size? _geoSize;
  FaceStyle? _geoFace;
  BoardGeometry? _geo;

  // Cartes déplacées lors du dernier changement (dessinées au-dessus).
  Map<int, (PileRef, Rect)> _lastPlaced = const {};
  List<int> _order = const [];
  int _dealSerialSeen = -1;

  // Étincelles en cours sur les fondations (effet cosmétique).
  final List<(int, Rect)> _sparkles = [];
  int _sparkleId = 0;

  // Double toucher.
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastTapCard;
  bool _lastTapMoved = false;

  @override
  void dispose() {
    _dragDelta.dispose();
    super.dispose();
  }

  BoardGeometry _geometry(
    GameState state,
    Size size,
    Look look,
    int dealSerial,
  ) {
    if (dealSerial != _dealSerialSeen) {
      // Nouvelle donne : les identifiants de cartes sont réutilisés, on
      // repart d'un ordre d'empilement naturel.
      _dealSerialSeen = dealSerial;
      _lastPlaced = const {};
      _geo = null;
    }
    if (_geo != null &&
        identical(state, _geoState) &&
        size == _geoSize &&
        look.faceStyle == _geoFace) {
      return _geo!;
    }
    final geo = BoardGeometry.compute(
      state: state,
      size: size,
      indexStrip: (w) => indexStripHeight(w, look.faceStyle),
    );
    _updateOrder(geo);
    _geoState = state;
    _geoSize = size;
    _geoFace = look.faceStyle;
    _geo = geo;
    return geo;
  }

  /// Ordre d'empilement : cartes immobiles, puis cartes venant de bouger.
  void _updateOrder(BoardGeometry geo) {
    final moved = <int>{};
    final placed = <int, (PileRef, Rect)>{};
    for (final p in geo.placements.values) {
      placed[p.card.id] = (p.pile, p.rect);
      final before = _lastPlaced[p.card.id];
      if (before != null && before.$1 != p.pile) {
        moved.add(p.card.id);
        if (p.pile.kind == PileKind.foundation) _addSparkle(p.rect);
      }
    }
    final all = geo.placements.values.toList()
      ..sort((a, b) {
        final ma = moved.contains(a.card.id) ? 1 : 0;
        final mb = moved.contains(b.card.id) ? 1 : 0;
        if (ma != mb) return ma - mb;
        return a.z.compareTo(b.z);
      });
    _order = [for (final p in all) p.card.id];
    _lastPlaced = placed;
  }

  void _addSparkle(Rect rect) {
    if (ref.read(lookProvider).effect != EffectStyle.sparkle) return;
    final entry = (++_sparkleId, rect);
    _sparkles.add(entry);
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      setState(() => _sparkles.remove(entry));
    });
  }

  // ---------------------------------------------------------------------------
  // Gestes.

  void _onDown(PointerDownEvent e, BoardGeometry geo, GameSession session) {
    if (_drag != null) return;
    ref.read(gameProvider.notifier).clearHint();
    final hit = geo.hitTest(e.localPosition);
    if (hit == null) {
      final slot = geo.slotAt(e.localPosition);
      if (slot?.kind == PileKind.stock) {
        _drag = _Drag(
          pointer: e.pointer,
          from: slot!,
          index: 0,
          count: 0,
          ids: const [],
          start: e.localPosition,
          baseRect: geo.slots[slot]!,
        );
      }
      return;
    }
    final pile = session.state.pile(hit.pile);
    final count = pile.length - hit.index;
    _drag = _Drag(
      pointer: e.pointer,
      from: hit.pile,
      index: hit.index,
      count: count,
      ids: [for (final c in pile.takeTop(count)) c.id],
      start: e.localPosition,
      baseRect: hit.rect,
    );
  }

  void _onMove(PointerMoveEvent e, GameSession session) {
    final d = _drag;
    if (d == null || d.pointer != e.pointer) return;
    final delta = e.localPosition - d.start;
    if (!d.active) {
      if (delta.distance < _dragSlop || d.count == 0) return;
      if (!session.rules.canPickUp(session.state, d.from, d.count)) return;
      d.active = true;
      setState(() => _dragIds = d.ids.toSet());
    }
    _dragDelta.value = delta;
  }

  void _onUp(PointerUpEvent e, BoardGeometry geo, GameSession session) {
    final d = _drag;
    if (d == null || d.pointer != e.pointer) return;
    _drag = null;
    final game = ref.read(gameProvider.notifier);
    if (d.active) {
      final target = _dropTarget(d, geo, session);
      game.drop(d.from, d.count, target);
      setState(() => _dragIds = const {});
      return;
    }
    // Toucher.
    final now = DateTime.now();
    final cardId = d.ids.isEmpty ? null : d.ids.first;
    final isDouble =
        now.difference(_lastTapAt) < _doubleTapWindow &&
        cardId != null &&
        cardId == _lastTapCard;
    if (!isDouble &&
        _lastTapMoved &&
        now.difference(_lastTapAt) < _doubleTapWindow) {
      // Second toucher rapide sur une autre carte après un coup joué :
      // on l'ignore pour éviter un coup involontaire.
      _lastTapMoved = false;
      return;
    }
    final before = ref.read(gameProvider).session;
    game.tap(
      d.from,
      d.from.kind == PileKind.stock ? null : d.index,
      doubleTap: isDouble,
    );
    final after = ref.read(gameProvider).session;
    _lastTapMoved = !identical(before, after);
    _lastTapAt = now;
    _lastTapCard = cardId;
  }

  void _onCancel(PointerCancelEvent e) {
    final d = _drag;
    if (d == null || d.pointer != e.pointer) return;
    _drag = null;
    if (d.active) setState(() => _dragIds = const {});
  }

  /// Pile cible : la zone de dépôt légale qui recouvre le plus la carte.
  PileRef? _dropTarget(_Drag d, BoardGeometry geo, GameSession session) {
    final moved = d.baseRect.shift(_dragDelta.value);
    PileRef? best;
    var bestArea = 0.0;
    for (final e in geo.dropZones.entries) {
      if (e.key == d.from) continue;
      final inter = e.value.intersect(moved);
      if (inter.width <= 0 || inter.height <= 0) continue;
      final area = inter.width * inter.height;
      if (area <= bestArea) continue;
      final ok = session.rules.isLegal(
        session.state,
        TransferMove(from: d.from, to: e.key, count: d.count),
      );
      if (ok) {
        best = e.key;
        bestArea = area;
      }
    }
    if (best != null) return best;
    // Aucun dépôt légal : on renvoie la zone la plus recouverte pour
    // signaler le refus (secousse), sinon rien (retour simple).
    for (final e in geo.dropZones.entries) {
      if (e.key == d.from) continue;
      final inter = e.value.intersect(moved);
      if (inter.width > 0 &&
          inter.height > 0 &&
          inter.width * inter.height > moved.width * moved.height * 0.3) {
        return e.key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final look = ref.watch(lookProvider);
    final session = game.session;
    if (session == null) return const SizedBox.expand();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final geo = _geometry(session.state, size, look, game.dealSerial);
        final hintIds = game.hint?.cardIds ?? const <int>{};
        final dealOrigin = _dealOrigin(geo, session.mode);
        final dealOrder = _dealOrder(geo);

        final sprites = <Widget>[];
        final dragged = <Widget>[];
        for (final id in _order) {
          final p = geo.placements[id]!;
          final sprite = Positioned(
            key: ValueKey(id),
            left: 0,
            top: 0,
            child: CardSprite(
              card: p.card,
              target: p.rect,
              look: look,
              dragDelta: _dragDelta,
              dragging: _dragIds.contains(id),
              highlighted: hintIds.contains(id),
              shakeSerial: game.invalidCards.contains(id)
                  ? game.invalidSerial
                  : -1,
              dealSerial: game.dealSerial,
              dealOrigin: dealOrigin,
              dealDelay: Duration(milliseconds: 16 * (dealOrder[id] ?? 0)),
            ),
          );
          (_dragIds.contains(id) ? dragged : sprites).add(sprite);
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _onDown(e, geo, session),
          onPointerMove: (e) => _onMove(e, session),
          onPointerUp: (e) => _onUp(e, geo, session),
          onPointerCancel: _onCancel,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SlotsPainter(
                      geo: geo,
                      state: session.state,
                      color: look.theme.slot,
                      recyclable: session.rules.isLegal(
                        session.state,
                        const RecycleMove(),
                      ),
                    ),
                  ),
                ),
              ),
              if (game.hint?.target case final target?)
                _TargetGlow(
                  key: ValueKey('hint${game.hint!.serial}'),
                  rect: _targetRect(geo, session.state, target),
                  color: look.theme.highlight,
                ),
              ...sprites,
              for (final (id, rect) in _sparkles)
                Positioned.fromRect(
                  key: ValueKey('sparkle$id'),
                  rect: Rect.fromCenter(
                    center: rect.center,
                    width: rect.width * 2.2,
                    height: rect.width * 2.2,
                  ),
                  child: IgnorePointer(
                    child: SparkleBurst(
                      color: look.theme.highlight,
                      size: rect.width * 2.2,
                    ),
                  ),
                ),
              ...dragged,
            ],
          ),
        );
      },
    );
  }

  Rect _targetRect(BoardGeometry geo, GameState state, PileRef target) {
    final pile = state.pile(target);
    final top = pile.top;
    if (top != null) return geo.placements[top.id]!.rect;
    return geo.slots[target]!;
  }

  Rect _dealOrigin(BoardGeometry geo, GameMode mode) {
    final stock = geo.slots[PileRef.stock];
    if (stock != null) return stock;
    final s = geo.cardSize;
    return Rect.fromLTWH(
      (geo.size.width - s.width) / 2,
      geo.size.height - s.height * 0.6,
      s.width,
      s.height,
    );
  }

  /// Rang de distribution : ligne par ligne, de gauche à droite.
  Map<int, int> _dealOrder(BoardGeometry geo) {
    final list =
        geo.placements.values
            .where((p) => p.pile.kind == PileKind.tableau)
            .toList()
          ..sort((a, b) {
            final byRow = a.index.compareTo(b.index);
            return byRow != 0 ? byRow : a.pile.index.compareTo(b.pile.index);
          });
    return {for (var i = 0; i < list.length; i++) list[i].card.id: i};
  }
}

/// Emplacements vides : fondations, cellules, colonnes, pioche.
class _SlotsPainter extends CustomPainter {
  _SlotsPainter({
    required this.geo,
    required this.state,
    required this.color,
    required this.recyclable,
  });

  final BoardGeometry geo;
  final GameState state;
  final Color color;
  final bool recyclable;

  @override
  void paint(Canvas canvas, Size size) {
    final family = state.mode.family;
    for (final e in geo.slots.entries) {
      final ref = e.key;
      final rect = e.value;
      String? label;
      switch (ref.kind) {
        case PileKind.foundation:
          if (family == GameFamily.spider) continue;
          label = 'A';
        case PileKind.tableau:
          label = family == GameFamily.klondike ? 'R' : null;
        case PileKind.freeCell:
          label = null;
        case PileKind.stock:
          // Pioche épuisée : on ne dessine l'emplacement que s'il permet
          // de recycler la défausse, pour ne pas suggérer de cartes restantes.
          if (state.stock.isNotEmpty || !recyclable) continue;
        case PileKind.waste:
          continue;
      }
      canvas.save();
      canvas.translate(rect.left, rect.top);
      SlotPainter(color: color, label: label).paint(canvas, rect.size);
      canvas.restore();
      if (ref.kind == PileKind.stock && recyclable) {
        _recycleIcon(canvas, rect);
      }
    }
  }

  void _recycleIcon(Canvas canvas, Rect rect) {
    final c = rect.center;
    final r = rect.width * 0.22;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, rect.width * 0.05)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi * 0.35,
      math.pi * 1.55,
      false,
      paint,
    );
    final tip = Offset(
      c.dx + r * math.cos(-math.pi * 0.35),
      c.dy + r * math.sin(-math.pi * 0.35),
    );
    final path = Path()
      ..moveTo(tip.dx - r * 0.45, tip.dy - r * 0.2)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - r * 0.1, tip.dy + r * 0.45);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SlotsPainter old) =>
      old.geo != geo || old.color != color || old.recyclable != recyclable;
}

/// Halo pulsé sur la destination d'un indice.
class _TargetGlow extends StatefulWidget {
  const _TargetGlow({super.key, required this.rect, required this.color});

  final Rect rect;
  final Color color;

  @override
  State<_TargetGlow> createState() => _TargetGlowState();
}

class _TargetGlowState extends State<_TargetGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: widget.rect.inflate(3),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.rect.width * 0.12),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35 * _c.value),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
