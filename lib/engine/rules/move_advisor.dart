import '../model/card.dart';
import '../model/game_mode.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../model/pile.dart';
import 'game_rules.dart';

/// Une suggestion commune à l'indice et au coup assisté.
final class MoveAdvice {
  const MoveAdvice({
    required this.move,
    required this.instruction,
    required this.reason,
    required this.points,
  });

  final Move move;
  final String instruction;
  final String reason;

  /// Variation réelle des points de jeu, avant le coût de l'aide.
  final int points;
}

/// Évalue les effets des coups pertinents : progression d'abord, points ensuite.
/// Cette estimation locale ne garantit pas une solution jusqu'à la victoire.
abstract final class MoveAdvisor {
  static MoveAdvice? best(
    GameRules rules,
    GameState state, {
    Iterable<GameState> history = const [],
  }) {
    // Évite de facturer des allers-retours vers des plateaux déjà parcourus.
    final visited = history.map(_layout).toSet();
    MoveAdvice? best;
    var bestProgress = -1000000;
    for (final move in rules.hintMoves(state)) {
      final next = rules.apply(state, move);
      if (visited.contains(_layout(next))) continue;
      final (progress, reason) = _evaluate(rules, state, next, move);
      final points = next.points - state.points;
      if (best != null &&
          (progress < bestProgress ||
              (progress == bestProgress && points <= best.points))) {
        continue;
      }
      bestProgress = progress;
      best = MoveAdvice(
        move: move,
        instruction: _instruction(state, move),
        reason: reason,
        points: points,
      );
    }
    return best;
  }

  static (int, String) _evaluate(
    GameRules rules,
    GameState before,
    GameState after,
    Move move,
  ) {
    if (rules.isWon(after)) return (100000, 'Ce coup termine la partie.');
    final spider = before.mode.family == GameFamily.spider;
    var progress = 0;
    final reasons = <String>[];
    final foundationGain =
        after.foundationCardCount - before.foundationCardCount;
    if (spider && foundationGain > 0) {
      progress += 1000 * (foundationGain ~/ 13);
      reasons.add('complète ${foundationGain ~/ 13} suite(s) Roi–As');
    }
    int hidden(GameState s) =>
        s.tableau.expand((p) => p.cards).where((c) => !c.faceUp).length;
    final revealed = hidden(before) - hidden(after);
    if (revealed > 0) {
      progress += 120 * revealed;
      reasons.add(
        revealed == 1
            ? 'révèle une carte cachée'
            : 'révèle $revealed cartes cachées',
      );
    }
    if (move is TransferMove) {
      final source = before.pile(move.from);
      final base = source.cards[source.length - move.count];
      if (move.to.kind == PileKind.foundation) {
        final safe = rules.isSafeForFoundation(before, base);
        progress += safe ? 100 : 20;
        reasons.add(
          safe
              ? 'avance une fondation sans retirer de support utile'
              : 'avance une fondation',
        );
      }
      if (move.from.kind == PileKind.freeCell) {
        progress += 60;
        reasons.add('libère une cellule de réserve');
      }
      final remaining = after.pile(move.from).top;
      if (move.from.kind == PileKind.tableau &&
          remaining != null &&
          source.cards.any((c) => c.id == remaining.id && c.faceUp) &&
          rules.foundationFor(after, remaining) != null &&
          !spider) {
        progress += 80;
        reasons.add('rend ${_card(remaining)} accessible pour une fondation');
      }
      final emptyGain =
          after.tableau.where((p) => p.isEmpty).length -
          before.tableau.where((p) => p.isEmpty).length;
      if (emptyGain > 0) {
        progress += 50 * emptyGain;
        reasons.add('libère une colonne pour les prochains déplacements');
      }
      final links = _links(after) - _links(before);
      if (links > 0) {
        progress += 30 * links;
        reasons.add(
          spider
              ? 'allonge une suite de la même couleur'
              : 'regroupe des cartes en suite décroissante alternée',
        );
      }
      if (spider &&
          before.stock.isNotEmpty &&
          before.tableau.any((p) => p.isEmpty) &&
          after.tableau.every((p) => p.isNotEmpty)) {
        progress += 70;
        reasons.add('permet de distribuer la prochaine rangée');
      } else if (spider &&
          before.stock.isNotEmpty &&
          before.pile(move.to).isEmpty &&
          emptyGain < 0) {
        progress += 20;
        reasons.add('remplit une colonne vide pour préparer la distribution');
      }
      if (move.from.kind == PileKind.waste && reasons.isEmpty) {
        progress += 20;
        reasons.add('met une carte de la défausse en jeu');
      }
      if (reasons.isEmpty) {
        reasons.add('rend la carte située dessous accessible');
      }
    } else if (move is DrawMove) {
      // Les coups constructifs déjà disponibles passent avant une distribution.
      progress -= 100;
      reasons.add(
        spider
            ? 'apporte une nouvelle rangée à jouer'
            : 'avance dans la pioche vers une carte jouable',
      );
    } else {
      progress -= 120;
      reasons.add('redonne accès aux cartes jouables de la défausse');
    }
    return (progress, 'Ce coup ${reasons.join(' et ')}.');
  }

  static int _links(GameState state) {
    var count = 0;
    final spider = state.mode.family == GameFamily.spider;
    for (final pile in state.tableau) {
      for (var i = 1; i < pile.length; i++) {
        final a = pile.cards[i - 1];
        final b = pile.cards[i];
        if (a.faceUp &&
            b.faceUp &&
            a.rank.value == b.rank.value + 1 &&
            (spider ? a.suit == b.suit : a.suit.isOppositeColorOf(b.suit))) {
          count++;
        }
      }
    }
    return count;
  }

  static String _instruction(GameState state, Move move) => switch (move) {
    TransferMove(:final from, :final to, :final count) =>
      'Déplace ${count == 1 ? _card(state.pile(from).top!) : 'la suite de $count cartes à partir de ${_card(state.pile(from).takeTop(count).first)}'} '
          'depuis ${_pile(from)} vers ${_pile(to)}.',
    DrawMove() =>
      state.mode.family == GameFamily.spider
          ? 'Distribue une nouvelle rangée.'
          : 'Pioche ${state.mode.drawCount == 3 ? 'trois cartes' : 'une carte'}.',
    RecycleMove() => 'Remets la défausse dans la pioche.',
  };

  static String _card(Card card) =>
      '${card.rank.label} de ${card.suit.label.toLowerCase()}';

  static String _pile(PileRef pile) => switch (pile.kind) {
    PileKind.tableau => 'la colonne ${pile.index + 1}',
    PileKind.foundation => 'la fondation ${pile.index + 1}',
    PileKind.freeCell => 'la cellule ${pile.index + 1}',
    PileKind.waste => 'la défausse',
    PileKind.stock => 'la pioche',
  };

  static String _layout(GameState state) => state.allPiles
      .map(
        (pile) =>
            pile.cards.map((card) => '${card.id}:${card.faceUp}').join(','),
      )
      .join('|');
}
