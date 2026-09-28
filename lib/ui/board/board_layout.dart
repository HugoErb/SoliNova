import 'dart:math' as math;
import 'dart:ui';

import '../../engine/model/card.dart';
import '../../engine/model/game_mode.dart';
import '../../engine/model/game_state.dart';
import '../../engine/model/pile.dart';

/// Position calculée d'une carte sur le plateau.
final class CardPlacement {
  const CardPlacement({
    required this.card,
    required this.pile,
    required this.index,
    required this.rect,
    required this.z,
  });

  final Card card;
  final PileRef pile;
  final int index;
  final Rect rect;

  /// Ordre d'empilement naturel (plus grand = au-dessus).
  final int z;
}

/// Géométrie complète du plateau pour une taille d'écran et un état donnés.
///
/// Calcul pur, sans widget : la largeur des cartes, les marges et les
/// chevauchements s'adaptent à l'espace réellement disponible, pour que tout
/// tienne dans la largeur et la hauteur de l'écran, sans défilement.
final class BoardGeometry {
  BoardGeometry._({
    required this.size,
    required this.cardSize,
    required this.slots,
    required this.placements,
    required this.dropZones,
    required this.tableauTop,
    required this.minFaceUpOffset,
  });

  final Size size;
  final Size cardSize;

  /// Emplacement de base de chaque pile.
  final Map<PileRef, Rect> slots;
  final Map<int, CardPlacement> placements;

  /// Zones de dépôt pour le glisser-déposer.
  final Map<PileRef, Rect> dropZones;
  final double tableauTop;

  /// Décalage minimal entre deux cartes visibles (lisibilité de l'index).
  final double minFaceUpOffset;

  /// Ratio hauteur / largeur d'une carte.
  static const aspect = 1.42;

  static int columnsFor(GameMode mode) => switch (mode.family) {
    GameFamily.klondike => 7,
    GameFamily.spider => 10,
    GameFamily.freecell => 8,
  };

  static BoardGeometry compute({
    required GameState state,
    required Size size,
    required double Function(double cardWidth) indexStrip,
  }) {
    final mode = state.mode;
    final cols = columnsFor(mode);
    final pad = (size.width * 0.022).clamp(4.0, 12.0);
    final gap = (size.width * (cols >= 10 ? 0.008 : 0.014)).clamp(2.0, 8.0);
    var cardW = (size.width - 2 * pad - gap * (cols - 1)) / cols;
    // Sur un écran très court, la hauteur limite aussi la taille des cartes.
    cardW = math.min(
      cardW,
      size.height * 0.16 / aspect * (cols >= 10 ? 1.1 : 1),
    );
    cardW = math.min(cardW, 96);
    // Si la colonne la plus chargée ne tient pas lisiblement, on réduit
    // légèrement la largeur des cartes (au plus 20 %) plutôt que de
    // masquer les index.
    final baseW = cardW;
    for (var k = 1.0; k >= 0.8; k -= 0.04) {
      cardW = baseW * k;
      if (_fits(state, size, cardW, pad, indexStrip(cardW))) break;
    }
    final cardH = cardW * aspect;
    final usedW = cardW * cols + gap * (cols - 1);
    final left = (size.width - usedW) / 2;
    double colX(num c) => left + c * (cardW + gap);

    final top = pad;
    final rowGap = math.max(8.0, cardH * 0.16);
    final tableauTop = top + cardH + rowGap;
    final strip = indexStrip(cardW);

    final slots = <PileRef, Rect>{};
    final placements = <int, CardPlacement>{};
    final dropZones = <PileRef, Rect>{};
    var z = 0;
    Rect cardAt(double x, double y) => Rect.fromLTWH(x, y, cardW, cardH);

    void place(Pile pile, int index, Rect rect) {
      placements[pile.cards[index].id] = CardPlacement(
        card: pile.cards[index],
        pile: pile.ref,
        index: index,
        rect: rect,
        z: z++,
      );
    }

    void stacked(Pile pile, Rect slot) {
      slots[pile.ref] = slot;
      for (var i = 0; i < pile.length; i++) {
        place(pile, i, slot);
      }
    }

    // Rangée du haut.
    switch (mode.family) {
      case GameFamily.klondike:
        stacked(state.stock, cardAt(colX(0), top));
        final wasteSlot = cardAt(colX(1), top);
        slots[PileRef.waste] = wasteSlot;
        final waste = state.waste;
        final fanCount = mode.drawCount == 1 ? 1 : 3;
        final fanStart = math.max(0, waste.length - fanCount);
        final fanStep = cardW * 0.36;
        for (var i = 0; i < waste.length; i++) {
          final k = i < fanStart ? 0 : i - fanStart;
          place(waste, i, wasteSlot.shift(Offset(k * fanStep, 0)));
        }
        for (var f = 0; f < 4; f++) {
          stacked(state.foundations[f], cardAt(colX(3 + f), top));
        }
      case GameFamily.freecell:
        for (var c = 0; c < 4; c++) {
          stacked(state.freeCells[c], cardAt(colX(c), top));
        }
        for (var f = 0; f < 4; f++) {
          stacked(state.foundations[f], cardAt(colX(4 + f), top));
        }
      case GameFamily.spider:
        // Suites terminées, en éventail compact à gauche.
        for (var f = 0; f < state.foundations.length; f++) {
          stacked(
            state.foundations[f],
            cardAt(colX(0) + f * cardW * 0.32, top),
          );
        }
        // Pioche : une carte par distribution restante, à droite.
        final stock = state.stock;
        final groups = (stock.length / 10).ceil();
        final base = cardAt(colX(cols - 1), top);
        slots[PileRef.stock] = base;
        for (var i = 0; i < stock.length; i++) {
          final g = i ~/ 10;
          place(
            stock,
            i,
            base.shift(Offset(-(groups - 1 - g) * cardW * 0.18, 0)),
          );
        }
    }

    // Tableau.
    final bottomPad = pad;
    final available = size.height - tableauTop - bottomPad;
    final prefDown = cardH * 0.13;
    final minDown = math.max(3.0, cardH * 0.06);
    final prefUp = math.max(strip * 1.12, cardH * 0.27);
    final minUp = strip * 0.9;
    for (var c = 0; c < state.tableau.length; c++) {
      final pile = state.tableau[c];
      final x = colX(c);
      final slot = cardAt(x, tableauTop);
      slots[pile.ref] = slot;
      dropZones[pile.ref] = Rect.fromLTRB(
        x - gap / 2,
        tableauTop - rowGap / 2,
        x + cardW + gap / 2,
        size.height,
      );
      final down = pile.firstFaceUpIndex;
      final up = pile.length - down;
      final (dOff, uOff) = _offsets(
        down: down,
        up: up,
        room: available - cardH,
        prefDown: prefDown,
        minDown: minDown,
        prefUp: prefUp,
        minUp: minUp,
      );
      var y = tableauTop;
      for (var i = 0; i < pile.length; i++) {
        place(pile, i, cardAt(x, y));
        y += pile.cards[i].faceUp ? uOff : dOff;
      }
    }

    // Zones de dépôt de la rangée du haut.
    for (final e in slots.entries) {
      if (e.key.kind == PileKind.foundation ||
          e.key.kind == PileKind.freeCell) {
        dropZones[e.key] = e.value.inflate(gap / 2 + 2);
      }
    }
    if (mode.family == GameFamily.spider) {
      dropZones.removeWhere((k, _) => k.kind == PileKind.foundation);
    }

    return BoardGeometry._(
      size: size,
      cardSize: Size(cardW, cardH),
      slots: slots,
      placements: placements,
      dropZones: dropZones,
      tableauTop: tableauTop,
      minFaceUpOffset: minUp,
    );
  }

  static bool _fits(
    GameState state,
    Size size,
    double cardW,
    double pad,
    double strip,
  ) {
    final cardH = cardW * aspect;
    final room =
        size.height - (pad + cardH + math.max(8.0, cardH * 0.16)) - pad - cardH;
    final minDown = math.max(3.0, cardH * 0.06);
    final minUp = strip * 0.9;
    for (final col in state.tableau) {
      final down = col.firstFaceUpIndex;
      final up = col.length - down;
      if (down * minDown + math.max(0, up - 1) * minUp > room) return false;
    }
    return true;
  }

  /// Décalages (cartes cachées, cartes visibles) pour qu'une colonne tienne
  /// dans [room] : on réduit d'abord l'écart des cartes visibles, puis celui
  /// des cartes cachées, puis les deux proportionnellement.
  static (double, double) _offsets({
    required int down,
    required int up,
    required double room,
    required double prefDown,
    required double minDown,
    required double prefUp,
    required double minUp,
  }) {
    final gapsUp = math.max(0, up - 1);
    if (down * prefDown + gapsUp * prefUp <= room) return (prefDown, prefUp);
    if (gapsUp > 0) {
      final u = (room - down * prefDown) / gapsUp;
      if (u >= minUp) return (prefDown, u);
    }
    if (gapsUp > 0) {
      final u = (room - down * minDown) / gapsUp;
      if (u >= minUp) return (minDown, math.min(u, prefUp));
    } else if (down > 0) {
      final d = room / down;
      if (d >= minDown) return (math.min(d, prefDown), prefUp);
    }
    final total = down * minDown + gapsUp * minUp;
    if (total <= 0) return (minDown, minUp);
    final k = math.max(0.0, room) / total;
    return (minDown * k, minUp * k);
  }

  /// Carte la plus haute sous [point], ou null.
  CardPlacement? hitTest(Offset point) {
    CardPlacement? best;
    for (final p in placements.values) {
      if (p.rect.contains(point) && (best == null || p.z > best.z)) best = p;
    }
    return best;
  }

  /// Pile dont l'emplacement de base contient [point].
  PileRef? slotAt(Offset point) {
    for (final e in slots.entries) {
      if (e.value.contains(point)) return e.key;
    }
    return null;
  }
}
