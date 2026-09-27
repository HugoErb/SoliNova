import 'package:solinova/engine/model/card.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/game_state.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/model/rank.dart';
import 'package:solinova/engine/model/suit.dart';

var _nextId = 1000;

/// Carte visible pour construire des plateaux de test.
Card c(int rank, Suit suit, {bool up = true}) =>
    Card(id: _nextId++, suit: suit, rank: Rank.fromValue(rank), faceUp: up);

const s = Suit.spades;
const h = Suit.hearts;
const d = Suit.diamonds;
const cl = Suit.clubs;

/// Construit un plateau sur mesure.
GameState board(
  GameMode mode, {
  List<List<Card>> tableau = const [],
  List<List<Card>> foundations = const [],
  List<Card> stock = const [],
  List<Card> waste = const [],
  List<List<Card>> cells = const [],
  int tableauCount = 7,
  int foundationCount = 4,
  int cellCount = 0,
}) {
  return GameState(
    mode: mode,
    stock: Pile(PileRef.stock, stock),
    waste: Pile(PileRef.waste, waste),
    foundations: [
      for (var i = 0; i < foundationCount; i++)
        Pile(
          PileRef.foundation(i),
          i < foundations.length ? foundations[i] : const [],
        ),
    ],
    tableau: [
      for (var i = 0; i < tableauCount; i++)
        Pile(PileRef.tableau(i), i < tableau.length ? tableau[i] : const []),
    ],
    freeCells: [
      for (var i = 0; i < cellCount; i++)
        Pile(PileRef.freeCell(i), i < cells.length ? cells[i] : const []),
    ],
  );
}

/// Série As → [upTo] d'une couleur, pour remplir une fondation.
List<Card> run(Suit suit, int upTo) => [for (var r = 1; r <= upTo; r++) c(r, suit)];
