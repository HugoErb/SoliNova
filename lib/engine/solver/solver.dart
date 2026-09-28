import '../model/card.dart';
import '../model/game_mode.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../model/pile.dart';
import '../rules/game_rules.dart';

/// Résultat d'une recherche de solution.
final class SolveResult {
  const SolveResult._(
    this.moves, {
    required this.exhausted,
    required this.nodes,
  });

  /// Suite de coups menant à la victoire, ou null si aucune n'a été trouvée.
  final List<Move>? moves;

  /// Vrai si tout l'espace de recherche a été parcouru sans solution :
  /// la position est perdue (aux coups élagués près).
  final bool exhausted;

  /// Nombre de positions développées.
  final int nodes;

  bool get solved => moves != null;
}

/// Recherche une suite de coups gagnante (meilleur d'abord, avec budget).
///
/// Les coups inutiles sont élagués et les positions équivalentes (colonnes
/// ou cellules permutées, cartes identiques du Spider) ne sont visitées
/// qu'une fois. Une solution trouvée est toujours jouable telle quelle.
abstract final class Solver {
  static SolveResult solve(
    GameRules rules,
    GameState start, {
    int maxNodes = 60000,
  }) {
    if (_done(rules, start)) {
      return const SolveResult._([], exhausted: false, nodes: 0);
    }
    final family = start.mode.family;
    final nodes = <_Node>[_Node(start, -1, const [], 0)];
    final seen = <String>{_key(start)};
    final open = _Heap()..push(_score(rules, start), 0);
    var expanded = 0;
    while (open.isNotEmpty) {
      if (expanded >= maxNodes) {
        return SolveResult._(null, exhausted: false, nodes: expanded);
      }
      final index = open.pop();
      final node = nodes[index];
      expanded++;
      for (final move in _candidates(rules, family, node.state)) {
        var next = rules.apply(node.state, move);
        final path = <Move>[move];
        // Les coups sûrs vers la fondation sont joués aussitôt.
        for (
          var auto = rules.nextSafeAutoMove(next);
          auto != null;
          auto = rules.nextSafeAutoMove(next)
        ) {
          next = rules.apply(next, auto);
          path.add(auto);
        }
        if (!seen.add(_key(next))) continue;
        nodes.add(_Node(next, index, path, node.depth + 1));
        if (_done(rules, next)) {
          return SolveResult._(
            _unwind(nodes, nodes.length - 1),
            exhausted: false,
            nodes: expanded,
          );
        }
        open.push(_score(rules, next) - node.depth, nodes.length - 1);
      }
    }
    return SolveResult._(null, exhausted: true, nodes: expanded);
  }

  /// Victoire, ou plus aucune carte hors des fondations (plateaux partiels
  /// des tests et exemples).
  static bool _done(GameRules rules, GameState s) =>
      rules.isWon(s) ||
      (s.stock.isEmpty &&
          s.waste.isEmpty &&
          s.tableau.every((p) => p.isEmpty) &&
          s.freeCells.every((p) => p.isEmpty));

  /// Empreinte exacte d'un plateau (piles à leur place), pour reconnaître
  /// une position déjà résolue.
  static String layoutKey(GameState state) {
    final buf = StringBuffer();
    for (final pile in state.allPiles) {
      for (final c in pile.cards) {
        buf.writeCharCode(_code(c));
      }
      buf.write('|');
    }
    return buf.toString();
  }

  static List<Move> _unwind(List<_Node> nodes, int index) {
    final chunks = <List<Move>>[];
    for (var i = index; i > 0; i = nodes[i].parent) {
      chunks.add(nodes[i].path);
    }
    return [for (final c in chunks.reversed) ...c];
  }

  /// Carte réduite à couleur, valeur et face (les doubles du Spider se
  /// confondent).
  static int _code(Card c) =>
      48 + c.suit.index * 32 + c.rank.value * 2 + (c.faceUp ? 1 : 0);

  static String _pileKey(Pile p) =>
      String.fromCharCodes([for (final c in p.cards) _code(c)]);

  /// Empreinte à l'ordre près des colonnes, cellules et fondations.
  static String _key(GameState s) {
    final cols = [for (final p in s.tableau) _pileKey(p)]..sort();
    final cells = [for (final p in s.freeCells) _pileKey(p)]..sort();
    final founds = [
      for (final p in s.foundations)
        p.isEmpty ? '' : _pileKey(Pile(p.ref, [p.top!])),
    ]..sort();
    return '${_pileKey(s.stock)}/${_pileKey(s.waste)}/${founds.join(',')}/'
        '${cells.join(',')}/${cols.join('|')}';
  }

  // ---------------------------------------------------------------------------
  // Évaluation.

  static int _score(GameRules rules, GameState s) => switch (s.mode.family) {
    GameFamily.klondike => _klondikeScore(s),
    GameFamily.freecell => _freecellScore(s),
    GameFamily.spider => _spiderScore(s),
  };

  static int _hidden(GameState s) =>
      s.tableau.fold(0, (n, p) => n + p.firstFaceUpIndex);

  static int _klondikeScore(GameState s) =>
      s.foundationCardCount * 60 -
      _hidden(s) * 40 -
      s.stock.length -
      s.waste.length * 2;

  static int _freecellScore(GameState s) {
    var score = s.foundationCardCount * 60;
    for (final cell in s.freeCells) {
      if (cell.isEmpty) score += 12;
    }
    for (final col in s.tableau) {
      if (col.isEmpty) {
        score += 25;
        continue;
      }
      // Cartes posées au-dessus d'une carte plus faible : à déplacer.
      var minRank = 14;
      for (final c in col.cards) {
        if (c.rank.value > minRank) score -= 6;
        if (c.rank.value < minRank) minRank = c.rank.value;
      }
    }
    return score;
  }

  static int _spiderScore(GameState s) {
    var score = s.foundationCardCount * 60 - _hidden(s) * 25;
    for (final col in s.tableau) {
      if (col.isEmpty) {
        score += 40;
        continue;
      }
      for (var i = col.firstFaceUpIndex + 1; i < col.length; i++) {
        final a = col.cards[i - 1];
        final b = col.cards[i];
        if (a.rank.value != b.rank.value + 1) {
          score -= 12;
        } else if (a.suit == b.suit) {
          score += 10;
        } else {
          score -= 4;
        }
      }
    }
    return score - s.stock.length;
  }

  // ---------------------------------------------------------------------------
  // Coups candidats.

  static List<Move> _candidates(
    GameRules rules,
    GameFamily family,
    GameState s,
  ) => switch (family) {
    GameFamily.klondike => _klondikeMoves(rules, s),
    GameFamily.freecell => _freecellMoves(rules, s),
    GameFamily.spider => _spiderMoves(rules, s),
  };

  static int _firstEmptyColumn(GameState s) =>
      s.tableau.indexWhere((p) => p.isEmpty);

  static void _toFoundation(
    GameRules rules,
    GameState s,
    PileRef from,
    List<Move> out,
  ) {
    final card = s.pile(from).top;
    if (card == null || !card.faceUp) return;
    final f = rules.foundationFor(s, card);
    if (f != null) out.add(TransferMove(from: from, to: PileRef.foundation(f)));
  }

  static List<Move> _klondikeMoves(GameRules rules, GameState s) {
    final out = <Move>[];
    final empty = _firstEmptyColumn(s);
    _toFoundation(rules, s, PileRef.waste, out);
    for (var i = 0; i < s.tableau.length; i++) {
      _toFoundation(rules, s, PileRef.tableau(i), out);
    }
    void toTableau(PileRef from, int count, Card base) {
      for (var j = 0; j < s.tableau.length; j++) {
        final to = PileRef.tableau(j);
        if (to == from) continue;
        if (s.tableau[j].isEmpty && j != empty) continue;
        final m = TransferMove(from: from, to: to, count: count);
        if (rules.isLegal(s, m)) out.add(m);
      }
    }

    final waste = s.waste.top;
    if (waste != null) toTableau(PileRef.waste, 1, waste);
    for (var i = 0; i < s.tableau.length; i++) {
      final col = s.tableau[i];
      if (col.isEmpty) continue;
      final first = col.firstFaceUpIndex;
      for (var start = first; start < col.length; start++) {
        final base = col.cards[start];
        if (start == first) {
          // Une colonne commençant par un Roi n'a pas à être vidée.
          if (start == 0 && base.rank.isKing) continue;
        } else {
          // Scinder une suite n'est utile que pour libérer la carte dessous.
          if (rules.foundationFor(s, col.cards[start - 1]) == null) continue;
        }
        toTableau(PileRef.tableau(i), col.length - start, base);
      }
    }
    // Reprendre une carte de la fondation pour débloquer une carte.
    for (var f = 0; f < s.foundations.length; f++) {
      final card = s.foundations[f].top;
      if (card == null || card.rank.value < 3) continue;
      for (var j = 0; j < s.tableau.length; j++) {
        final m = TransferMove(
          from: PileRef.foundation(f),
          to: PileRef.tableau(j),
        );
        if (s.tableau[j].isNotEmpty && rules.isLegal(s, m)) out.add(m);
      }
    }
    if (s.stock.isNotEmpty) {
      out.add(const DrawMove());
    } else if (s.waste.isNotEmpty) {
      out.add(const RecycleMove());
    }
    return out;
  }

  static List<Move> _freecellMoves(GameRules rules, GameState s) {
    final out = <Move>[];
    final emptyCol = _firstEmptyColumn(s);
    final emptyCell = s.freeCells.indexWhere((p) => p.isEmpty);
    for (var i = 0; i < s.freeCells.length; i++) {
      _toFoundation(rules, s, PileRef.freeCell(i), out);
    }
    for (var i = 0; i < s.tableau.length; i++) {
      _toFoundation(rules, s, PileRef.tableau(i), out);
    }
    for (var i = 0; i < s.freeCells.length; i++) {
      if (s.freeCells[i].isEmpty) continue;
      for (var j = 0; j < s.tableau.length; j++) {
        if (s.tableau[j].isEmpty && j != emptyCol) continue;
        final m = TransferMove(
          from: PileRef.freeCell(i),
          to: PileRef.tableau(j),
        );
        if (rules.isLegal(s, m)) out.add(m);
      }
    }
    for (var i = 0; i < s.tableau.length; i++) {
      final col = s.tableau[i];
      if (col.isEmpty) continue;
      var runStart = col.length - 1;
      while (runStart > 0 &&
          GameRules.isAlternatingRun(col.cards.sublist(runStart - 1))) {
        runStart--;
      }
      for (var start = runStart; start < col.length; start++) {
        final count = col.length - start;
        for (var j = 0; j < s.tableau.length; j++) {
          if (j == i) continue;
          final target = s.tableau[j];
          // Déplacer toute la colonne vers une colonne vide est inutile.
          if (target.isEmpty && (j != emptyCol || start == 0)) continue;
          final m = TransferMove(
            from: PileRef.tableau(i),
            to: PileRef.tableau(j),
            count: count,
          );
          if (rules.isLegal(s, m)) out.add(m);
        }
      }
      if (emptyCell >= 0) {
        out.add(
          TransferMove(
            from: PileRef.tableau(i),
            to: PileRef.freeCell(emptyCell),
          ),
        );
      }
    }
    return out;
  }

  static List<Move> _spiderMoves(GameRules rules, GameState s) {
    final out = <Move>[];
    final emptyCol = _firstEmptyColumn(s);
    for (var i = 0; i < s.tableau.length; i++) {
      final col = s.tableau[i];
      if (col.isEmpty) continue;
      for (var count = 1; count <= col.length; count++) {
        final from = PileRef.tableau(i);
        if (!rules.canPickUp(s, from, count)) break;
        final start = col.length - count;
        final base = col.cards[start];
        final below = start > 0 ? col.cards[start - 1] : null;
        final restsOnNext =
            below != null &&
            below.faceUp &&
            below.rank.value == base.rank.value + 1;
        for (var j = 0; j < s.tableau.length; j++) {
          if (j == i) continue;
          final target = s.tableau[j];
          if (target.isEmpty) {
            if (j != emptyCol || below == null) continue;
            // Détacher une suite déjà bien posée vers le vide : rarement
            // utile, sauf pour la carte du dessus seule.
            if (restsOnNext && below.suit == base.suit) continue;
          } else {
            final top = target.top!;
            if (top.rank.value != base.rank.value + 1) continue;
            // Déjà posée sur une carte de rang supérieur : seul un passage
            // vers la même couleur (quand la source ne l'est pas) améliore.
            if (restsOnNext &&
                (below.suit == base.suit || top.suit != base.suit)) {
              continue;
            }
          }
          final m = TransferMove(
            from: from,
            to: PileRef.tableau(j),
            count: count,
          );
          if (rules.isLegal(s, m)) out.add(m);
        }
      }
    }
    if (rules.isLegal(s, const DrawMove())) out.add(const DrawMove());
    return out;
  }
}

final class _Node {
  const _Node(this.state, this.parent, this.path, this.depth);

  final GameState state;
  final int parent;
  final List<Move> path;
  final int depth;
}

/// File de priorité (maximum d'abord ; à égalité, le plus récent d'abord).
final class _Heap {
  final _prio = <int>[];
  final _ids = <int>[];

  bool get isNotEmpty => _ids.isNotEmpty;

  bool _above(int a, int b) =>
      _prio[a] > _prio[b] || (_prio[a] == _prio[b] && _ids[a] > _ids[b]);

  void _swap(int a, int b) {
    final p = _prio[a];
    _prio[a] = _prio[b];
    _prio[b] = p;
    final i = _ids[a];
    _ids[a] = _ids[b];
    _ids[b] = i;
  }

  void push(int priority, int id) {
    _prio.add(priority);
    _ids.add(id);
    var i = _ids.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!_above(i, parent)) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final top = _ids.first;
    final last = _ids.length - 1;
    _swap(0, last);
    _prio.removeLast();
    _ids.removeLast();
    var i = 0;
    while (true) {
      final l = 2 * i + 1;
      final r = l + 1;
      var best = i;
      if (l < _ids.length && _above(l, best)) best = l;
      if (r < _ids.length && _above(r, best)) best = r;
      if (best == i) break;
      _swap(i, best);
      i = best;
    }
    return top;
  }
}
