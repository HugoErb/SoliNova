import '../model/card.dart';
import '../model/game_mode.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../model/pile.dart';

/// Contrat commun à toutes les variantes de Solitaire.
///
/// Les règles sont sans état : elles valident et appliquent des mouvements sur
/// un [GameState] immuable. Ajouter une variante (Pyramid, TriPeaks, Yukon…)
/// revient à implémenter cette classe et à l'enregistrer dans le registre.
abstract base class GameRules {
  const GameRules(this.mode);

  final GameMode mode;

  /// Nombre total de cartes de la variante.
  int get cardCount;

  /// Distribution initiale déterministe pour une graine donnée.
  GameState deal(int seed);

  /// Vrai si [move] respecte strictement les règles.
  bool isLegal(GameState state, Move move);

  /// Applique un mouvement légal, avec ses effets automatiques
  /// (retournement de carte, suite complète en Spider…).
  GameState apply(GameState state, Move move);

  /// Vrai si le joueur peut saisir les [count] cartes du dessus de [from].
  bool canPickUp(GameState state, PileRef from, int count);

  bool isWon(GameState state);

  /// Mouvement vers une fondation sans risque, joué automatiquement si
  /// l'option « déplacement automatique » est active.
  Move? nextSafeAutoMove(GameState state) => null;

  /// Vrai quand la fin de partie peut être terminée automatiquement.
  bool canAutoComplete(GameState state) => false;

  /// Prochain mouvement de la terminaison automatique.
  Move? nextAutoCompleteMove(GameState state) => null;

  /// Tous les mouvements légaux (utile pour les indices et les tests).
  List<Move> legalMoves(GameState state);

  /// Mouvements pertinents pour un indice, du plus utile au moins utile.
  /// Ne regarde qu'un coup à l'avance.
  List<Move> hintMoves(GameState state);

  /// Meilleur mouvement pour un toucher sur les [count] cartes du dessus de
  /// [from]. Priorité à la fondation si [foundationOnly] ou si possible.
  Move? bestMoveFor(
    GameState state,
    PileRef from,
    int count, {
    bool foundationOnly = false,
  }) {
    if (!canPickUp(state, from, count)) return null;
    final candidates = <Move>[
      if (count == 1)
        for (var i = 0; i < state.foundations.length; i++)
          TransferMove(from: from, to: PileRef.foundation(i)),
    ];
    if (!foundationOnly) {
      final nonEmpty = <Move>[];
      final empty = <Move>[];
      final order = _tableauOrderFrom(state, from);
      for (final i in order) {
        final to = PileRef.tableau(i);
        if (to == from) continue;
        final m = TransferMove(from: from, to: to, count: count);
        (state.tableau[i].isEmpty ? empty : nonEmpty).add(m);
      }
      candidates
        ..addAll(preferTableauTargets(state, from, count, nonEmpty))
        ..addAll(_uselessEmptyMove(state, from, count) ? const [] : empty);
      if (count == 1) {
        for (var i = 0; i < state.freeCells.length; i++) {
          if (from.kind == PileKind.freeCell) break;
          candidates.add(TransferMove(from: from, to: PileRef.freeCell(i)));
        }
      }
    }
    for (final m in candidates) {
      if (isLegal(state, m)) return m;
    }
    return null;
  }

  /// Permet à une variante de réordonner les colonnes cibles (ex. Spider
  /// préfère une carte de même couleur).
  List<Move> preferTableauTargets(
    GameState state,
    PileRef from,
    int count,
    List<Move> moves,
  ) => moves;

  /// Parcourt les colonnes en partant de la plus proche de la source.
  List<int> _tableauOrderFrom(GameState state, PileRef from) {
    final n = state.tableau.length;
    final origin = from.kind == PileKind.tableau ? from.index : 0;
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final da = (a - origin).abs();
        final db = (b - origin).abs();
        return da != db ? da.compareTo(db) : a.compareTo(b);
      });
    return order;
  }

  /// Déplacer une colonne entière vers une colonne vide ne sert à rien.
  bool _uselessEmptyMove(GameState state, PileRef from, int count) =>
      from.kind == PileKind.tableau &&
      state.tableau[from.index].length == count;

  // ---------------------------------------------------------------------------
  // Outils partagés par les variantes.

  /// Déplace [count] cartes et retourne la nouvelle carte du dessus de la
  /// source si elle est cachée. Renvoie aussi si une carte a été révélée.
  (GameState, bool) transfer(
    GameState state,
    PileRef from,
    PileRef to,
    int count, {
    bool revealSource = true,
  }) {
    final source = state.pile(from);
    final moved = source.takeTop(count);
    var newSource = source.removeTop(count);
    var revealed = false;
    if (revealSource &&
        from.kind == PileKind.tableau &&
        newSource.top != null &&
        !newSource.top!.faceUp) {
      newSource = newSource.revealTop();
      revealed = true;
    }
    final target = state.pile(to).push(moved);
    return (state.withPiles([newSource, target]), revealed);
  }

  /// Fondation pouvant recevoir [card] (règle classique : même couleur,
  /// valeur croissante depuis l'As), ou null.
  int? foundationFor(GameState state, Card card) {
    int? emptyIndex;
    for (var i = 0; i < state.foundations.length; i++) {
      final f = state.foundations[i];
      final top = f.top;
      if (top == null) {
        emptyIndex ??= i;
      } else if (top.suit == card.suit &&
          top.rank.value + 1 == card.rank.value) {
        return i;
      }
    }
    return card.rank.isAce ? emptyIndex : null;
  }

  bool canPlaceOnFoundation(Pile foundation, Card card) {
    final top = foundation.top;
    if (top == null) return card.rank.isAce;
    return top.suit == card.suit && top.rank.value + 1 == card.rank.value;
  }

  /// Plus haute valeur posée en fondation pour une couleur (0 si aucune).
  int foundationRank(GameState state, Card card) {
    var best = 0;
    for (final f in state.foundations) {
      final top = f.top;
      if (top != null && top.suit == card.suit) best = top.rank.value;
    }
    return best;
  }

  /// Règle classique du « coup sûr » vers la fondation : la carte ne pourra
  /// plus servir de support dans le tableau.
  bool isSafeForFoundation(GameState state, Card card) {
    if (card.rank.value <= 2) return true;
    var minOpposite = 13;
    var opposites = 0;
    for (final f in state.foundations) {
      final top = f.top;
      if (top != null && top.suit.isOppositeColorOf(card.suit)) {
        opposites++;
        if (top.rank.value < minOpposite) minOpposite = top.rank.value;
      }
    }
    if (opposites < 2) return false;
    return minOpposite >= card.rank.value - 1;
  }

  /// Suite alternée décroissante (Klondike, FreeCell).
  static bool isAlternatingRun(List<Card> cards) {
    for (var i = 1; i < cards.length; i++) {
      final a = cards[i - 1];
      final b = cards[i];
      if (!a.faceUp || !b.faceUp) return false;
      if (!a.suit.isOppositeColorOf(b.suit)) return false;
      if (a.rank.value != b.rank.value + 1) return false;
    }
    return cards.isEmpty || cards.first.faceUp;
  }

  /// Suite décroissante de même couleur (Spider).
  static bool isSameSuitRun(List<Card> cards) {
    for (var i = 1; i < cards.length; i++) {
      final a = cards[i - 1];
      final b = cards[i];
      if (!a.faceUp || !b.faceUp) return false;
      if (a.suit != b.suit) return false;
      if (a.rank.value != b.rank.value + 1) return false;
    }
    return cards.isEmpty || cards.first.faceUp;
  }
}
