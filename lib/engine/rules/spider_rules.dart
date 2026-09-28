import '../model/card.dart';
import '../model/deck.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../model/pile.dart';
import '../model/suit.dart';
import '../scoring/live_points.dart';
import 'game_rules.dart';

/// Spider à 1, 2 ou 4 couleurs : 104 cartes, 10 colonnes, 8 suites à former.
final class SpiderRules extends GameRules {
  const SpiderRules(super.mode);

  static const columns = 10;
  static const suitesToComplete = 8;

  @override
  int get cardCount => 104;

  List<Suit> get _suits => switch (mode.suitCount) {
    1 => const [Suit.spades],
    2 => const [Suit.spades, Suit.hearts],
    _ => Suit.values,
  };

  @override
  GameState deal(int seed) {
    final suits = _suits;
    final deck = Deck.build(suits, copies: 8 ~/ suits.length);
    final cards = Deck.shuffled(deck, seed);
    var next = 0;
    final cols = List.generate(columns, (_) => <Card>[]);
    for (var col = 0; col < columns; col++) {
      final size = col < 4 ? 6 : 5;
      for (var k = 0; k < size; k++) {
        cols[col].add(cards[next++].flipped(k == size - 1));
      }
    }
    return GameState(
      mode: mode,
      stock: Pile(PileRef.stock, cards.sublist(next)),
      waste: Pile(PileRef.waste),
      foundations: [
        for (var i = 0; i < suitesToComplete; i++) Pile(PileRef.foundation(i)),
      ],
      tableau: [
        for (var i = 0; i < columns; i++) Pile(PileRef.tableau(i), cols[i]),
      ],
    );
  }

  @override
  bool canPickUp(GameState state, PileRef from, int count) {
    if (from.kind != PileKind.tableau || count < 1) return false;
    final pile = state.pile(from);
    if (pile.length < count) return false;
    return GameRules.isSameSuitRun(pile.takeTop(count));
  }

  @override
  bool isLegal(GameState state, Move move) {
    switch (move) {
      case DrawMove():
        return state.stock.isNotEmpty &&
            state.tableau.every((p) => p.isNotEmpty);
      case RecycleMove():
        return false;
      case TransferMove(:final from, :final to, :final count):
        if (from == to || to.kind != PileKind.tableau) return false;
        if (!canPickUp(state, from, count)) return false;
        final base = state.pile(from).cards[state.pile(from).length - count];
        final top = state.pile(to).top;
        return top == null ||
            (top.faceUp && top.rank.value == base.rank.value + 1);
    }
  }

  @override
  GameState apply(GameState state, Move move) {
    assert(isLegal(state, move), 'Mouvement illégal : $move');
    var next = state;
    var delta = 0;
    switch (move) {
      case DrawMove():
        final dealt = <Pile>[];
        final stock = state.stock;
        for (var i = 0; i < columns; i++) {
          final card = stock.cards[stock.length - 1 - i].flipped(true);
          dealt.add(state.tableau[i].push([card]));
        }
        next = state.withPiles([stock.removeTop(columns), ...dealt]);
      case RecycleMove():
        throw StateError('Pas de recyclage en Spider');
      case TransferMove(:final from, :final to, :final count):
        final (moved, revealed) = transfer(state, from, to, count);
        next = moved;
        if (revealed) delta += LivePoints.reveal;
    }
    // Retire les suites complètes Roi → As de même couleur.
    for (var i = 0; i < columns; i++) {
      final col = next.tableau[i];
      if (col.length < 13) continue;
      final run = col.takeTop(13);
      if (run.first.rank.value != 13 || !GameRules.isSameSuitRun(run)) {
        continue;
      }
      final slot = next.foundations.indexWhere((f) => f.isEmpty);
      var rest = col.removeTop(13);
      if (rest.top != null && !rest.top!.faceUp) {
        rest = rest.revealTop();
        delta += LivePoints.reveal;
      }
      next = next.withPiles([rest, next.foundations[slot].push(run.reversed)]);
      delta += LivePoints.spiderSuite;
    }
    return next.copyWith(points: state.points + delta);
  }

  @override
  bool isWon(GameState state) => state.foundations.every((f) => f.length == 13);

  @override
  List<Move> legalMoves(GameState state) {
    final moves = <Move>[];
    for (var i = 0; i < columns; i++) {
      final col = state.tableau[i];
      for (var count = 1; count <= col.length; count++) {
        final from = PileRef.tableau(i);
        if (!canPickUp(state, from, count)) break;
        for (var j = 0; j < columns; j++) {
          final m = TransferMove(
            from: from,
            to: PileRef.tableau(j),
            count: count,
          );
          if (isLegal(state, m)) moves.add(m);
        }
      }
    }
    if (isLegal(state, const DrawMove())) moves.add(const DrawMove());
    return moves;
  }

  @override
  List<Move> preferTableauTargets(
    GameState state,
    PileRef from,
    int count,
    List<Move> moves,
  ) {
    final pile = state.pile(from);
    final base = pile.cards[pile.length - count];
    final sameSuit = <Move>[];
    final others = <Move>[];
    for (final m in moves) {
      final top = state.pile((m as TransferMove).to).top;
      (top != null && top.suit == base.suit ? sameSuit : others).add(m);
    }
    return [...sameSuit, ...others];
  }

  @override
  List<Move> hintMoves(GameState state) {
    final sameSuitJoin = <Move>[];
    final revealing = <Move>[];
    final toEmpty = <Move>[];
    // Coups vers une colonne vide, utiles seulement quand une colonne vide
    // empêche de distribuer : d'abord sans casser de suite, puis en en
    // détachant le moins de cartes possible.
    final fillEmpty = <Move>[];
    final breakRun = <TransferMove>[];
    final other = <Move>[];
    for (final move in legalMoves(state)) {
      if (move is! TransferMove) continue;
      final col = state.tableau[move.from.index];
      final start = col.length - move.count;
      final base = col.cards[start];
      final below = start > 0 ? col.cards[start - 1] : null;
      final target = state.tableau[move.to.index].top;

      // Déplacements qui ne changent rien : la suite repose déjà sur une
      // carte de valeur supérieure de même couleur.
      final alreadyLinked =
          below != null &&
          below.faceUp &&
          below.rank.value == base.rank.value + 1 &&
          below.suit == base.suit;

      if (target == null) {
        if (below == null) continue;
        if (alreadyLinked) {
          breakRun.add(move);
        } else {
          (below.faceUp ? fillEmpty : toEmpty).add(move);
        }
        continue;
      }
      if (alreadyLinked) continue;
      if (target.suit == base.suit) {
        sameSuitJoin.add(move);
      } else if (below == null || !below.faceUp) {
        revealing.add(move);
      } else if (below.rank.value != base.rank.value + 1) {
        other.add(move);
      }
    }
    final canDeal = isLegal(state, const DrawMove());
    final mustFill = !canDeal && state.stock.isNotEmpty;
    breakRun.sort((a, b) => a.count.compareTo(b.count));
    return [
      ...sameSuitJoin,
      ...revealing,
      ...other,
      ...toEmpty,
      if (canDeal) const DrawMove(),
      if (mustFill) ...fillEmpty,
      if (mustFill) ...breakRun,
    ];
  }
}
