import '../model/card.dart';
import '../model/deck.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../model/pile.dart';
import '../scoring/live_points.dart';
import 'game_rules.dart';

/// Klondike classique, tirage 1 ou 3 cartes, passages illimités.
final class KlondikeRules extends GameRules {
  const KlondikeRules(super.mode);

  int get drawCount => mode.drawCount;

  @override
  int get cardCount => 52;

  @override
  GameState deal(int seed) {
    final cards = Deck.shuffled(Deck.standard(), seed);
    var next = 0;
    final columns = List.generate(7, (_) => <Card>[]);
    for (var row = 0; row < 7; row++) {
      for (var col = row; col < 7; col++) {
        columns[col].add(cards[next++].flipped(col == row));
      }
    }
    return GameState(
      mode: mode,
      stock: Pile(PileRef.stock, cards.sublist(next)),
      waste: Pile(PileRef.waste),
      foundations: [for (var i = 0; i < 4; i++) Pile(PileRef.foundation(i))],
      tableau: [
        for (var i = 0; i < 7; i++) Pile(PileRef.tableau(i), columns[i]),
      ],
    );
  }

  @override
  bool canPickUp(GameState state, PileRef from, int count) {
    if (count < 1) return false;
    final pile = state.pile(from);
    if (pile.length < count) return false;
    return switch (from.kind) {
      PileKind.waste || PileKind.foundation => count == 1,
      PileKind.tableau => GameRules.isAlternatingRun(pile.takeTop(count)),
      _ => false,
    };
  }

  @override
  bool isLegal(GameState state, Move move) {
    switch (move) {
      case DrawMove():
        return state.stock.isNotEmpty;
      case RecycleMove():
        return state.stock.isEmpty && state.waste.isNotEmpty;
      case TransferMove(:final from, :final to, :final count):
        if (from == to || !canPickUp(state, from, count)) return false;
        final base = state.pile(from).cards[state.pile(from).length - count];
        final target = state.pile(to);
        return switch (to.kind) {
          PileKind.foundation =>
            count == 1 &&
                from.kind != PileKind.foundation &&
                canPlaceOnFoundation(target, base),
          PileKind.tableau => _canPlaceOnTableau(target, base),
          _ => false,
        };
    }
  }

  bool _canPlaceOnTableau(Pile target, Card base) {
    final top = target.top;
    if (top == null) return base.rank.isKing;
    return top.faceUp &&
        top.suit.isOppositeColorOf(base.suit) &&
        top.rank.value == base.rank.value + 1;
  }

  @override
  GameState apply(GameState state, Move move) {
    assert(isLegal(state, move), 'Mouvement illégal : $move');
    switch (move) {
      case DrawMove():
        final n = drawCount < state.stock.length
            ? drawCount
            : state.stock.length;
        final drawn = [
          for (var i = 0; i < n; i++)
            state.stock.cards[state.stock.length - 1 - i].flipped(true),
        ];
        return state.withPiles([
          state.stock.removeTop(n),
          state.waste.push(drawn),
        ]);
      case RecycleMove():
        final back = [
          for (final c in state.waste.cards.reversed) c.flipped(false),
        ];
        final penalty = drawCount == 1 ? LivePoints.recycleDraw1 : 0;
        return state.withPiles(
          [state.stock.withCards(back), state.waste.withCards(const [])],
          recycleCount: state.recycleCount + 1,
          points: state.points + penalty,
        );
      case TransferMove(:final from, :final to, :final count):
        final (next, revealed) = transfer(state, from, to, count);
        var delta = revealed ? LivePoints.reveal : 0;
        if (to.kind == PileKind.foundation) delta += LivePoints.toFoundation;
        if (from.kind == PileKind.waste && to.kind == PileKind.tableau) {
          delta += LivePoints.wasteToTableau;
        }
        if (from.kind == PileKind.foundation) {
          delta += LivePoints.foundationToTableau;
        }
        return next.copyWith(points: state.points + delta);
    }
  }

  @override
  bool isWon(GameState state) => state.foundationCardCount == cardCount;

  Iterable<PileRef> _topSources(GameState state) sync* {
    yield PileRef.waste;
    for (var i = 0; i < state.tableau.length; i++) {
      yield PileRef.tableau(i);
    }
  }

  @override
  Move? nextSafeAutoMove(GameState state) {
    for (final from in _topSources(state)) {
      final card = state.pile(from).top;
      if (card == null || !card.faceUp) continue;
      final f = foundationFor(state, card);
      if (f != null && isSafeForFoundation(state, card)) {
        return TransferMove(from: from, to: PileRef.foundation(f));
      }
    }
    return null;
  }

  @override
  bool canAutoComplete(GameState state) =>
      !isWon(state) &&
      state.stock.isEmpty &&
      state.waste.isEmpty &&
      state.tableau.every((p) => p.cards.every((c) => c.faceUp));

  @override
  Move? nextAutoCompleteMove(GameState state) {
    Move? best;
    var bestRank = 99;
    for (final from in _topSources(state)) {
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
    final sources = <PileRef>[
      PileRef.waste,
      for (var i = 0; i < 4; i++) PileRef.foundation(i),
    ];
    for (final from in sources) {
      if (state.pile(from).isEmpty) continue;
      _addTransfers(state, from, 1, moves);
    }
    for (var i = 0; i < 7; i++) {
      final col = state.tableau[i];
      for (var start = col.firstFaceUpIndex; start < col.length; start++) {
        _addTransfers(state, PileRef.tableau(i), col.length - start, moves);
      }
    }
    if (isLegal(state, const DrawMove())) moves.add(const DrawMove());
    if (isLegal(state, const RecycleMove())) moves.add(const RecycleMove());
    return moves;
  }

  void _addTransfers(GameState state, PileRef from, int count, List<Move> out) {
    final targets = <PileRef>[
      for (var i = 0; i < 4; i++) PileRef.foundation(i),
      for (var i = 0; i < 7; i++) PileRef.tableau(i),
    ];
    for (final to in targets) {
      final m = TransferMove(from: from, to: to, count: count);
      if (isLegal(state, m)) out.add(m);
    }
  }

  @override
  List<Move> hintMoves(GameState state) {
    final toFoundation = <Move>[];
    final revealing = <Move>[];
    final fromWaste = <Move>[];
    final useful = <Move>[];
    for (final move in legalMoves(state)) {
      if (move is! TransferMove) continue;
      final from = move.from;
      final to = move.to;
      if (from.kind == PileKind.foundation) continue;
      if (to.kind == PileKind.foundation) {
        toFoundation.add(move);
        continue;
      }
      if (from.kind == PileKind.waste) {
        fromWaste.add(move);
        continue;
      }
      // Tableau vers tableau.
      final col = state.tableau[from.index];
      final start = col.length - move.count;
      if (start == 0) {
        // Vider une colonne n'a d'intérêt que si ce n'est pas déjà un Roi.
        if (!col.cards.first.rank.isKing) useful.add(move);
        continue;
      }
      final below = col.cards[start - 1];
      if (!below.faceUp) {
        revealing.add(move);
      } else if (foundationFor(state, below) != null) {
        // Libère une carte jouable en fondation.
        useful.add(move);
      }
    }
    final result = <Move>[
      ...toFoundation,
      ...revealing,
      ...fromWaste,
      ...useful,
    ];
    if (_stockHasPlayableCard(state)) {
      if (state.stock.isNotEmpty) {
        result.add(const DrawMove());
      } else if (state.waste.isNotEmpty) {
        result.add(const RecycleMove());
      }
    }
    return result;
  }

  /// Vrai si une carte de la pioche ou de la défausse pourrait être jouée
  /// sur le plateau actuel : piocher a alors un intérêt.
  bool _stockHasPlayableCard(GameState state) {
    for (final card in _reachableFromStock(state)) {
      if (foundationFor(state, card) != null) return true;
      for (final col in state.tableau) {
        if (_canPlaceOnTableau(col, card.flipped(true))) return true;
      }
    }
    return false;
  }

  /// Cartes de la pioche et de la défausse qui peuvent arriver sur le dessus
  /// de la défausse, sans jouer d'autre coup. En tirage 3, seule une carte
  /// sur trois est accessible à chaque passage.
  List<Card> _reachableFromStock(GameState state) {
    // Ordre de sortie des cartes de la pioche lors du passage en cours.
    final pass = state.stock.cards.reversed.toList();
    if (drawCount == 1) {
      return [
        ...pass,
        ...state.waste.cards.take(
          state.waste.length > 0 ? state.waste.length - 1 : 0,
        ),
      ];
    }
    // Après recyclage, toutes les cartes sortent dans cet ordre, et chaque
    // passage suivant est identique.
    final cycle = [...state.waste.cards, ...pass];
    return [..._drawnTops(pass), ..._drawnTops(cycle)];
  }

  /// Cartes visibles sur la défausse après chaque tirage de [order].
  Iterable<Card> _drawnTops(List<Card> order) sync* {
    for (var i = 0; i < order.length; i++) {
      if ((i + 1) % drawCount == 0 || i == order.length - 1) yield order[i];
    }
  }
}
