import '../model/card.dart';
import '../model/deck.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../model/pile.dart';
import '../scoring/live_points.dart';
import 'game_rules.dart';

/// FreeCell : 52 cartes visibles, 8 colonnes, 4 cellules libres.
final class FreeCellRules extends GameRules {
  const FreeCellRules(super.mode);

  static const columns = 8;
  static const cells = 4;

  @override
  int get cardCount => 52;

  @override
  GameState deal(int seed) {
    final cards = Deck.shuffled(Deck.standard(), seed);
    final cols = List.generate(columns, (_) => <Card>[]);
    for (var i = 0; i < cards.length; i++) {
      cols[i % columns].add(cards[i].flipped(true));
    }
    return GameState(
      mode: mode,
      stock: Pile(PileRef.stock),
      waste: Pile(PileRef.waste),
      foundations: [for (var i = 0; i < 4; i++) Pile(PileRef.foundation(i))],
      tableau: [
        for (var i = 0; i < columns; i++) Pile(PileRef.tableau(i), cols[i]),
      ],
      freeCells: [for (var i = 0; i < cells; i++) Pile(PileRef.freeCell(i))],
    );
  }

  /// Nombre maximal de cartes déplaçables d'un coup vers [to].
  int maxMovable(GameState state, {required bool toEmptyColumn}) {
    final freeCells = state.freeCells.where((c) => c.isEmpty).length;
    var emptyColumns = state.tableau.where((c) => c.isEmpty).length;
    if (toEmptyColumn) emptyColumns--;
    return (freeCells + 1) * (1 << emptyColumns);
  }

  @override
  bool canPickUp(GameState state, PileRef from, int count) {
    if (count < 1) return false;
    final pile = state.pile(from);
    if (pile.length < count) return false;
    return switch (from.kind) {
      PileKind.freeCell => count == 1,
      PileKind.tableau =>
        GameRules.isAlternatingRun(pile.takeTop(count)) &&
            count <= maxMovable(state, toEmptyColumn: false),
      _ => false,
    };
  }

  @override
  bool isLegal(GameState state, Move move) {
    if (move is! TransferMove) return false;
    final from = move.from;
    final to = move.to;
    final count = move.count;
    if (from == to) return false;
    final source = state.pile(from);
    if (source.length < count) return false;
    final moved = source.takeTop(count);
    switch (from.kind) {
      case PileKind.freeCell:
        if (count != 1) return false;
      case PileKind.tableau:
        if (!GameRules.isAlternatingRun(moved)) return false;
      default:
        return false;
    }
    final base = moved.first;
    final target = state.pile(to);
    switch (to.kind) {
      case PileKind.foundation:
        return count == 1 && canPlaceOnFoundation(target, base);
      case PileKind.freeCell:
        return count == 1 && target.isEmpty;
      case PileKind.tableau:
        if (count > maxMovable(state, toEmptyColumn: target.isEmpty)) {
          return false;
        }
        final top = target.top;
        return top == null ||
            (top.suit.isOppositeColorOf(base.suit) &&
                top.rank.value == base.rank.value + 1);
      default:
        return false;
    }
  }

  @override
  GameState apply(GameState state, Move move) {
    assert(isLegal(state, move), 'Mouvement illégal : $move');
    final m = move as TransferMove;
    final (next, _) = transfer(state, m.from, m.to, m.count);
    final delta = m.to.kind == PileKind.foundation ? LivePoints.toFoundation : 0;
    return next.copyWith(points: state.points + delta);
  }

  @override
  bool isWon(GameState state) => state.foundationCardCount == cardCount;

  Iterable<PileRef> _sources(GameState state) sync* {
    for (var i = 0; i < cells; i++) {
      yield PileRef.freeCell(i);
    }
    for (var i = 0; i < columns; i++) {
      yield PileRef.tableau(i);
    }
  }

  @override
  Move? nextSafeAutoMove(GameState state) {
    for (final from in _sources(state)) {
      final card = state.pile(from).top;
      if (card == null) continue;
      final f = foundationFor(state, card);
      if (f != null && isSafeForFoundation(state, card)) {
        return TransferMove(from: from, to: PileRef.foundation(f));
      }
    }
    return null;
  }

  /// Fin automatique quand chaque colonne est triée en ordre décroissant :
  /// il n'y a plus aucun blocage possible.
  @override
  bool canAutoComplete(GameState state) {
    if (isWon(state)) return false;
    for (final col in state.tableau) {
      for (var i = 1; i < col.length; i++) {
        if (col.cards[i - 1].rank.value < col.cards[i].rank.value) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Move? nextAutoCompleteMove(GameState state) {
    Move? best;
    var bestRank = 99;
    for (final from in _sources(state)) {
      final card = state.pile(from).top;
      if (card == null) continue;
      final f = foundationFor(state, card);
      if (f != null && card.rank.value < bestRank) {
        best = TransferMove(from: from, to: PileRef.foundation(f));
        bestRank = card.rank.value;
      }
    }
    return best;
  }

  @override
  List<Move> legalMoves(GameState state) {
    final moves = <Move>[];
    final targets = <PileRef>[
      for (var i = 0; i < 4; i++) PileRef.foundation(i),
      for (var i = 0; i < columns; i++) PileRef.tableau(i),
      for (var i = 0; i < cells; i++) PileRef.freeCell(i),
    ];
    for (final from in _sources(state)) {
      final pile = state.pile(from);
      final maxCount = from.kind == PileKind.freeCell
          ? (pile.isEmpty ? 0 : 1)
          : pile.length;
      for (var count = 1; count <= maxCount; count++) {
        if (!GameRules.isAlternatingRun(pile.takeTop(count))) break;
        for (final to in targets) {
          final m = TransferMove(from: from, to: to, count: count);
          if (isLegal(state, m)) moves.add(m);
        }
      }
    }
    return moves;
  }

  @override
  List<Move> hintMoves(GameState state) {
    final toFoundation = <Move>[];
    final fromCell = <Move>[];
    final productive = <Move>[];
    final toEmpty = <Move>[];
    final toCell = <Move>[];
    // Une seule cellule cible suffit pour les indices.
    var cellTargetSeen = false;
    for (final move in legalMoves(state)) {
      move as TransferMove;
      final from = move.from;
      final to = move.to;
      if (to.kind == PileKind.foundation) {
        toFoundation.add(move);
        continue;
      }
      if (from.kind == PileKind.freeCell) {
        if (to.kind == PileKind.tableau) fromCell.add(move);
        continue;
      }
      final col = state.tableau[from.index];
      final start = col.length - move.count;
      final below = start > 0 ? col.cards[start - 1] : null;
      final linked =
          below != null &&
          below.suit.isOppositeColorOf(col.cards[start].suit) &&
          below.rank.value == col.cards[start].rank.value + 1;
      if (to.kind == PileKind.freeCell) {
        // Utile seulement si la carte libérée va en fondation.
        if (!cellTargetSeen &&
            move.count == 1 &&
            below != null &&
            foundationFor(state, below) != null) {
          toCell.add(move);
          cellTargetSeen = true;
        }
        continue;
      }
      if (linked) continue;
      if (state.tableau[to.index].isEmpty) {
        if (start > 0) toEmpty.add(move);
      } else {
        productive.add(move);
      }
    }
    return [...toFoundation, ...fromCell, ...productive, ...toCell, ...toEmpty];
  }
}
